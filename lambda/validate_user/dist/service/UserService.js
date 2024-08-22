"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserService = void 0;
class UserService {
    constructor(dynamoDB, usersTable) {
        this.dynamoDB = dynamoDB;
        this.usersTable = usersTable;
    }
    async validateUser(userId, amount) {
        if (!userId) {
            return {
                statusCode: 400,
                body: JSON.stringify({ message: "UserId is required" }),
            };
        }
        const params = {
            TableName: this.usersTable,
            Key: { user_id: userId },
        };
        try {
            const result = await this.dynamoDB.get(params).promise();
            if (!result.Item) {
                return {
                    statusCode: 404,
                    body: JSON.stringify({ message: "User not found" }),
                };
            }
            return {
                statusCode: 200,
                body: JSON.stringify({
                    message: "User validated successfully",
                    userId,
                    amount,
                }),
            };
        }
        catch (error) {
            console.error("Error executing validate user:", error);
            return {
                statusCode: 500,
                body: JSON.stringify({ message: "Internal Server Error" }),
            };
        }
    }
}
exports.UserService = UserService;
