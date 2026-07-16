/* Generated from frozen rock_bottom_v19.html.
 * Source seams: sprite data and sprite caches.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { P, runtime, state } from '../core/runtime_ui.js';
import { last } from '../core/update.js';
import { EQUIPMENT } from '../data/catalogs.js';
import { H } from '../data/world.js';
import { WEAPONS } from '../minigames/activities.js';

export let PALS, PLAYER_LAYER_PAL, CART_LAYER_PAL, SPRITE_CACHE, INCIDENT_PALS;

export function parseGrid(rows) {
  return rows.map(r => r.split('').map(c => c === '.' ? 0 : parseInt(c)));
}

export function applyVars(rows, vars) {
  return rows.map(r => {
    let out = r;
    for (const k in vars) out = out.split(k).join(vars[k]);
    return out;
  });
}

export function blankSpriteGrid(){return Array.from({length:16},()=>Array(16).fill(0));}

export function gridPut(g,x,y,v){if(x>=0&&x<16&&y>=0&&y<16)g[y][x]=v;}

export function gridBox(g,x,y,w,h,v){for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)gridPut(g,xx,yy,v);}

export function gridLine(g,x1,y1,x2,y2,v){const n=Math.max(Math.abs(x2-x1),Math.abs(y2-y1));for(let i=0;i<=n;i++)gridPut(g,Math.round(x1+(x2-x1)*(i/(n||1))),Math.round(y1+(y2-y1)*(i/(n||1))),v);}

export function mirrorGrid(g){return g.map(row=>row.slice().reverse());}

export function anchorGridToBottom(g){
  let bottom=-1;for(let y=0;y<16;y++)for(let x=0;x<16;x++)if(g[y][x])bottom=Math.max(bottom,y);
  if(bottom<0||bottom===15)return g.map(r=>r.slice());
  const out=blankSpriteGrid(),shift=15-bottom;
  for(let y=0;y<16;y++)for(let x=0;x<16;x++)if(g[y][x])gridPut(out,x,y+shift,g[y][x]);
  return out;
}

export function makePlayer() {
  const base=(dir)=>{
    const g=blankSpriteGrid(),H=1,S=2,T=4,P=6,A=5,E=6,X=7;
    if(dir==='down'){
      gridBox(g,7,1,3,1,H);gridBox(g,6,2,5,1,H);gridBox(g,5,3,7,1,H);
      gridBox(g,5,4,7,3,H);gridBox(g,6,4,5,3,S);gridPut(g,7,5,H);gridPut(g,9,5,H);gridPut(g,8,6,X);
      gridBox(g,6,7,5,1,H);gridBox(g,4,8,8,5,T);gridBox(g,6,9,4,2,A);gridPut(g,3,10,S);gridPut(g,12,11,S);
      gridBox(g,5,13,3,2,P);gridBox(g,9,13,2,2,P);gridBox(g,4,15,4,1,E);gridBox(g,9,15,3,1,E);
    }else if(dir==='up'){
      gridBox(g,7,1,3,1,H);gridBox(g,6,2,5,1,H);gridBox(g,5,3,7,4,H);gridBox(g,7,4,2,3,X);
      gridBox(g,6,7,5,1,H);gridBox(g,4,8,8,5,T);gridLine(g,8,8,8,12,A);gridPut(g,3,11,S);gridPut(g,12,10,S);
      gridBox(g,5,13,3,2,P);gridBox(g,9,13,2,2,P);gridBox(g,4,15,4,1,E);gridBox(g,9,15,3,1,E);
    }else{
      gridBox(g,5,1,4,1,H);gridBox(g,4,2,6,1,H);gridBox(g,3,3,7,1,H);gridBox(g,3,4,7,3,H);
      gridBox(g,3,4,5,3,S);gridPut(g,4,5,H);gridPut(g,2,5,S);gridPut(g,7,6,X);gridBox(g,4,7,5,1,H);
      gridBox(g,4,8,6,5,T);gridBox(g,6,9,3,2,A);gridLine(g,4,10,2,12,S);gridPut(g,10,10,S);
      gridBox(g,5,13,2,2,P);gridBox(g,8,13,2,2,P);gridBox(g,4,15,3,1,E);gridBox(g,8,15,3,1,E);
    }
    return dir==='right'?mirrorGrid(g):g;
  };
  const step=(dir,frame)=>{
    const g=base(dir),S=2,T=4,P=6,E=6;
    if(frame===1){
      if(dir==='left'||dir==='right'){
        gridBox(g,3,10,2,2,0);gridLine(g,dir==='left'?4:11,10,dir==='left'?1:14,11,S);
        gridBox(g,4,13,3,2,0);gridBox(g,4,14,2,1,P);gridBox(g,3,15,4,1,E);
      }else{
        gridPut(g,3,10,0);gridLine(g,4,9,2,11,S);gridBox(g,5,13,3,3,0);gridBox(g,4,13,3,2,P);gridBox(g,3,15,4,1,E);
      }
    }else if(frame===2){
      gridPut(g,4,8,0);gridPut(g,11,8,0);gridPut(g,3,12,T);gridPut(g,12,12,T);gridBox(g,5,14,2,1,P);gridBox(g,9,14,2,1,P);
    }else if(frame===3){
      if(dir==='left'||dir==='right'){
        gridPut(g,10,10,0);gridLine(g,dir==='left'?9:6,10,dir==='left'?12:3,12,S);
        gridBox(g,8,13,3,3,0);gridBox(g,9,14,2,1,P);gridBox(g,9,15,4,1,E);
      }else{
        gridPut(g,12,11,0);gridLine(g,11,9,13,11,S);gridBox(g,9,13,3,3,0);gridBox(g,10,13,2,2,P);gridBox(g,9,15,4,1,E);
      }
    }
    return g;
  };
  const left=[0,1,2,3].map(f=>step('left',f));
  return {
    down:[0,1,2,3].map(f=>step('down',f)),
    up:[0,1,2,3].map(f=>step('up',f)),
    left,
    // Finish the left gait before mirroring it. Editing an already mirrored base produced
    // a second left leg on two frames and made rightward movement look like a limp.
    right:left.map(mirrorGrid),
  };
}

export function makePlayerAttack(player,dir,phase){
  const g=player[dir][0].map(r=>r.slice()),S=2,T=4;
  if(dir==='left'){gridBox(g,1,9,5,4,0);gridLine(g,5,9,phase?0:1,11,T);gridBox(g,phase?0:1,10,2,2,S);}
  if(dir==='right'){gridBox(g,10,9,5,4,0);gridLine(g,10,9,phase?15:14,11,T);gridBox(g,phase?14:13,10,2,2,S);}
  if(dir==='down'){gridLine(g,4,9,phase?7:5,13,T);gridBox(g,phase?7:5,12,2,2,S);gridPut(g,12,11,0);}
  if(dir==='up'){gridLine(g,11,9,phase?8:10,5,T);gridBox(g,phase?7:9,4,2,2,S);gridPut(g,3,11,0);}
  return g;
}

export function makePlayerGear(id,dir){
  const right=dir==='right',d=right?'left':dir,g=blankSpriteGrid(),side=d==='left';
  if(id==='mesh_cap'){if(side){gridBox(g,3,1,7,2,6);gridBox(g,1,3,5,1,2);}else{gridBox(g,5,1,7,2,6);gridBox(g,4,3,8,1,2);}}
  else if(id==='ski_mask'){if(side){gridBox(g,3,3,7,4,1);gridPut(g,4,5,5);}else{gridBox(g,5,3,7,4,1);gridPut(g,7,5,5);gridPut(g,9,5,5);}}
  else if(id==='helmet'){if(side){gridBox(g,4,0,6,2,2);gridBox(g,2,2,8,1,4);}else{gridBox(g,6,0,5,2,2);gridBox(g,4,2,9,1,4);}}
  else if(id==='cowboy'){if(side){gridBox(g,4,0,5,2,4);gridBox(g,1,2,10,1,3);}else{gridBox(g,6,0,5,2,4);gridBox(g,3,2,10,1,3);}}
  else if(id==='pigeon_crown'){if(side){gridBox(g,3,2,8,1,2);gridPut(g,4,0,2);gridPut(g,7,0,2);gridPut(g,9,1,2);}else{gridBox(g,4,2,9,1,2);gridPut(g,5,0,2);gridPut(g,8,0,2);gridPut(g,11,0,2);gridPut(g,8,1,7);}}
  else if(id==='priest_collar'){if(side){gridBox(g,4,7,5,1,5);gridPut(g,5,7,1);}else{gridBox(g,5,7,7,1,5);gridBox(g,7,7,2,1,1);}}
  else if(id==='trench'){if(side){gridBox(g,4,8,7,6,3);gridLine(g,6,8,8,14,1);}else{gridBox(g,3,8,10,6,3);gridLine(g,5,8,8,14,1);gridLine(g,11,8,8,14,1);}}
  else if(id==='windbreaker'){if(side){gridBox(g,4,8,7,4,7);gridLine(g,5,9,9,9,2);}else{gridBox(g,3,8,10,4,7);gridLine(g,4,9,11,9,2);}}
  else if(id==='bathrobe'){if(side){gridBox(g,4,8,7,6,5);gridLine(g,5,8,8,12,7);gridBox(g,4,11,7,1,7);}else{gridBox(g,3,8,10,6,5);gridLine(g,4,8,8,12,7);gridLine(g,11,8,8,12,7);gridBox(g,3,11,10,1,7);}}
  else if(id==='parka'){if(side){gridBox(g,3,8,8,6,6);gridBox(g,3,8,8,1,2);}else{gridBox(g,2,8,12,6,6);gridBox(g,3,8,10,1,2);gridPut(g,2,10,2);gridPut(g,13,10,2);}}
  else if(id==='airpods'){if(side)gridBox(g,2,5,1,3,5);else gridBox(g,4,5,1,3,5);}
  else if(id==='crocs'){gridBox(g,3,15,4,1,3);}
  else if(id==='walmart_sneak'){gridBox(g,3,15,4,1,5);gridBox(g,9,15,4,1,5);gridPut(g,4,15,1);gridPut(g,10,15,1);}
  else if(id==='vibrams'){gridBox(g,3,15,4,1,4);gridBox(g,9,15,4,1,4);gridPut(g,3,15,2);gridPut(g,12,15,2);}
  else if(id==='propane_torch'){if(side){gridBox(g,10,10,3,5,4);gridPut(g,11,9,2);}else{gridBox(g,12,10,3,5,4);gridPut(g,13,9,2);}}
  return right?mirrorGrid(g):g;
}

export function makeRoutePatch(tier,dir){
  const right=dir==='right',d=right?'left':dir,g=blankSpriteGrid(),side=d==='left';
  if(tier>=1)gridBox(g,5,9,2,2,2);
  if(tier>=2)gridBox(g,side?7:9,11,2,2,4);
  if(tier>=3)gridLine(g,side?4:3,12,side?8:5,12,7);
  if(tier>=4){gridBox(g,side?8:10,8,3,4,5);gridPut(g,side?9:11,9,1);gridPut(g,side?9:11,11,1);}
  return right?mirrorGrid(g):g;
}

export function makeWeaponLayer(id,dir,attack){
  const right=dir==='right',d=right?'left':dir,g=blankSpriteGrid(),side=d==='left';
  let x1=side?(attack?0:1):12,y1=side?(attack?10:11):(attack?8:10),x2=side?6:14,y2=side?11:14;
  if(d==='down'){x1=attack?7:12;y1=attack?10:10;x2=attack?9:13;y2=15;}
  if(d==='up'){x1=attack?7:3;y1=attack?3:9;x2=attack?9:4;y2=attack?9:13;}
  const line=v=>gridLine(g,x1,y1,x2,y2,v);
  if(id==='fists'){
    // A tiny wrist + two knuckles. One isolated cream pixel read as sprite damage.
    gridBox(g,x1,y1,attack?3:2,2,5);gridPut(g,x1+(side?-1:2),y1+1,2);
  }
  else if(id==='pipe'){line(4);gridPut(g,x2,y2,2);}
  else if(id==='brick'){gridBox(g,x1,y1,3,3,3);gridPut(g,x1+1,y1+1,4);}
  else if(id==='cart_wheel'){
    const cx=x1+((d==='down'&&!attack)?1:2),cy=y1+2;
    for(let a=0;a<8;a++){const q=a*Math.PI/4;gridPut(g,Math.round(cx+Math.cos(q)*2),Math.round(cy+Math.sin(q)*2),5);}gridPut(g,cx,cy,1);
  }
  else if(id==='shoe'){gridLine(g,x1,y1,x2,y2,3);gridBox(g,x2-1,y2-1,3,2,3);}
  else if(id==='baguette'){line(5);gridPut(g,x1,y1,2);gridPut(g,x2,y2,2);}
  else if(id==='microphone'){line(1);gridBox(g,x1-1,y1-1,3,3,7);}
  else if(id==='knife'){gridLine(g,x1,y1,x2,y2,5);gridPut(g,x1,y1,3);gridPut(g,x1+1,y1,3);}
  else if(id==='broken_bottle'){gridLine(g,x1,y1,x2,y2,7);gridBox(g,x1-1,y1-1,3,3,4);gridPut(g,x2,y2,5);}
  return right?mirrorGrid(g):g;
}

export function makeAttackSmear(dir,phase){
  const g=blankSpriteGrid(),v=phase?4:2;
  if(dir==='right'){
    if(!phase){gridLine(g,5,5,11,7,v);gridLine(g,6,8,12,10,v);}else{gridLine(g,2,3,13,7,v);gridLine(g,4,8,15,11,v);gridPut(g,13,12,5);}
  }
  if(dir==='left'){
    if(!phase){gridLine(g,10,5,4,7,v);gridLine(g,9,8,3,10,v);}else{gridLine(g,13,3,2,7,v);gridLine(g,11,8,0,11,v);gridPut(g,2,12,5);}
  }
  if(dir==='down'){
    if(!phase){gridLine(g,5,4,7,10,v);gridLine(g,9,5,10,11,v);}else{gridLine(g,3,1,7,14,v);gridLine(g,9,3,12,15,v);gridPut(g,13,13,5);}
  }
  if(dir==='up'){
    if(!phase){gridLine(g,5,11,7,5,v);gridLine(g,9,10,10,4,v);}else{gridLine(g,3,14,7,1,v);gridLine(g,9,12,12,0,v);gridPut(g,13,2,5);}
  }
  return g;
}

export function makeCartUnderlay(dir){
  const g=blankSpriteGrid();
  gridLine(g,2,8,13,8,3);gridLine(g,3,13,12,13,2);gridLine(g,2,8,3,13,2);gridLine(g,13,8,12,13,2);
  for(let x=4;x<=11;x+=2)gridLine(g,x,9,x,12,2);
  gridLine(g,3,10,12,10,3);gridLine(g,3,12,12,12,3);
  gridBox(g,3,14,3,2,1);gridBox(g,10,14,3,2,1);putCartHub(g,4,14);putCartHub(g,11,14);
  if(dir==='left')gridLine(g,2,8,0,6,3);else if(dir==='right')gridLine(g,13,8,15,6,3);else gridLine(g,12,8,14,6,3);
  return g;
}

export function putCartHub(g,x,y){gridPut(g,x,y,4);gridPut(g,x+1,y+1,2);}

export function rasterize(grid, palette, opts={}) {
  // v15: paint on the true 16x16 logical grid, then scale once. The old 1-device-pixel
  // halo and shine created half-logical pixels that blurred every silhouette.
  const logical = document.createElement('canvas');
  logical.width = 16; logical.height = 16;
  const lg = logical.getContext('2d');
  lg.imageSmoothingEnabled = false;
  if (!opts.noOutline) {
    lg.fillStyle = 'rgba(0,0,0,.9)';
    for (let y=0;y<16;y++) for (let x=0;x<16;x++) {
      if (!grid[y] || grid[y][x] === 0) continue;
      lg.fillRect(x-1,y,1,1); lg.fillRect(x+1,y,1,1);
      lg.fillRect(x,y-1,1,1); lg.fillRect(x,y+1,1,1);
    }
  }
  for (let y=0;y<16;y++) for (let x=0;x<16;x++) {
    const idx = grid[y] ? grid[y][x] : 0;
    const col = palette[idx];
    if (!idx || !col || col === 'transparent') continue;
    lg.fillStyle = col;
    lg.fillRect(x,y,1,1);
  }
  const c = document.createElement('canvas');
  c.width = 32; c.height = 32;
  const g = c.getContext('2d');
  g.imageSmoothingEnabled = false;
  g.drawImage(logical,0,0,32,32);
  return c;
}

export function makeDog() {
  const B=3, D=2, E=1, T=4, M=7;
  const f = (frame) => parseGrid(applyVars([
    '................',
    '...BBBB.........',
    '..BBBBBBB.......',
    '..BBM.MBBBBBB...',
    '..BBBBBBBBBBBB..',
    '.BBBBBBBBBBBBBT.',
    '..BBBBBBBBBBBB..',
    '..BBBBBBBBBBBB..',
    '..D..D...D..D...',
    '..D..D...D..D...',
    frame===0 ? '..D..D...D..D...' : '...D.....D......',
    frame===0 ? '..E..E...E..E...' : '...E..D..E..D...',
    frame===0 ? '................' : '..........E..E..',
    '................',
    '................',
    '................',
  ], {B:B, D:D, E:E, T:T, M:M}));
  return [f(0), f(1)];
}

export function applyDogSignature(kind, source, frame) {
  const g=source.map(row=>row.slice()),put=(x,y,v)=>{if(g[y]&&x>=0&&x<16)g[y][x]=v;};
  if(kind==='brutus'){
    put(4,3,5);put(6,3,1); // one cloudy eye. fourteen years is enough information.
    put(13,5,0);put(14,5,2);put(14,6,2);
  } else if(kind==='scrap_dog'){
    put(7,5,1);put(9,5,1);put(11,5,1);put(8,6,1);put(10,6,1); // ribs
    put(1,8,0);put(13,8,0);put(14,5,0);put(14,6,0);
    put(frame?14:13,7,2);put(frame?15:14,6,2); // the wag finally reaches the pixels
  } else if(kind==='os_brutus'){
    for(let x=4;x<12;x++)put(x,1,2);
    for(let x=2;x<14;x++)put(x,2,3);
    put(1,4,3);put(14,4,3);put(4,3,1);put(6,3,1);
  }
  return g;
}

export function makePigeon() {
  const f = (frame) => parseGrid(applyVars([
    '................',
    '.....C.C.C......',
    '.....CCCCC......',
    '......HHHO......',
    '.....HHHHHHF....',
    '....BBBBBBBB....',
    '...BBBBBBBBBB...',
    '...BBBBBBBBBB...',
    '....BBBBBBBB....',
    frame===0 ? '......F.F.......' : '......FF........',
    frame===0 ? '......F.F.......' : '......F.........',
    '................',
    '................',
    '................',
    '................',
    '................',
  ], {H:'2', O:'6', B:'3', F:'6', C:'7'}));
  return [f(0), f(1)];
}

export function makePossum() {
  const f = (frame) => parseGrid(applyVars([
    '................',
    '.....OOOOO......',
    '.....OPPPPO.....',
    '.....OPPPPO.....',
    '....HHHHHHH.....',
    '...HFFFFFFF.....',
    '..HFFOoOOoOF....',
    '..HFFFFFFFFFF...',
    '.HFFFFFFFFFFFF..',
    '.HFFFFFFFFFFFFt.',
    '..HFFFFFFFFFFF..',
    frame===0 ? '..D..D....D..D..' : '...D..D....D..D.',
    '................',
    '................',
    '................',
    '................',
  ], {O:'6', P:'7', H:'2', F:'4', o:'1', D:'3', t:'2'}));
  return [f(0), f(1)];
}

export function applyNpcSignature(id, g, frame) {
  const put=(x,y,v)=>{ if(y>=0&&y<16&&x>=0&&x<16) g[y][x]=v; };
  const line=(x1,y1,x2,y2,v)=>{
    const n=Math.max(Math.abs(x2-x1),Math.abs(y2-y1));
    for(let i=0;i<=n;i++) put(Math.round(x1+(x2-x1)*(i/(n||1))),Math.round(y1+(y2-y1)*(i/(n||1))),v);
  };
  const box=(x,y,w,h,v)=>{for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)put(xx,yy,v);};
  const clear=(x,y,w,h)=>box(x,y,w,h,0);

  if (id === 'tony_coat_3' || id === 'tony') {
    box(2,8,2,5,4); box(12,8,2,5,4); line(5,8,7,12,7); line(10,8,8,12,7);
  } else if (id === 'tony_coat_2') {
    put(3,9,4); put(12,9,4); line(5,8,7,12,7); line(10,8,8,12,7);
  } else if (id === 'tony_coat_1') {
    clear(3,9,1,4); clear(12,9,1,4); line(6,8,7,12,7); line(9,8,8,12,7);
  } else if (id === 'tony_bare') {
    clear(3,8,2,5); clear(11,8,2,5); box(5,8,6,5,6); put(6,5,1); put(9,5,1);
  } else if (id === 'yuri') {
    // bald crown, square beard, and a hubcap held like an invoice.
    clear(5,1,6,2); box(6,2,4,1,4); box(5,6,6,2,2); put(7,6,4); put(9,6,4);
    line(11,9,13,10,2); put(13,9,5); put(14,10,5); put(13,11,5); put(12,10,5); put(13,10,1);
  } else if (id === 'pete') {
    // apron, chest pocket, and one rectangular hot-pocket unit.
    box(5,8,6,6,5); line(5,8,7,13,1); line(10,8,8,13,1); box(7,10,3,2,7);
    line(11,9,13,10,3); box(13,9,3,2,4); put(14,9,5);
  } else if (id === 'lurch' || id === 'biggu') {
    clear(3,10,2,3); clear(11,10,2,3); line(4,8,1,14,3); line(11,8,14,14,3);
    put(1,15,5); put(14,15,5); if(id==='biggu'){put(2,8,4);put(13,8,4);put(2,9,4);put(13,9,4);}
  } else if (id === 'sherri') {
    // hard hair spikes and a phone already halfway into the next conversation.
    put(4,0,2); put(6,0,2); put(9,0,2); put(11,1,2);
    line(3,9,1,12,4); line(12,9,14,7,4); box(14,5,2,4,7); put(2,13,5);
  } else if (id === 'paulie') {
    clear(3,1,10,7); box(4,1,8,1,2); box(3,2,10,6,4); box(4,3,8,4,5);
    box(5,4,2,2,1); box(9,4,2,2,1); box(6,7,4,1,1); box(13,10,2,3,6);
  } else if (id === 'mom') {
    // kombucha bottle, label, and sensible little shoes.
    line(11,9,13,10,4); box(13,8,2,5,6); put(14,7,7); put(13,10,5);
    box(4,15,3,1,5); box(10,15,3,1,5);
  } else if (id === 'priest') {
    box(7,7,2,1,7); line(7,9,7,12,6); line(6,10,8,10,6);
  } else if (id === 'priest_fallen') {
    clear(7,7,2,1); line(2,8,5,13,6); line(13,8,10,13,6); put(6,5,7); put(9,5,7); box(7,6,2,1,1);
  } else if (id === 'conductor') {
    box(4,0,8,2,1); box(3,2,10,1,2); put(8,1,5);
    line(10,9,13,11,5); box(13,10,3,3,7); line(13,11,15,11,1);
  } else if (id === 'larry') {
    box(6,5,4,3,1); box(7,5,2,1,5); put(6,7,5); put(9,7,5);
    line(3,9,0,7,6); line(12,9,15,7,6); put(0,6,5); put(15,6,5);
  } else if (id === 'stripe') {
    // hood aperture, one severe diagonal stripe, and the suspicious soap package.
    box(5,3,6,4,1); box(6,4,4,3,5); put(7,5,1); put(9,5,1);
    line(3,8,11,13,5); line(4,8,12,13,7); box(13,10,3,3,6); put(14,11,7);
  } else if (id === 'cubscout') {
    line(5,8,10,12,5); box(13,10,2,3,6);
  } else if (id === 'jogger') {
    line(4,9,2,11,4); line(11,9,14,8,4); if(frame) put(13,14,0);
  } else if (id === 'busker') {
    line(4,8,11,14,2); box(9,10,4,3,4);
  } else if (id === 'dogwalker') {
    line(12,11,15,14,2); put(14,14,4); put(15,14,4); put(15,13,5);
  } else if (id === 'vapelord') {
    box(3,8,2,4,2); put(13,6,6); put(14,5,6);
  } else if (id === 'mayorscousin') {
    box(5,13,2,3,5); box(9,13,2,3,5);
  } else if (id === 'phoneguy') {
    box(12,5,2,4,7); put(11,8,5);
  } else if (id === 'launderlady') {
    box(4,10,8,3,7); line(5,11,10,11,6);
  } else if (id === 'metermaid') {
    box(12,9,3,4,5); line(12,10,14,10,7);
  } else if (id === 'foodtruck') {
    box(5,9,6,5,5); line(12,8,15,11,7);
  } else if (id === 'priestson') {
    line(4,2,11,2,1); put(4,1,1);
  } else if (id === 'karaoke') {
    box(4,10,8,4,2); box(6,11,4,1,6);
  } else if (id === 'barb') {
    box(3,9,10,5,7); line(5,10,10,10,1); line(5,12,9,12,1); put(12,8+(frame?1:0),5);
  } else if (id === 'pinky') {
    line(4,1,11,1,1); line(5,8,5,13,5); line(10,8,10,13,5);
  } else if (id === 'math') {
    box(11,9,4,5,7); line(12,10,14,10,1); line(12,12,14,12,1);
  } else if (id === 'brendan') {
    line(12,8,15,9,7); put(15,8,6); put(14,7,6);
  } else if (id === 'train_hopper') {
    box(3,7,2,6,7); put(2,8,7); line(11,8,13,13,2);
  } else if (id === 'philosopher') {
    line(12,8,14,15,2); put(14,15,1); box(3,9,2,3,7);
  } else if (id === 'lease_guy') {
    // Clipboard on one side, an unreasonable key ring on the other.
    box(11,8,4,6,7);line(12,9,14,9,1);line(12,11,14,11,1);
    line(4,9,2,12,6);put(1,12,6);put(2,13,6);put(3,12,6);put(2,11,6);put(2,12,1);
  } else if (id === 'gutter_greg') {
    // Crooked hook plus the rubber duck he has entered as inventory.
    line(3,8,1,14,7);put(2,15,7);box(12,10,3,3,6);put(13,9,6);put(15,11,5);
  } else if (id === 'blue_tarp_guard') {
    clear(2,0,12,5);box(3,0,10,3,2);line(2,3,13,3,2);box(3,3,2,6,2);put(4,2,5);put(11,2,5);put(12,4,7);
  } else if (id === 'receipt_guard') {
    line(4,7,11,14,2);line(5,7,12,14,2);box(12,8,3,6,2);put(13,10,1);put(14,10,1);put(12,12,5);put(14,13,1);
  } else if (id === 'wire_guard') {
    line(4,9,11,9,5);line(4,11,11,11,5);line(5,13,10,13,5);box(12,8,3,5,7);line(13,12,15,15,5);
  } else if (id === 'darryl_under_blue') {
    clear(1,0,14,13);box(2,0,12,3,2);line(1,3,14,3,2);box(1,3,3,10,2);box(12,3,3,10,2);box(5,4,6,4,3);put(3,2,5);put(12,2,5);put(7,5,1);put(9,5,1);
  } else if (id === 'general_receipt') {
    clear(2,0,12,4);line(3,2,7,0,2);line(8,0,12,2,2);line(3,2,12,2,2);box(2,8,3,4,2);box(11,8,3,4,2);box(6,8,4,5,2);put(7,9,1);put(8,9,1);put(7,11,7);put(8,11,7);box(13,11,3,5,2);
  } else if (id === 'bishop_wire') {
    clear(4,0,8,4);line(5,3,7,0,5);line(10,3,8,0,5);line(7,0,8,0,7);line(12,7,14,15,5);put(13,6,5);put(15,8,5);box(6,7,4,1,7);line(4,10,11,10,5);line(4,12,11,12,5);
  } else if (id === 'curb_emperor') {
    clear(1,0,14,4);box(3,2,10,2,2);put(3,0,2);put(6,1,2);put(9,0,2);put(12,1,2);box(1,8,4,4,2);box(11,8,4,4,2);line(4,8,11,14,5);line(13,8,15,14,7);box(14,7,2,2,5);
  } else if (id === 'price_guy') {
    box(3,1,10,2,1); box(4,7,8,8,2); put(7,5,7);
  }
  return g;
}

export function makeSleepingDave() {
  const f=(frame)=>parseGrid([
    '................','................','................','................',
    '................','................','................','................',
    '..........222...','...111...2333...','..15511115555...','..55555556666...',
    '.6666666666666..','..66..66..66....',frame?'...7.......7....':'..7.........7...','................'
  ]);
  return [f(0),f(1)];
}

export function makeNPC(opts={}) {
  const H = opts.hat ?? 1, S = opts.skin ?? 3, T = opts.shirt ?? 4, P = opts.pants ?? 6, A = opts.accent ?? 5;
  const C2 = opts.shirt2 ?? T;
  const ACC = opts.accColor ?? 5;
  const E = 6; // boots/feet color index
  const isWide = opts.wide, isTall = opts.tall, isThin = opts.thin;
  const isBald = opts.bald, isHood = opts.hood;
  const isYell = opts.yelling, hasBeard = opts.beard;
  const cap = opts.cap;
  const coats = opts.coats ?? 1;
  const accessory = opts.accessory;

  const f = (frame) => {
    // head row layout
    let headTop = '......HHHH......';
    let headW1  = '.....HHHHHH.....';
    if (isTall) { headTop = '.......HH.......'; headW1 = '......HHHH......'; }
    if (cap) {
      headTop = '....HHHHHHHHHH..';
      headW1  = '....HHHHHHHHHH..';
    }
    if (isHood) {
      headTop = '.....HHHHHH.....';
      headW1  = '....HHHHHHHH....';
    }
    let row3 = isBald ? '.....SSSSSS.....' : '.....HHHHHH.....';
    let row4 = '.....SSSSSS.....';
    let eyes = isYell ? '.....SOOOOS.....' : '.....SeSeS......';
    let row6 = '.....SSSSSS.....';
    if (hasBeard) row6 = '.....HSHHSH.....';
    if (isHood) { row3 = '.....HHHHHH.....'; row4 = '.....HSSSSH.....'; eyes = '.....HSeSeH.....'; row6 = '.....HSSSSH.....'; }
    // body
    let body = [
      '................',
      headTop,
      headW1,
      row3,
      row4,
      eyes,
      row6,
      isWide ? '....TTTTTTTTTT..' : '....TTTTTTTT....',
      coats >= 2 ? '....CCTTTTTTCC..' : '....TTAAAATT....',
      coats >= 3 ? '...CCCCTTTTCCC..' : '...TTTTTTTTT....',
      '...STTTTTTTTS...',
      isWide ? '...STTTTTTTTTS..' : '...STTTTTTTS....',
      '....TTTTTTTT....',
      '....PPPPPPPP....',
      '....PP....PP....',
      '....EE....EE....',
    ];
    if (isThin) {
      body[7]  = '.....TTTTTT.....';
      body[8]  = '....TTAATT......';
      body[9]  = '....TTTTTT......';
      body[10] = '....STTTTS......';
      body[11] = '....STTTTS......';
      body[12] = '.....TTTT.......';
      body[13] = '.....PPPP.......';
      body[14] = '.....P..P.......';
      body[15] = '.....E..E.......';
    }
    // walk frames — staggered legs
    if (frame === 1) {
      body[14] = isThin ? '.....PP.P.......' : '....PPP.PPPP....';
      body[15] = isThin ? '.....EE..P......' : '....EE.....P....';
    } else if (frame === 2) {
      body[14] = isThin ? '.....P.PP.......' : '....PPPP.PPP....';
      body[15] = isThin ? '.....P..EE......' : '....P.....EE....';
    }
    // accessory overlays
    if (accessory === 'cross') {
      body[9]  = '...TTTTAATTT....';
      body[11] = '...STTTAATTS....';
    }
    if (accessory === 'kombucha') {
      body[11] = '...STTTTTTTKS...'.replace(/K/g, A);
      body[12] = '....TTTTTTTK....'.replace(/K/g, A);
    }
    if (accessory === 'badge') {
      body[9] = '....TTAAAATB....'.replace(/B/g, ACC);
    }
    if (accessory === 'sash') {
      body[9] = '....AATTTTAA....';
      body[10] = '...TAATTTTAAT...';
    }
    if (accessory === 'glasses') {
      // square wire-frame glasses — accent frames bracketing each eye, skin nose bridge between
      body[5] = '....ASeASeSA....';
      body[4] = '.....AAAAAA.....';
    }
    if (isTall) {
      body[0]=body[1]; body[1]=body[2]; body[2]=body[3]; body[3]=body[4];
      body[4]=body[5]; body[5]=body[6]; body[6]='.....TTTTTT.....';
      body[13]='.....PPPP.......';
      body[14]=frame===1?'.....PP.P.......':frame===2?'.....P.PP.......':'.....P..P.......';
      body[15]=frame===1?'.....EE.P.......':frame===2?'.....P.EE.......':'.....E..E.......';
    }
    body = applyVars(body, {H:H, S:S, T:T, P:P, A:A, E:E, C:C2, O:'1', e:'1'});
    return applyNpcSignature(opts.signature||'', parseGrid(body), frame);
  };
  return [f(0), f(1), f(2)];
}

export function buildSprites() {
  // v17 player — four-beat shuffle, two attack poses, visible equipment, weapons and route patches.
  const p = makePlayer();
  ['down','up','left','right'].forEach(d => {
    p[d].forEach((g,i) => {
      SPRITE_CACHE['player_'+d+'_'+i] = rasterize(g, PALS.player);
      SPRITE_CACHE['playerhi_'+d+'_'+i] = rasterize(g, PALS.player_high);
    });
    for(let phase=0;phase<2;phase++){
      const attack=makePlayerAttack(p,d,phase);
      SPRITE_CACHE['playerattack_'+d+'_'+phase]=rasterize(attack,PALS.player);
      SPRITE_CACHE['playerattackhi_'+d+'_'+phase]=rasterize(attack,PALS.player_high);
      SPRITE_CACHE['attack_smear_'+d+'_'+phase]=rasterize(makeAttackSmear(d,phase),PLAYER_LAYER_PAL,{noOutline:true});
    }
    for(const id of Object.keys(EQUIPMENT)){
      SPRITE_CACHE['gear_'+id+'_'+d]=rasterize(makePlayerGear(id,d),PLAYER_LAYER_PAL,{noOutline:true});
    }
    for(const id of Object.keys(WEAPONS)){
      SPRITE_CACHE['weapon_'+id+'_'+d+'_0']=rasterize(makeWeaponLayer(id,d,false),PLAYER_LAYER_PAL,{noOutline:id==='fists'});
      SPRITE_CACHE['weapon_'+id+'_'+d+'_1']=rasterize(makeWeaponLayer(id,d,true),PLAYER_LAYER_PAL,{noOutline:id==='fists'});
    }
    for(let tier=1;tier<=4;tier++){
      SPRITE_CACHE['route_patch_'+tier+'_'+d]=rasterize(makeRoutePatch(tier,d),PLAYER_LAYER_PAL,{noOutline:true});
    }
    SPRITE_CACHE['cart_underlay_'+d]=rasterize(makeCartUnderlay(d),CART_LAYER_PAL,{noOutline:true});
  });
  // NPCs — distinctive styles, 3-frame walks
  const npcStyles = {
    tony:      { hat:6, skin:3, shirt:4, pants:6, accent:5, coats:3, shirt2:7 },          // three coats, never blinks
    yuri:      { hat:6, skin:3, shirt:2, pants:6, accent:5, bald:true, beard:true },      // bald, beard
    pete:      { hat:2, skin:3, shirt:6, pants:5, accent:4, wide:true },                  // wide, behind glass
    lurch:     { hat:1, skin:3, shirt:6, pants:6, accent:5, tall:true },                  // 7ft tall
    sherri:    { hat:6, skin:3, shirt:6, pants:2, accent:5, thin:true },                  // thin, fast
    paulie:    { hat:1, skin:4, shirt:3, pants:6, accent:5 },                             // the face
    dave:      { hat:2, skin:3, shirt:6, pants:6, accent:5 },                             // sleeps
    mom:       { hat:6, skin:5, shirt:4, pants:5, accent:6, accessory:'kombucha' },       // kombucha
    priest:    { hat:1, skin:5, shirt:1, pants:1, accent:6, accessory:'cross' },          // collar + cross
    conductor: { hat:6, skin:3, shirt:6, pants:1, accent:5, cap:true },                   // train cap
    larry:     { hat:5, skin:3, shirt:6, pants:2, accent:4, yelling:true, wide:true },    // YELLING
    stripe:    { hat:5, skin:3, shirt:6, pants:2, accent:4, hood:true },                  // hood up
    cop:       { hat:3, skin:5, shirt:3, pants:1, accent:7, cap:true, accessory:'badge', accColor:5 },
    biggu:     { hat:5, skin:3, shirt:6, pants:6, accent:5, tall:true, wide:true },       // tall AND big
    cubscout:  { hat:5, skin:5, shirt:4, pants:1, accent:7, accessory:'sash', thin:true },
    jogger:    { hat:5, skin:5, shirt:4, pants:1, accent:7, thin:true },
    busker:    { hat:5, skin:3, shirt:4, pants:6, accent:7 },
    dogwalker: { hat:6, skin:5, shirt:4, pants:1, accent:6 },
    vapelord:  { hat:5, skin:3, shirt:2, pants:1, accent:6, hood:true, accessory:'kombucha' },
    mayorscousin: { hat:1, skin:3, shirt:6, pants:1, accent:5, coats:2, shirt2:5 },
    phoneguy:  { hat:5, skin:3, shirt:2, pants:6, accent:7, thin:true },
    launderlady: { hat:6, skin:5, shirt:4, pants:1, accent:6, wide:true },
    metermaid: { hat:6, skin:5, shirt:4, pants:1, accent:6, cap:true, accessory:'badge', accColor:5 },
    foodtruck: { hat:5, skin:3, shirt:6, pants:6, accent:5, wide:true, accessory:'badge' },
    priestson: { hat:5, skin:5, shirt:2, pants:1, accent:6, thin:true, cap:true },
    karaoke:   { hat:5, skin:3, shirt:6, pants:2, accent:4 },
    // v13 wave 2
    barb:      { hat:2, skin:3, shirt:4, pants:6, accent:5, wide:true },
    pinky:     { hat:2, skin:3, shirt:4, pants:6, accent:5, thin:true },
    math:      { hat:2, skin:3, shirt:4, pants:6, accent:5, thin:true, accessory:'glasses' },
    brendan:   { hat:3, skin:5, shirt:3, pants:6, accent:7, cap:true, accessory:'badge', accColor:5, thin:true },
    // v13 wave 8a — train hopper: wiry, gray beard, faded jacket. accessory shows the backpack on his back via accent color.
    train_hopper: { hat:2, skin:3, shirt:3, pants:6, accent:7, thin:true, beard:true },
    // v13 wave 8a — philosopher: kindly old woman, gray hair under a hat, brown coat
    philosopher:  { hat:6, skin:5, shirt:2, pants:6, accent:7, wide:true },
    lease_guy:    { hat:2, skin:5, shirt:3, pants:1, accent:7, cap:true, wide:true },
    gutter_greg:  { hat:2, skin:4, shirt:3, pants:7, accent:6, thin:true, beard:true },
    blue_tarp_guard:   {hat:2,skin:3,shirt:4,pants:6,accent:5,hood:true,wide:true},
    receipt_guard:     {hat:7,skin:3,shirt:4,pants:6,accent:2,cap:true,accessory:'sash'},
    wire_guard:        {hat:1,skin:3,shirt:4,pants:6,accent:5,thin:true,beard:true},
    darryl_under_blue: {hat:2,skin:3,shirt:4,pants:6,accent:5,hood:true,wide:true,coats:2,shirt2:2},
    general_receipt:   {hat:2,skin:3,shirt:4,pants:6,accent:7,cap:true,wide:true,coats:2,shirt2:2},
    bishop_wire:       {hat:5,skin:3,shirt:4,pants:6,accent:7,tall:true,beard:true},
    curb_emperor:      {hat:2,skin:3,shirt:4,pants:6,accent:5,wide:true,yelling:true,coats:3,shirt2:2},
    // v13 wave 8a — price guy: silhouette in a black coat. brim hat. unsettling.
    price_guy:    { hat:1, skin:4, shirt:3, pants:3, accent:6, hood:true },
    // v13 wave 8a — old school brutus reuses the dog sprite (handled below), this entry not used
  };
  Object.entries(npcStyles).forEach(([k, opts]) => {
    const frames = makeNPC({...opts, signature:k});
    frames.forEach((g, i) => {
      SPRITE_CACHE[k+'_'+i] = rasterize(g, PALS[k] || PALS.tony);
    });
  });
  // v15 readable state art: Dave lies down; Tony's contractually numbered coats actually
  // leave his body; Fallen O'Malley no longer relies on n.color that cached art ignores.
  makeSleepingDave().forEach((g,i)=>{ SPRITE_CACHE['dave_sleep_'+i]=rasterize(anchorGridToBottom(g),PALS.dave); });
  const tonyStates = [
    ['tony_coat_2', {...npcStyles.tony, coats:2, signature:'tony_coat_2'}],
    ['tony_coat_1', {...npcStyles.tony, coats:1, signature:'tony_coat_1'}],
    ['tony_bare',   {...npcStyles.tony, coats:1, signature:'tony_bare'}],
  ];
  for (const [key,def] of tonyStates) makeNPC(def).forEach((g,i)=>{
    SPRITE_CACHE[key+'_'+i]=rasterize(g,PALS.tony);
  });
  makeNPC({...npcStyles.priest, coats:1, signature:'priest_fallen'}).forEach((g,i)=>{
    SPRITE_CACHE['priest_fallen_'+i]=rasterize(g,PALS.priest_fallen);
  });
  // possum, brutus, pigeon — special silhouettes, 2-frame
  const possum = makePossum();
  possum.forEach((g,i) => { SPRITE_CACHE['possum_'+i] = rasterize(anchorGridToBottom(g), PALS.possum); });
  const dog = makeDog();
  dog.forEach((g,i) => { SPRITE_CACHE['brutus_'+i] = rasterize(anchorGridToBottom(applyDogSignature('brutus',g,i)), PALS.brutus); });
  // v13 wave 6 — scrap_dog reuses the dog shape with a different (mangier) palette
  dog.forEach((g,i) => { SPRITE_CACHE['scrap_dog_'+i] = rasterize(anchorGridToBottom(applyDogSignature('scrap_dog',g,i)), PALS.scrap_dog); });
  // v13 wave 8a — old school brutus reuses the dog shape with the deeper-rust palette. boss-tier.
  dog.forEach((g,i) => { SPRITE_CACHE['os_brutus_'+i] = rasterize(anchorGridToBottom(applyDogSignature('os_brutus',g,i)), PALS.os_brutus); });
  const pig = makePigeon();
  pig.forEach((g,i) => { SPRITE_CACHE['pigeon_'+i] = rasterize(anchorGridToBottom(g), PALS.pigeon); });

  // horse cop — horse with cop on top (special)
  const hc = makeHorseCop();
  hc.forEach((g,i) => { SPRITE_CACHE['horsecop_'+i] = rasterize(anchorGridToBottom(g), PALS.horsecop); });
  // pothole — a hole that talks
  SPRITE_CACHE['pothole_0'] = rasterize(makePothole(0), PALS.pothole);
  SPRITE_CACHE['pothole_1'] = rasterize(makePothole(1), PALS.pothole);
  SPRITE_CACHE['pothole_2'] = rasterize(makePothole(2), PALS.pothole);
  buildIncidentSprites();
}

export function buildIncidentSprites() {
  const defs={
    incident_mattress:[
      [
        '................','................','...1111111111...','..122222222221..',
        '.12333333333321.','.12343333333421.','.12333333333321.','.12333333333321.',
        '.12333333333321.','.12343333333421.','.12333333333321.','..122222222221..',
        '...1111111111...','....6......6....','................','................'
      ],
      [
        '................','................','....111111111...','...12222222221..',
        '..1233333333321.','..1234333333421.','..1233333333321.','..1233333333321.',
        '..1233333333321.','..1234333333421.','..1233333333321.','...12222222221..',
        '....111111111...','...6......6.....','................','................'
      ]
    ],
    incident_forklift:[
      [
        '................','................','.....3333.......','....333333......',
        '....311113......','....311113......','....333333......','...222233333....',
        '..2222233333....','..2222233333.11.','..2222233333.11.','..4444444444.11.',
        '.41111111111411.','..11......11.11.','..66......66....','................'
      ],
      [
        '................','................','.....3333.......','....333333......',
        '....311113......','....311113......','....333333......','...222233333....',
        '..2222233333.11.','..2222233333.11.','..2222233333.11.','..4444444444.11.',
        '.41111111111411.','...11....11..11.','...66....66.....','................'
      ]
    ],
    incident_dryer:[
      [
        '................','....11111111....','...1222222221...','...1233333321...',
        '...1234444321...','...1241111421...','...1241551421...','...1241551421...',
        '...1241111421...','...1234444321...','...1233333321...','...1222222221...',
        '...1222222221...','...1111111111...','....6......6....','................'
      ],
      [
        '................','.....11111111...','....1222222221..','....1233333321..',
        '....1234444321..','....1241111421..','....1241551421..','....1241551421..',
        '....1241111421..','....1234444321..','....1233333321..','....1222222221..',
        '....1222222221..','....1111111111..','.....6......6...','................'
      ]
    ],
    incident_suitcase:[
      [
        '................','......1111......','.....122221.....','.....1....1.....',
        '...1111111111...','..122222222221..','..123333333321..','..123333333321..',
        '..123336633321..','..123336633321..','..123333333321..','..123333333321..',
        '..122222222221..','...1111111111...','....7......7....','................'
      ],
      [
        '................','.......1111.....','......122221....','......1....1....',
        '....1111111111..','...122222222221.','...123333333321.','...123333333321.',
        '...123336633321.','...123336633321.','...123333333321.','...123333333321.',
        '...122222222221.','....1111111111..','.....7......7...','................'
      ]
    ],
    incident_sprinkler:[
      [
        '................','................','................','...........44...',
        '..........444...','.....1111144....','....1222221.....','....1233321.....',
        '....1233321.....','....1233321.....','....1233321.....','....1222221.....',
        '...111111111....','..12222222221...','..11111111111...','................'
      ],
      [
        '................','................','................','...44...........',
        '...444..........','....4411111.....','.....1222221....','.....1233321....',
        '.....1233321....','.....1233321....','.....1233321....','.....1222221....',
        '....111111111...','...12222222221..','...11111111111..','................'
      ]
    ],
  };
  for(const [key,frames] of Object.entries(defs)) frames.forEach((rows,i)=>{
    SPRITE_CACHE[key+'_'+i]=rasterize(parseGrid(rows),INCIDENT_PALS[key.slice(9)]);
  });
}

export function makeHorseCop() {
  // 16x16 sprite, horse body + cop torso on top
  const f = (frame) => parseGrid(applyVars([
    '...HHHH.........', // cop hat
    '...HHHH.........',
    '....SSSS........', // cop face
    '....SeSe........',
    '....cccc........', // cop torso
    '...cBccBc.......', // badge
    '...cccccc.......',
    '..HHHHHHHHH.....', // horse back
    '..HHHHHHHHHHH...',
    '.HHHHHHHHHHHHM..',
    '.HHHHHHHHHHHHH..',
    '.HHHHHHHHHHHHH..',
    frame===0 ? '.DD..D.D..D.D...' : '.D.D.DD..DD.D...',
    frame===0 ? '.DD..D.D..D.D...' : '.D.D.DD..DD.D...',
    '.EE..E.E..E.E...',
    '................',
  ], {H:'6', S:'5', e:'1', c:'3', B:'7', M:'7', D:'3', E:'1'}));
  return [f(0), f(1)];
}

export function makePothole(frame) {
  // dark oval, slightly animating shape (it's TALKING)
  const open = frame === 1 ? 'eeee' : (frame === 2 ? 'EEEE' : 'eEEe');
  return parseGrid(applyVars([
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '.....2222.......',
    '....222222......',
    '...22XXXX22.....'.replace(/XXXX/g, open),
    '...22XXXX22.....'.replace(/XXXX/g, open),
    '....222222......',
    '.....2222.......',
    '................',
    '................',
    '................',
    '................',
  ], {e:'1', E:'1'}));
}

export function init_sprites() {
  // ---------- NPCs canonical data ----------
  // pixel-art sprite as palette-indexed strings (16x16)
  PALS = {
    player: ['transparent','#2a1f10','#604020','#a07050','#e8c040','#d4c896','#1a1810','#3a2820'],
    player_high: ['transparent','#5a4020','#a07020','#e8c040','#fff0a0','#fff8d0','#3a2810','#7a5020'],
    tony: ['transparent','#1a0805','#3a1818','#5a2820','#8a3a3a','#d4c896','#603020','#000'],
    yuri: ['transparent','#1a1008','#4a2818','#8a3a18','#d4c896','#e8c040','#5a3018','#000'],
    brutus: ['transparent','#000','#3a2018','#603020','#a07050','#1a0805','#d4c896','#8a3018'],
    pete: ['transparent','#1a1008','#4a4028','#8a7050','#d4c896','#604020','#a08840','#000'],
    lurch: ['transparent','#1a0810','#3a2030','#604040','#a07060','#d4c896','#2a1810','#d4c896'],
    sherri: ['transparent','#1a0808','#3a1820','#603030','#a05050','#d4c896','#d488d4','#000'],
    paulie: ['transparent','#1a0808','#5a3030','#8a5050','#d4a880','#d4c896','#603020','#000'],
    dave: ['transparent','#1a1008','#3a2818','#604020','#a07050','#d4c896','#88663a','#000'],
    mom: ['transparent','#1a0810','#503040','#80a050','#a8c030','#d4c896','#d488d4','#d4c896'],
    possum: ['transparent','#1a0805','#3a2820','#604030','#a08868','#d4c896','#e8c040','#a07020'],
    priest: ['transparent','#000','#1a1020','#2a2030','#4a3040','#d4c896','#d488d4','#d4c896'],
    priest_fallen: ['transparent','#050306','#160b18','#321438','#5a205f','#d4c896','#8a3a78','#e8c040'],
    conductor: ['transparent','#1a1010','#3a2820','#604030','#a07050','#d4c896','#8a3a3a','#604030'],
    larry: ['transparent','#1a0808','#3a1818','#8a3030','#d4c896','#e8c040','#d06030','#d4c896'],
    stripe: ['transparent','#0a0a18','#1a1828','#3a3848','#7a7888','#d4c896','#e8c040','#d4d4d4'],
    pigeon: ['transparent','#1a1810','#3a3828','#605840','#888070','#d4c896','#d06030','#e8c040'],
    cop: ['transparent','#000','#080820','#1818a0','#2828d0','#d4c896','#e8c040','#d4c896'],
    biggu: ['transparent','#1a1008','#3a2818','#604030','#a08060','#d4c896','#604020','#000'],
    horsecop: ['transparent','#000','#080820','#1818a0','#2828d0','#d4c896','#604030','#d4c896'],
    vapelord: ['transparent','#1a0820','#3a1850','#603080','#a050c0','#d4c896','#d488d4','#d4c896'],
    mayorscousin: ['transparent','#1a1008','#3a2818','#604030','#a07050','#d4c896','#8a3a3a','#d4c896'],
    phoneguy: ['transparent','#1a1008','#3a2818','#604030','#a07050','#d4c896','#88c0ff','#d4c896'],
    pothole: ['transparent','#000','#0a0805','#1a1810','#2a2818','#3a3828','#604020','#d4c896'],
    launderlady: ['transparent','#1a0820','#3a3a44','#605a70','#a09abd','#d4c896','#88c0ff','#d4c896'],
    metermaid: ['transparent','#1a1810','#3a3818','#605828','#a8c030','#d4c896','#8a3a3a','#d4c896'],
    foodtruck: ['transparent','#1a0805','#3a1810','#603020','#a04830','#d4c896','#d06030','#d4c896'],
    priestson: ['transparent','#1a0820','#2a2030','#4a3040','#80708a','#d4c896','#88c0ff','#d4c896'],
    karaoke: ['transparent','#1a0820','#3a1850','#603080','#a050c0','#d4c896','#e8c040','#d4c896'],
    // v13 wave 2 — converting the last four emoji-era styles and giving barb her own skin
    cubscout: ['transparent','#1a1810','#2828a8','#e8c0a0','#2a5028','#e8c040','#20202a','#d4c896'],
    jogger: ['transparent','#1a0810','#c8a850','#f0c8b0','#d488d4','#f8a8c8','#1a1a20','#d4c896'],
    busker: ['transparent','#1a1008','#5a3018','#d4a878','#8a6840','#604030','#283848','#d4c896'],
    dogwalker: ['transparent','#1a1010','#604020','#e8c8a8','#e8a880','#88c0ff','#4a4848','#d4c896'],
    barb: ['transparent','#20182a','#b0a8a0','#c0a890','#8a6080','#c898c0','#4a3040','#d4c896'],
    pinky: ['transparent','#0a0805','#180810','#c08850','#c8b070','#e8c040','#2a1810','#d4c896'],
    math: ['transparent','#0a0a08','#2a1810','#b09078','#c8b8a0','#6a6a5a','#6a5a4a','#d4c896'],
    brendan: ['transparent','#000','#0a0a28','#2838c0','#4048e8','#f4d8b8','#181828','#d4c896'],
    // v13 wave 6 — scrap_dog: scrappy brown + black, mangier than brutus
    scrap_dog: ['transparent','#000','#3a2010','#4a2810','#684830','#a08040','#d4c896','#181010'],
    // v13 wave 8a — train hopper: faded denim jacket + gray beard + dusty backpack
    train_hopper: ['transparent','#0a0805','#3a3a4a','#5a5a78','#8a8898','#d4c896','#3a2818','#a09080'],
    // v13 wave 8a — park bench philosopher: gray hair + brown coat + kindly face
    philosopher:  ['transparent','#0a0805','#604838','#8a7868','#c8c0b8','#d4c896','#3a2820','#88a08c'],
    // v13 wave 8a — price guy: black coat + hat brim + a stillness about him. mostly silhouette.
    price_guy:    ['transparent','#000','#0a0808','#181818','#2a2a2a','#d4c896','#5a3030','#d4c896'],
    lease_guy:    ['transparent','#15100a','#3a3024','#6a5840','#9a8058','#d4c896','#c08038','#88c0ff'],
    gutter_greg:  ['transparent','#10120f','#29382f','#496050','#7a8060','#d4c896','#e8c040','#3a2818'],
    // v19 rival courts. Slate blue avoids the bright cop-only blue language.
    blue_tarp_guard: ['transparent','#111418','#34485a','#9a6848','#263540','#e8c040','#2a2118','#6a7b80'],
    receipt_guard: ['transparent','#17130d','#d4c896','#9a6848','#5a4b38','#8a3a3a','#2a241c','#9a9270'],
    wire_guard: ['transparent','#100b08','#4a5028','#8a5b3a','#33251d','#d06030','#201814','#8a3a3a'],
    darryl_under_blue: ['transparent','#0b0e10','#2f4658','#a07050','#1d2b34','#e8c040','#2a2018','#7890a0'],
    general_receipt: ['transparent','#15110d','#d4c896','#a07050','#604c30','#e8c040','#302820','#8a3a3a'],
    bishop_wire: ['transparent','#0b0907','#2e241c','#a07050','#4a5028','#d06030','#211812','#d4c896'],
    curb_emperor: ['transparent','#0a0805','#5a5548','#9a6848','#8a3a3a','#e8c040','#1a1810','#d06030'],
    // v13 wave 8a — old school brutus: bigger brutus palette w/ deeper rust + darker accents
    os_brutus:    ['transparent','#000','#2a1810','#4a2818','#604030','#1a0805','#a08040','#5a2010'],
  };
  
  // 16x16 pixel art helpers — parse a row string of 0-7 (dot=transparent)
  
  
  
  // player sprites — 4 directions, 3 walk frames each (idle / left-step / right-step)
  
  
  
  
  
  
  
  // v17: real directional silhouettes and a four-beat uneven shuffle.
  
  
  
  
  PLAYER_LAYER_PAL=['transparent','#0a0805','#e8c040','#8a3a3a','#d06030','#d4c896','#4a5028','#d488d4'];
  
  
  
  
  
  CART_LAYER_PAL=['transparent','#0a0805','#66665e','#9a988b','#d4c896'];
  
  
  
  // Render palette-indexed sprite to a 32×32 offscreen canvas (16×16 scaled 2x)
  // v10: adds automatic outline (1px black around all opaque pixels) and shading
  // (lighter pixel on top-left of each colored region) for a more polished look.
  
  
  // Quadruped (Brutus) — 14 year old mostly blind dog. 2-frame trot.
  
  
  
  
  // Pigeon — small, one foot per VIBE
  
  
  // Possum — flat brown lump, dignified, tiny construction helmet
  
  
  // v15 authored identity layer. These are still edits to the 16x16 palette grid, not
  // runtime drawing. Shared bodies keep the roster coherent; silhouette/held-object pixels
  // carry the joke before a nameplate is read.
  
  
  
  
  // Generic humanoid NPC with style options
  // opts:
  //   hat,skin,shirt,pants,accent  — palette indices (1-7)
  //   tall: bool (add rows up top)
  //   wide: bool (extend body sides)
  //   bald: bool (flatter head, skin showing)
  //   yelling: bool (open mouth)
  //   hood: bool (hood drape over face)
  //   coats: 1-3 (layered shirts/colors)
  //   cap: bool (square hat top)
  //   accessory: 'cross' | 'pipe' | 'kombucha' | 'badge' | 'sash' | null
  //   beard: bool
  //   thin: bool (narrower body)
  
  
  // Build the SPRITE_CACHE
  SPRITE_CACHE = {};
  
  
  INCIDENT_PALS = {
    mattress:['transparent','#1a1008','#8a6840','#d4c896','#6a4a35','#e8c040','#3a2818','#8a3a3a'],
    forklift:['transparent','#17130f','#5a4828','#e8c040','#a07020','#d4c896','#604020','#8a3a3a'],
    dryer:['transparent','#17130f','#4a4848','#8a8880','#b0aaa0','#88c0ff','#604020','#d4c896'],
    suitcase:['transparent','#17130f','#3a2818','#6a4828','#a07020','#d4c896','#8a3a3a','#e8c040'],
    sprinkler:['transparent','#172018','#3a5030','#6a7860','#88c0ff','#d4c896','#305878','#e8c040'],
  };
  
  
  
  
  
  
  
}
