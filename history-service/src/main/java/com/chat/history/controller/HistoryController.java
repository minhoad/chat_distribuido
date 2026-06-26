package com.chat.history.controller;

import com.chat.history.document.ChatMessageDocument;
import com.chat.history.service.HistoryService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/history")
@RequiredArgsConstructor
public class HistoryController {

    private final HistoryService historyService;

    @GetMapping("/conversation/{userId}/{peerId}")
    public List<ChatMessageDocument> getConversation(
            @PathVariable String userId,
            @PathVariable String peerId) {
        return historyService.getConversation(userId, peerId);
    }

    @GetMapping("/recipient/{recipientId}")
    public List<ChatMessageDocument> getMessagesForRecipient(@PathVariable String recipientId) {
        return historyService.getMessagesForRecipient(recipientId);
    }
}
