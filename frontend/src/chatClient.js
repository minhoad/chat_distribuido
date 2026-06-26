import { Client } from '@stomp/stompjs';
import SockJS from 'sockjs-client';

const JSON_HEADERS = { 'content-type': 'application/json' };

export function createChatClient(token, { onError } = {}) {
  const wsUrl = import.meta.env.VITE_WS_BASE || `${window.location.origin}/ws`;

  const client = new Client({
    webSocketFactory: () => new SockJS(wsUrl),
    connectHeaders: {
      Authorization: `Bearer ${token}`,
    },
    reconnectDelay: 3000,
    heartbeatIncoming: 10000,
    heartbeatOutgoing: 10000,
    debug: (msg) => {
      if (import.meta.env.DEV) console.debug('[STOMP]', msg);
    },
  });

  client.onStompError = (frame) => {
    const message = frame.headers?.message || 'Falha na conexão do chat';
    onError?.(message);
    console.error('[STOMP ERROR]', frame);
  };

  client.onWebSocketError = (event) => {
    onError?.('Não foi possível conectar ao servidor de chat');
    console.error('[WS ERROR]', event);
  };

  const ensureConnected = () => {
    if (!client.connected) {
      throw new Error('Chat desconectado. Aguarde a reconexão.');
    }
  };

  const publishMessage = (payload) => {
    ensureConnected();
    client.publish({
      destination: '/app/chat.send',
      headers: JSON_HEADERS,
      body: JSON.stringify(payload),
    });
  };

  const api = {
    client,
    connect: () => client.activate(),
    disconnect: () => client.deactivate(),
    sendPrivate: (recipientId, content, senderId) => {
      publishMessage({
        senderId,
        recipientId,
        content,
        type: 'PRIVATE',
      });
    },
    sendGroup: (groupId, content, senderId) => {
      publishMessage({
        senderId,
        recipientId: groupId,
        content,
        type: 'GROUP',
      });
    },
    subscribeGroup: (groupId, handler) => {
      return client.subscribe(`/topic/group.${groupId}`, (msg) => {
        handler(JSON.parse(msg.body));
      });
    },
    subscribePrivate: (handler) => {
      return client.subscribe('/user/queue/messages', (msg) => {
        handler(JSON.parse(msg.body));
      });
    },
  };

  return api;
}
