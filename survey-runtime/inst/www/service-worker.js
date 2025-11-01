// Service Worker for NomadForms - Offline Capability
// Version 1.0

const CACHE_NAME = 'nomadforms-v1';
const OFFLINE_CACHE = 'nomadforms-offline-v1';

// Assets to cache for offline use
const ASSETS_TO_CACHE = [
  '/',
  '/nomadforms.css',
  'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css'
];

// Install event - cache assets
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...');
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[Service Worker] Caching app shell');
        return cache.addAll(ASSETS_TO_CACHE);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');
  
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((cacheName) => {
            return cacheName.startsWith('nomadforms-') &&
                   cacheName !== CACHE_NAME &&
                   cacheName !== OFFLINE_CACHE;
          })
          .map((cacheName) => {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
  // Skip cross-origin requests
  if (!event.request.url.startsWith(self.location.origin) &&
      !event.request.url.startsWith('https://cdnjs.cloudflare.com')) {
    return;
  }

  event.respondWith(
    caches.match(event.request)
      .then((cachedResponse) => {
        if (cachedResponse) {
          // Return cached version
          return cachedResponse;
        }

        // Clone the request
        const fetchRequest = event.request.clone();

        return fetch(fetchRequest).then((response) => {
          // Check if valid response
          if (!response || response.status !== 200 || response.type !== 'basic') {
            return response;
          }

          // Clone the response
          const responseToCache = response.clone();

          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });

          return response;
        }).catch((error) => {
          console.log('[Service Worker] Fetch failed; returning offline page instead.', error);
          
          // Return offline page if available
          return caches.match('/offline.html');
        });
      })
  );
});

// Message event - handle sync requests
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  if (event.data && event.data.type === 'CACHE_RESPONSE') {
    // Cache survey response for offline sync
    const response = event.data.payload;
    
    caches.open(OFFLINE_CACHE).then((cache) => {
      const request = new Request(`/offline-responses/${response.session_id}`, {
        method: 'POST',
        body: JSON.stringify(response)
      });
      
      cache.put(request, new Response(JSON.stringify(response), {
        headers: { 'Content-Type': 'application/json' }
      }));
      
      console.log('[Service Worker] Cached offline response:', response.session_id);
    });
  }
});

// Background Sync event - sync offline responses when online
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-responses') {
    console.log('[Service Worker] Syncing offline responses...');
    
    event.waitUntil(
      caches.open(OFFLINE_CACHE)
        .then((cache) => cache.keys())
        .then((requests) => {
          return Promise.all(
            requests.map((request) => {
              return caches.match(request)
                .then((response) => response.json())
                .then((data) => {
                  // Send to server
                  return fetch('/api/responses', {
                    method: 'POST',
                    headers: {
                      'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(data)
                  });
                })
                .then(() => {
                  // Remove from cache after successful sync
                  return caches.open(OFFLINE_CACHE).then((cache) => {
                    return cache.delete(request);
                  });
                })
                .catch((error) => {
                  console.error('[Service Worker] Sync failed for request:', error);
                });
            })
          );
        })
    );
  }
});

