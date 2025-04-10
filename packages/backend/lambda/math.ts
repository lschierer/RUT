import { type APIGatewayProxyHandlerV2 } from 'aws-lambda';

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
    /*start work around for GetFrontmatter requiring async */
    await new Promise((resolve) => setTimeout(resolve, 1));
    /* end workaround */

    const body = event.body !== undefined ? (JSON.parse(event.body) as object) : {};
    const values = Object.keys(body).includes('values') ? body['values' as keyof typeof body] : [];

    const result = values.reduce((sum: number, n: number) => sum + n, 0);

    const allowedOrigin = process.env.ALLOWED_ORIGIN ?? 'localhost:5173';

    return {
        statusCode: 200,
        headers: {
            'Access-Control-Allow-Origin': allowedOrigin,
            'Access-Control-Allow-Headers': 'Content-Type',
        },
        body: JSON.stringify({ result }),
    };
};
