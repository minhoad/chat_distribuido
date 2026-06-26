// URLs relativas → passam pelo proxy do Vite (evita CORS)
const API_BASE = import.meta.env.VITE_API_BASE || '';

async function parseApiError(res) {
  const contentType = res.headers.get('content-type') || '';

  if (contentType.includes('application/json')) {
    const data = await res.json();
    if (data.message) return data.message;
    if (data.error) return data.error;
    if (Array.isArray(data.violations) && data.violations.length > 0) {
      return data.violations[0].message;
    }
  }

  const text = await res.text();
  if (text) return text;
  return `Erro ${res.status}`;
}

export async function register(username, email, password) {
  const res = await fetch(`${API_BASE}/api/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, email, password }),
  });
  if (!res.ok) {
    throw new Error(await parseApiError(res));
  }
  return res.json();
}

export async function login(username, password) {
  const res = await fetch(`${API_BASE}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  });
  if (!res.ok) {
    throw new Error(await parseApiError(res));
  }
  return res.json();
}

export async function fetchUsers() {
  const res = await fetch(`${API_BASE}/api/auth/users`);
  if (!res.ok) {
    throw new Error(await parseApiError(res));
  }
  return res.json();
}

export async function fetchConversation(userId, peerId) {
  const res = await fetch(`${API_BASE}/api/history/conversation/${userId}/${peerId}`);
  if (!res.ok) {
    throw new Error(await parseApiError(res));
  }
  return res.json();
}

export async function fetchGroupHistory(groupId) {
  const res = await fetch(`${API_BASE}/api/history/recipient/${groupId}`);
  if (!res.ok) {
    throw new Error(await parseApiError(res));
  }
  return res.json();
}
