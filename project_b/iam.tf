/** IAM STUFF FOR SQS **/

# Data containing the Resource-based policy to allow messages to be sent to the main queue from the specified workshop bucket
data "aws_iam_policy_document" "queue_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.bucket.arn]
    }
  }
}

# Attachment of resource-based policy onto the main SQS queue
resource "aws_sqs_queue_policy" "policy_attachment" {
  queue_url = aws_sqs_queue.queue.id
  policy = data.aws_iam_policy_document.queue_policy.json
}

#---------------------------------------------------------------------

/** IAM STUFF FOR LAMBDA **/

# Data containing the Trust-based policy which allows lambda to assume the create lambda role
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {

    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]

  }
}

# Creation of lambda role, which includes the attachment of the Trust-based policy
resource "aws_iam_role" "lambda_role" {
  name = "lambda_workshop_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

# Data containing the IAM Policy to be appended to the created lambda role
# This policy allows all the specific actions the lambda function needs to carry out the project
data "aws_iam_policy_document" "lambda_role_policy_data" {
  statement {
    effect = "Allow"
    actions = ["SNS:Publish"]
    resources = [aws_sns_topic.sns_topic.arn]
  }

  statement {
    effect = "Allow"
    actions = ["SNS:ListTopics"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = ["sqs:ReceiveMessage", "sqs:GetQueueUrl", "sqs:DeleteMessage"]
    resources = [aws_sqs_queue.queue.arn]
  }

  statement {
    effect = "Allow"
    actions = ["logs:CreateLogGroup"]
    resources = [ "arn:aws:logs:us-east-1:${var.aws_account_number}" ]
  }

  statement {
    effect = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:us-east-1:${var.aws_account_number}:log-group:/aws/lambda/polling_function:*"]
  }

}

# Creation of the IAM Policy for the lambda role using the data directly above
resource "aws_iam_policy" "lambda_role_policy" {
  name = "workshop_lambda_policy"
  policy = data.aws_iam_policy_document.lambda_role_policy_data.json
}

# Attachment of the IAM Policy (meant for the lambda role) to the lambda role
resource "aws_iam_role_policy_attachment" "attach_policy_to_lambda_role" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_role_policy.arn
}

# Allows the invoking of the lambda function using Cloudwatch
resource "aws_lambda_permission" "cloudwatch_permission" {
  statement_id  = "AllowCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.polling_function.function_name
  principal     = "logs.us-east-1.amazonaws.com"
}

# Allows the invoking of the lambda function using Eventbridge
resource "aws_lambda_permission" "allow_eventbridge_to_invoke_lambda" {
  statement_id = "AllowEventBridgeInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.polling_function.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.lambda_cron_rule.arn
}