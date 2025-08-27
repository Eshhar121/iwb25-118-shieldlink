import backend.model;
import backend.repository;

import ballerina/file;
import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/mime;
import ballerina/time;

public isolated class FileService {
    private final repository:FileRepository fileRepository;
    private final string uploadsDir = "./uploads";

    public function init() returns error? {
        self.fileRepository = check new repository:FileRepository();
        // Create uploads directory if it doesn't exist
        check file:createDir(self.uploadsDir, option = file:RECURSIVE);
        log:printInfo("File service initialized with uploads directory: " + self.uploadsDir);
    }

    public isolated function uploadFile(http:Request request, string ownerId) returns model:FileResponse|error {
        // Parse multipart request
        mime:Entity[] bodyParts = check request.getBodyParts();

        http:Request fileRequest = new;
        string? customName = ();
        model:AccessLevel accessLevel = model:PRIVATE; // Default to private

        // Process each part of the multipart request
        foreach mime:Entity part in bodyParts {
            mime:ContentDisposition? contentDisposition = part.getContentDisposition();
            if contentDisposition is mime:ContentDisposition {
                string fieldName = contentDisposition.name;

                if fieldName == "file" {
                    // This is the file part
                    byte[] fileContent = check part.getByteArray();
                    string? fileName = contentDisposition.fileName;

                    if fileName is () {
                        return error("File name is required");
                    }

                    string contentType = part.getContentType();

                    // Generate unique file ID and path
                    time:Utc currentTime = time:utcNow();
                    int timestamp = currentTime[0];
                    string fileId = timestamp.toString() + "_" + fileName;
                    string filePath = self.uploadsDir + "/" + fileId;

                    // Save file to disk
                    check io:fileWriteBytes(filePath, fileContent);

                    // Create file metadata
                    model:FileMetadata fileMetadata = {
                        fileId: fileId,
                        originalName: fileName,
                        customName: customName,
                        filePath: filePath,
                        ownerId: ownerId,
                        createdAt: currentTime,
                        fileSize: fileContent.length(),
                        contentType: contentType,
                        accessLevel: accessLevel
                    };

                    // Save metadata to database
                    check self.fileRepository.insertFile(fileMetadata);

                    log:printInfo("File uploaded successfully: " + fileId + " for user: " + ownerId + " with access level: " + accessLevel);

                    // Return file response
                    model:FileResponse fileResponse = {
                        fileId: fileMetadata.fileId,
                        originalName: fileMetadata.originalName,
                        customName: fileMetadata.customName,
                        ownerId: fileMetadata.ownerId,
                        createdAt: fileMetadata.createdAt,
                        fileSize: fileMetadata.fileSize,
                        contentType: fileMetadata.contentType,
                        accessLevel: fileMetadata.accessLevel
                    };

                    return fileResponse;
                } else if fieldName == "customName" {
                    // This is the custom name field
                    customName = check part.getText();
                } else if fieldName == "accessLevel" {
                    // This is the access level field
                    string accessLevelText = check part.getText();
                    if accessLevelText == "private" {
                        accessLevel = model:PRIVATE;
                    } else if accessLevelText == "read-only" {
                        accessLevel = model:READ_ONLY;
                    } else if accessLevelText == "public" {
                        accessLevel = model:PUBLIC;
                    }
                }
            }
        }

        return error("No file found in the request");
    }

    public isolated function downloadFile(string fileIdOrName, string ownerId) returns http:Response|error {
        // First try to find by file ID
        model:FileMetadata? fileMetadata = check self.fileRepository.findFileByIdAndOwner(fileIdOrName, ownerId);

        // If not found by ID, try to find by name
        if fileMetadata is () {
            fileMetadata = check self.fileRepository.findFileByNameAndOwner(fileIdOrName, ownerId);
        }

        if fileMetadata is () {
            return error("File not found or access denied");
        }

        // Read file content
        byte[]|io:Error fileContent = io:fileReadBytes(fileMetadata.filePath);
        if fileContent is io:Error {
            log:printError("Failed to read file: " + fileMetadata.filePath + " - " + fileContent.message());
            return error("Failed to read file");
        }

        // Create response with file content
        http:Response response = new;
        response.setBinaryPayload(fileContent);
        response.setHeader("Content-Type", fileMetadata.contentType);

        string displayName = fileMetadata.customName ?: fileMetadata.originalName;
        response.setHeader("Content-Disposition", "attachment; filename=\"" + displayName + "\"");

        log:printInfo("File downloaded: " + fileMetadata.fileId + " by user: " + ownerId);

        return response;
    }

    public isolated function getUserFiles(string ownerId) returns model:FileResponse[]|error {
        model:FileMetadata[] fileMetadataList = check self.fileRepository.findFilesByOwner(ownerId);

        model:FileResponse[] fileResponses = [];
        foreach model:FileMetadata fileMetadata in fileMetadataList {
            model:FileResponse fileResponse = {
                fileId: fileMetadata.fileId,
                originalName: fileMetadata.originalName,
                customName: fileMetadata.customName,
                ownerId: fileMetadata.ownerId,
                createdAt: fileMetadata.createdAt,
                fileSize: fileMetadata.fileSize,
                contentType: fileMetadata.contentType,
                accessLevel: fileMetadata.accessLevel
            };
            fileResponses.push(fileResponse);
        }

        log:printInfo("Retrieved " + fileResponses.length().toString() + " files for user: " + ownerId);

        return fileResponses;
    }

    public isolated function deleteFile(string fileId, string ownerId) returns string|error {
        // Find and delete file metadata from database (with ownership check)
        model:FileMetadata? fileMetadata = check self.fileRepository.deleteFileByIdAndOwner(fileId, ownerId);
        
        if fileMetadata is () {
            return error("File not found or access denied");
        }

        // Delete physical file from filesystem
        file:Error? fileDeleteResult = file:remove(fileMetadata.filePath);
        if fileDeleteResult is file:Error {
            log:printError("Failed to delete physical file: " + fileMetadata.filePath + " - " + fileDeleteResult.message());
            // Note: File metadata is already deleted from DB, but physical file remains
            // In production, you might want to implement a cleanup job for orphaned files
        } else {
            log:printInfo("Physical file deleted successfully: " + fileMetadata.filePath);
        }

        log:printInfo("File deleted successfully: " + fileId + " by user: " + ownerId);
        return "File deleted successfully";
    }

    public isolated function updateFileAccess(string fileId, string ownerId, model:AccessLevel accessLevel) returns model:FileResponse|error {
        // Update file access level in database
        model:FileMetadata? updatedMetadata = check self.fileRepository.updateFileAccessLevel(fileId, ownerId, accessLevel);
        
        if updatedMetadata is () {
            return error("File not found or access denied");
        }

        // Convert to response format
        model:FileResponse fileResponse = {
            fileId: updatedMetadata.fileId,
            originalName: updatedMetadata.originalName,
            customName: updatedMetadata.customName,
            ownerId: updatedMetadata.ownerId,
            createdAt: updatedMetadata.createdAt,
            fileSize: updatedMetadata.fileSize,
            contentType: updatedMetadata.contentType,
            accessLevel: updatedMetadata.accessLevel
        };

        log:printInfo("File access level updated successfully: " + fileId + " to " + accessLevel + " by user: " + ownerId);
        return fileResponse;
    }
}