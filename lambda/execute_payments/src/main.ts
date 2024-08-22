import axios from "axios";
import { DynamoDB } from "aws-sdk";
//{ "statusCode": 200, "body": "{\"message\":\"User validated successfully\",\"userId\":\"f529177d-0521-414e-acd9-6ac840549e97\",\"amount\":30}"
export const handler = async (event: {
  statusCode: number;
  body: string;
}): Promise<any> => {
  console.log("reach this point execute :");
  const dynamoDB = new DynamoDB.DocumentClient();
  const MOCK_API_URL = process.env.MOCK_API_URL!;
  // Parse the JSON body
  const { userId, amount } = JSON.parse(event.body);
  //const { userId, amount } = event;

  console.log("event" + event);

  if (!userId) {
    return {
      statusCode: 400,
      body: JSON.stringify({
        message: "userId is required in execute payments",
      }),
    };
  }

  const transactionId = generateUUID();
  console.log("execute payment userId:", userId);
  console.log("execute payment MOCK_API_URL:", MOCK_API_URL);
  // Simulate a successful payment
  const response = await axios.post(MOCK_API_URL, { userId });
  if (response.data.status !== "success") {
    throw new Error("Transaction failed");
  }
  // If payment is successful, save the transaction

  const params = {
    TableName: process.env.TRANSACTIONS_TABLE!,
    Item: {
      transaction_id: transactionId,
      userId,
      timestamp: new Date().toISOString(),
      paymentAmount: amount,
    },
  };

  console.log("execute payment transactionId:", transactionId);
  console.log("execute payment params:", JSON.stringify(params, null, 2));

  await dynamoDB.put(params).promise();

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: "Payment executed successfully",
      transactionId,
    }),
  };
};

function generateUUID(): string {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
