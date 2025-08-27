import backend.services;
import backend.middleware;
import backend.model;
import ballerina/http;
import ballerina/log;
import ballerina/jwt;

public service class FileService {
    *http:InterceptableService;
    private final services:FileService fileService;

    public function init() returns error? {
        do {
            self.fileService = check new services:FileService();
            log:printInfo("File service initialized successfully");
        } on fail error e {
            log:printError("Failed to initialize file service: " + e.message());
            return e;
        }
    }

    resource function post upload(http:RequestContext ctx, http:Request req) returns http:Ok|http:BadRequest|http:InternalServerError|http:Unauthorized|error {
        // Get user ID from JWT payload
        jwt:Payload|error payload = ctx.getWithType("jwtPayload", jwt:Payload);
        if payload is error {
            return <http:Unauthorized>{body: {"error": "Missing or invalid JWT payload - " + payload.message()}};
        }

        string ownerId = payload.sub.toString();
        log:printInfo("Processing file upload for user: " + ownerId);

        model:FileResponse|error result = self.fileService.uploadFile(req, ownerId);
        if result is model:FileResponse {
            log:printInfo("File uploaded successfully: " + result.fileId);
            return <http:Ok>{body: result};
        } else {
            log:printError("File upload failed: " + result.message());
            return <http:InternalServerError>{body: {"error": "File upload failed: " + result.message()}};
        }
    }

    resource function get [string fileIdOrName](http:RequestContext ctx, http:Request req) returns http:Response|http:NotFound|http:InternalServerError|http:Unauthorized|error {
        // Get user ID from JWT payload
        jwt:Payload|error payload = ctx.getWithType("jwtPayload", jwt:Payload);
        if payload is error {
            http:Response response = new;
            response.statusCode = 401;
            response.setJsonPayload({"error": "Unauthorized: Missing or invalid JWT payload - " + payload.message()});
            return response;
        }

        string ownerId = payload.sub.toString();
        log:printInfo("Processing file download for user: " + ownerId + ", file: " + fileIdOrName);

        http:Response|error result = self.fileService.downloadFile(fileIdOrName, ownerId);
        if result is http:Response {
            log:printInfo("File download successful for: " + fileIdOrName);
            return result;
        } else {
            log:printError("File download failed: " + result.message());
            http:Response response = new;
            response.statusCode = 404;
            response.setJsonPayload({"error": "File not found or access denied"});
            return response;
        }
    }

    resource function get .(http:RequestContext ctx, http:Request req) returns http:Ok|http:InternalServerError|http:Unauthorized|error {
        // Get user ID from JWT payload
        jwt:Payload|error payload = ctx.getWithType("jwtPayload", jwt:Payload);
        if payload is error {
            return <http:Unauthorized>{body: {"error": "Unauthorized: Missing or invalid JWT payload - " + payload.message()}};
        }

        string ownerId = payload.sub.toString();
        log:printInfo("Processing file list request for user: " + ownerId);

        model:FileResponse[]|error result = self.fileService.getUserFiles(ownerId);
        if result is model:FileResponse[] {
            log:printInfo("File list retrieved successfully for user: " + ownerId);
            return <http:Ok>{body: {"files": result}};
        } else {
            log:printError("Failed to retrieve file list: " + result.message());
            return <http:InternalServerError>{body: {"error": "Failed to retrieve files: " + result.message()}};
        }
    }

    resource function delete [string fileId](http:RequestContext ctx, http:Request req) returns http:Ok|http:NotFound|http:InternalServerError|http:Unauthorized|error {
        // Get user ID from JWT payload
        jwt:Payload|error payload = ctx.getWithType("jwtPayload", jwt:Payload);
        if payload is error {
            return <http:Unauthorized>{body: {"error": "Unauthorized: Missing or invalid JWT payload - " + payload.message()}};
        }

        string ownerId = payload.sub.toString();
        log:printInfo("Processing file deletion for user: " + ownerId + ", file: " + fileId);

        string|error result = self.fileService.deleteFile(fileId, ownerId);
        if result is string {
            log:printInfo("File deleted successfully: " + fileId + " by user: " + ownerId);
            return <http:Ok>{body: {"message": result}};
        } else {
            string errorMessage = result.message();
            log:printError("File deletion failed: " + errorMessage);
            
            if errorMessage.includes("not found") || errorMessage.includes("access denied") {
                return <http:NotFound>{body: {"error": "File not found or access denied"}};
            } else {
                return <http:InternalServerError>{body: {"error": "File deletion failed: " + errorMessage}};
            }
        }
    }

    resource function patch [string fileId]/access(http:RequestContext ctx, http:Request req) returns http:Ok|http:BadRequest|http:NotFound|http:InternalServerError|http:Unauthorized|error {
        // Get user ID from JWT payload
        jwt:Payload|error payload = ctx.getWithType("jwtPayload", jwt:Payload);
        if payload is error {
            return <http:Unauthorized>{body: {"error": "Unauthorized: Missing or invalid JWT payload - " + payload.message()}};
        }

        string ownerId = payload.sub.toString();
        log:printInfo("Processing file access update for user: " + ownerId + ", file: " + fileId);

        // Parse request body
        json requestPayload = check req.getJsonPayload();
        
        // Handle potential type conversion errors for invalid access levels
        model:FileAccessUpdateRequest|error accessUpdateRequest = requestPayload.cloneWithType(model:FileAccessUpdateRequest);
        if accessUpdateRequest is error {
            return <http:BadRequest>{body: {"error": "Invalid access level. Must be 'private', 'read-only', or 'public'"}};
        }

        model:AccessLevel newAccessLevel = accessUpdateRequest.accessLevel;

        // Update file access level
        model:FileResponse|error result = self.fileService.updateFileAccess(fileId, ownerId, newAccessLevel);
        if result is model:FileResponse {
            log:printInfo("File access level updated successfully: " + fileId + " to " + newAccessLevel + " by user: " + ownerId);
            return <http:Ok>{body: result};
        } else {
            string errorMessage = result.message();
            log:printError("File access update failed: " + errorMessage);
            
            if errorMessage.includes("not found") || errorMessage.includes("access denied") {
                return <http:NotFound>{body: {"error": "File not found or access denied"}};
            } else {
                return <http:InternalServerError>{body: {"error": "File access update failed: " + errorMessage}};
            }
        }
    }

    public function createInterceptors() returns http:Interceptor[] {
        return middleware:createInterceptors();
    }
}