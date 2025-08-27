import backend.config;
import backend.model;

import ballerina/log;
import ballerinax/mongodb;

public isolated class ApiKeyRepository {
    private final mongodb:Database db;

    public function init() returns error? {
        mongodb:Client mongoClient = config:getMongoClient();
        self.db = check mongoClient->getDatabase("shieldlink");
    }

    public isolated function insertApiKey(model:ApiKey apiKey) returns error? {
        mongodb:Collection apiKeyCollection = check self.db->getCollection("apikeys");
        log:printInfo("Inserting API key into MongoDB for user: " + apiKey.userId);
        check apiKeyCollection->insertOne(apiKey);
        log:printInfo("API key inserted successfully for user: " + apiKey.userId);
    }

    public isolated function findApiKeyByUserId(string userId) returns model:ApiKey?|error {
        mongodb:Collection apiKeyCollection = check self.db->getCollection("apikeys");
        map<json> filter = {"userId": userId};

        log:printInfo("Searching for API key for user: " + userId);

        stream<model:ApiKey, error?> apiKeyStream = check apiKeyCollection->find(filter);
        model:ApiKey[] apiKeys = check from var apiKey in apiKeyStream
            select apiKey;
        check apiKeyStream.close();

        if apiKeys.length() > 0 {
            log:printInfo("API key found for user: " + userId);
            return apiKeys[0];
        } else {
            log:printInfo("No API key found for user: " + userId);
            return ();
        }
    }

    public isolated function findApiKeyByValue(string keyValue) returns model:ApiKey?|error {
        mongodb:Collection apiKeyCollection = check self.db->getCollection("apikeys");
        map<json> filter = {"keyValue": keyValue};

        log:printInfo("Searching for API key by value");

        stream<model:ApiKey, error?> apiKeyStream = check apiKeyCollection->find(filter);
        model:ApiKey[] apiKeys = check from var apiKey in apiKeyStream
            select apiKey;
        check apiKeyStream.close();

        if apiKeys.length() > 0 {
            log:printInfo("API key found by value");
            return apiKeys[0];
        } else {
            log:printInfo("No API key found by value");
            return ();
        }
    }

    public isolated function deleteApiKeyByUserId(string userId) returns error? {
        mongodb:Collection apiKeyCollection = check self.db->getCollection("apikeys");
        map<json> filter = {"userId": userId};

        log:printInfo("Deleting API key for user: " + userId);
        mongodb:DeleteResult deleteResult = check apiKeyCollection->deleteOne(filter);

        if deleteResult.deletedCount > 0 {
            log:printInfo("API key deleted successfully for user: " + userId);
        } else {
            log:printInfo("No API key was deleted for user: " + userId);
        }
    }
}