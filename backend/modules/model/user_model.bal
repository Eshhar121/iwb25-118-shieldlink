public type User record {|
    string username;
    string email;
    string passwordHash;
|};

public type UserRegistrationRequest record {|
    string username;
    string email;
    string password;
|};

public type UserLoginRequest record {|
    string usernameOrEmail;
    string password;
|};