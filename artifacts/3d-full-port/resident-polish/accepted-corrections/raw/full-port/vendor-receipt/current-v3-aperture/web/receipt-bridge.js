/* Thin actual-render observer; storage writes are isolated attempt markers only. */
(() => {
  'use strict';
  const ui=Object.fromEntries(['canvas','status','start','abort','report-download','frames','png','frame-label','image','report','log'].map(id=>[id,document.getElementById(id)]));
  const run=new URLSearchParams(location.search).get('run')||'',began=performance.now();
  const images=new Map(),errors=[],engineErrors=[],logs=[];let latest=null,started=false,ended=null,exit=null,selected=-1;
  const bound=(list,v)=>{if(list.length<100)list.push(String(v).slice(0,1800));};
  const digest=async b=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',b))].map(x=>x.toString(16).padStart(2,'0')).join('');
  function fail(e){bound(errors,e);publish();}
  function webgl(){const gl=ui.canvas.getContext('webgl2');return gl?{webgl2:true,version:gl.getParameter(gl.VERSION),renderer:gl.getParameter(gl.RENDERER),drawing_buffer:[gl.drawingBufferWidth,gl.drawingBufferHeight]}:{webgl2:false};}
  function publish(){
    if(!latest){ui.status.textContent=errors.length?'FAILED: '+errors.join('; '):'Loading actual engine.';return;}
    let render;try{render=webgl();}catch(e){render={webgl2:false,error:String(e)};}
    const verified=latest.frames.length===4&&latest.frames.every((r,i)=>images.get(i)?.verified===true&&images.get(i).record.png_sha256===r.png_sha256);
    const healthy=errors.length===0&&engineErrors.length===0&&exit===null;
    const evidence={...latest,browser:{userAgent:navigator.userAgent,webgl:render,canvas:[ui.canvas.width,ui.canvas.height],elapsed_ms:(ended??performance.now())-began},engine_errors:[...engineErrors],browser_errors:[...errors],actual_exit:exit,pngs_verified:verified,acceptance:latest.acceptance===true&&healthy&&verified&&render.webgl2===true,visual_acceptance:false,shutdown_acceptance:false,format_mode:'web_capture_keepalive'};
    window.rbReceiptEvidence=evidence;ui.report.textContent=JSON.stringify(evidence,null,2);
    ui.start.disabled=started||latest.ready!==true||!healthy;ui.abort.disabled=latest.finished===true||typeof window.rbReceiptControl!=='function';ui['report-download'].disabled=false;
    ui.status.textContent=latest.finished?`FINISHED — machine checks ${evidence.acceptance?'PASS':'FAIL/incomplete'}; visual review pending`:`${started?'RUNNING ordinary input':'READY for explicit Start'} — one300s attempt`;
  }
  function select(i){const f=images.get(i);if(!f?.verified)return;selected=i;ui.frames.value=String(i);ui.image.src=f.url;ui.image.hidden=false;ui.png.disabled=false;ui['frame-label'].textContent=f.record.label+' — original960x540 PNG, SHA256 '+f.record.png_sha256;}
  window.rbReceiptFrame=async(i,b64,record)=>{try{
    if(!Number.isInteger(i)||i<0||i>4||images.has(i)||typeof b64!=='string'||b64.length>8388608)throw Error('Invalid/duplicate/big frame');
    const bytes=Uint8Array.from(atob(b64),x=>x.charCodeAt(0));if(!bytes.length||bytes.length>6291456||bytes.length!==record.png_bytes)throw Error('Original PNG byte count');
    const row={record,base64:b64,verified:false};images.set(i,row);
    if(await digest(bytes)!==record.png_sha256)throw Error('Original PNG hash mismatch');
    row.url=URL.createObjectURL(new Blob([bytes],{type:'image/png'}));const img=new Image();img.src=row.url;await img.decode();
    if(img.naturalWidth!==960||img.naturalHeight!==540||JSON.stringify(record.framebuffer)!=='[960,540]')throw Error('Actual PNG size mismatch');
    row.verified=true;const option=document.createElement('option');option.value=i;option.textContent=record.label;ui.frames.appendChild(option);ui.frames.disabled=false;select(i);publish();
  }catch(e){fail(e);}};
  window.rbReceiptReport=r=>{if(!r||r.format!=='rock-bottom-vendor-receipt-visual'||!Array.isArray(r.frames)||r.frames.length>4){fail('Malformed bounded report');return;}latest=r;if(r.finished){ended??=performance.now();clearTimeout(timer);}publish();};
  ui.start.onclick=async()=>{if(ui.start.disabled||started)return;started=true;ui.start.disabled=true;try{
    const key='rockbottom_3d_receipt_qa_'+run+'__attempt';const old=await window.storage.get(key);if(old!=='')throw Error('Attempt key already used; retained, no retry');
    await window.storage.set(key,JSON.stringify({run,started_unix_ms:Date.now(),kind:'receipt_visual_attempt'}));window.rbReceiptControl('start');publish();
  }catch(e){fail(e);if(typeof window.rbReceiptControl==='function')window.rbReceiptControl('abort');}};
  ui.abort.onclick=()=>{if(typeof window.rbReceiptControl==='function')window.rbReceiptControl('abort');};
  const download=(blob,name)=>{const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
  ui.frames.onchange=()=>select(Number(ui.frames.value));
  ui.png.onclick=()=>{const f=images.get(selected);if(f?.verified)download(new Blob([Uint8Array.from(atob(f.base64),c=>c.charCodeAt(0))],{type:'image/png'}),f.record.label+'.png');};
  ui['report-download'].onclick=()=>download(new Blob([JSON.stringify({format:'rock-bottom-receipt-browser-originals',report:window.rbReceiptEvidence,frames:[...images].map(([index,f])=>({index,record:f.record,base64:f.base64,verified:f.verified}))},null,2)],{type:'application/json'}),'receipt-browser-originals.json');
  addEventListener('error',e=>fail(e.message));addEventListener('unhandledrejection',e=>fail(e.reason));
  const timer=setTimeout(()=>{fail('Independent300s browser watchdog');if(typeof window.rbReceiptControl==='function')window.rbReceiptControl('abort');},300000);
  window.rbReceiptBoot=config=>{
    if(!/^[a-z0-9][a-z0-9_-]{0,47}$/.test(run)){fail('Explicit fresh ?run= identifier required');return;}
    config.args=['--script','res://tests/vendor_receipt_probe.gd','--','--qa-full','--run-id='+run];config.canvas=ui.canvas;config.canvasResizePolicy=0;config.focusCanvas=false;
    config.onPrint=(...p)=>{bound(logs,p.join(' '));ui.log.textContent=logs.join('\n');};
    config.onPrintError=(...p)=>{bound(engineErrors,p.join(' '));ui.log.textContent=[...logs,...engineErrors].join('\n');publish();};
    config.onExit=code=>{exit=code;fail('Unexpected engine exit; keepalive capture has no shutdown acceptance');};
    new Engine(config).startGame().catch(fail);
  };
})();
