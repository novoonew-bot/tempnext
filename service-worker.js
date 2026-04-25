// Tempnext Service Worker v217.2
const SW_VERSION = "v217.2";
const CACHE_NAME = "tempnext-" + SW_VERSION + "-" + Date.now();
const ASSETS_HOST = ["fonts.googleapis.com", "fonts.gstatic.com", "images.unsplash.com"];

self.addEventListener("install", (event) => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    Promise.all([
      caches.keys().then(names => Promise.all(
        names.filter(n => n.startsWith("tempnext-") && n !== CACHE_NAME)
             .map(n => caches.delete(n))
      )),
      self.clients.claim(),
    ])
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  const url = new URL(req.url);
  if(req.method !== "GET") return;

  const isHTML = req.mode === "navigate" ||
                 (req.headers.get("accept") || "").includes("text/html") ||
                 url.pathname.endsWith(".html") ||
                 url.pathname === "/" ||
                 url.pathname.endsWith(".js") ||
                 url.pathname.endsWith(".css");

  if(isHTML && url.origin === location.origin){
    event.respondWith(
      fetch(req)
        .then(response => {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(c => c.put(req, clone)).catch(()=>{});
          return response;
        })
        .catch(() => {
          return caches.match(req).then(cached => cached || new Response("Offline", {status:503}));
        })
    );
    return;
  }

  const isAsset = ASSETS_HOST.some(h => url.host.includes(h)) ||
                  /\.(png|jpg|jpeg|webp|gif|svg|woff|woff2|ttf|otf)$/i.test(url.pathname);

  if(isAsset){
    event.respondWith(
      caches.match(req).then(cached => {
        if(cached) return cached;
        return fetch(req).then(response => {
          if(response.ok){
            const clone = response.clone();
            caches.open(CACHE_NAME).then(c => c.put(req, clone)).catch(()=>{});
          }
          return response;
        }).catch(() => cached);
      })
    );
    return;
  }
});

self.addEventListener("message", (event) => {
  if(event.data === "skip-waiting"){
    self.skipWaiting();
  }
});