package com.chat.chat.service;

import com.chat.common.model.ChatMessage;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class KafkaProducerService {

    private final KafkaTemplate<String, ChatMessage> kafkaTemplate;

    @Value("${chat.kafka.topic}")
    private String chatTopic;

    public void sendMessageToHistory(ChatMessage message) {
        kafkaTemplate.send(chatTopic, message.getId(), message);
    }
}
