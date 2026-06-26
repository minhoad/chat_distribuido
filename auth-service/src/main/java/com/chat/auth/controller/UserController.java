package com.chat.auth.controller;

import com.chat.auth.dto.UserSummary;
import com.chat.auth.entity.User;
import com.chat.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;

    @GetMapping("/users")
    public List<UserSummary> listUsers() {
        return userRepository.findAll().stream()
                .map(this::toSummary)
                .toList();
    }

    private UserSummary toSummary(User user) {
        return new UserSummary(user.getId(), user.getUsername(), user.getEmail());
    }
}
