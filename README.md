# asg-ddns AWS Lambda function

## Description

AWS Lambda function use to update a Route53 DNS record with the ip addresses of
all the instances of an AutoScaling Group. If an instance joins the ASG, its IP
will be added to the DNS record. If an instance is terminated, its IP will be removed
to the DNS record. The ASG will send a notification to an SNS topic that will trigger
this lambda function.

## Dependencies

* Python 3.4+
* boto3

## Deployment

The lambda IAM role must have at least the following policy attached:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "ec2:DescribeInstances"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "route53:ListResourceRecordSets",
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": "arn:aws:route53:::hostedzone/*",
            "Effect": "Allow"
        }
    ]
}
```

A Terraform template is provided if you want to try it out. It will deploy a SNS topic and the lambda
function. You can then edit an existing AutoScaling group to send notification to the SNS topic when
an instance is created or deleted.

A test script is provided to try the lambda function after deployment, sending a SNS notification on
behalf of an AutoScaling Group.

```
./test.sh launch <sns_topic_arn> <asg_name>
```
