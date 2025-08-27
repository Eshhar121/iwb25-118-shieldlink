import backend.services;
import backend.middleware;
import backend.model;
import ballerina/http;
import ballerina/log;
import ballerina/jwt;

public service class ApiKeyService {
    *http:InterceptableService;
    private final services:ApiKeyService apiKeyService;

    public function init() returns error? {
        do {
            self.apiKeyService = check new services:ApiKeyService();
            log:printInfo("API Key service initialized successfully");
        } on fail error e {
            log:printError("Failed to initialize API Key service: " + e.message());
            return e;
        }
    }

    resource function post .(http:RequestContext ctx, http:Request req) returns http:Ok|http:InternalServerError|http:Unauthorized|error {
        // Get user ID from JWT payload
        jwt:Payload|error payload = ctx.getWithType("jwtPayload", jwt:Payload);
        if payload is error {
            return <http:Unauthorized>{body: {"error": "Unauthorized: Missing or invalid JWT payload - " + payload.message()}};
        }

        string userId = payload.sub.toString();
        log:printInfo("Generating API key for user: " + userId);

        model:ApiKeyResponse|error result = self.apiKeyService.generateApiKey(userId);
        if result is model:ApiKeyResponse {
            log:printInfo("API key generated successfully for user: " + userId);
            return <http:Ok>{body: result};
        } else {
            log:printError("API key generation failed: " + result.message());
            return <http:InternalServerError>{body: {"error": "API key generation failed: " + result.message()}};
        }
    }

    resource function get .(http:RequestContext ctx, http:Request req) returns http:Ok|http:NotFound|http:InternalServerError|http:Unauthorized|error {
        // Get user ID from JWT payload
        jwt:Payload|error payload = ctx.getWithType("jwtPayload", jwt:Payload);
        if payload is error {
            return <http:Unauthorized>{body: {"error": "Unauthorized: Missing or invalid JWT payload - " + payload.message()}};
        }

        string userId = payload.sub.toString();
        log:printInfo("Retrieving API key for user: " + userId);

        model:ApiKeyResponse|error result = self.apiKeyService.getUserApiKey(userId);
        if result is model:ApiKeyResponse {
            log:printInfo("API key retrieved successfully for user: " + userId);
            return <http:Ok>{body: result};
        } else {
            log:printError("API key retrieval failed: " + result.message());
            if result.message().includes("No API key found") {
                return <http:NotFound>{body: {"error": "No API key found for user"}};
            } else {
                return <http:InternalServerError>{body: {"error": "API key retrieval failed: " + result.message()}};
            }
        }
    }

    public function createInterceptors() returns http:Interceptor[] {
        return middleware:createInterceptors();
    }
}