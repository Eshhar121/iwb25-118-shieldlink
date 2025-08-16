import backend.repository;
import backend.model;
import backend.utils;
import ballerina/jwt;
import ballerina/time;
import ballerina/log;

public isolated class AuthService {
    private final repository:UserRepository userRepository;

    public function init() returns error? {
        self.userRepository = check new repository:UserRepository();
    }

    public isolated function register(model:UserRegistrationRequest userRequest) returns string|error {
        log:printInfo("Hashing password for user: " + userRequest.username);
        string hashedPassword = check utils:hashPassword(userRequest.password);
        
        model:User newUser = {
            username: userRequest.username,
            email: userRequest.email,
            passwordHash: hashedPassword
        };
        
        log:printInfo("Inserting user into database: " + userRequest.username);
        check self.userRepository.insertUser(newUser);
        log:printInfo("User successfully inserted into database: " + userRequest.username);
        
        return "User registered successfully!";
    }

    public isolated function login(string usernameOrEmail, string password) returns jwt:Payload|error {
        log:printInfo("Searching for user: " + usernameOrEmail);
        
        model:User[]|error users = self.userRepository.findUserByUsernameOrEmail(usernameOrEmail);
        if users is error {
            log:printError("Database error while searching for user: " + users.message());
            return error("Database error: " + users.message());
        }

        if users.length() == 0 {
            log:printError("User not found in database: " + usernameOrEmail);
            return error("User not found");
        }

        model:User user = users[0];
        log:printInfo("User found: " + user.username + ", verifying password");
        
        boolean isValid = check utils:verifyPassword(password, user.passwordHash);
        if !isValid {
            log:printError("Password verification failed for user: " + usernameOrEmail);
            return error("Invalid password");
        }

        log:printInfo("Password verified successfully for user: " + usernameOrEmail);
        
        time:Utc currentTime = time:utcNow();
        int currentTimeSeconds = currentTime[0];

        jwt:Payload payload = {
            sub: user.username,
            iss: "eshhar/backend",
            exp: currentTimeSeconds + (24 * 60 * 60),
            iat: currentTimeSeconds,
            "role": "user"
        };
        return payload;
    }
    
    public isolated function getUserRepository() returns repository:UserRepository {
        return self.userRepository;
    }
}