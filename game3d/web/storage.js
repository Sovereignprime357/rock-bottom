/* A separate namespace; never touches the v22 browser save. */
(() => {
  const dbName = 'rockbottom_3d_slice_v1';
  let dbPromise;
  const open = () => dbPromise ??= new Promise((resolve, reject) => {
    const request = indexedDB.open(dbName, 1);
    request.onupgradeneeded = () => request.result.createObjectStore('saves');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error('save database blocked'));
  });
  window.storage = {
    async set(key, value) {
      try {
        const db = await open();
        await new Promise((resolve, reject) => {
          const tx = db.transaction('saves', 'readwrite');
          tx.objectStore('saves').put(value, key);
          tx.oncomplete = resolve;
          tx.onerror = () => reject(tx.error);
          tx.onabort = () => reject(tx.error);
        });
      } catch (error) { throw error; }
    },
    async get(key) {
      try {
        const db = await open();
        return await new Promise((resolve, reject) => {
          const tx = db.transaction('saves', 'readonly');
          const request = tx.objectStore('saves').get(key);
          request.onsuccess = () => resolve(request.result ?? '');
          request.onerror = () => reject(request.error);
        });
      } catch (error) { throw error; }
    }
  };
  window.rb3dStorageResult = '';
  let requestId = 0;
  window.rb3dSave = async (payload, key = 'rockbottom_3d_slice_v1') => {
    const id = ++requestId;
    window.rb3dStorageResult = '';
    try {
      await window.storage.set(key, payload);
      if (id === requestId) window.rb3dStorageResult = JSON.stringify({ok: true});
    } catch (_) {
      if (id === requestId) window.rb3dStorageResult = JSON.stringify({ok: false, error: 'the drawer will not close.'});
    }
  };
  window.rb3dLoad = async (key = 'rockbottom_3d_slice_v1') => {
    const id = ++requestId;
    window.rb3dStorageResult = '';
    try {
      const data = await window.storage.get(key);
      if (id === requestId) window.rb3dStorageResult = JSON.stringify({ok: true, data});
    } catch (_) {
      if (id === requestId) window.rb3dStorageResult = JSON.stringify({ok: false, error: 'the drawer will not open.'});
    }
  };
})();
