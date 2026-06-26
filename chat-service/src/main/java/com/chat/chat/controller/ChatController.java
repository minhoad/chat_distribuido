package com.chat.chat.controller;

import com.chat.common.model.ChatMessage;
import com.chat.chat.service.KafkaProducerService;
import com.chat.chat.service.RedisPubSubService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Controller;

import java.time.Instant;
import java.util.UUID;

@Controller
@RequiredArgsConstructor
public class ChatController {

    private final RedisPubSubService redisPubSubService;
    private final KafkaProducerService kafkaProducerService;

    @MessageMapping("/chat.send")
    public void sendMessage(@Payload ChatMessage message) {
        if (message.getTimestamp() == null) {
            message.setTimestamp(Instant.now());
        }
        if (message.getId() == null) {
            message.setId(UUID.randomUUID().toString());
        }

        redisPubSubService.publish(message);
        kafkaProducerService.sendMessageToHistory(message);
    }
}
