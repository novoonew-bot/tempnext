// vite.config.js — Tempnext dev server
// Serve C:\tempnext\ em http://localhost:5173 com hot reload.
// NÃO afeta compilar.js, deploy.bat, ou o fluxo de produção.

import { defineConfig } from 'vite';

export default defineConfig({
  root: '.',
  server: {
    port: 5173,
    host: 'localhost',
    open: true,
    cors: true,
  },
  build: {
    outDir: 'dist-vite',
  },
});