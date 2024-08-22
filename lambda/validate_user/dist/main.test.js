"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const main_1 = require("./main");
const sinon_1 = __importDefault(require("sinon"));
const aws_sdk_1 = require("aws-sdk");
const chai_1 = require("chai");
describe("Validate User Lambda", () => {
    let dynamoDBMock;
    beforeEach(() => {
        dynamoDBMock = sinon_1.default.stub(aws_sdk_1.DynamoDB.DocumentClient.prototype, "get");
    });
    afterEach(() => {
        dynamoDBMock.restore();
    });
    it("should return 400 if userId is not provided", async () => {
        const event = { body: JSON.stringify({}) };
        const result = await (0, main_1.handler)(event);
        (0, chai_1.expect)(result.statusCode).to.equal(400);
        (0, chai_1.expect)(JSON.parse(result.body).message).to.equal("UserId is required");
    });
    it("should return 404 if user is not found", async () => {
        const event = { body: JSON.stringify({ userId: "non-existent-user-id" }) };
        dynamoDBMock.returns({
            promise: () => Promise.resolve({}),
        });
        const result = await (0, main_1.handler)(event);
        (0, chai_1.expect)(result.statusCode).to.equal(404);
        (0, chai_1.expect)(JSON.parse(result.body).message).to.equal("User not found");
    });
    it("should return 200 if user is found", async () => {
        const event = { body: JSON.stringify({ userId: "existing-user-id" }) };
        dynamoDBMock.returns({
            promise: () => Promise.resolve({
                Item: { user_id: "existing-user-id" },
            }),
        });
        const result = await (0, main_1.handler)(event);
        (0, chai_1.expect)(result.statusCode).to.equal(200);
        (0, chai_1.expect)(result.message).to.equal("User validated successfully");
    });
});
