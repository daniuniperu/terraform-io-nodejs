"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ActivityService = void 0;
// Servicio encargado de procesar los registros y almacenarlos en DynamoDB
class ActivityService {
    constructor(dynamoDB, activityTable) {
        this.dynamoDB = dynamoDB;
        this.activityTable = activityTable;
    }
    async registerActivity(transactionId, timestamp) {
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
exports.ActivityService = ActivityService;
