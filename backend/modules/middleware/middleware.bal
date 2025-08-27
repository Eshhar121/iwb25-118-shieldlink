import backend.utils;
import backend.services;
import ballerina/http;
import ballerina/jwt;
import ballerina/log;
import backend.repository;
import backend.model;

configurable string[] CORS_ALLOWED_ORIGINS = ["http://localhost:5173"];
configurable string[] CORS_ALLOWED_METHODS = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"];
configurable string[] CORS_ALLOWED_HEADERS = ["Content-Type", "Authorization", "X-Requested-With"];
configurable boolean CORS_ALLOW_CREDENTIALS = true;

service class CorsRequestInterceptor {
    *http:RequestInterceptor;

    resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|http:Ok|error? {
        // Store the origin header in context for later use in response interceptor
        string originHeader = getOriginHeader(req);
        ctx.set("originHeader", originHeader);
        
        // Handle OPTIONS requests immediately for CORS preflight
        if req.method == "OPTIONS" {
            return <http:Ok>{
                body: "",
                headers: {
                    "Access-Control-Allow-Origin": originHeader,
                    "Access-Control-Allow-Methods": string:'join(", ", ...CORS_ALLOWED_METHODS),
                    "Access-Control-Allow-Headers": string:'join(", ", ...CORS_ALLOWED_HEADERS),
                    "Access-Control-Allow-Credentials": CORS_ALLOW_CREDENTIALS.toString(),
                    "Access-Control-Max-Age": "86400"
                }
            };
        }
        return ctx.next();
    }
}

service class CorsResponseInterceptor {
    *http:ResponseInterceptor;

    remote function interceptResponse(http:RequestContext ctx, http:Response res) returns http:NextService|error? {
        // Get the origin header from context
        any originValue = ctx.get("originHeader");
        string originHeader = "*";
        
        if originValue is string {
            originHeader = originValue;
        } else {
            // Fallback to first allowed origin or wildcard
            originHeader = CORS_ALLOWED_ORIGINS.length() > 0 ? CORS_ALLOWED_ORIGINS[0] : "*";
        }
        
        res.setHeader("Access-Control-Allow-Origin", originHeader);
        res.setHeader("Access-Control-Allow-Methods", string:'join(", ", ...CORS_ALLOWED_METHODS));
        res.setHeader("Access-Control-Allow-Headers", string:'join(", ", ...CORS_ALLOWED_HEADERS));
        
        if CORS_ALLOW_CREDENTIALS {
            res.setHeader("Access-Control-Allow-Credentials", "true");
        }
        
        res.setHeader("Access-Control-Max-Age", "86400");
        
        return ctx.next();
    }
}

service class AuthInterceptor {
    *http:RequestInterceptor;
    private final services:ApiKeyService apiKeyService;

    public function init() returns error? {
        self.apiKeyService = check new services:ApiKeyService();
    }

    resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|http:Unauthorized|error? {
        string requestPath = path.length() > 0 ? "/" + string:'join("/", ...path) : "/";
        log:printInfo("Processing request for path: " + requestPath);

        // Skip authentication for register, login, and OPTIONS requests
        if requestPath == "/register" || requestPath == "/login" || req.method == "OPTIONS" {
            ctx.set("authType", "none");
            return ctx.next();
        }

        // Check for API key in query parameters (for file access)
        if requestPath.startsWith("/files/") {
            map<string[]> queryParams = req.getQueryParams();
            if queryParams.hasKey("key") {
                string[] keyValues = queryParams.get("key");
                if keyValues.length() > 0 {
                    string apiKey = keyValues[0];
                    
                    string|error userId = self.apiKeyService.validateApiKey(apiKey);
                    if userId is string {
                        // Create a mock JWT payload for API key authentication
                        jwt:Payload apiKeyPayload = {
                            sub: userId,
                            iss: "apikey",
                            exp: 0, // API keys don't expire
                            iat: 0,
                            "role": "user"
                        };
                        ctx.set("jwtPayload", apiKeyPayload);
                        ctx.set("authType", "apikey");
                        log:printInfo("API key authentication successful for user: " + userId);
                        return ctx.next();
                    } else {
                        log:printError("API key validation failed: " + userId.message());
                        // Let it fall through to JWT check
                    }
                }
            }
        }

        // Check for JWT token in Authorization header
        string|http:HeaderNotFoundError authHeaderResult = req.getHeader("Authorization");
        if authHeaderResult is http:HeaderNotFoundError || authHeaderResult == "" || !authHeaderResult.startsWith("Bearer ") {
            // For file routes, allow unauthenticated access (handled by FileAccessInterceptor)
            if requestPath.startsWith("/files/") {
                ctx.set("authType", "none");
                return ctx.next();
            }
            return <http:Unauthorized>{body: {"error": "Unauthorized: Missing or invalid Bearer token"}};
        }

        string authHeader = authHeaderResult;
        string token = authHeader.substring(7);
        jwt:Payload|error payload = utils:validateToken(token);
        if payload is error {
            log:printError("Token validation failed: " + payload.message());
            if requestPath.startsWith("/files/") {
                ctx.set("authType", "none");
                return ctx.next();
            }
            return <http:Unauthorized>{body: {"error": "Unauthorized: Invalid token - " + payload.message()}};
        }

        ctx.set("jwtPayload", payload);
        ctx.set("authType", "jwt");
        return ctx.next();
    }
}

service class FileAccessInterceptor {
    *http:RequestInterceptor;
    private final repository:FileRepository fileRepository;

    public function init() returns error? {
        self.fileRepository = check new repository:FileRepository();
    }

    resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|http:Unauthorized|http:Forbidden|http:NotFound|error? {
        string requestPath = path.length() > 0 ? "/" + string:'join("/", ...path) : "/";
        
        // Only apply access control to file routes with file ID/name
        if !requestPath.startsWith("/files/") || path.length() < 2 {
            return ctx.next();
        }

        string fileIdOrName = path[1];
        string httpMethod = req.method;
        
        log:printInfo("Checking file access for: " + fileIdOrName + " with method: " + httpMethod);

        // Get file metadata to check access level
        model:FileMetadata? fileMetadata = check self.fileRepository.findFileById(fileIdOrName);
        
        // If not found by ID, search by name with owner context
        if fileMetadata is () {
            any authTypeValue = ctx.get("authType");
            string authType = authTypeValue is string ? authTypeValue : "none";
            
            if authType == "none" {
                return <http:NotFound>{body: {"error": "File not found"}};
            }
            
            any payloadValue = ctx.get("jwtPayload");
            if !(payloadValue is jwt:Payload) {
                return <http:NotFound>{body: {"error": "File not found"}};
            }
            
            jwt:Payload payload = payloadValue;
            string userId = payload.sub.toString();
            fileMetadata = check self.fileRepository.findFileByNameAndOwner(fileIdOrName, userId);
            
            if fileMetadata is () {
                return <http:NotFound>{body: {"error": "File not found or access denied"}};
            }
        }

        // Ensure fileMetadata is not null before accessing fields
        if fileMetadata is () {
            return <http:NotFound>{body: {"error": "File not found"}};
        }

        model:AccessLevel accessLevel = fileMetadata.accessLevel;
        string fileOwnerId = fileMetadata.ownerId;

        any authTypeValue = ctx.get("authType");
        string authType = authTypeValue is string ? authTypeValue : "none";

        if accessLevel == model:PUBLIC {
            log:printInfo("Public file access granted for: " + fileIdOrName);
            return ctx.next();
        } else if accessLevel == model:READ_ONLY {
            if httpMethod == "GET" {
                if authType == "none" {
                    return <http:Unauthorized>{body: {"error": "Unauthorized: API key required for read-only files"}};
                }
                log:printInfo("Read-only file GET access granted for: " + fileIdOrName);
                return ctx.next();
            } else {
                if authType != "jwt" {
                    return <http:Unauthorized>{body: {"error": "Unauthorized: JWT authentication required for modifying read-only files"}};
                }
                any payloadValue = ctx.get("jwtPayload");
                if !(payloadValue is jwt:Payload) {
                    return <http:Unauthorized>{body: {"error": "Unauthorized: Invalid JWT authentication"}};
                }
                jwt:Payload payload = payloadValue;
                string userId = payload.sub.toString();
                if userId != fileOwnerId {
                    return <http:Forbidden>{body: {"error": "Forbidden: Only file owner can modify read-only files"}};
                }
                log:printInfo("Read-only file modification access granted for owner: " + userId + ", file: " + fileIdOrName);
                return ctx.next();
            }
        } else if accessLevel == model:PRIVATE {
            if authType != "jwt" {
                return <http:Unauthorized>{body: {"error": "Unauthorized: JWT authentication required for private files"}};
            }
            any payloadValue = ctx.get("jwtPayload");
            if !(payloadValue is jwt:Payload) {
                return <http:Unauthorized>{body: {"error": "Unauthorized: Invalid JWT authentication"}};
            }
            jwt:Payload payload = payloadValue;
            string userId = payload.sub.toString();
            if userId != fileOwnerId {
                return <http:Forbidden>{body: {"error": "Forbidden: Access denied - file is private"}};
            }
            log:printInfo("Private file access granted for owner: " + userId + ", file: " + fileIdOrName);
            return ctx.next();
        }
    }
}
 
service class RoleInterceptor {
    *http:RequestInterceptor;

    resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|http:Unauthorized|http:Forbidden|error? {
        string requestPath = path.length() > 0 ? "/" + string:'join("/", ...path) : "/";
        log:printInfo("Processing role check for path: " + requestPath);

        // Skip role check for register, login, OPTIONS requests, and unauthenticated file access
        if requestPath == "/register" || requestPath == "/login" || req.method == "OPTIONS" {
            return ctx.next();
        }

        // Skip role check for file routes that might be public or read-only
        if requestPath.startsWith("/files/") {
            any authTypeValue = ctx.get("authType");
            string authType = authTypeValue is string ? authTypeValue : "none";
            
            if authType == "none" {
                return ctx.next(); // Let FileAccessInterceptor handle the authorization
            }
        }

        any payloadValue = ctx.get("jwtPayload");
        if !(payloadValue is jwt:Payload) {
            if requestPath.startsWith("/files/") {
                return ctx.next();
            }
            return <http:Unauthorized>{body: {"error": "Unauthorized: No JWT payload in context"}};
        }

        jwt:Payload payload = payloadValue;
        anydata roleValue = payload.get("role");
        if roleValue is string && roleValue == "user" {
            return ctx.next();
        }
        return <http:Forbidden>{body: {"error": "Forbidden: Insufficient role"}};
    }
}

public function getOriginHeader(http:Request req) returns string {
    string|http:HeaderNotFoundError originHeader = req.getHeader("Origin");
    if originHeader is string {
        // Check if the origin is in the allowed list
        foreach string allowedOrigin in CORS_ALLOWED_ORIGINS {
            if allowedOrigin == originHeader || allowedOrigin == "*" {
                return originHeader;
            }
        }
    }
    
    // Return first allowed origin as fallback
    return CORS_ALLOWED_ORIGINS.length() > 0 ? CORS_ALLOWED_ORIGINS[0] : "*";
}

public function setCorsHeaders(http:Response response) {
    // Set allowed origins - use first one as default
    string originHeader = CORS_ALLOWED_ORIGINS.length() > 0 ? CORS_ALLOWED_ORIGINS[0] : "*";
    response.setHeader("Access-Control-Allow-Origin", originHeader);
    
    // Set allowed methods
    string methodsStr = string:'join(", ", ...CORS_ALLOWED_METHODS);
    response.setHeader("Access-Control-Allow-Methods", methodsStr);
    
    // Set allowed headers
    string headersStr = string:'join(", ", ...CORS_ALLOWED_HEADERS);
    response.setHeader("Access-Control-Allow-Headers", headersStr);
    
    // Set credentials
    if CORS_ALLOW_CREDENTIALS {
        response.setHeader("Access-Control-Allow-Credentials", "true");
    }
    
    // Set max age for preflight cache
    response.setHeader("Access-Control-Max-Age", "86400");
}

public function createInterceptors() returns http:Interceptor[] {
    AuthInterceptor|error authInterceptor = new AuthInterceptor();
    FileAccessInterceptor|error fileAccessInterceptor = new FileAccessInterceptor();
    
    if authInterceptor is error {
        log:printError("Failed to create AuthInterceptor: " + authInterceptor.message());
        return [new CorsRequestInterceptor(), new CorsResponseInterceptor(), new RoleInterceptor()];
    }
    
    if fileAccessInterceptor is error {
        log:printError("Failed to create FileAccessInterceptor: " + fileAccessInterceptor.message());
        return [new CorsRequestInterceptor(), new CorsResponseInterceptor(), authInterceptor, new RoleInterceptor()];
    }
    
    return [new CorsRequestInterceptor(), new CorsResponseInterceptor(), authInterceptor, fileAccessInterceptor, new RoleInterceptor()];
}