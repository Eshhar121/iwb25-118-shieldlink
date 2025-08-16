import ballerina/jwt;

public isolated function issueToken(string username, string issuer) returns string|error {
    jwt:IssuerConfig issuerConfig = {
        username: username,
        issuer: issuer,
        audience: ["*"],
        expTime: 86400,
        customClaims: {
            "role": "user"
        },
        signatureConfig: {
            algorithm: jwt:RS256,
            config: {
                keyFile: "resources/private.key"
            }
        }
    };
    return jwt:issue(issuerConfig);
}

public isolated function validateToken(string token) returns jwt:Payload|error {
    jwt:ValidatorConfig validatorConfig = {
        issuer: "dev-lord",
        audience: ["*"],
        clockSkew: 60,
        signatureConfig: {
            certFile: "resources/public.crt"
        }
    };
    return jwt:validate(token, validatorConfig);
}