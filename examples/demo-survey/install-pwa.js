// PWA Installation Handler for NomadForms
// Handles service worker registration and install prompts

let deferredPrompt;
let installButton;

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  initPWA();
});

async function initPWA() {
  // Register service worker
  if ('serviceWorker' in navigator) {
    try {
      const registration = await navigator.serviceWorker.register('/service-worker.js');
      console.log('✓ Service Worker registered:', registration.scope);

      // Check for updates
      registration.addEventListener('updatefound', () => {
        const newWorker = registration.installing;
        newWorker.addEventListener('statechange', () => {
          if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
            showUpdateNotification();
          }
        });
      });
    } catch (error) {
      console.error('✗ Service Worker registration failed:', error);
    }
  }

  // Initialize IndexedDB
  if ('indexedDB' in window) {
    try {
      const db = new NomadFormsDB();
      await db.init();
      console.log('✓ IndexedDB initialized');
      
      // Make database available globally
      window.nomadDB = db;
      
      // Show database stats
      const stats = await db.getStats();
      console.log('📊 Database stats:', stats);
      
      // Auto-sync on load if online
      if (navigator.onLine) {
        await syncOfflineData();
      }
    } catch (error) {
      console.error('✗ IndexedDB initialization failed:', error);
    }
  }

  // Handle install prompt
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    showInstallButton();
  });

  // Handle successful installation
  window.addEventListener('appinstalled', () => {
    console.log('✓ PWA installed successfully');
    deferredPrompt = null;
    hideInstallButton();
    showNotification('App installed! You can now use NomadForms offline.', 'success');
  });

  // Handle online/offline events
  window.addEventListener('online', handleOnline);
  window.addEventListener('offline', handleOffline);

  // Set initial online/offline status
  updateConnectionStatus();
}

function showInstallButton() {
  // Create install button if it doesn't exist
  if (!installButton) {
    installButton = document.createElement('button');
    installButton.innerHTML = '<i class="fas fa-download"></i> Install App';
    installButton.className = 'btn btn-success install-button';
    installButton.style.cssText = `
      position: fixed;
      bottom: 20px;
      right: 20px;
      z-index: 1000;
      padding: 15px 25px;
      font-size: 16px;
      border-radius: 50px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
      animation: bounce 2s infinite;
    `;
    
    installButton.addEventListener('click', installPWA);
    document.body.appendChild(installButton);
    
    // Add bounce animation
    const style = document.createElement('style');
    style.innerHTML = `
      @keyframes bounce {
        0%, 20%, 50%, 80%, 100% {
          transform: translateY(0);
        }
        40% {
          transform: translateY(-10px);
        }
        60% {
          transform: translateY(-5px);
        }
      }
    `;
    document.head.appendChild(style);
  }
}

function hideInstallButton() {
  if (installButton) {
    installButton.remove();
    installButton = null;
  }
}

async function installPWA() {
  if (!deferredPrompt) {
    return;
  }

  // Show install prompt
  deferredPrompt.prompt();

  // Wait for user response
  const { outcome } = await deferredPrompt.userChoice;
  console.log(`User response to install prompt: ${outcome}`);

  deferredPrompt = null;
  hideInstallButton();
}

function showUpdateNotification() {
  const notification = document.createElement('div');
  notification.innerHTML = `
    <div style="
      position: fixed;
      top: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: #007bff;
      color: white;
      padding: 15px 25px;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
      z-index: 1001;
      display: flex;
      align-items: center;
      gap: 15px;
    ">
      <i class="fas fa-sync-alt"></i>
      <span>New version available!</span>
      <button onclick="window.location.reload()" style="
        background: white;
        color: #007bff;
        border: none;
        padding: 8px 15px;
        border-radius: 5px;
        font-weight: bold;
        cursor: pointer;
      ">Update</button>
      <button onclick="this.parentElement.remove()" style="
        background: transparent;
        color: white;
        border: none;
        cursor: pointer;
        font-size: 20px;
      ">&times;</button>
    </div>
  `;
  document.body.appendChild(notification);
}

async function handleOnline() {
  console.log('✓ Connection restored');
  updateConnectionStatus();
  
  // Show notification
  showNotification('Back online! Syncing data...', 'success');
  
  // Sync offline data
  await syncOfflineData();
}

function handleOffline() {
  console.log('⚠ Connection lost');
  updateConnectionStatus();
  
  // Show notification
  showNotification('You are offline. Responses will be saved locally.', 'warning');
}

function updateConnectionStatus() {
  const isOnline = navigator.onLine;
  const onlineStatus = document.getElementById('connection-status');
  const offlineStatus = document.getElementById('offline-status');

  if (isOnline) {
    if (onlineStatus) onlineStatus.style.display = 'block';
    if (offlineStatus) offlineStatus.style.display = 'none';
  } else {
    if (onlineStatus) onlineStatus.style.display = 'none';
    if (offlineStatus) offlineStatus.style.display = 'block';
  }
}

async function syncOfflineData() {
  if (!window.nomadDB) {
    console.log('⚠ Database not initialized');
    return;
  }

  try {
    const serverUrl = window.location.origin;
    await window.nomadDB.processSyncQueue(serverUrl);
    
    const stats = await window.nomadDB.getStats();
    if (stats.unsynced_responses > 0) {
      showNotification(`${stats.unsynced_responses} responses pending sync`, 'warning');
    } else {
      showNotification('All data synced!', 'success');
    }
  } catch (error) {
    console.error('✗ Sync failed:', error);
    showNotification('Sync failed. Will retry later.', 'error');
  }
}

function showNotification(message, type = 'info') {
  // Use Shiny's notification if available, otherwise create custom notification
  if (typeof Shiny !== 'undefined' && Shiny.setInputValue) {
    const iconMap = {
      success: 'check-circle',
      error: 'exclamation-circle',
      warning: 'exclamation-triangle',
      info: 'info-circle'
    };
    const icon = iconMap[type] || 'info-circle';
    Shiny.setInputValue('notification', {
      message: message,
      type: type,
      icon: icon,
      timestamp: Date.now()
    });
  } else {
    // Fallback to browser notification
    console.log(`[${type.toUpperCase()}] ${message}`);
  }
}

// Export functions for use in Shiny
window.nomadForms = {
  syncOfflineData,
  updateConnectionStatus,
  showNotification
};

