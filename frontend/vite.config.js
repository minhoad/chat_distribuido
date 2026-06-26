import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Em dev, o proxy aponta direto nos microsserviços (não depende do Gateway).
// Se o Gateway estiver rodando em 8080, use VITE_USE_GATEWAY=true no .env
const useGateway = process.env.VITE_USE_GATEWAY === 'true';
const gateway = 'http://localhost:8080';

export default defineConfig({
  plugins: [react()],
  define: {
    global: 'globalThis',
  },
  server: {
    port: 5173,
    proxy: useGateway
      ? {
          '/api': gateway,
          '/ws': { target: gateway, ws: true, changeOrigin: true },
        }
      : {
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
        },
  },
});
