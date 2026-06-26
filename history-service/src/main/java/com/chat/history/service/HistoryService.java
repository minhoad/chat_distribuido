package com.chat.history.service;

import com.chat.history.document.ChatMessageDocument;
import com.chat.history.repository.ChatMessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class HistoryService {

    private final ChatMessageRepository chatMessageRepository;

    public ChatMessageDocument save(ChatMessageDocument message) {
        return chatMessageRepository.save(message);
    }

    public List<ChatMessageDocument> getConversation(String userId, String peerId) {
        return chatMessageRepository.findConversation(userId, peerId).stream()
                .sorted((a, b) -> a.getTimestamp().compareTo(b.getTimestamp()))
                .toList();
    }

    public List<ChatMessageDocument> getMessagesForRecipient(String recipientId) {
        return chatMessageRepository.findByRecipientIdOrderByTimestampAsc(recipientId);
    }
}
