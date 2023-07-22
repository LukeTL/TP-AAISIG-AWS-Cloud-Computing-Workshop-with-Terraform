# START OF PROJECT B

# Creating the s3 bucket
resource "aws_s3_bucket" "bucket" {

  # For the sake of the workshop, a random string of length 16 will be the name of the bucket
  # Note: The bucket name will be different after every "terraform apply"

  # Reasoning: The name of every s3 bucket must be universally unique
  # If you receive a bucket name error, it is likely due to this fun fact
  bucket = "${random_string.random_string_for_bucket.result}-bucket"
}

# Creating the main message queue where the messages sent through bucket notifications will be stored
resource "aws_sqs_queue" "queue" {

  # The name of the main queue will literally just be "queue" so don't be confused
  name = "queue"

  # The duration of which the messages will stay in the queue before automatic disposal is set to 80 thousand seconds
  # For this workshop you don't really need to care about this
  message_retention_seconds = 80000

  # Visibility refers to the duration the messages stays invisible after they have been received by the consumer
  # After 30 seconds, the messages which have failed to be deleted from the queue will re-appear to be processed again
  visibility_timeout_seconds = 30

  # The redrive policy defines the max number of receives a message can have before it is sent to the dead letter queue
  # In this case, each message can be received up to a max of 2 before being sent to the dead letter queue
  redrive_policy = jsonencode({
    "deadLetterTargetArn" = aws_sqs_queue.dead_letter_queue.arn,
    "maxReceiveCount" = 2
  })
}

# Creating the Dead Letter Queue
# This will essential store all the messages which have failed processing twice in the main queue
resource "aws_sqs_queue" "dead_letter_queue" {
  name = "queue-DLQ"

  # Same retension and visbility duration 
  message_retention_seconds = 80000
  visibility_timeout_seconds = 30
}

# Setting up the bucket notifications
# When a new .txt file is added into the bucket, a message containing the details of the event will be sent to the main queue
# When a .txt file is delete from the bucket, a message containg the details of the event will be sent to the main queue 
resource "aws_s3_bucket_notification" "bucket_notification" {
  # Specifying what bucket to append the notification configuration to
  bucket = aws_s3_bucket.bucket.id

  # Specifying what bucket actions will trigger the sending of the messages to the queue
  queue {
    queue_arn     = aws_sqs_queue.queue.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]

    # This notification only be triggered by actions involving text files
    filter_suffix = ".txt"
  }
}

# Creation of the SNS Topic
resource "aws_sns_topic" "sns_topic" {
  name = "workshop_topic"
}

# Add a subscriber to the above topic
# Every time a message is published to the topic, all subscribers associated will perform their specified actions
# In this subscription, an email containing the message contents will be sent to the indicated email address
# IMPORTANT: CHECK YOUR SCHOOL OUTLOOK. There will be an email from aws. Open the link and accept the subscription
resource "aws_sns_topic_subscription" "subscription" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol = "email"
  endpoint = var.school_email
}

# Zips the python file in the directory and stores it within the same directory under a different name
# We will be loading this python file into the lambda function below
data "archive_file" "python_lambda_codes" {
  type = "zip"
  source_file = "./lambda_function.py"
  output_path = "./lambda.zip"
}

# Creating our python lambda polling function
# When ran, this lambda function will poll messages from the queue and selectively process them
# Messages concerning the creation of a new text file will cause the lambda to send a message to the SNS topic
# Messages concerning the deletion of a text file will not be processed ON PURPOSE, to show the capabilities of the dead letter queue
resource "aws_lambda_function" "polling_function" {
  function_name =  "polling_function"
  role = aws_iam_role.lambda_role.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.8"
  timeout = 30

  # This load the zip file into the lambda function
  filename = "./lambda.zip"

  # Stores the hash of the lambda function in the terraform state file
  # When the hash of the current zip differs from the old zip, it will update the codes in the live lambda function
  source_code_hash = data.archive_file.python_lambda_codes.output_base64sha256
}

# Creating the lambda CRON rule
# This is what will activate our lambda to poll the messages
# The rule is set to activate every 1 minute
resource "aws_cloudwatch_event_rule" "lambda_cron_rule" {
  name = "lambda_cron_rule"
  schedule_expression = "rate(1 minute)"
}

# This section is just to append the rule to our polling lambda function
resource "aws_cloudwatch_event_target" "lambda_cron_target" {
  rule = aws_cloudwatch_event_rule.lambda_cron_rule.name
  target_id = "lambda_cron_target"
  arn = aws_lambda_function.polling_function.arn
}
