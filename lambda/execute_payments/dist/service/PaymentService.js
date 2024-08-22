"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentService = void 0;
class PaymentService {
    constructor(dynamoDB, transactionsTable, apiClient) {
        this.dynamoDB = dynamoDB;
        this.transactionsTable = transactionsTable;
        this.apiClient = apiClient;
    }
    async executePayment(userId, amount) {
        if (!userId) {
            return {
                statusCode: 400,
                body: JSON.stringify({ message: "userId is required" }),
            };
        }
        const transactionId = this.generateUUID();
        console.log("Executing payment for userId:", userId);
        // Simulate a successful payment
        const response = await this.apiClient.post(process.env.MOCK_API_URL, {
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
    generateUUID() {
        return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
            const r = (Math.random() * 16) | 0;
            const v = c === "x" ? r : (r & 0x3) | 0x8;
            return v.toString(16);
        });
    }
}
exports.PaymentService = PaymentService;
