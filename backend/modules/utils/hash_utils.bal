import ballerina/crypto;

public isolated function hashPassword(string password) returns string|error {
    byte[] hashed = crypto:hashSha256(password.toBytes());
    return hashed.toBase64();
}

public isolated function verifyPassword(string password, string hashedPassword) returns boolean|error {
    string hashedInput = check hashPassword(password);
    return hashedInput == hashedPassword;
}