
import 'dotenv/config';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';

const { ENDPOINT_URL, REGION } = process.env;

const normalizedEndpoint = ENDPOINT_URL && !ENDPOINT_URL.startsWith('http')
  ? `http://${ENDPOINT_URL}`
  : ENDPOINT_URL;

const baseClient = new DynamoDBClient({
  region: REGION,
  endpoint: normalizedEndpoint,
});

const docClient = DynamoDBDocumentClient.from(baseClient, {
  marshallOptions: {
    removeUndefinedValues: true,
    convertClassInstanceToMap: true,
  },
});

export const dynamoDBClient = (): DynamoDBDocumentClient => docClient;