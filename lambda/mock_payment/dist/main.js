"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handler = void 0;
const handler = async (event) => {
    try {
        // Simulate a successful transaction response
        const response = {
            statusCode: 200,
            body: JSON.stringify({
                status: "success",
                transactionId: `txn_${Date.now()}`,
                message: "Payment registered successfully",
            }),
        };
        console.log("Response:", response);
        return response;
    }
    catch (error) {
        console.error("Error in mock payment handler:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({
                status: "error",
                message: "Internal Server Error Mock Payment",
            }),
        };
    }
};
exports.handler = handler;
