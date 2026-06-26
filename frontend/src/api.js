// URLs relativas → passam pelo proxy do Vite (evita CORS)
const API_BASE = import.meta.env.VITE_API_BASE || '';

export async function register(username, email, password) {
  const res = await fetch(`${API_BASE}/api/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, email, password }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `Erro ${res.status} ao registrar`);
  }
  return res.json();
}

export async function login(username, password) {
  const res = await fetch(`${API_BASE}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  });
  if (!res.ok) throw new Error('Credenciais inválidas');
  return res.json();
}

export async function fetchUsers() {
  const res = await fetch(`${API_BASE}/api/auth/users`);
  if (!res.ok) throw new Error('Falha ao listar usuários');
  return res.json();
}

export async function fetchConversation(userId, peerId) {
  const res = await fetch(`${API_BASE}/api/history/conversation/${userId}/${peerId}`);
  if (!res.ok) throw new Error('Falha ao carregar histórico');
  return res.json();
}
