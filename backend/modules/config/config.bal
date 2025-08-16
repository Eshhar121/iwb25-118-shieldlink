import ballerina/io;
import ballerinax/mongodb;

configurable string MONGODB_URI = ?;

isolated mongodb:Client mongoDb = check new ({
    connection: MONGODB_URI
});

public isolated function getMongoClient() returns mongodb:Client {
    lock {
	    return mongoDb;
    }
}

public function startConfigs() {
    io:println("MongoDB connected.");
}