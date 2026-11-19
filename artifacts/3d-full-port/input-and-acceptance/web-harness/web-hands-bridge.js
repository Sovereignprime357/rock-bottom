/* Isolated draft bridge. No game state access, storage API or arbitrary commands. */
(() => {
  'use strict';
  const ids=['canvas','stage','status','next','abort','frames','live','png','json','held-frame','frame-label','frame-result','report','log'];
  const ui=Object.fromEntries(ids.map(id=>[id,document.getElementById(id)]));
  const width=new URLSearchParams(location.search).get('size')==='960'?960:1280;
  const height=width===960?540:720;
  ui.canvas.width=width;ui.canvas.height=height;ui.stage.style.maxWidth=width+'px';
  const images=new Map(),logs=[],engineErrors=[],browserErrors=[];
  const trusted={keydown:0,keyup:0,mousedown:0,mouseup:0,mousemove:0,pointerlock_changes:0};
  let last=null,selected=-1,busy=true,finished=false,bytesHeld=0,booted=false,live=false,webgl=null;
  const limit=96*1024*1024;
  function bounded(list,value,cap=50){if(list.length<cap)list.push(String(value).slice(0,1800));}
  function log(value,isError=false){bounded(logs,value,120);if(isError)bounded(engineErrors,value);ui.log.textContent=logs.join('\n');if(last)publish();}
  function error(value){bounded(browserErrors,value);ui.log.textContent=[...logs,...browserErrors].join('\n');if(last)publish();else ui.status.textContent='FAILED — '+String(value);}
  function actualWebGL(){
    try{const gl=ui.canvas.getContext('webgl2');return gl?{webgl2:true,version:gl.getParameter(gl.VERSION),renderer:gl.getParameter(gl.RENDERER),vendor:gl.getParameter(gl.VENDOR),drawing_buffer:[gl.drawingBufferWidth,gl.drawingBufferHeight],attributes:gl.getContextAttributes()}:{webgl2:false};}
    catch(e){error(e);return {webgl2:false};}
  }
  function selectFrame(index){
    if(!images.has(index))return;
    selected=index;ui.frames.value=String(index);const frame=images.get(index);
    if(frame.ready)ui['held-frame'].src=frame.url;
    ui['held-frame'].hidden=live||!frame.ready;
    ui['frame-label'].textContent=`CAPTURED WEB FRAME ${index+1}/16 — ${frame.label} — ${frame.record.framebuffer.join('×')} — ${frame.ready?'PNG dimensions/hash verified':'verifying PNG'}${live?' | showing LIVE normally paused canvas':''}`;
    ui['frame-result'].textContent=JSON.stringify({...frame.record,png_verified:frame.ready},null,2);
    ui.png.disabled=!frame.ready;ui.live.disabled=!frame.ready;
  }
  function publish(){
    if(!last)return;
    if(!webgl&&booted)webgl=actualWebGL();
    const records=last.records||[];
    const pngsVerified=records.every(row=>images.get(row.index)?.ready===true);
    const healthy=engineErrors.length===0&&browserErrors.length===0;
    const evidence={...last,browser:{userAgent:navigator.userAgent,platform:navigator.platform,devicePixelRatio:devicePixelRatio,webgl,canvas:[ui.canvas.width,ui.canvas.height],trusted_event_counts:{...trusted},pointer_locked:document.pointerLockElement===ui.canvas},pngs_verified:pngsVerified,engine_errors:[...engineErrors],browser_errors:[...browserErrors],input_frame_checks_pass:last.input_frame_checks_pass===true&&healthy&&pngsVerified&&webgl?.webgl2===true,visual_acceptance:false,provenance_note:'Empty exported GDScript hashes are unavailable, not proof. Preserve external frozen project/export hashes. Trusted event counts alone do not prove successful pointer lock or gameplay.'};
    window.rbHandsEvidence=evidence;
    ui.report.textContent=JSON.stringify(evidence,null,2);
    const ready=last.ready===true&&!busy&&!finished&&healthy&&pngsVerified;
    ui.next.disabled=!ready;ui.abort.disabled=finished||!booted;
    ui.json.disabled=false;
    ui.next.textContent=last.current<0?'Start actual input sequence':`Next: ${last.phases?.[last.current+1]||'complete'}`;
    ui.status.className=healthy&&(last.failures||[]).length===0?'':'failure';
    ui.status.textContent=busy?'RUNNING real input — no screenshot acceptance yet':finished?`FINISHED — input/frame checks ${evidence.input_frame_checks_pass?'PASS':'FAIL/incomplete'}; visual review still required`:ready?'READY — actual title/pause; next phase is bounded':'NOT READY — inspect report/PNG verification';
  }
  window.rbHandsBusy=index=>{busy=true;live=true;ui['held-frame'].hidden=true;ui.status.textContent=`RUNNING real phase ${index+1}/16`;ui.next.disabled=true;};
  window.rbHandsReport=report=>{
    if(!report||report.format!=='rock-bottom-web-hands-draft'||!Array.isArray(report.records)||report.records.length>16){error('Malformed bounded engine report');return;}
    booted=true;clearTimeout(coldWatchdog);last=report;busy=false;finished=report.finished===true;
    publish();if(selected>=0)selectFrame(selected);
  };
  window.rbHandsFrame=async(index,label,base64,record)=>{
    try{
      if(!Number.isInteger(index)||index<0||index>=16||images.has(index)||typeof label!=='string'||typeof base64!=='string'||base64.length>8388608||record.index!==index)throw new Error('Rejected duplicate/invalid/big frame');
      const binary=atob(base64),bytes=Uint8Array.from(binary,char=>char.charCodeAt(0));
      if(bytes.length===0||bytes.length>6291456||bytesHeld+bytes.length>limit)throw new Error('PNG retention budget exceeded');
      if(bytes.length!==record.png_bytes)throw new Error('PNG byte count differs');
      bytesHeld+=bytes.length;
      const url=URL.createObjectURL(new Blob([bytes],{type:'image/png'}));
      const frame={label,record,url,ready:false};images.set(index,frame);
      const option=document.createElement('option');option.value=String(index);option.textContent=`${index+1} — ${label}`;ui.frames.appendChild(option);ui.frames.disabled=false;
      const hash=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes));
      if(Array.from(hash,value=>value.toString(16).padStart(2,'0')).join('')!==record.png_sha256)throw new Error('Actual PNG hash differs');
      const decoded=new Image();decoded.src=url;await decoded.decode();
      if(decoded.naturalWidth!==width||decoded.naturalHeight!==height||record.framebuffer[0]!==width||record.framebuffer[1]!==height)throw new Error('Real PNG/framebuffer dimensions differ');
      frame.ready=true;live=false;selectFrame(index);publish();
    }catch(e){error(e);}
  };
  ui.next.onclick=()=>{
    if(ui.next.disabled||typeof window.rbHandsControl!=='function'||!last)return;
    busy=true;ui.next.disabled=true;window.rbHandsControl('next',last.current+1);
  };
  ui.abort.onclick=()=>{if(typeof window.rbHandsControl==='function')window.rbHandsControl('abort',-1);};
  ui.frames.onchange=()=>{live=false;selectFrame(Number(ui.frames.value));};
  ui.live.onclick=()=>{live=!live;ui.live.textContent=live?'Show captured Web frame':'Show live paused canvas';selectFrame(selected);};
  function download(url,name,revoke=false){const link=document.createElement('a');link.href=url;link.download=name;link.click();if(revoke)setTimeout(()=>URL.revokeObjectURL(url),1000);}
  ui.png.onclick=()=>{const frame=images.get(selected);if(frame?.ready)download(frame.url,`${String(selected+1).padStart(2,'0')}_${frame.label}_${width}.png`);};
  ui.json.onclick=()=>download(URL.createObjectURL(new Blob([JSON.stringify(window.rbHandsEvidence,null,2)],{type:'application/json'})),`web-hands-${width}.json`,true);
  for(const type of ['keydown','keyup','mousedown','mouseup','mousemove'])ui.canvas.addEventListener(type,event=>{if(event.isTrusted)trusted[type]++;});
  document.addEventListener('pointerlockchange',()=>{trusted.pointerlock_changes++;if(last)publish();});
  addEventListener('error',event=>error(event.message));addEventListener('unhandledrejection',event=>error(event.reason));
  addEventListener('beforeunload',()=>{for(const frame of images.values())URL.revokeObjectURL(frame.url);});
  const coldWatchdog=setTimeout(()=>{if(!booted){error('180s browser cold startup watchdog expired');if(typeof window.rbHandsControl==='function')window.rbHandsControl('abort',-1);}},180000);
  window.rbHandsBoot=config=>{
    config.args=['--script','res://tests/web_hands_probe.gd','--','--qa-full',...(width===960?['--web-hands-size=960']:[])];
    config.canvas=ui.canvas;config.canvasResizePolicy=0;config.focusCanvas=false;
    config.onPrint=(...parts)=>log(parts.join(' '));config.onPrintError=(...parts)=>log(parts.join(' '),true);
    config.onProgress=(loaded,total)=>{if(!booted)ui.status.textContent=total>0?`LOADING engine ${Math.round(loaded*100/total)}%`:'LOADING actual engine';};
    new Engine(config).startGame().catch(error);
  };
})();
