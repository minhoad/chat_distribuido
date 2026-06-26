package com.chat.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @NotBlank(message = "Informe um nome de usuário.")
        @Size(min = 3, max = 50, message = "O usuário deve ter entre 3 e 50 caracteres.")
        String username,
        @NotBlank(message = "Informe um email.")
        @Email(message = "Informe um email válido.")
        String email,
        @NotBlank(message = "Informe uma senha.")
        @Size(min = 6, max = 100, message = "A senha deve ter entre 6 e 100 caracteres.")
        String password
) {}
