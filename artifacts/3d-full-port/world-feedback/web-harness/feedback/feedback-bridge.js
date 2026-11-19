/* Thin evidence IO: no source state, fake pixels, arbitrary commands or new storage API. */
(() => {
  'use strict';
  const ids=['canvas','stage','status','packet','size','start','reload','frames','live','png','json','held-frame','frame-label','frame-result','report','log'];
  const ui=Object.fromEntries(ids.map(id=>[id,document.getElementById(id)]));
  const query=new URLSearchParams(location.search);
  ui.packet.value=query.get('packet')==='authority'?'authority':'core';ui.size.value=query.get('size')==='960'?'960':'1280';
  const images=new Map(),logs=[],engineErrors=[],browserErrors=[];
  let config=null,last=null,started=false,finished=false,selected=-1,live=true,bytesHeld=0,webgl=null,watchdog=null;
  let width=1280,height=720,packet='core',startAt=0;
  const byteLimit=192*1024*1024,frameLimit=96;
  window.rbFeedbackEvidence={ready:false,complete:false,acceptance:false,visual_acceptance:false,phase:'not_started'};
  function bounded(list,value,cap=50){if(list.length<cap)list.push(String(value).slice(0,1800));}
  function error(value){bounded(browserErrors,value);ui.log.textContent=[...logs,...browserErrors].join('\n');publish();}
  function log(value,isError=false){bounded(logs,value,120);if(isError)bounded(engineErrors,value);ui.log.textContent=logs.join('\n');publish();}
  function actualWebGL(){
    try{const gl=ui.canvas.getContext('webgl2');return gl?{webgl2:true,version:gl.getParameter(gl.VERSION),renderer:gl.getParameter(gl.RENDERER),vendor:gl.getParameter(gl.VENDOR),drawing_buffer:[gl.drawingBufferWidth,gl.drawingBufferHeight],attributes:gl.getContextAttributes()}:{webgl2:false};}
    catch(e){bounded(browserErrors,e);return {webgl2:false};}
  }
  function selectFrame(index){
    const frame=images.get(index);if(!frame)return;
    selected=index;ui.frames.value=String(index);
    if(frame.ready)ui['held-frame'].src=frame.url;
    ui['held-frame'].hidden=live||!frame.ready;
    ui['frame-label'].textContent=`ORIGINAL WEB CAPTURE ${index+1} — ${frame.label} — ${width}×${height} — ${frame.ready?'PNG hash/dimensions verified':'verifying PNG'}${live?' | displaying LIVE held engine canvas':''}`;
    ui['frame-result'].textContent=JSON.stringify({...frame.record,png_verified:frame.ready},null,2);
    ui.png.disabled=!frame.ready;ui.live.disabled=!frame.ready;
  }
  function publish(){
    const healthy=engineErrors.length===0&&browserErrors.length===0;
    const verified=images.size>0&&[...images.values()].every(frame=>frame.ready);
    const complete=last?.complete===true;
    const receipts=last?.acceptance===true;
    const captureCountMatches=Array.isArray(last?.captures)&&last.captures.length===images.size;
    const evidence={...(last||{}),format:'rock-bottom-domain-feedback-web-evidence',ready:finished&&healthy&&verified,complete,acceptance:complete&&receipts&&healthy&&verified&&captureCountMatches&&webgl?.webgl2===true,visual_acceptance:false,visual_review_required:true,packet,width,height,browser_wall_ms:started?Math.round(performance.now()-startAt):0,browser:{userAgent:navigator.userAgent,webgl,canvas:[ui.canvas.width,ui.canvas.height]},captured_png_count:images.size,png_bytes_held:bytesHeld,pngs_verified:verified,capture_count_matches:captureCountMatches,engine_errors:[...engineErrors],browser_errors:[...browserErrors],source:'Original Godot framebuffer PNG bytes only. No Canvas redraw or image processing.'};
    window.rbFeedbackEvidence=evidence;ui.canvas.dataset.ready=String(evidence.ready);
    ui.report.textContent=JSON.stringify(evidence,null,2);ui.json.disabled=!started;
    ui.status.className=healthy?'':'failure';
    ui.status.textContent=!started?'NOT STARTED — select one bounded packet and size.':!healthy?'FAILED — inspect bounded engine/browser evidence':finished?`FINISHED — source/render receipts ${evidence.acceptance?'PASS':'FAIL/incomplete'}; human visual review required`:`RUNNING actual packet ${packet} — ${images.size} original captures; no acceptance yet`;
  }
  window.rbFeedbackBooted=()=>{webgl=actualWebGL();publish();};
  window.rbFeedbackFrame=async(index,label,base64,record)=>{
    try{
      if(!started||!Number.isInteger(index)||index<0||index>=frameLimit||images.has(index)||typeof label!=='string'||typeof base64!=='string'||base64.length>12*1024*1024||record.index!==index)throw new Error('Duplicate/invalid/oversized actual frame');
      const binary=atob(base64),bytes=Uint8Array.from(binary,char=>char.charCodeAt(0));
      if(bytes.length===0||bytes.length>8*1024*1024||bytesHeld+bytes.length>byteLimit||record.png_bytes!==bytes.length)throw new Error('Original PNG byte count/budget failed');
      bytesHeld+=bytes.length;
      const url=URL.createObjectURL(new Blob([bytes],{type:'image/png'}));
      const frame={label,record,url,ready:false};images.set(index,frame);
      const option=document.createElement('option');option.value=String(index);option.textContent=`${index+1} — ${label}`;ui.frames.appendChild(option);ui.frames.disabled=false;
      const hash=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes));
      if(Array.from(hash,value=>value.toString(16).padStart(2,'0')).join('')!==record.png_sha256)throw new Error('Original Godot PNG hash differs in browser');
      const decoded=new Image();decoded.src=url;await decoded.decode();
      if(decoded.naturalWidth!==width||decoded.naturalHeight!==height||record.framebuffer[0]!==width||record.framebuffer[1]!==height)throw new Error('Actual framebuffer/PNG dimensions differ');
      frame.ready=true;if(selected<0){live=false;selectFrame(index);}publish();
    }catch(e){error(e);}
  };
  window.rbFeedbackReport=report=>{
    if(!report||report.format!=='rock-bottom-domain-feedback-web-visual'||!Array.isArray(report.captures)||report.captures.length>frameLimit||report.packet!==packet||report.width!==width){error('Malformed/wrong packet engine report');return;}
    last=report;finished=report.finished===true;if(finished)clearTimeout(watchdog);publish();
  };
  window.rbFeedbackConfigure=value=>{config=value;};
  ui.start.onclick=()=>{
    if(started||!config)return;
    packet=ui.packet.value;width=Number(ui.size.value);height=width===960?540:720;
    if(!['core','authority'].includes(packet)||![1280,960].includes(width)){error('Invalid finite selection');return;}
    if(!window.storage?.set||!window.storage?.get){error('Existing window.storage bridge missing');return;}
    started=true;startAt=performance.now();ui.start.disabled=true;ui.packet.disabled=true;ui.size.disabled=true;
    history.replaceState(null,'',`?packet=${packet}&size=${width}`);
    ui.canvas.width=width;ui.canvas.height=height;ui.stage.style.maxWidth=width+'px';ui.canvas.focus();
    const nonce=Date.now().toString(36)+'-'+crypto.getRandomValues(new Uint32Array(1))[0].toString(36);
    config.args=['--script','res://tests/web_feedback_visual_probe.gd','--','--qa-full',`--packet=${packet}`,`--width=${width}`,`--output=user://feedback-visual/${nonce}`];
    config.canvas=ui.canvas;config.canvasResizePolicy=0;config.focusCanvas=true;
    config.onPrint=(...parts)=>log(parts.join(' '));config.onPrintError=(...parts)=>log(parts.join(' '),true);
    config.onProgress=(loaded,total)=>{if(!last)ui.status.textContent=total>0?`LOADING actual engine ${Math.round(loaded*100/total)}%`:'LOADING actual engine';};
    watchdog=setTimeout(()=>{if(!finished)error('Browser300s global wall cap expired; result is incomplete. Reload/close this bounded run.');},300000);
    new Engine(config).startGame().catch(error);publish();
  };
  ui.reload.onclick=()=>location.reload();
  ui.frames.onchange=()=>{live=false;selectFrame(Number(ui.frames.value));};
  ui.live.onclick=()=>{live=!live;ui.live.textContent=live?'Show original captured PNG':'Show live held canvas';selectFrame(selected);};
  function download(url,name,revoke=false){const link=document.createElement('a');link.href=url;link.download=name;link.click();if(revoke)setTimeout(()=>URL.revokeObjectURL(url),1000);}
  ui.png.onclick=()=>{const frame=images.get(selected);if(frame?.ready)download(frame.url,frame.record.file);};
  ui.json.onclick=()=>download(URL.createObjectURL(new Blob([JSON.stringify(window.rbFeedbackEvidence,null,2)],{type:'application/json'})),`feedback-${packet}-${width}.json`,true);
  addEventListener('error',event=>error(event.message));addEventListener('unhandledrejection',event=>error(event.reason));
  addEventListener('beforeunload',()=>{for(const frame of images.values())URL.revokeObjectURL(frame.url);});
})();
