package com.chat.history.consumer;

import com.chat.common.model.ChatMessage;
import com.chat.history.document.ChatMessageDocument;
import com.chat.history.service.HistoryService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class ChatMessageConsumer {

    private final HistoryService historyService;

    @KafkaListener(topics = "${chat.kafka.topic}", groupId = "history-consumer-group")
    public void consume(ChatMessage message) {
        ChatMessageDocument saved = historyService.save(ChatMessageDocument.from(message));
        log.info("Mensagem persistida: id={}, sender={}, recipient={}",
                saved.getId(), saved.getSenderId(), saved.getRecipientId());
    }
}
