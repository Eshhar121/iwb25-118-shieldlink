import ballerina/crypto;
import ballerina/time;

public isolated function generateApiKey() returns string|error {
    // Generate a unique API key using current timestamp and random hash
    time:Utc currentTime = time:utcNow();
    string timestamp = currentTime[0].toString();
    string randomString = timestamp + "_" + currentTime[1].toString();
    
    byte[] hashedBytes = crypto:hashSha256(randomString.toBytes());
    string hashedString = hashedBytes.toBase64();
    
    // Create a more user-friendly API key format
    string apiKey = "sk_" + hashedString.substring(0, 32);
    
    return apiKey;
}