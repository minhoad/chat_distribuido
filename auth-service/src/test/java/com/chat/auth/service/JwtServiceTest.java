package com.chat.auth.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JwtServiceTest {

    private JwtService jwtService;

    @BeforeEach
    void setUp() {
        jwtService = new JwtService(
                "chave-super-secreta-para-assinar-tokens-min-32-chars",
                3600000);
    }

    @Test
    void generatesAndValidatesToken() {
        String token = jwtService.generateToken("user-99", "carol");

        assertTrue(jwtService.isTokenValid(token));
        assertEquals("user-99", jwtService.extractUserId(token));
        assertEquals("carol", jwtService.extractUsername(token));
    }

    @Test
    void invalidTokenIsRejected() {
        assertFalse(jwtService.isTokenValid("token-invalido"));
    }
}
