package com.chat.history.service;

import com.chat.common.model.ChatMessage;
import com.chat.common.model.MessageType;
import com.chat.history.document.ChatMessageDocument;
import com.chat.history.repository.ChatMessageRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class HistoryServiceTest {

    @Mock
    private ChatMessageRepository chatMessageRepository;

    @InjectMocks
    private HistoryService historyService;

    @Test
    void savePersistsMessage() {
        ChatMessageDocument message = ChatMessageDocument.from(ChatMessage.builder()
                .id("msg-1")
                .senderId("a")
                .recipientId("b")
                .content("hello")
                .timestamp(Instant.now())
                .type(MessageType.PRIVATE)
                .build());

        when(chatMessageRepository.save(message)).thenReturn(message);

        ChatMessageDocument saved = historyService.save(message);

        assertEquals("msg-1", saved.getId());
        verify(chatMessageRepository).save(message);
    }

    @Test
    void getConversationReturnsSortedMessages() {
        Instant t1 = Instant.parse("2024-01-01T10:00:00Z");
        Instant t2 = Instant.parse("2024-01-01T11:00:00Z");
        ChatMessageDocument first = ChatMessageDocument.from(ChatMessage.builder().id("1").timestamp(t2).build());
        ChatMessageDocument second = ChatMessageDocument.from(ChatMessage.builder().id("2").timestamp(t1).build());

        when(chatMessageRepository.findConversation("a", "b")).thenReturn(List.of(first, second));

        List<ChatMessageDocument> result = historyService.getConversation("a", "b");

        assertEquals("2", result.get(0).getId());
        assertEquals("1", result.get(1).getId());
    }
}
