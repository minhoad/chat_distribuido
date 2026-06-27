import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

// Dev padrão: proxy direto nos microsserviços (mais estável para WebSocket).
// Demo/apresentação: npm run dev:gateway → tráfego via API Gateway (:8080).
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const useGateway = env.VITE_USE_GATEWAY === 'true';
  const gateway = env.VITE_GATEWAY_URL || 'http://localhost:8080';

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

  return {
    plugins: [react()],
    define: {
      global: 'globalThis',
    },
    server: {
      port: 5173,
      proxy: useGateway ? gatewayProxy : directProxy,
    },
  };
});
