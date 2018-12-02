# -*- coding: utf-8 -*-

"""
AWS Lambda function use to update a Route53 DNS record with the ip addesses of
all the instances of an AutoScaling Group. If an instance joins the ASG, its IP
will be added to the record. If an instance is terminated, its IP will be removed
to the record. The ASG will send a notification to an SNS topic that will trigger
this lambda function.
"""

import json
import logging
import os

import boto3

_ASG_CLIENT = None
_EC2_RESOURCE = None
_R53_CLIENT = None

LOGGER = logging.getLogger(name=__name__)
LOGGER.setLevel(logging.INFO)


def _get_asg_client():
    global _ASG_CLIENT
    if _ASG_CLIENT is None:
        _ASG_CLIENT = boto3.client('autoscaling')
    return _ASG_CLIENT


def _get_ec2_resource():
    global _EC2_RESOURCE
    if _EC2_RESOURCE is None:
        _EC2_RESOURCE = boto3.resource('ec2')
    return _EC2_RESOURCE


def _get_r53_client():
    global _R53_CLIENT
    if _R53_CLIENT is None:
        _R53_CLIENT = boto3.client('route53')
    return _R53_CLIENT


def list_autoscaling_ip(autoscaling_group_name):
    """
    Create the list of ip of the instances located in a given AutoScaling group.

    :param autoscaling_group_name: the name given to an ASG
    :return: list of IP
    """
    LOGGER.info('Building list of ips from instances in autoscaling group %s', autoscaling_group_name)
    ip_list = []
    filters = [{
        'Name': 'tag:Name',
        'Values': [tag['Value'] for tag in _get_asg_client().describe_auto_scaling_groups(
            AutoScalingGroupNames=[autoscaling_group_name])['AutoScalingGroups'][0]['Tags'] if tag['Key'] == "Name"]
    }]
    for instance in _get_ec2_resource().instances.filter(Filters=filters):
        if instance.state['Name'] == 'running' or instance.state['Name'] == 'pending':
            LOGGER.info('Adding ip %s from instance %s to the list', instance.private_ip_address, instance.id)
            ip_list.append({'Value': instance.private_ip_address})
    return ip_list


def change_route53_record(hosted_zone_id, domain_name, ip_list):
    """
    Update a Route53 record in a given hosted zone with a given IP list. Delete the record if the ip list is empty

    :param hosted_zone_id: name of the Route53 hosted zone where the Route53 record is located
    :param domain_name: domain name that should be included in the Route53 record
    :param ip_list: list of ip that should be included in the Route53 record
    :return: 0 if successful, 1 if error
    """
    action = 'UPSERT'
    resource_records_sets = {
        'Name': domain_name,
        'Type': 'A',
        'ResourceRecords': ip_list,
        'TTL': 300
    }
    if not ip_list:
        LOGGER.info('No instance in the autoscaling group: removing Route53 record for domain %s from hosted zone %s',
                    domain_name,
                    hosted_zone_id)
        action = 'DELETE'
        list_resource_record_sets = _get_r53_client().list_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            StartRecordType='A',
            StartRecordName=domain_name,
            MaxItems="1")
        if list_resource_record_sets['ResourceRecordSets'] \
                and list_resource_record_sets['ResourceRecordSets'][0]['Name'] in domain_name:
            resource_records_sets = list_resource_record_sets['ResourceRecordSets'][0]
        else:
            raise RuntimeError('Invalid Route53 record set for domain %s on hosted zone %s' % domain_name,
                               hosted_zone_id)
    _get_r53_client().change_resource_record_sets(
        HostedZoneId=hosted_zone_id,
        ChangeBatch={
            'Changes': [
                {
                    'Action': action,
                    'ResourceRecordSet': resource_records_sets
                }
            ]
        }
    )
    LOGGER.info('Route53 record for domain %s updated on hosted zone %s with the ips: %s',
                domain_name,
                hosted_zone_id,
                ip_list)
    return 0


def lambda_handler(event, context):
    """
    Entrypoint function when the module is called as a lambda function.

    :return: change_route53_record function return value, 0 if successful, 1 if error
    """
    LOGGER.info("Autoscaling event receive : %s", event)
    message = json.loads(event['Records'][0]['Sns']['Message'])
    if (message['Event'] == 'autoscaling:EC2_INSTANCE_LAUNCH'
            or message['Event'] == 'autoscaling:EC2_INSTANCE_TERMINATE'):
        LOGGER.info("Starting Route53 record update")
        return change_route53_record(os.environ['hosted_zone_id'],
                                     os.environ['domain_name'],
                                     list_autoscaling_ip(message['AutoScalingGroupName']))
    print("Ignoring event")
    return 0
