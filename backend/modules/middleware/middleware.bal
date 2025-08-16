import backend.utils;
import ballerina/http;
import ballerina/jwt;
import ballerina/log;

configurable string[] CORS_ALLOWED_ORIGINS = ?;
configurable string[] CORS_ALLOWED_METHODS = ?;
configurable string[] CORS_ALLOWED_HEADERS = ?;
configurable boolean CORS_ALLOW_CREDENTIALS = ?;

service class CorsRequestInterceptor {
    *http:RequestInterceptor;

    resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|http:Ok|error? {
        // Handle OPTIONS requests immediately for CORS preflight
        if req.method == "OPTIONS" {
            return <http:Ok>{
                body: "",
                headers: {
                    "Access-Control-Allow-Origin": CORS_ALLOWED_ORIGINS.length() > 0 ? CORS_ALLOWED_ORIGINS[0] : "*",
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
        setCorsHeaders(res);
        return ctx.next();
    }
}

service class AuthInterceptor {
    *http:RequestInterceptor;

    resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|error? {
        string requestPath = path.length() > 0 ? "/" + string:'join("/", ...path) : "/";
        log:printInfo("Processing request for path: " + requestPath);

        // Skip authentication for register, login, and OPTIONS requests
        if requestPath == "/register" || requestPath == "/login" || req.method == "OPTIONS" {
            return ctx.next();
        }

        string|http:HeaderNotFoundError authHeaderResult = req.getHeader("Authorization");
        if authHeaderResult is http:HeaderNotFoundError || authHeaderResult == "" || !authHeaderResult.startsWith("Bearer ") {
            return error("Unauthorized: Missing or invalid Bearer token");
        }

        string authHeader = authHeaderResult;
        string token = authHeader.substring(7);
        jwt:Payload|error payload = utils:validateToken(token);
        if payload is error {
            log:printError("Token validation failed: " + payload.message());
            return error("Unauthorized: Invalid token - " + payload.message());
        }

        ctx.set("jwtPayload", payload);
        return ctx.next();
    }
}

service class RoleInterceptor {
    *http:RequestInterceptor;

    resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|error? {
        string requestPath = path.length() > 0 ? "/" + string:'join("/", ...path) : "/";
        log:printInfo("Processing role check for path: " + requestPath);

        // Skip role check for register, login, and OPTIONS requests
        if requestPath == "/register" || requestPath == "/login" || req.method == "OPTIONS" {
            return ctx.next();
        }

        jwt:Payload|error payload = ctx.getWithType("jwtPayload", jwt:Payload);
        if payload is error {
            return error("Unauthorized: No JWT payload in context - " + payload.message());
        }

        anydata role = payload.get("role");
        if role is string && role == "user" {
            return ctx.next();
        }
        return error("Forbidden: Insufficient role");
    }
}

public function setCorsHeaders(http:Response response) {
    // Set allowed origins
    if CORS_ALLOWED_ORIGINS.length() > 0 {
        string firstOrigin = CORS_ALLOWED_ORIGINS[0];
        response.setHeader("Access-Control-Allow-Origin", firstOrigin);
    }
    
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
    return [new CorsRequestInterceptor(), new CorsResponseInterceptor(), new AuthInterceptor(), new RoleInterceptor()];
}