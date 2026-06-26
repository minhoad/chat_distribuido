package com.chat.history.repository;

import com.chat.history.document.ChatMessageDocument;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

import java.util.List;

public interface ChatMessageRepository extends MongoRepository<ChatMessageDocument, String> {

    List<ChatMessageDocument> findByRecipientIdOrderByTimestampAsc(String recipientId);

    List<ChatMessageDocument> findBySenderIdAndRecipientIdOrderByTimestampAsc(String senderId, String recipientId);

    @Query("""
            { $or: [
                { senderId: ?0, recipientId: ?1 },
                { senderId: ?1, recipientId: ?0 }
            ] }
            """)
    List<ChatMessageDocument> findConversation(String userId, String peerId);
}
