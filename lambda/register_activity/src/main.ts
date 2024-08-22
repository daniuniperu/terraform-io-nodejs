import { DynamoDB } from "aws-sdk";
import { DynamoDBStreamEvent, DynamoDBStreamHandler } from "aws-lambda";

export const handler: DynamoDBStreamHandler = async (
  event: DynamoDBStreamEvent
): Promise<any> => {
  const dynamoDB = new DynamoDB.DocumentClient();

  console.log("Received event:", JSON.stringify(event, null, 2));

  for (const record of event.Records) {
    if (record.eventName === "INSERT" && record.dynamodb?.NewImage) {
      const { transaction_id: transId, timestamp } = record.dynamodb.NewImage;

      const params = {
        TableName: process.env.ACTIVITY_TABLE!,
        Item: {
          activity_id: `${transId.S}-${Date.now()}`,
          transaction_id: transId.S,
          date: timestamp.S,
        },
      };

      await dynamoDB.put(params).promise();
    }
  }

  return {
    statusCode: 200,
    message: "Activity registered successfully",
  };
};
