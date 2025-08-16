import ballerinax/mongodb;
import backend.model;
import backend.config;
import ballerina/log;

public isolated class UserRepository {
    private final mongodb:Database db;

    public function init() returns error? {
        mongodb:Client mongoClient = config:getMongoClient();
        self.db = check mongoClient->getDatabase("shieldlink");
    }

    public isolated function insertUser(model:User user) returns error? {
        mongodb:Collection userCollection = check self.db->getCollection("users");
        log:printInfo("Inserting user into MongoDB: " + user.username);
        check userCollection->insertOne(user);
        log:printInfo("User inserted successfully: " + user.username);
    }

    public isolated function findUserByUsernameOrEmail(string usernameOrEmail) returns model:User[]|error {
        mongodb:Collection userCollection = check self.db->getCollection("users");
        map<json> filter = {
            "$or": [
                {"username": usernameOrEmail},
                {"email": usernameOrEmail}
            ]
        };

        log:printInfo("Searching for user with filter: " + filter.toString());
        
        stream<model:User, error?> userStream = check userCollection->find(filter);
        model:User[] users = check from var user in userStream
            select user;
        check userStream.close();
        
        log:printInfo("Found " + users.length().toString() + " users matching: " + usernameOrEmail);
        
        return users;
    }
}