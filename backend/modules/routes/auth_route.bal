import backend.model;
import backend.services;
import backend.utils;
import backend.middleware;
import backend.repository;

import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/jwt;

public function startRoutes() {
    io:println("routes are connected.");
}

public service class AuthService {
    *http:InterceptableService;
    private final services:AuthService authService;

    public function init() returns error? {
        do {
            self.authService = check new services:AuthService();
            log:printInfo("Auth service initialized successfully on port 9090");
        } on fail error e {
            log:printError("Failed to initialize auth service: " + e.message());
            return e;
        }
    }

    resource function post register(http:RequestContext ctx, http:Request req) returns http:Ok|http:BadRequest|http:InternalServerError|error {
        json payload = check req.getJsonPayload();
        log:printInfo("Registration payload received: " + payload.toString());
        
        model:UserRegistrationRequest userRequest = check payload.cloneWithType(model:UserRegistrationRequest);
        log:printInfo("Registering user: " + userRequest.username + " with email: " + userRequest.email);

        string|error result = self.authService.register(userRequest);
        if result is string {
            log:printInfo("User registered successfully: " + userRequest.username);
            return <http:Ok>{body: {"message": result}};
        } else {
            log:printError("Registration failed: " + result.message());
            return <http:InternalServerError>{body: {"error": "Registration failed: " + result.message()}};
        }
    }

    resource function post login(http:RequestContext ctx, http:Request req) returns http:Ok|http:Unauthorized|http:InternalServerError|http:BadRequest|error {
        json payload = check req.getJsonPayload();
        log:printInfo("Login payload received: " + payload.toString());
        
        map<json>? payloadMap = ();
        if payload is map<json> {
            payloadMap = payload;
        } else {
            return <http:BadRequest>{body: {"error": "Invalid payload format"}};
        }

        if payloadMap is () || !payloadMap.hasKey("usernameOrEmail") || !payloadMap.hasKey("password") {
            return <http:BadRequest>{body: {"error": "Missing required fields"}};
        }

        string usernameOrEmail = check payload.usernameOrEmail.ensureType(string);
        string password = check payload.password.ensureType(string);

        log:printInfo("Attempting login for user: " + usernameOrEmail + " with password: " + password);

        jwt:Payload|error result = self.authService.login(usernameOrEmail, password);

        if result is jwt:Payload {
            string|error token = utils:issueToken(usernameOrEmail, "dev-lord");
            if token is string {
                log:printInfo("Login successful for user: " + usernameOrEmail);
                return <http:Ok>{body: {"token": token, "message": "Login successful"}};
            } else {
                log:printError("Token issuance failed: " + token.message());
                return <http:InternalServerError>{body: {"error": "Server error"}};
            }
        } else {
            log:printError("Login failed for user " + usernameOrEmail + ": " + result.message());
            return <http:Unauthorized>{body: {"error": "Invalid credentials"}};
        }
    }

    resource function get user(http:RequestContext ctx, http:Request req) returns http:Ok|http:Unauthorized|http:Forbidden|http:InternalServerError|error {
        jwt:Payload|error payload = ctx.getWithType("jwtPayload", jwt:Payload);
        if payload is error {
            return <http:Unauthorized>{body: {"error": "Missing or invalid JWT payload - " + payload.message()}};
        }

        string username = payload.sub.toString();
        repository:UserRepository userRepository = self.authService.getUserRepository();
        model:User[]|error users = userRepository.findUserByUsernameOrEmail(username);
        if users is error {
            return <http:InternalServerError>{body: {"error": "Database error: " + users.message()}};
        }

        if users.length() > 0 {
            model:User user = users[0];
            // Don't return password hash to frontend
            json userResponse = {
                "username": user.username,
                "email": user.email
            };
            return <http:Ok>{body: userResponse};
        } else {
            return <http:InternalServerError>{body: {"error": "User data not found"}};
        }
    }

    public function createInterceptors() returns http:Interceptor[] {
        return middleware:createInterceptors();
    }
}