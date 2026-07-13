// This file configures the Flutter web service worker.
// It is automatically loaded by Flutter's web bootstrapper.

// Cache version - increment when deploying new versions
const CACHE_VERSION = 'medismart-v2.0.0';

// Files to cache for offline support
const RESOURCES_TO_CACHE = [
  '/',
  '/index.html',
  '/manifest.json',
  '/flutter.js',
  '/flutter_bootstrap.js',
];

self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE_VERSION).then(function(cache) {
      return cache.addAll(RESOURCES_TO_CACHE);
    })
  );
});

self.addEventListener('fetch', function(event) {
  event.respondWith(
    caches.match(event.request).then(function(response) {
      if (response) {
        return response;
      }
      return fetch(event.request);
    })
  );
});
