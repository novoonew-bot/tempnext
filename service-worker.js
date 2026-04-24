// ============================================================
// Tempnext — Service Worker mínimo
// ============================================================
// Propósito: tornar o app instalável como PWA. NÃO faz cache
// agressivo do app (porque o app muda muito durante desenvolvimento).
// ============================================================

const CACHE_NAME = "tempnext-v208";

// Instalação — passa direto, sem cachear nada.
self.addEventListener("install", (event) => {
  // Skip waiting pra atualizar imediatamente sem precisar fechar o app
  self.skipWaiting();
});

// Ativação — limpa caches antigos
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((nomes) =>
      Promise.all(
        nomes
          .filter((nome) => nome !== CACHE_NAME)
          .map((nome) => caches.delete(nome))
      )
    )
  );
  // Toma controle de todas as abas imediatamente
  return self.clients.claim();
});

// Fetch — sempre vai à rede primeiro (network-first).
// Pra app em desenvolvimento, evitar cache é mais importante que offline.
self.addEventListener("fetch", (event) => {
  // Só intercepta GET e ignora chamadas a outros domínios (Supabase, Unsplash, etc)
  if (event.request.method !== "GET") return;
  if (!event.request.url.startsWith(self.location.origin)) return;

  event.respondWith(
    fetch(event.request).catch(() => {
      // Fallback offline básico — retorna cache se houver
      return caches.match(event.request);
    })
  );
});
