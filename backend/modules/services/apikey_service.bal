import backend.repository;
import backend.model;
import backend.utils;
import ballerina/time;
import ballerina/log;

public isolated class ApiKeyService {
    private final repository:ApiKeyRepository apiKeyRepository;

    public function init() returns error? {
        self.apiKeyRepository = check new repository:ApiKeyRepository();
    }

    public isolated function generateApiKey(string userId) returns model:ApiKeyResponse|error {
        log:printInfo("Generating API key for user: " + userId);
        
        // Generate a new API key
        string keyValue = check utils:generateApiKey();
        time:Utc currentTime = time:utcNow();
        
        model:ApiKey apiKey = {
            keyValue: keyValue,
            userId: userId,
            createdAt: currentTime
        };

        // Check if user already has an API key
        model:ApiKey? existingApiKey = check self.apiKeyRepository.findApiKeyByUserId(userId);
        
        if existingApiKey is model:ApiKey {
            // Delete existing API key and insert new one
            check self.apiKeyRepository.deleteApiKeyByUserId(userId);
            check self.apiKeyRepository.insertApiKey(apiKey);
            log:printInfo("API key replaced for user: " + userId);
        } else {
            // Insert new API key
            check self.apiKeyRepository.insertApiKey(apiKey);
            log:printInfo("New API key created for user: " + userId);
        }

        model:ApiKeyResponse response = {
            keyValue: keyValue,
            createdAt: currentTime
        };

        return response;
    }

    public isolated function getUserApiKey(string userId) returns model:ApiKeyResponse|error {
        log:printInfo("Retrieving API key for user: " + userId);
        
        model:ApiKey? apiKey = check self.apiKeyRepository.findApiKeyByUserId(userId);
        
        if apiKey is () {
            return error("No API key found for user");
        }

        model:ApiKeyResponse response = {
            keyValue: apiKey.keyValue,
            createdAt: apiKey.createdAt
        };

        return response;
    }

    public isolated function validateApiKey(string keyValue) returns string|error {
        log:printInfo("Validating API key");
        
        model:ApiKey? apiKey = check self.apiKeyRepository.findApiKeyByValue(keyValue);
        
        if apiKey is () {
            return error("Invalid API key");
        }

        log:printInfo("API key validated for user: " + apiKey.userId);
        return apiKey.userId;
    }
}