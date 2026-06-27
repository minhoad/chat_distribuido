/**
 * E2E minimo: REST auth (via Gateway) + STOMP (login -> CONNECT -> envio GROUP -> recebimento).
 * Nao substitui teste de 10 usuarios concorrentes; valida integracao auth + chat-service.
 *
 * Env:
 *   GATEWAY_URL  default http://localhost:8080
 *   WS_URL       default http://localhost:8080/ws  (Gateway -> chat-service)
 *
 * Uso: npm install && npm run e2e
 */

import { Client } from '@stomp/stompjs';
import SockJS from 'sockjs-client';

const GATEWAY = process.env.GATEWAY_URL || 'http://localhost:8080';
const WS_URL = process.env.WS_URL || `${GATEWAY}/ws`;
const GROUP_ID = 'sala-geral';
const TIMEOUT_MS = 15000;

const JSON_HEADERS = { 'content-type': 'application/json' };

function log(step, msg) {
  console.log(`[${step}] ${msg}`);
}

async function registerOrLogin(username) {
  const password = 'senha123';
  const email = `${username}@e2e.test`;
  const registerRes = await fetch(`${GATEWAY}/api/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, email, password }),
  });
  if (registerRes.ok) {
    return registerRes.json();
  }
  const loginRes = await fetch(`${GATEWAY}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  });
  if (!loginRes.ok) {
    const text = await loginRes.text();
    throw new Error(`Auth falhou para ${username}: ${loginRes.status} ${text}`);
  }
  return loginRes.json();
}

function connectStomp(token) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      client.deactivate();
      reject(new Error(`STOMP connect timeout (${TIMEOUT_MS}ms) em ${WS_URL}`));
    }, TIMEOUT_MS);

    const client = new Client({
      webSocketFactory: () => new SockJS(WS_URL),
      connectHeaders: { Authorization: `Bearer ${token}` },
      reconnectDelay: 0,
      heartbeatIncoming: 0,
      heartbeatOutgoing: 0,
      debug: () => {},
      onStompError: (frame) => {
        clearTimeout(timer);
        reject(new Error(`STOMP error: ${frame.headers?.message || 'unknown'}`));
      },
      onWebSocketError: (ev) => {
        clearTimeout(timer);
        reject(new Error(`WebSocket error: ${ev?.message || ev}`));
      },
      onConnect: () => {
        clearTimeout(timer);
        resolve(client);
      },
    });
    client.activate();
  });
}

function waitForGroupMessage(client, groupId, predicate, timeoutMs) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      sub?.unsubscribe();
      reject(new Error(`Timeout aguardando mensagem no grupo ${groupId}`));
    }, timeoutMs);

    const sub = client.subscribe(`/topic/group.${groupId}`, (msg) => {
      try {
        const body = JSON.parse(msg.body);
        if (predicate(body)) {
          clearTimeout(timer);
          sub.unsubscribe();
          resolve(body);
        }
      } catch (e) {
        clearTimeout(timer);
        sub.unsubscribe();
        reject(e);
      }
    });
  });
}

function publishGroup(client, { senderId, groupId, content }) {
  client.publish({
    destination: '/app/chat.send',
    headers: JSON_HEADERS,
    body: JSON.stringify({
      senderId,
      recipientId: groupId,
      content,
      type: 'GROUP',
    }),
  });
}

async function main() {
  const runId = Date.now();
  const senderName = `e2e_sender_${runId}`;
  const receiverName = `e2e_recv_${runId}`;
  const marker = `e2e-msg-${runId}`;
  const timings = {};

  console.log('=== E2E auth + STOMP ===');
  console.log(`Gateway: ${GATEWAY}`);
  console.log(`WebSocket: ${WS_URL}`);
  console.log('');

  let t0 = performance.now();
  log('1/5', 'Register/login sender e receiver via Gateway...');
  const sender = await registerOrLogin(senderName);
  const receiver = await registerOrLogin(receiverName);
  timings.authMs = Math.round(performance.now() - t0);

  if (!sender.token || !receiver.token) {
    throw new Error('Token JWT ausente na resposta de auth');
  }
  log('1/5', `OK — sender=${sender.userId}, receiver=${receiver.userId} (${timings.authMs}ms)`);

  t0 = performance.now();
  log('2/5', 'STOMP CONNECT receiver...');
  const recvClient = await connectStomp(receiver.token);
  timings.receiverConnectMs = Math.round(performance.now() - t0);
  log('2/5', `OK (${timings.receiverConnectMs}ms)`);

  t0 = performance.now();
  log('3/5', 'STOMP CONNECT sender...');
  const sendClient = await connectStomp(sender.token);
  timings.senderConnectMs = Math.round(performance.now() - t0);
  log('3/5', `OK (${timings.senderConnectMs}ms)`);

  log('4/5', 'Subscribe grupo + envio mensagem...');
  const receivePromise = waitForGroupMessage(
    recvClient,
    GROUP_ID,
    (m) => m.content === marker && m.senderId === sender.userId,
    TIMEOUT_MS,
  );

  t0 = performance.now();
  publishGroup(sendClient, {
    senderId: sender.userId,
    groupId: GROUP_ID,
    content: marker,
  });

  const received = await receivePromise;
  timings.deliveryMs = Math.round(performance.now() - t0);
  log('4/5', `OK — mensagem recebida em ${timings.deliveryMs}ms`);

  log('5/5', 'Verificando historico REST (best-effort, Kafka assincrono)...');
  await new Promise((r) => setTimeout(r, 3000));
  t0 = performance.now();
  const histRes = await fetch(`${GATEWAY}/api/history/recipient/${GROUP_ID}`);
  timings.historyCheckMs = Math.round(performance.now() - t0);
  let historyFound = false;
  if (histRes.ok) {
    const hist = await histRes.json();
    historyFound = hist.some((m) => m.content === marker && m.senderId === sender.userId);
  }
  log(
    '5/5',
    historyFound
      ? `OK — mensagem encontrada no Mongo via history-service (${timings.historyCheckMs}ms)`
      : `AVISO — mensagem NAO encontrada no historico apos 3s (Kafka/Mongo podem atrasar; entrega STOMP OK)`,
  );

  sendClient.deactivate();
  recvClient.deactivate();

  console.log('');
  console.log('=== Resultado ===');
  console.log(JSON.stringify({ success: true, stompDelivery: true, historyFound, timings }, null, 2));
  console.log('');
  console.log('Integracao auth->STOMP: PASS');
  if (!historyFound) {
    console.log('Persistencia historico: NAO CONFIRMADA nesta execucao (nao e falha do fluxo tempo real)');
  }
  process.exit(0);
}

main().catch((err) => {
  console.error('');
  console.error('=== FALHA E2E ===');
  console.error(err.message || err);
  console.error('');
  console.error('Verifique: docker compose up -d, Eureka, auth, chat, history, gateway UP');
  console.error(`  WS_URL=${WS_URL}`);
  process.exit(1);
});
