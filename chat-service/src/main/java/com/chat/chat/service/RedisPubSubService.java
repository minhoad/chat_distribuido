package com.chat.chat.service;

import com.chat.common.model.ChatMessage;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class RedisPubSubService {

    private final RedisTemplate<String, ChatMessage> redisTemplate;
    private final ChannelTopic chatTopic;

    public void publish(ChatMessage message) {
        redisTemplate.convertAndSend(chatTopic.getTopic(), message);
    }
}
