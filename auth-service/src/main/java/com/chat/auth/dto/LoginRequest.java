package com.chat.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
        @NotBlank(message = "Informe o usuário.") String username,
        @NotBlank(message = "Informe a senha.") String password
) {}
