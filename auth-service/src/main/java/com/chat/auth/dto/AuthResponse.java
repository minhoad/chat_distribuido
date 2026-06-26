package com.chat.auth.dto;

public record AuthResponse(
        String token,
        String userId,
        String username
) {}
