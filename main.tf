variable "region" {
  type = "string"
  default = "eu-west-1"
}

variable "domain_name" {
  type = "string"
}

variable "hosted_zone_id" {
  type = "string"
}

provider "aws" {
  region = "${var.region}"
}

resource "aws_iam_role" "asg_ddns_lambda_role" {
  name = "asg_ddns_lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "asg_ddns_lambda_policy" {
  name = "asg_ddns_lambda_policy"
  role = "${aws_iam_role.asg_ddns_lambda_role.id}"
  policy = <<EOF
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
EOF
}

resource "aws_sns_topic" "asg_notification_topic" {
  name = "asg_notification_topic"
}

resource "aws_lambda_function" "asg_ddns_lambda" {
    function_name = "asg_ddns_lambda"
    handler = "asg_ddns.lambda_handler"
    runtime = "python3.6"
    filename = "asg_ddns.zip"
    source_code_hash = "${base64sha256(file("asg_ddns.zip"))}"
    role = "${aws_iam_role.asg_ddns_lambda_role.arn}"
    environment {
        variables = {
            domain_name = "${var.domain_name}"
            hosted_zone_id = "${var.hosted_zone_id}"
        }
  }
}

resource "aws_sns_topic_subscription" "asg_ddns_lambda_asg_notification_subscription" {
  topic_arn = "${aws_sns_topic.asg_notification_topic.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.asg_ddns_lambda.arn}"
}

resource "aws_lambda_permission" "waws_ddns_lambda_sns_permission" {
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.asg_ddns_lambda.arn}"
    principal = "sns.amazonaws.com"
    source_arn = "${aws_sns_topic.asg_notification_topic.arn}"
}
