import axios, { AxiosInstance } from "axios";
import { DynamoDB } from "aws-sdk";

export class PaymentService {
  private dynamoDB: DynamoDB.DocumentClient;
  private transactionsTable: string;
  private apiClient: AxiosInstance;

  constructor(
    dynamoDB: DynamoDB.DocumentClient,
    transactionsTable: string,
    apiClient: AxiosInstance
  ) {
    this.dynamoDB = dynamoDB;
    this.transactionsTable = transactionsTable;
    this.apiClient = apiClient;
  }

  async executePayment(userId: string, amount: number): Promise<any> {
    if (!userId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ message: "userId is required" }),
      };
    }

    const transactionId = this.generateUUID();
    console.log("Executing payment for userId:", userId);

    // Simulate a successful payment
    const response = await this.apiClient.post(process.env.MOCK_API_URL!, {
      userId,
    });
    if (response.data.status !== "success") {
      throw new Error("Transaction failed");
    }

    // If payment is successful, save the transaction in DynamoDB
    const params = {
      TableName: this.transactionsTable,
      Item: {
        transaction_id: transactionId,
        userId,
        timestamp: new Date().toISOString(),
        paymentAmount: amount,
      },
    };

    await this.dynamoDB.put(params).promise();

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Payment executed successfully",
        transactionId,
      }),
    };
  }

  private generateUUID(): string {
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === "x" ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }
}
