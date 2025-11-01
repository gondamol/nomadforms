// IndexedDB Manager for NomadForms - Offline Data Storage
// Version 1.0

const DB_NAME = 'nomadforms';
const DB_VERSION = 1;
const STORE_RESPONSES = 'responses';
const STORE_DRAFTS = 'drafts';
const STORE_SURVEYS = 'surveys';
const STORE_SYNC_QUEUE = 'sync_queue';

class NomadFormsDB {
  constructor() {
    this.db = null;
  }

  /**
   * Initialize the database
   * @returns {Promise<IDBDatabase>}
   */
  async init() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        this.db = request.result;
        resolve(this.db);
      };

      request.onupgradeneeded = (event) => {
        const db = event.target.result;

        // Create responses store
        if (!db.objectStoreNames.contains(STORE_RESPONSES)) {
          const responsesStore = db.createObjectStore(STORE_RESPONSES, {
            keyPath: 'response_id',
            autoIncrement: false
          });
          responsesStore.createIndex('session_id', 'session_id', { unique: false });
          responsesStore.createIndex('survey_id', 'survey_id', { unique: false });
          responsesStore.createIndex('submitted_at', 'submitted_at', { unique: false });
          responsesStore.createIndex('synced', 'synced', { unique: false });
        }

        // Create drafts store
        if (!db.objectStoreNames.contains(STORE_DRAFTS)) {
          const draftsStore = db.createObjectStore(STORE_DRAFTS, {
            keyPath: 'session_id'
          });
          draftsStore.createIndex('saved_at', 'saved_at', { unique: false });
        }

        // Create surveys store (cached survey definitions)
        if (!db.objectStoreNames.contains(STORE_SURVEYS)) {
          const surveysStore = db.createObjectStore(STORE_SURVEYS, {
            keyPath: 'survey_id'
          });
          surveysStore.createIndex('updated_at', 'updated_at', { unique: false });
        }

        // Create sync queue store
        if (!db.objectStoreNames.contains(STORE_SYNC_QUEUE)) {
          const syncStore = db.createObjectStore(STORE_SYNC_QUEUE, {
            keyPath: 'id',
            autoIncrement: true
          });
          syncStore.createIndex('created_at', 'created_at', { unique: false });
          syncStore.createIndex('action', 'action', { unique: false });
        }
      };
    });
  }

  /**
   * Save survey response
   * @param {Object} response - Response object
   * @returns {Promise}
   */
  async saveResponse(response) {
    const tx = this.db.transaction([STORE_RESPONSES], 'readwrite');
    const store = tx.objectStore(STORE_RESPONSES);

    const responseData = {
      ...response,
      response_id: response.response_id || this.generateId(),
      submitted_at: response.submitted_at || new Date().toISOString(),
      synced: false,
      local_only: true
    };

    await store.put(responseData);
    await tx.complete;

    // Add to sync queue
    await this.addToSyncQueue({
      action: 'save_response',
      data: responseData
    });

    return responseData.response_id;
  }

  /**
   * Save draft
   * @param {Object} draft - Draft data
   * @returns {Promise}
   */
  async saveDraft(draft) {
    const tx = this.db.transaction([STORE_DRAFTS], 'readwrite');
    const store = tx.objectStore(STORE_DRAFTS);

    const draftData = {
      ...draft,
      saved_at: new Date().toISOString()
    };

    await store.put(draftData);
    await tx.complete;

    console.log('✓ Draft saved:', draftData.session_id);
    return draftData.session_id;
  }

  /**
   * Get draft by session ID
   * @param {string} sessionId - Session ID
   * @returns {Promise<Object|null>}
   */
  async getDraft(sessionId) {
    const tx = this.db.transaction([STORE_DRAFTS], 'readonly');
    const store = tx.objectStore(STORE_DRAFTS);
    const draft = await store.get(sessionId);
    return draft || null;
  }

  /**
   * Get all drafts
   * @returns {Promise<Array>}
   */
  async getAllDrafts() {
    const tx = this.db.transaction([STORE_DRAFTS], 'readonly');
    const store = tx.objectStore(STORE_DRAFTS);
    const index = store.index('saved_at');
    return await index.getAll();
  }

  /**
   * Delete draft
   * @param {string} sessionId - Session ID
   * @returns {Promise}
   */
  async deleteDraft(sessionId) {
    const tx = this.db.transaction([STORE_DRAFTS], 'readwrite');
    const store = tx.objectStore(STORE_DRAFTS);
    await store.delete(sessionId);
    await tx.complete;
    console.log('✓ Draft deleted:', sessionId);
  }

  /**
   * Get all unsynced responses
   * @returns {Promise<Array>}
   */
  async getUnsyncedResponses() {
    const tx = this.db.transaction([STORE_RESPONSES], 'readonly');
    const store = tx.objectStore(STORE_RESPONSES);
    const index = store.index('synced');
    return await index.getAll(false);
  }

  /**
   * Mark response as synced
   * @param {string} responseId - Response ID
   * @returns {Promise}
   */
  async markAsSynced(responseId) {
    const tx = this.db.transaction([STORE_RESPONSES], 'readwrite');
    const store = tx.objectStore(STORE_RESPONSES);
    const response = await store.get(responseId);
    
    if (response) {
      response.synced = true;
      response.synced_at = new Date().toISOString();
      response.local_only = false;
      await store.put(response);
      await tx.complete;
      console.log('✓ Response synced:', responseId);
    }
  }

  /**
   * Add to sync queue
   * @param {Object} item - Sync item
   * @returns {Promise}
   */
  async addToSyncQueue(item) {
    const tx = this.db.transaction([STORE_SYNC_QUEUE], 'readwrite');
    const store = tx.objectStore(STORE_SYNC_QUEUE);

    const syncItem = {
      ...item,
      created_at: new Date().toISOString(),
      retries: 0,
      last_error: null
    };

    await store.add(syncItem);
    await tx.complete;
  }

  /**
   * Get sync queue
   * @returns {Promise<Array>}
   */
  async getSyncQueue() {
    const tx = this.db.transaction([STORE_SYNC_QUEUE], 'readonly');
    const store = tx.objectStore(STORE_SYNC_QUEUE);
    return await store.getAll();
  }

  /**
   * Remove from sync queue
   * @param {number} id - Sync item ID
   * @returns {Promise}
   */
  async removeFromSyncQueue(id) {
    const tx = this.db.transaction([STORE_SYNC_QUEUE], 'readwrite');
    const store = tx.objectStore(STORE_SYNC_QUEUE);
    await store.delete(id);
    await tx.complete;
  }

  /**
   * Process sync queue
   * @param {string} serverUrl - Server URL
   * @returns {Promise}
   */
  async processSyncQueue(serverUrl) {
    if (!navigator.onLine) {
      console.log('⚠ Offline - skipping sync');
      return;
    }

    const queue = await this.getSyncQueue();
    console.log(`📤 Syncing ${queue.length} items...`);

    for (const item of queue) {
      try {
        await this.syncItem(item, serverUrl);
        await this.removeFromSyncQueue(item.id);
        
        if (item.action === 'save_response' && item.data.response_id) {
          await this.markAsSynced(item.data.response_id);
        }
        
        console.log('✓ Synced:', item.action, item.id);
      } catch (error) {
        console.error('✗ Sync failed:', item.id, error);
        // Update retry count
        const tx = this.db.transaction([STORE_SYNC_QUEUE], 'readwrite');
        const store = tx.objectStore(STORE_SYNC_QUEUE);
        const updatedItem = await store.get(item.id);
        if (updatedItem) {
          updatedItem.retries = (updatedItem.retries || 0) + 1;
          updatedItem.last_error = error.message;
          await store.put(updatedItem);
        }
        await tx.complete;
      }
    }

    console.log('✓ Sync complete');
  }

  /**
   * Sync individual item to server
   * @param {Object} item - Sync item
   * @param {string} serverUrl - Server URL
   * @returns {Promise}
   */
  async syncItem(item, serverUrl) {
    const endpoint = item.action === 'save_response' 
      ? `${serverUrl}/api/responses`
      : `${serverUrl}/api/sync`;

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(item.data)
    });

    if (!response.ok) {
      throw new Error(`Server error: ${response.status}`);
    }

    return await response.json();
  }

  /**
   * Generate unique ID
   * @returns {string}
   */
  generateId() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  /**
   * Get database statistics
   * @returns {Promise<Object>}
   */
  async getStats() {
    const tx = this.db.transaction([STORE_RESPONSES, STORE_DRAFTS, STORE_SYNC_QUEUE], 'readonly');
    
    const responsesStore = tx.objectStore(STORE_RESPONSES);
    const draftsStore = tx.objectStore(STORE_DRAFTS);
    const syncStore = tx.objectStore(STORE_SYNC_QUEUE);

    const [responses, drafts, syncQueue] = await Promise.all([
      responsesStore.count(),
      draftsStore.count(),
      syncStore.count()
    ]);

    const unsyncedResponses = await this.getUnsyncedResponses();

    return {
      total_responses: responses,
      synced_responses: responses - unsyncedResponses.length,
      unsynced_responses: unsyncedResponses.length,
      drafts: drafts,
      sync_queue: syncQueue
    };
  }

  /**
   * Clear all data (for testing)
   * @returns {Promise}
   */
  async clearAll() {
    const tx = this.db.transaction([STORE_RESPONSES, STORE_DRAFTS, STORE_SURVEYS, STORE_SYNC_QUEUE], 'readwrite');
    
    await Promise.all([
      tx.objectStore(STORE_RESPONSES).clear(),
      tx.objectStore(STORE_DRAFTS).clear(),
      tx.objectStore(STORE_SURVEYS).clear(),
      tx.objectStore(STORE_SYNC_QUEUE).clear()
    ]);

    await tx.complete;
    console.log('✓ All data cleared');
  }
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
  module.exports = NomadFormsDB;
}

