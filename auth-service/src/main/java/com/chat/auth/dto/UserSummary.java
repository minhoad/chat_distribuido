package com.chat.auth.dto;

public record UserSummary(
        String id,
        String username,
        String email
) {}
