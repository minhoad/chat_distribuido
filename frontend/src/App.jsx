import { useState } from 'react';
import { login, register } from './api';
import ChatPage from './ChatPage';

export default function App() {
  const [auth, setAuth] = useState(() => {
    const saved = localStorage.getItem('chatAuth');
    return saved ? JSON.parse(saved) : null;
  });
  const [mode, setMode] = useState('login');
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (mode === 'register' && password.length < 6) {
      setError('A senha deve ter entre 6 e 100 caracteres.');
      return;
    }

    setLoading(true);
    try {
      const data = mode === 'login'
        ? await login(username, password)
        : await register(username, email, password);
      localStorage.setItem('chatAuth', JSON.stringify(data));
      setAuth(data);
    } catch (err) {
      setError(err.message || 'Erro na autenticação');
    } finally {
      setLoading(false);
    }
  };

  const logout = () => {
    localStorage.removeItem('chatAuth');
    setAuth(null);
  };

  if (auth) {
    return <ChatPage auth={auth} onLogout={logout} />;
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <h1>Chat Distribuído</h1>
        <p className="subtitle">Comunicação em tempo real com microsserviços</p>

        <div className="tabs">
          <button
            type="button"
            className={mode === 'login' ? 'active' : ''}
            onClick={() => setMode('login')}
          >
            Login
          </button>
          <button
            type="button"
            className={mode === 'register' ? 'active' : ''}
            onClick={() => setMode('register')}
          >
            Registrar
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          <label>
            Usuário
            <input value={username} onChange={(e) => setUsername(e.target.value)} required />
          </label>
          {mode === 'register' && (
            <label>
              Email
              <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
            </label>
          )}
          <label>
            Senha
            <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
          </label>
          {error && <p className="error">{error}</p>}
          <button type="submit" disabled={loading}>
            {loading ? 'Aguarde...' : mode === 'login' ? 'Entrar' : 'Criar conta'}
          </button>
        </form>
      </div>
    </div>
  );
}
