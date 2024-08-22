import { DynamoDB } from "aws-sdk";

const dynamoDB = new DynamoDB.DocumentClient();

export const handler = async (event: any): Promise<any> => {
  try {
    // Parse the body to get userId
    const { userId, amount } = JSON.parse(event.body);
    console.log("validate userId:", userId);

    if (!userId) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          message: "UserId is required in validate user",
        }),
      };
    }

    const params = {
      TableName: process.env.USERS_TABLE!,
      Key: { user_id: userId },
    };

    console.log("validate params:", JSON.stringify(params, null, 2));

    console.log("validate process.env.USERS_TABLE:", process.env.USERS_TABLE);

    const result = await dynamoDB.get(params).promise();

    console.log("validate result:", JSON.stringify(result, null, 2));

    if (!result.Item) {
      return {
        statusCode: 404,
        body: JSON.stringify({ message: "User not found" }),
      };
    }
    console.log("reach this point :");
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "User validated successfully",
        userId,
        amount,
      }),
    };
  } catch (error) {
    console.error("Error executing validate user, Something was wrong:", error);
  }
};
