import { Client } from '@stomp/stompjs';
import SockJS from 'sockjs-client';

export function createChatClient(token) {
  const wsUrl = import.meta.env.VITE_WS_BASE || `${window.location.origin}/ws`;

  const client = new Client({
    webSocketFactory: () => new SockJS(wsUrl),
    connectHeaders: {
      Authorization: `Bearer ${token}`,
    },
    reconnectDelay: 3000,
    debug: (msg) => {
      if (import.meta.env.DEV) console.debug('[STOMP]', msg);
    },
  });

  const api = {
    client,
    connect: () => client.activate(),
    disconnect: () => client.deactivate(),
    sendPrivate: (recipientId, content, senderId) => {
      client.publish({
        destination: '/app/chat.send',
        body: JSON.stringify({
          senderId,
          recipientId,
          content,
          type: 'PRIVATE',
        }),
      });
    },
    sendGroup: (groupId, content, senderId) => {
      client.publish({
        destination: '/app/chat.send',
        body: JSON.stringify({
          senderId,
          recipientId: groupId,
          content,
          type: 'GROUP',
        }),
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
