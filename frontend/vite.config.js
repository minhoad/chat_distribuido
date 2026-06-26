import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Dev: proxy direto nos microsserviços (mais estável que passar pelo Gateway).
// SockJS/WebSocket quebra com proxy duplo (Vite → Gateway → chat).
// Use VITE_USE_GATEWAY=true para testar via API Gateway (8080).
const useGateway = process.env.VITE_USE_GATEWAY === 'true';
const gateway = 'http://localhost:8080';

const directProxy = {
  '/api/auth': {
    target: 'http://localhost:8081',
    changeOrigin: true,
  },
  '/api/history': {
    target: 'http://localhost:8083',
    changeOrigin: true,
  },
  '/ws': {
    target: 'http://localhost:8082',
    ws: true,
    changeOrigin: true,
  },
};

const gatewayProxy = {
  '/api': {
    target: gateway,
    changeOrigin: true,
  },
  '/ws': {
    target: gateway,
    ws: true,
    changeOrigin: true,
  },
};

export default defineConfig({
  plugins: [react()],
  define: {
    global: 'globalThis',
  },
  server: {
    port: 5173,
    proxy: useGateway ? gatewayProxy : directProxy,
  },
});
