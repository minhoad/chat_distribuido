package com.chat.chat.config;

import com.chat.common.model.ChatMessage;
import com.chat.chat.service.RedisMessageSubscriber;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;
import org.springframework.data.redis.serializer.Jackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.StringRedisSerializer;

@Configuration
public class RedisConfig {

    @Value("${chat.redis.channel}")
    private String redisChannel;

    @Bean
    public ObjectMapper redisObjectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());
        return mapper;
    }

    @Bean
    public Jackson2JsonRedisSerializer<ChatMessage> chatMessageSerializer(ObjectMapper redisObjectMapper) {
        return new Jackson2JsonRedisSerializer<>(redisObjectMapper, ChatMessage.class);
    }

    @Bean
    public RedisTemplate<String, ChatMessage> redisTemplate(
            RedisConnectionFactory factory,
            Jackson2JsonRedisSerializer<ChatMessage> chatMessageSerializer) {
        RedisTemplate<String, ChatMessage> template = new RedisTemplate<>();
        template.setConnectionFactory(factory);
        template.setKeySerializer(new StringRedisSerializer());
        template.setValueSerializer(chatMessageSerializer);
        template.setHashKeySerializer(new StringRedisSerializer());
        template.setHashValueSerializer(chatMessageSerializer);
        template.afterPropertiesSet();
        return template;
    }

    @Bean
    public ChannelTopic chatTopic() {
        return new ChannelTopic(redisChannel);
    }

    @Bean
    public RedisMessageListenerContainer redisMessageListenerContainer(
            RedisConnectionFactory factory,
            RedisMessageSubscriber subscriber,
            ChannelTopic chatTopic) {
        RedisMessageListenerContainer container = new RedisMessageListenerContainer();
        container.setConnectionFactory(factory);
        container.addMessageListener(subscriber, chatTopic);
        return container;
    }
}
