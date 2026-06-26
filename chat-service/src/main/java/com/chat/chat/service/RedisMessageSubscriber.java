package com.chat.chat.service;

import com.chat.common.model.ChatMessage;
import com.chat.common.model.MessageType;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class RedisMessageSubscriber implements MessageListener {

    private final SimpMessagingTemplate messagingTemplate;
    private final ObjectMapper redisObjectMapper;

    @Override
    public void onMessage(Message message, byte[] pattern) {
        try {
            ChatMessage chatMessage = redisObjectMapper.readValue(message.getBody(), ChatMessage.class);
            deliverMessage(chatMessage);
        } catch (Exception e) {
            log.error("Falha ao processar mensagem do Redis Pub/Sub", e);
        }
    }

    private void deliverMessage(ChatMessage chatMessage) {
        if (chatMessage.getType() == MessageType.GROUP) {
            messagingTemplate.convertAndSend(
                    "/topic/group." + chatMessage.getRecipientId(),
                    chatMessage);
            return;
        }

        messagingTemplate.convertAndSendToUser(
                chatMessage.getRecipientId(),
                "/queue/messages",
                chatMessage);
    }
}
