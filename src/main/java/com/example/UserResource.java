package com.example;

import io.quarkus.oidc.IdToken;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.jwt.JsonWebToken;

@Path("/api/user")
public class UserResource {

    @Inject
    @IdToken
    JsonWebToken idToken;

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String user() {
        return idToken.getName();
    }
}
