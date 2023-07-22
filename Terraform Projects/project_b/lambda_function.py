import json
import boto3

# Getting the clients for sns and sqs to perform their related commands
sns = boto3.client('sns')
sqs = boto3.client('sqs')

# TLDR: Anything inside of this handler will be run
def lambda_handler(event, context):

    # Getting the created topic amazon resource number (arn) using the topic's name
    # Expected output: arn:aws:sns:<region>:<account-number>:<topic-name>
    sns_response = sns.list_topics()

    for topic in sns_response["Topics"]:
        if topic["TopicArn"].split(":")[-1] == "workshop_topic":
            topic_arn = topic["TopicArn"]
        else:
            pass
    
    # Getting the url of the main queue using the main queue's name
    # Expected output: https://sqs.<region>.amazonaws.com/<account-number>/<queue-name>
    queue_url = sqs.get_queue_url(QueueName="queue")["QueueUrl"]

    # Polling/receving the messages from the main queue
    # We can obtain a max of 10 messages at a time
    # If there are no messages in the queue, the lambda function would wait 5 seconds for incoming messages till it ends its execution
    sqs_response = sqs.receive_message(
            QueueUrl = queue_url,
            MaxNumberOfMessages = 10,
            WaitTimeSeconds = 5
    )

    # Getting the "Messages" portion of the output
    # If "Messages" portions does not exist, return empty list
    messages = sqs_response.get('Messages', [])

    # If there are not messages, return log of "No messages"
    if not messages:
        return {
            'statusCode' : 200,
            'body' : "No Messages"
        }
    
    # Looping through the messages
    for message in messages:

        # Converting "Body" portion of message from JSON string to JSON
        message_json_string = message["Body"]
        message_json = json.loads(message_json_string)

        # Logging to CloudWatch Logs
        print(message_json)

        # This if statement is to counter the test event which is unavoidably created when setting up bucket notifications
        # When test event is detected -> Delete the message from the queue
        if "Event" in message_json:
            sqs.delete_message(
                    QueueUrl = queue_url,
                    ReceiptHandle = message['ReceiptHandle']
                )
            print("Handled S3 notifcation test event")

        # If it is not the test event, flow will continue here
        else:
            # Getting event name of the message
            notif_type = message_json["Records"][0]["eventName"]
            
            # If its an object creation action, go here
            if notif_type == "ObjectCreated:Put":

                # Sending email
                sns.publish(TopicArn = topic_arn, Message = "ALERT: Object created in bucket")
                # Deleting the message after the email is sent
                sqs.delete_message(
                    QueueUrl = queue_url,
                    ReceiptHandle = message['ReceiptHandle']
                )
                print("Successfully publish to SNS")
            # Every action other than object creation goes here
            else:
                # Does not do any deletion, the messages will appear visible in the queue again after 30 seconds to be reprocessed again until it ends up in the DLQ
                print("Delete event detected, message will appear visible in the queue again after 30 seconds to be reprocessed again until it ends up in the DLQ")
                pass
    
    return "Successfully Polled"


