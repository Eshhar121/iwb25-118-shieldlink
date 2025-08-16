import ballerina/http;
import backend.routes;
import backend.config;

listener http:Listener authListener = new (9090);

public function main() returns error? {
    config:startConfigs();
    check authListener.attach(check new routes:AuthService(), "/auth");
    check authListener.start();
    routes:startRoutes();
}