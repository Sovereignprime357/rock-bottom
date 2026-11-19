/* Isolated QA bridge: start/abort only; no game-state or storage access. */
(() => {
  'use strict';
  const get=id=>document.getElementById(id);
  const canvas=get('canvas'),status=get('status'),report=get('report'),log=get('log');
  const images=new Map(),errors=[],messages=[];
  let last=null,started=false,verifiedBytes=0,watchdog=null;
  canvas.width=960;canvas.height=540;
  function fail(value){if(errors.length<32)errors.push(String(value).slice(0,1600));publish();}
  function publish(){
    log.textContent=[...messages,...errors].join('\n');
    if(!last){status.textContent=errors.length?'FAILED before report':'Loading actual Web engine';return;}
    const verified=(last.frames||[]).length===3&&[...images.values()].filter(x=>x.verified).length===3;
    window.rbDaveEvidence={...last,browser:{userAgent:navigator.userAgent,platform:navigator.platform,devicePixelRatio,canvas:[canvas.width,canvas.height]},pngs_verified:verified,browser_errors:[...errors],machine_checks_pass:last.acceptance===true&&verified&&errors.length===0,visual_acceptance:false};
    report.textContent=JSON.stringify(window.rbDaveEvidence,null,2);
    get('start').disabled=started||last.finished===true||errors.length>0;
    get('abort').disabled=last.finished===true;
    get('json').disabled=false;
    status.textContent=last.finished?`FINISHED — machine checks ${window.rbDaveEvidence.machine_checks_pass?'PASS':'FAIL/incomplete'}; visual review required`:started?'RUNNING ordinary input; one120s total limit':'READY — Start once; cold startup and waiting count toward120s';
  }
  window.rbDaveReport=value=>{
    if(!value||value.format!=='rock-bottom-dave-walkthrough'||!Array.isArray(value.frames)||value.frames.length>3){fail('Invalid bounded Dave report');return;}
    last=value;if(last.finished)clearTimeout(watchdog);publish();
  };
  window.rbDaveFrame=async(index,base64,row)=>{
    try{
      if(!Number.isInteger(index)||index<0||index>2||images.has(index)||typeof base64!=='string'||base64.length>8388608||!row||row.png_bytes<=0)throw Error('Invalid/duplicate bounded frame');
      const bytes=Uint8Array.from(atob(base64),c=>c.charCodeAt(0));
      if(bytes.length!==row.png_bytes||bytes.length>6291456||verifiedBytes+bytes.length>18874368)throw Error('PNG byte budget/count mismatch');
      verifiedBytes+=bytes.length;
      const url=URL.createObjectURL(new Blob([bytes],{type:'image/png'}));
      const entry={url,row,verified:false};images.set(index,entry);
      const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes));
      if(Array.from(digest,x=>x.toString(16).padStart(2,'0')).join('')!==row.png_sha256)throw Error('Original PNG hash mismatch');
      const image=new Image();image.src=url;await image.decode();
      if(image.naturalWidth!==960||image.naturalHeight!==540||row.framebuffer[0]!==960||row.framebuffer[1]!==540)throw Error('Actual PNG dimensions mismatch');
      entry.verified=true;
      const section=document.createElement('section');const title=document.createElement('h2');title.textContent=row.label;
      image.alt=`Original captured Web frame: ${row.label}`;
      const link=document.createElement('a');link.href=url;link.download=`${row.label}_960.png`;link.textContent='Download original PNG';
      const facts=document.createElement('pre');facts.textContent=JSON.stringify(row,null,2);
      section.append(title,image,link,facts);get('captures').append(section);publish();
    }catch(error){fail(error);}
  };
  get('start').onclick=()=>{
    if(started||get('start').disabled||typeof window.rbDaveControl!=='function')return;
    started=true;canvas.focus();get('start').disabled=true;window.rbDaveControl('start');publish();
  };
  get('abort').onclick=()=>{if(typeof window.rbDaveControl==='function')window.rbDaveControl('abort');};
  get('json').onclick=()=>{
    if(!window.rbDaveEvidence)return;
    const url=URL.createObjectURL(new Blob([JSON.stringify(window.rbDaveEvidence,null,2)],{type:'application/json'}));
    const link=document.createElement('a');link.href=url;link.download='dave-walkthrough-web-960.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  };
  addEventListener('error',event=>fail(event.message));addEventListener('unhandledrejection',event=>fail(event.reason));
  addEventListener('beforeunload',()=>{for(const row of images.values())URL.revokeObjectURL(row.url);});
  window.rbDaveBoot=config=>{
    watchdog=setTimeout(()=>{fail('120s browser attempt watchdog expired');if(typeof window.rbDaveControl==='function')window.rbDaveControl('abort');},120000);
    config.args=['--script','res://tests/dave_walkthrough_probe.gd','--','--qa-full'];
    config.canvas=canvas;config.canvasResizePolicy=0;config.focusCanvas=false;
    config.onPrint=(...parts)=>{if(messages.length<80)messages.push(parts.join(' ').slice(0,1600));publish();};
    config.onPrintError=(...parts)=>fail(parts.join(' '));
    new Engine(config).startGame().catch(fail);
  };
})();
