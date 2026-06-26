package com.chat.chat.controller;

import com.chat.common.model.ChatMessage;
import com.chat.chat.service.KafkaProducerService;
import com.chat.chat.service.RedisPubSubService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Controller;

import java.security.Principal;
import java.time.Instant;
import java.util.UUID;

@Slf4j
@Controller
@RequiredArgsConstructor
public class ChatController {

    private final RedisPubSubService redisPubSubService;
    private final KafkaProducerService kafkaProducerService;

    @MessageMapping("/chat.send")
    public void sendMessage(@Payload ChatMessage message, Principal principal) {
        if (principal == null) {
            log.warn("Mensagem rejeitada: usuário não autenticado no WebSocket");
            return;
        }

        if (message.getSenderId() == null || !principal.getName().equals(message.getSenderId())) {
            log.warn("Mensagem rejeitada: senderId {} não corresponde ao usuário autenticado {}",
                    message.getSenderId(), principal.getName());
            return;
        }

        if (message.getRecipientId() == null || message.getRecipientId().isBlank()) {
            log.warn("Mensagem rejeitada: recipientId ausente");
            return;
        }

        if (message.getContent() == null || message.getContent().isBlank()) {
            return;
        }

        if (message.getTimestamp() == null) {
            message.setTimestamp(Instant.now());
        }
        if (message.getId() == null) {
            message.setId(UUID.randomUUID().toString());
        }

        redisPubSubService.publish(message);
        kafkaProducerService.sendMessageToHistory(message);
        log.info("Mensagem encaminhada: id={}, sender={}, recipient={}, type={}",
                message.getId(), message.getSenderId(), message.getRecipientId(), message.getType());
    }
}
