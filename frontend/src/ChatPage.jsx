import { useCallback, useEffect, useRef, useState } from 'react';
import { fetchConversation, fetchGroupHistory, fetchUsers } from './api';
import { createChatClient } from './chatClient';
import { isGroupMessage, isPrivateBetween, mergeMessages, messageKey } from './messages';

const GROUPS = [
  { id: 'sala-geral', name: 'Sala Geral' },
  { id: 'projeto-sd', name: 'Projeto SD' },
];

const USERS_REFRESH_MS = 15000;

export default function ChatPage({ auth, onLogout }) {
  const [users, setUsers] = useState([]);
  const [selectedPeer, setSelectedPeer] = useState(null);
  const [selectedGroup, setSelectedGroup] = useState(null);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [connected, setConnected] = useState(false);
  const [chatError, setChatError] = useState('');
  const [historyError, setHistoryError] = useState('');
  const chatRef = useRef(null);
  const chatClientRef = useRef(null);

  const loadUsers = useCallback(() => {
    fetchUsers()
      .then((list) => setUsers(list.filter((u) => u.id !== auth.userId)))
      .catch((err) => console.error(err));
  }, [auth.userId]);

  useEffect(() => {
    loadUsers();
    const interval = setInterval(loadUsers, USERS_REFRESH_MS);
    return () => clearInterval(interval);
  }, [loadUsers]);

  const userNames = users.reduce((map, user) => {
    map[user.id] = user.username;
    return map;
  }, { [auth.userId]: auth.username });

  const appendMessage = useCallback((msg) => {
    setMessages((prev) => {
      const key = messageKey(msg);
      if (prev.some((m) => messageKey(m) === key)) return prev;
      return mergeMessages(prev, [msg]);
    });
    chatRef.current?.scrollTo({ top: chatRef.current.scrollHeight, behavior: 'smooth' });
  }, []);

  useEffect(() => {
    const chat = createChatClient(auth.token, {
      onError: (message) => setChatError(message),
    });
    chatClientRef.current = chat;

    chat.client.onConnect = () => {
      setConnected(true);
      setChatError('');
      chat.subscribePrivate(appendMessage);
      GROUPS.forEach((g) => chat.subscribeGroup(g.id, appendMessage));
    };
    chat.client.onDisconnect = () => setConnected(false);
    chat.connect();

    return () => chat.disconnect();
  }, [auth.token, appendMessage]);

  useEffect(() => {
    if (!selectedPeer) return;

    setHistoryError('');
    let cancelled = false;

    fetchConversation(auth.userId, selectedPeer.id)
      .then((history) => {
        if (cancelled) return;
        setMessages((prev) => {
          const live = prev.filter((msg) => isPrivateBetween(msg, auth.userId, selectedPeer.id));
          return mergeMessages(live, history);
        });
      })
      .catch((err) => {
        if (cancelled) return;
        setHistoryError(err.message || 'Falha ao carregar histórico');
      });

    return () => { cancelled = true; };
  }, [selectedPeer, auth.userId]);

  useEffect(() => {
    if (!selectedGroup) return;

    setHistoryError('');
    let cancelled = false;

    fetchGroupHistory(selectedGroup.id)
      .then((history) => {
        if (cancelled) return;
        setMessages((prev) => {
          const live = prev.filter((msg) => isGroupMessage(msg, selectedGroup.id));
          return mergeMessages(live, history);
        });
      })
      .catch((err) => {
        if (cancelled) return;
        setHistoryError(err.message || 'Falha ao carregar histórico do grupo');
      });

    return () => { cancelled = true; };
  }, [selectedGroup]);

  const sendMessage = () => {
    if (!input.trim() || !chatClientRef.current || !connected) return;
    const chat = chatClientRef.current;

    try {
      if (selectedPeer) {
        chat.sendPrivate(selectedPeer.id, input.trim(), auth.userId);
      } else if (selectedGroup) {
        chat.sendGroup(selectedGroup.id, input.trim(), auth.userId);
      } else {
        return;
      }
      setInput('');
      setChatError('');
    } catch (err) {
      setChatError(err.message || 'Não foi possível enviar a mensagem');
    }
  };

  const activeTitle = selectedPeer?.username || selectedGroup?.name || 'Selecione uma conversa';

  const visibleMessages = messages.filter((msg) => {
    if (selectedPeer) return isPrivateBetween(msg, auth.userId, selectedPeer.id);
    if (selectedGroup) return isGroupMessage(msg, selectedGroup.id);
    return false;
  });

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="sidebar-header">
          <div>
            <strong>{auth.username}</strong>
            <span className={`status ${connected ? 'online' : 'offline'}`}>
              {connected ? 'conectado' : 'desconectado'}
            </span>
          </div>
          <button type="button" className="ghost" onClick={onLogout}>Sair</button>
        </div>

        <section>
          <h3>Usuários</h3>
          <ul className="conversation-list">
            {users.map((user) => (
              <li
                key={user.id}
                className={selectedPeer?.id === user.id ? 'active' : ''}
                onClick={() => { setSelectedPeer(user); setSelectedGroup(null); }}
              >
                {user.username}
              </li>
            ))}
          </ul>
        </section>

        <section>
          <h3>Grupos (1:N)</h3>
          <ul className="conversation-list">
            {GROUPS.map((group) => (
              <li
                key={group.id}
                className={selectedGroup?.id === group.id ? 'active' : ''}
                onClick={() => { setSelectedGroup(group); setSelectedPeer(null); }}
              >
                {group.name}
              </li>
            ))}
          </ul>
        </section>
      </aside>

      <main className="chat-panel">
        <header className="chat-header">
          <h2>{activeTitle}</h2>
          {(chatError || historyError) && (
            <p className="error inline-error">{chatError || historyError}</p>
          )}
        </header>

        <div className="messages" ref={chatRef}>
          {visibleMessages.length === 0 && <p className="empty">Nenhuma mensagem ainda.</p>}
          {visibleMessages.map((msg) => {
            const isMine = msg.senderId === auth.userId;
            const senderLabel = isMine ? 'Você' : (userNames[msg.senderId] || 'Usuário');
            return (
              <div key={msg.id || `${msg.timestamp}-${msg.content}`} className={`bubble ${isMine ? 'mine' : 'other'}`}>
                <span className="meta">{senderLabel}</span>
                <p>{msg.content}</p>
              </div>
            );
          })}
        </div>

        <footer className="composer">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder={connected ? 'Digite sua mensagem...' : 'Conectando ao chat...'}
            onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
            disabled={(!selectedPeer && !selectedGroup) || !connected}
          />
          <button
            type="button"
            onClick={sendMessage}
            disabled={(!selectedPeer && !selectedGroup) || !connected}
          >
            Enviar
          </button>
        </footer>
      </main>
    </div>
  );
}
