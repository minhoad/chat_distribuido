package com.chat.chat.config;

import com.chat.chat.security.StompPrincipal;
import com.chat.chat.service.JwtValidator;
import com.chat.chat.service.PresenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@Order(Ordered.HIGHEST_PRECEDENCE + 99)
@RequiredArgsConstructor
public class WebSocketAuthConfig implements WebSocketMessageBrokerConfigurer {

    private final PresenceService presenceService;
    private final JwtValidator jwtValidator;

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new UserIdChannelInterceptor(presenceService, jwtValidator));
    }

    @RequiredArgsConstructor
    static class UserIdChannelInterceptor implements ChannelInterceptor {

        private final PresenceService presenceService;
        private final JwtValidator jwtValidator;

        @Override
        public Message<?> preSend(Message<?> message, MessageChannel channel) {
            StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
            if (accessor == null) {
                return message;
            }

            if (accessor.getCommand() == StompCommand.CONNECT) {
                String token = extractToken(accessor);
                if (token == null || !jwtValidator.isValid(token)) {
                    throw new MessageDeliveryException("Token inválido ou ausente");
                }
                String userId = jwtValidator.extractUserId(token);
                accessor.setUser(new StompPrincipal(userId));
                presenceService.userConnected(userId, accessor.getSessionId());
            }

            if (accessor.getCommand() == StompCommand.DISCONNECT) {
                if (accessor.getUser() != null) {
                    presenceService.userDisconnected(accessor.getUser().getName());
                }
            }

            return message;
        }

        private String extractToken(StompHeaderAccessor accessor) {
            String authorization = accessor.getFirstNativeHeader("Authorization");
            if (authorization != null && authorization.startsWith("Bearer ")) {
                return authorization.substring(7);
            }
            String token = accessor.getFirstNativeHeader("token");
            if (token != null && !token.isBlank()) {
                return token;
            }
            return null;
        }
    }
}
