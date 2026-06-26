package com.chat.chat.config;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

@Configuration
public class KafkaConfig {

    @Value("${chat.kafka.topic}")
    private String chatTopic;

    @Bean
    public NewTopic chatMessagesTopic() {
        return TopicBuilder.name(chatTopic)
                .partitions(3)
                .replicas(1)
                .build();
    }
}
