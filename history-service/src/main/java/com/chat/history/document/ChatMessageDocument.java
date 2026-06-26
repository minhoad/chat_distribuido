package com.chat.history.document;

import com.chat.common.model.ChatMessage;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;
import org.springframework.data.mongodb.core.mapping.Document;

@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
@Document(collection = "messages")
public class ChatMessageDocument extends ChatMessage {

    public static ChatMessageDocument from(ChatMessage message) {
        ChatMessageDocument document = new ChatMessageDocument();
        document.setId(message.getId());
        document.setSenderId(message.getSenderId());
        document.setRecipientId(message.getRecipientId());
        document.setContent(message.getContent());
        document.setTimestamp(message.getTimestamp());
        document.setType(message.getType());
        return document;
    }
}
