package com.chat.chat.service;

import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;

@Service
@RequiredArgsConstructor
public class PresenceService {

    private static final String SESSION_KEY_PREFIX = "user:session:";
    private static final String ONLINE_KEY_PREFIX = "user:online:";
    private static final Duration SESSION_TTL = Duration.ofHours(24);

    private final StringRedisTemplate stringRedisTemplate;

    public void userConnected(String userId, String sessionId) {
        stringRedisTemplate.opsForValue().set(sessionKey(userId), sessionId, SESSION_TTL);
        stringRedisTemplate.opsForValue().set(onlineKey(userId), "true", SESSION_TTL);
    }

    public void userDisconnected(String userId) {
        stringRedisTemplate.delete(sessionKey(userId));
        stringRedisTemplate.delete(onlineKey(userId));
    }

    public boolean isOnline(String userId) {
        return Boolean.TRUE.toString().equals(stringRedisTemplate.opsForValue().get(onlineKey(userId)));
    }

    public String getSessionId(String userId) {
        return stringRedisTemplate.opsForValue().get(sessionKey(userId));
    }

    private String sessionKey(String userId) {
        return SESSION_KEY_PREFIX + userId;
    }

    private String onlineKey(String userId) {
        return ONLINE_KEY_PREFIX + userId;
    }
}
