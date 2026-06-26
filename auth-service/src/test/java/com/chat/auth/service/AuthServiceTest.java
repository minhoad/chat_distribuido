package com.chat.auth.service;

import com.chat.auth.dto.LoginRequest;
import com.chat.auth.dto.RegisterRequest;
import com.chat.auth.entity.User;
import com.chat.auth.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    private JwtService jwtService;
    private AuthService authService;

    private User user;

    @BeforeEach
    void setUp() {
        jwtService = new JwtService(
                "chave-super-secreta-para-assinar-tokens-min-32-chars",
                3600000);
        authService = new AuthService(userRepository, passwordEncoder, jwtService);

        user = User.builder()
                .id("user-1")
                .username("alice")
                .email("alice@test.com")
                .password("encoded")
                .build();
    }

    @Test
    void loginWithValidCredentialsReturnsToken() {
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("senha123", "encoded")).thenReturn(true);

        var response = authService.login(new LoginRequest("alice", "senha123"));

        assertNotNull(response.token());
        assertEquals("user-1", response.userId());
    }

    @Test
    void loginWithInvalidPasswordThrowsUnauthorized() {
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("wrong", "encoded")).thenReturn(false);

        assertThrows(ResponseStatusException.class,
                () -> authService.login(new LoginRequest("alice", "wrong")));
    }

    @Test
    void registerPersistsUserAndReturnsToken() {
        when(userRepository.existsByUsername("bob")).thenReturn(false);
        when(userRepository.existsByEmail("bob@test.com")).thenReturn(false);
        when(passwordEncoder.encode(anyString())).thenReturn("encoded");
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> {
            User saved = invocation.getArgument(0);
            saved.setId("user-2");
            return saved;
        });

        var response = authService.register(new RegisterRequest("bob", "bob@test.com", "senha123"));

        assertNotNull(response.token());
        assertEquals("bob", response.username());
    }
}
