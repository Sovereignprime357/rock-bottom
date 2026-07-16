/* Generated from frozen rock_bottom_v19.html.
 * Source seams: window.storage shim.
 * Do not hand-edit; change the source module after the refactor lands.
 */

export function init_storage() {
  // ---------- window.storage shim ----------
  if (!window.storage) {
    // The artifact host injects window.storage. A normal hosted/double-clicked browser does
    // not, so keep the exact async API and back it with IndexedDB. No synchronous storage API.
    const mem = {};
    const DB_NAME='rock_bottom_window_storage',STORE_NAME='kv';
    const dbReady=new Promise(resolve=>{
      try{
        if(!window.indexedDB){resolve(null);return;}
        const req=window.indexedDB.open(DB_NAME,1);
        req.onupgradeneeded=()=>{try{const db=req.result;if(!db.objectStoreNames.contains(STORE_NAME))db.createObjectStore(STORE_NAME);}catch(_){}};
        req.onsuccess=()=>resolve(req.result);
        req.onerror=()=>resolve(null);
        req.onblocked=()=>resolve(null);
      }catch(_){resolve(null);}
    });
    const memoryGet=(k)=>{
      try{return mem[k]===undefined?null:{value:JSON.parse(mem[k])};}catch(_){return null;}
    };
    window.storage = {
      set: async (k, v) => {
        try{
          const encoded=JSON.stringify(v),db=await dbReady;
          if(!db){mem[k]=encoded;return;}
          await new Promise(resolve=>{
            try{
              const tx=db.transaction(STORE_NAME,'readwrite');
              tx.objectStore(STORE_NAME).put(encoded,k);
              tx.oncomplete=()=>resolve();
              tx.onerror=tx.onabort=()=>{mem[k]=encoded;resolve();};
            }catch(_){mem[k]=encoded;resolve();}
          });
        }catch(_){}
      },
      get: async (k) => {
        try {
          const db=await dbReady;if(!db)return memoryGet(k);
          const encoded=await new Promise(resolve=>{
            try{const req=db.transaction(STORE_NAME,'readonly').objectStore(STORE_NAME).get(k);req.onsuccess=()=>resolve(req.result);req.onerror=()=>resolve(undefined);}catch(_){resolve(undefined);}
          });
          if(encoded===undefined)return memoryGet(k);
          return {value:JSON.parse(encoded)};
        } catch(_){return memoryGet(k);}
      },
    };
  }
  
  
}
