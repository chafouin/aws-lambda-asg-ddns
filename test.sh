#!/bin/bash
#
# Test script for asg-ddns lambda function.
# Send a message containing the ASG scaling notification to SNS topic that
# will trigger the lambda function.
#
# ./test.sh <sns_topic_arn> <asg_name> [launch|terminate|test]
#

TOPIC_ARN="$1"
ASG_NAME="$2"

if [ "$3" == "launch" ]; then
  ASG_EVENT="autoscaling:EC2_INSTANCE_LAUNCH"
elif [ "$3" == "terminate" ]; then
  ASG_EVENT="autoscaling:EC2_INSTANCE_TERMINATE"
else
  ASG_EVENT="autoscaling:TEST_NOTIFICATION"
fi

SNS_REQUEST="{\"AutoScalingGroupName\":\"${ASG_NAME}\",\"Event\":\"${ASG_EVENT}\"}"

echo "Send ${ASG_EVENT} message on behalf of the ASG ${ASG_NAME} to SNS topic ${TOPIC_ARN}"

aws sns publish --topic-arn "$TOPIC_ARN" --message "$SNS_REQUEST"
