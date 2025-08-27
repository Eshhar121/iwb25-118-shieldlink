import ballerina/time;

public enum AccessLevel {
    PRIVATE = "private",
    READ_ONLY = "read-only",
    PUBLIC = "public"
}

public type FileMetadata record {|
    string fileId;
    string originalName;
    string? customName;
    string filePath;
    string ownerId;
    time:Utc createdAt;
    int fileSize;
    string contentType;
    AccessLevel accessLevel = PRIVATE;
|};

public type FileUploadRequest record {|
    string? customName;
    AccessLevel? accessLevel;
|};

public type FileResponse record {|
    string fileId;
    string originalName;
    string? customName;
    string ownerId;
    time:Utc createdAt;
    int fileSize;
    string contentType;
    AccessLevel accessLevel;
|};

public type FileAccessUpdateRequest record {|
    AccessLevel accessLevel;
|};