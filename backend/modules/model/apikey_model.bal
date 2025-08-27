import ballerina/time;

public type ApiKey record {|
    string keyValue;
    string userId;
    time:Utc createdAt;
|};

public type ApiKeyResponse record {|
    string keyValue;
    time:Utc createdAt;
|};