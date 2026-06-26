import { useCallback, useEffect, useRef, useState } from 'react';
import { fetchConversation, fetchUsers } from './api';
import { createChatClient } from './chatClient';

const GROUPS = [
  { id: 'sala-geral', name: 'Sala Geral' },
  { id: 'projeto-sd', name: 'Projeto SD' },
];

export default function ChatPage({ auth, onLogout }) {
  const [users, setUsers] = useState([]);
  const [selectedPeer, setSelectedPeer] = useState(null);
  const [selectedGroup, setSelectedGroup] = useState(null);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [connected, setConnected] = useState(false);
  const chatRef = useRef(null);
  const chatClientRef = useRef(null);

  useEffect(() => {
    fetchUsers()
      .then((list) => setUsers(list.filter((u) => u.id !== auth.userId)))
      .catch(console.error);
  }, [auth.userId]);

  const appendMessage = useCallback((msg) => {
    setMessages((prev) => {
      if (prev.some((m) => m.id === msg.id)) return prev;
      return [...prev, msg];
    });
    chatRef.current?.scrollTo({ top: chatRef.current.scrollHeight, behavior: 'smooth' });
  }, []);

  useEffect(() => {
    const chat = createChatClient(auth.token);
    chatClientRef.current = chat;

    chat.client.onConnect = () => {
      setConnected(true);
      chat.subscribePrivate(appendMessage);
      GROUPS.forEach((g) => chat.subscribeGroup(g.id, appendMessage));
    };
    chat.client.onDisconnect = () => setConnected(false);
    chat.connect();

    return () => chat.disconnect();
  }, [auth.token, appendMessage]);

  useEffect(() => {
    if (!selectedPeer) return;
    fetchConversation(auth.userId, selectedPeer.id)
      .then((history) => setMessages(history))
      .catch(() => setMessages([]));
  }, [selectedPeer, auth.userId]);

  useEffect(() => {
    if (!selectedGroup) return;
    setMessages([]);
  }, [selectedGroup]);

  const sendMessage = () => {
    if (!input.trim() || !chatClientRef.current) return;
    const chat = chatClientRef.current;

    if (selectedPeer) {
      chat.sendPrivate(selectedPeer.id, input.trim(), auth.userId);
    } else if (selectedGroup) {
      chat.sendGroup(selectedGroup.id, input.trim(), auth.userId);
    } else {
      return;
    }
    setInput('');
  };

  const activeTitle = selectedPeer?.username || selectedGroup?.name || 'Selecione uma conversa';

  const visibleMessages = messages.filter((msg) => {
    if (selectedPeer) {
      const type = msg.type?.toString();
      return type === 'PRIVATE' && (
        (msg.senderId === auth.userId && msg.recipientId === selectedPeer.id) ||
        (msg.senderId === selectedPeer.id && msg.recipientId === auth.userId)
      );
    }
    if (selectedGroup) {
      return msg.type?.toString() === 'GROUP' && msg.recipientId === selectedGroup.id;
    }
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
        </header>

        <div className="messages" ref={chatRef}>
          {visibleMessages.length === 0 && <p className="empty">Nenhuma mensagem ainda.</p>}
          {visibleMessages.map((msg) => {
            const isMine = msg.senderId === auth.userId;
            return (
              <div key={msg.id || `${msg.timestamp}-${msg.content}`} className={`bubble ${isMine ? 'mine' : 'other'}`}>
                <span className="meta">{isMine ? 'Você' : msg.senderId}</span>
                <p>{msg.content}</p>
              </div>
            );
          })}
        </div>

        <footer className="composer">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Digite sua mensagem..."
            onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
            disabled={!selectedPeer && !selectedGroup}
          />
          <button type="button" onClick={sendMessage} disabled={!selectedPeer && !selectedGroup}>
            Enviar
          </button>
        </footer>
      </main>
    </div>
  );
}
