import ballerinax/mongodb;
import backend.model;
import backend.config;
import ballerina/log;
import ballerina/time;

// Internal record for MongoDB storage - store createdAt as Unix timestamp
type FileMetadataDocument record {|
    string fileId;
    string originalName;
    string? customName;
    string filePath;
    string ownerId;
    int createdAt; // Store as Unix timestamp (standard approach)
    int fileSize;
    string contentType;
    string accessLevel;
|};

public isolated class FileRepository {
    private final mongodb:Database db;

    public function init() returns error? {
        mongodb:Client mongoClient = config:getMongoClient();
        self.db = check mongoClient->getDatabase("shieldlink");
    }

    public isolated function insertFile(model:FileMetadata fileMetadata) returns error? {
        mongodb:Collection fileCollection = check self.db->getCollection("files");
        log:printInfo("Inserting file metadata into MongoDB: " + fileMetadata.fileId);
        
        // Convert to document format for storage - convert time:Utc to Unix timestamp
        FileMetadataDocument document = {
            fileId: fileMetadata.fileId,
            originalName: fileMetadata.originalName,
            customName: fileMetadata.customName,
            filePath: fileMetadata.filePath,
            ownerId: fileMetadata.ownerId,
            createdAt: fileMetadata.createdAt[0], // Store only the seconds part as Unix timestamp
            fileSize: fileMetadata.fileSize,
            contentType: fileMetadata.contentType,
            accessLevel: fileMetadata.accessLevel
        };
        
        check fileCollection->insertOne(document);
        log:printInfo("File metadata inserted successfully: " + fileMetadata.fileId);
    }

    public isolated function findFilesByOwner(string ownerId) returns model:FileMetadata[]|error {
        mongodb:Collection fileCollection = check self.db->getCollection("files");
        map<json> filter = {"ownerId": ownerId};

        log:printInfo("Searching for files owned by: " + ownerId);
        
        stream<FileMetadataDocument, error?> fileStream = check fileCollection->find(filter);
        FileMetadataDocument[] documents = check from var document in fileStream
            select document;
        check fileStream.close();
        
        // Convert documents to FileMetadata
        model:FileMetadata[] files = [];
        foreach FileMetadataDocument document in documents {
            // Convert Unix timestamp back to time:Utc
            time:Utc createdAtUtc = [document.createdAt, 0.0d];
            model:FileMetadata fileMetadata = {
                fileId: document.fileId,
                originalName: document.originalName,
                customName: document.customName,
                filePath: document.filePath,
                ownerId: document.ownerId,
                createdAt: createdAtUtc,
                fileSize: document.fileSize,
                contentType: document.contentType,
                accessLevel: document.accessLevel == "private" ? model:PRIVATE : 
                           (document.accessLevel == "read-only" ? model:READ_ONLY : model:PUBLIC)
            };
            files.push(fileMetadata);
        }
        
        log:printInfo("Found " + files.length().toString() + " files for owner: " + ownerId);
        
        return files;
    }

    public isolated function findFileByIdAndOwner(string fileId, string ownerId) returns model:FileMetadata?|error {
        mongodb:Collection fileCollection = check self.db->getCollection("files");
        map<json> filter = {
            "$and": [
                {"fileId": fileId},
                {"ownerId": ownerId}
            ]
        };

        log:printInfo("Searching for file with ID: " + fileId + " owned by: " + ownerId);
        
        stream<FileMetadataDocument, error?> fileStream = check fileCollection->find(filter);
        FileMetadataDocument[] documents = check from var document in fileStream
            select document;
        check fileStream.close();
        
        if documents.length() > 0 {
            log:printInfo("File found: " + fileId);
            FileMetadataDocument document = documents[0];
            // Convert Unix timestamp back to time:Utc
            time:Utc createdAtUtc = [document.createdAt, 0.0d];
            model:FileMetadata fileMetadata = {
                fileId: document.fileId,
                originalName: document.originalName,
                customName: document.customName,
                filePath: document.filePath,
                ownerId: document.ownerId,
                createdAt: createdAtUtc,
                fileSize: document.fileSize,
                contentType: document.contentType,
                accessLevel: document.accessLevel == "private" ? model:PRIVATE : 
                           (document.accessLevel == "read-only" ? model:READ_ONLY : model:PUBLIC)
            };
            return fileMetadata;
        } else {
            log:printInfo("File not found or not owned by user: " + fileId);
            return ();
        }
    }

    public isolated function findFileById(string fileId) returns model:FileMetadata?|error {
        mongodb:Collection fileCollection = check self.db->getCollection("files");
        map<json> filter = {"fileId": fileId};

        log:printInfo("Searching for file with ID: " + fileId);
        
        stream<FileMetadataDocument, error?> fileStream = check fileCollection->find(filter);
        FileMetadataDocument[] documents = check from var document in fileStream
            select document;
        check fileStream.close();
        
        if documents.length() > 0 {
            log:printInfo("File found: " + fileId);
            FileMetadataDocument document = documents[0];
            // Convert Unix timestamp back to time:Utc
            time:Utc createdAtUtc = [document.createdAt, 0.0d];
            model:FileMetadata fileMetadata = {
                fileId: document.fileId,
                originalName: document.originalName,
                customName: document.customName,
                filePath: document.filePath,
                ownerId: document.ownerId,
                createdAt: createdAtUtc,
                fileSize: document.fileSize,
                contentType: document.contentType,
                accessLevel: document.accessLevel == "private" ? model:PRIVATE : 
                           (document.accessLevel == "read-only" ? model:READ_ONLY : model:PUBLIC)
            };
            return fileMetadata;
        } else {
            log:printInfo("File not found: " + fileId);
            return ();
        }
    }

    public isolated function findFileByNameAndOwner(string fileName, string ownerId) returns model:FileMetadata?|error {
        mongodb:Collection fileCollection = check self.db->getCollection("files");
        map<json> filter = {
            "$and": [
                {
                    "$or": [
                        {"originalName": fileName},
                        {"customName": fileName}
                    ]
                },
                {"ownerId": ownerId}
            ]
        };

        log:printInfo("Searching for file with name: " + fileName + " owned by: " + ownerId);
        
        stream<FileMetadataDocument, error?> fileStream = check fileCollection->find(filter);
        FileMetadataDocument[] documents = check from var document in fileStream
            select document;
        check fileStream.close();
        
        if documents.length() > 0 {
            log:printInfo("File found by name: " + fileName);
            FileMetadataDocument document = documents[0];
            // Convert Unix timestamp back to time:Utc
            time:Utc createdAtUtc = [document.createdAt, 0.0d];
            model:FileMetadata fileMetadata = {
                fileId: document.fileId,
                originalName: document.originalName,
                customName: document.customName,
                filePath: document.filePath,
                ownerId: document.ownerId,
                createdAt: createdAtUtc,
                fileSize: document.fileSize,
                contentType: document.contentType,
                accessLevel: document.accessLevel == "private" ? model:PRIVATE : 
                           (document.accessLevel == "read-only" ? model:READ_ONLY : model:PUBLIC)
            };
            return fileMetadata;
        } else {
            log:printInfo("File not found by name or not owned by user: " + fileName);
            return ();
        }
    }

    public isolated function deleteFileByIdAndOwner(string fileId, string ownerId) returns model:FileMetadata?|error {
        mongodb:Collection fileCollection = check self.db->getCollection("files");
        
        // First find the file to get its metadata before deletion
        model:FileMetadata? fileMetadata = check self.findFileByIdAndOwner(fileId, ownerId);
        if fileMetadata is () {
            log:printInfo("File not found or not owned by user for deletion: " + fileId);
            return ();
        }

        // Delete the file from database
        map<json> filter = {
            "$and": [
                {"fileId": fileId},
                {"ownerId": ownerId}
            ]
        };

        mongodb:DeleteResult deleteResult = check fileCollection->deleteOne(filter);
        if deleteResult.deletedCount > 0 {
            log:printInfo("File metadata deleted successfully: " + fileId);
            return fileMetadata;
        } else {
            log:printError("Failed to delete file metadata: " + fileId);
            return error("Failed to delete file from database");
        }
    }

    public isolated function updateFileAccessLevel(string fileId, string ownerId, model:AccessLevel accessLevel) returns model:FileMetadata?|error {
        mongodb:Collection fileCollection = check self.db->getCollection("files");
        
        // First verify the file exists and is owned by the user
        model:FileMetadata? fileMetadata = check self.findFileByIdAndOwner(fileId, ownerId);
        if fileMetadata is () {
            log:printInfo("File not found or not owned by user for access update: " + fileId);
            return ();
        }

        // Update the access level
        map<json> filter = {
            "$and": [
                {"fileId": fileId},
                {"ownerId": ownerId}
            ]
        };

        map<json> update = {
            "$set": {
                "accessLevel": accessLevel
            }
        };

        mongodb:UpdateResult updateResult = check fileCollection->updateOne(filter, <mongodb:Update>update);
        if updateResult.modifiedCount > 0 {
            log:printInfo("File access level updated successfully: " + fileId + " to " + accessLevel);
            
            // Return updated file metadata
            model:FileMetadata updatedMetadata = {
                fileId: fileMetadata.fileId,
                originalName: fileMetadata.originalName,
                customName: fileMetadata.customName,
                filePath: fileMetadata.filePath,
                ownerId: fileMetadata.ownerId,
                createdAt: fileMetadata.createdAt,
                fileSize: fileMetadata.fileSize,
                contentType: fileMetadata.contentType,
                accessLevel: accessLevel
            };
            
            return updatedMetadata;
        } else {
            log:printError("Failed to update file access level: " + fileId);
            return error("Failed to update file access level in database");
        }
    }
}