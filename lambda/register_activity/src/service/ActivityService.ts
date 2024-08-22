import { DynamoDB } from "aws-sdk";
import { DynamoDBStreamEvent, DynamoDBStreamHandler } from "aws-lambda";

// Servicio encargado de procesar los registros y almacenarlos en DynamoDB
export class ActivityService {
  private dynamoDB: DynamoDB.DocumentClient;
  private activityTable: string;

  constructor(dynamoDB: DynamoDB.DocumentClient, activityTable: string) {
    this.dynamoDB = dynamoDB;
    this.activityTable = activityTable;
  }

  async registerActivity(
    transactionId: string,
    timestamp: string
  ): Promise<void> {
    const params = {
      TableName: this.activityTable,
      Item: {
        activityId: `${transactionId}-${Date.now()}`,
        transactionId,
        date: timestamp,
      },
    };

    await this.dynamoDB.put(params).promise();
  }
}
