import {
  blankSpriteGrid, gridBox, gridEllipse, gridLine, gridPut,
} from './sprite_toolkit.js';

const SIZE=32;
const grid=()=>blankSpriteGrid(SIZE);
// Final eye-review targets live here: silhouette differences must survive the 32px screen rect.

function dogBody(kind,frame) {
  const g=grid();
  const body=kind==='scrap_dog'?2:3, shadow=2, light=4, dark=1, eye=6, accent=7;
  const lift=frame?1:0;

  // Low old-dog silhouette: a barrel with a shoulder hitch and no heroic chest.
  gridEllipse(g,15,19,11,7,body);
  gridBox(g,8,14,15,9,body);
  gridEllipse(g,25,17,6,6,body);
  gridBox(g,25,17,5,5,body);
  gridLine(g,6,16,2,12+(kind==='scrap_dog'?frame:0),shadow);
  gridLine(g,3,12+(kind==='scrap_dog'?frame:0),1,15+(kind==='scrap_dog'?frame:0),shadow);
  gridLine(g,9,14,21,13,light);
  gridLine(g,9,22,23,23,shadow);
  gridBox(g,27,12,3,4,shadow); // ear
  gridPut(g,29,13,dark);
  gridBox(g,28,19,3,3,light); // muzzle
  gridPut(g,30,19,dark);
  gridPut(g,27,17,dark);
  gridPut(g,26,17,kind==='brutus'?eye:dark);

  const frontX=frame?23:25, rearX=frame?8:10;
  gridBox(g,rearX,22,3,7-lift,shadow);
  gridBox(g,frontX,22,3,7-lift,shadow);
  gridBox(g,14,23,3,6+lift,body);
  gridBox(g,27,22,2,6+lift,body);
  gridBox(g,rearX-1,28-lift,5,2,dark);
  gridBox(g,frontX-1,28-lift,5,2,dark);
  gridBox(g,13,28+lift,5,2,dark);
  gridBox(g,26,28+lift,4,2,dark);

  if (kind==='brutus') {
    // Clouded eye, slack jowl, old collar with one surviving tag.
    gridPut(g,26,17,6);gridPut(g,27,17,1);
    gridLine(g,24,21,29,22,7);gridPut(g,28,23,5);
    gridLine(g,22,13,23,22,1);gridBox(g,22,20,3,2,7);
  } else if (kind==='scrap_dog') {
    // Ribs and missing fur turn the shared dog into a different read at 1px scale.
    gridEllipse(g,14,19,9,5,0);
    gridBox(g,7,16,15,7,body);
    for(let x=9;x<=19;x+=3)gridLine(g,x,16,x-1,21,1);
    gridPut(g,7,15,0);gridPut(g,9,14,0);gridPut(g,18,15,4);
    gridLine(g,28,12,30,9,1);gridPut(g,30,10,2);
    gridLine(g,6,16,frame?0:2,frame?11:13,2);
  } else {
    // Older Brutus has the same legal footprint and much less empty air: a shoulder
    // hump, ruined ear, heavy forelegs and a gym towel that outlived the gym.
    gridEllipse(g,17,12,8,5,body);gridBox(g,7,10,15,6,body);
    gridBox(g,22,11,8,10,body);gridBox(g,27,15,4,5,light);
    gridBox(g,25,8,4,5,shadow);gridPut(g,28,8,0);gridPut(g,29,9,dark);
    gridBox(g,21,9,4,13,6);gridLine(g,20,9,23,23,6);
    gridPut(g,21,13,0);gridPut(g,24,18,0);gridPut(g,22,23,6);
    gridLine(g,25,14,29,17,dark);gridPut(g,27,14,6);
    gridBox(g,23,21,5,8,shadow);gridBox(g,24,28,6,2,dark);
    gridBox(g,8,11,5,3,light);gridPut(g,6,16,accent);gridPut(g,5,17,accent);
  }
  return g;
}

export function makeDog32(kind) {
  if (!['brutus','scrap_dog','os_brutus'].includes(kind)) throw new Error(`unknown dog base ${kind}`);
  return [dogBody(kind,0),dogBody(kind,1)];
}

export function makePossum32() {
  const make=frame=>{
    const g=grid();
    // A low municipal lump. The helmet is too small and still has seniority.
    gridEllipse(g,15,21,11,6,4);gridBox(g,7,18,17,7,4);
    gridEllipse(g,23,20,5,5,4);
    // Pale wedge-face, black pin nose and whiskers keep the low body from reading
    // as a helmeted appliance.
    gridLine(g,22,17,30,21,5);gridLine(g,22,24,30,21,5);
    gridPut(g,25,19,1);gridPut(g,30,21,1);gridPut(g,31,21,1);
    gridLine(g,28,20,31,18,2);gridLine(g,28,22,31,24,2);
    gridLine(g,7,22,3,24,2);gridLine(g,3,24,0,27+(frame?0:-1),3);
    gridPut(g,1,26+(frame?0:-1),7);gridPut(g,4,24,7);
    gridLine(g,8,19,22,17,5);gridLine(g,9,24,23,25,2);
    for(let x=10;x<=22;x+=4)gridPut(g,x,20,5);
    const feet=frame?[[9,27],[16,28],[23,27]]:[[8,28],[15,27],[22,28]];
    for(const [x,y] of feet){gridBox(g,x,y,3,2,3);gridPut(g,x+3,y+1,1);}
    gridBox(g,11,12,10,3,6);gridBox(g,13,10,7,3,6);
    gridLine(g,10,15,22,15,7);gridPut(g,13,11,7);gridPut(g,18,10,7);
    return g;
  };
  return [make(0),make(1)];
}

export function makePigeon32() {
  const make=frame=>{
    const g=grid();
    const rise=frame?1:0;
    gridEllipse(g,16,20-rise,8,8,3);
    gridEllipse(g,18,12-rise,5,6,2);
    gridBox(g,13,15-rise,8,9,3);
    gridLine(g,10,18-rise,16,24-rise,4);gridLine(g,11,18-rise,13,24-rise,2);
    gridLine(g,22,18-rise,26,23-rise,2);gridPut(g,25,22-rise,4);
    gridPut(g,20,11-rise,1);gridPut(g,21,11-rise,5);
    gridLine(g,22,13-rise,27,14-rise,6);gridPut(g,27,14-rise,1);
    // Crown: specific, cheap, and visibly one size too large.
    gridLine(g,13,7-rise,22,7-rise,7);
    for(const x of [13,17,21]){gridPut(g,x,5-rise,7);gridPut(g,x+1,6-rise,7);}
    gridPut(g,18,6-rise,6);
    // One foot. The absent one does not get an explanatory animation.
    gridLine(g,16,26-rise,16,29,6);gridLine(g,16,29,13+(frame?1:0),30,6);
    if(frame){gridLine(g,9,18,5,14,3);gridLine(g,6,14,4,17,4);}
    return g;
  };
  return [make(0),make(1)];
}

export function makeHorseCop32() {
  const make=frame=>{
    const g=grid();
    // Horse is compressed into the legal rect and looks annoyed about zoning.
    gridEllipse(g,16,21,12,6,6);gridBox(g,6,18,20,8,6);
    gridBox(g,24,16,6,8,6);gridBox(g,27,14,4,6,5);
    gridPut(g,30,15,1);gridPut(g,29,16,7);gridLine(g,29,18,31,19,4);
    gridLine(g,5,19,1,15+(frame?2:0),6);gridPut(g,1,15+(frame?2:0),1);
    gridLine(g,7,19,24,18,4);gridLine(g,8,25,25,26,1);
    const legs=frame?[[8,25,7,30],[14,25,16,30],[21,25,20,30],[26,24,28,29]]:
      [[7,25,8,30],[14,25,13,30],[21,25,22,30],[27,24,26,29]];
    for(const [x1,y1,x2,y2] of legs){gridLine(g,x1,y1,x2,y2,6);gridBox(g,x2-1,y2,4,2,1);}

    // Rider: blue is authority-only here; badge sits slightly off-center.
    gridBox(g,10,7,9,9,3);gridBox(g,11,4,7,5,5);
    gridPut(g,13,6,1);gridPut(g,16,6,1);gridLine(g,13,8,16,8,2);
    gridBox(g,10,1,9,3,2);gridLine(g,8,4,20,4,4);
    gridLine(g,9,10,6,18,3);gridLine(g,19,10,23,17,3);
    gridPut(g,16,11,7);gridPut(g,17,12,7);gridLine(g,12,14,18,14,4);
    gridLine(g,20,12,27,15,1); // reins
    return g;
  };
  return [make(0),make(1)];
}

export function makePothole32(frame) {
  const g=grid();
  gridEllipse(g,16,24,13,6,2);gridEllipse(g,16,24,10,4,1);
  gridLine(g,5,22,10,19,3);gridLine(g,22,19,28,22,3);
  gridPut(g,8,25,4);gridPut(g,25,23,4);gridPut(g,12,20,6);
  if(frame===0){
    gridLine(g,11,24,21,24,7);gridPut(g,15,23,1);gridPut(g,18,25,1);
  }else if(frame===1){
    gridEllipse(g,16,24,6,3,0);gridLine(g,11,22,21,22,7);gridLine(g,12,26,20,26,7);
    gridPut(g,13,23,1);gridPut(g,18,25,1);
  }else{
    gridLine(g,10,23,22,25,7);gridPut(g,12,23,1);gridPut(g,15,24,1);gridPut(g,19,25,1);
    gridLine(g,11,26,20,26,3);
  }
  return g;
}

function mattress(frame) {
  const g=grid(),shift=frame?1:0;
  // Soft corners, sagged quilting, a mold continent and exposed springs. A rigid
  // rectangle read as a framed envelope at 3x review scale.
  gridBox(g,4+shift,8,25,17,1);gridBox(g,3+shift,10,27,13,1);
  gridBox(g,5+shift,9,23,15,2);gridBox(g,6+shift,10,21,13,3);
  gridPut(g,4+shift,8,0);gridPut(g,28+shift,8,0);gridPut(g,3+shift,10,0);
  gridPut(g,29+shift,22,0);gridPut(g,5+shift,24,0);gridPut(g,27+shift,24,0);
  gridLine(g,7+shift,15,25+shift,15,2);gridLine(g,16+shift,10,16+shift,22,2);
  for(const [x,y] of [[9,12],[22,12],[10,19],[22,20],[16,16]]){
    gridPut(g,x+shift,y,5);gridPut(g,x+shift-1,y,4);gridPut(g,x+shift,y+1,2);
  }
  gridEllipse(g,10+shift,20,4,2,4);gridPut(g,8+shift,19,7);gridPut(g,12+shift,21,7);
  gridBox(g,26+shift,19,3,4,0);gridLine(g,26+shift,19,30+shift,17,6);
  gridLine(g,26+shift,21,30+shift,20,6);gridPut(g,29+shift,18,7);
  gridLine(g,6+shift,24,9+shift,27,2);gridLine(g,25+shift,24,23+shift,27,2);
  return g;
}

function forklift(frame) {
  const g=grid(),wheel=frame?1:0;
  gridBox(g,4,15,18,11,2);gridBox(g,8,8,11,9,3);gridBox(g,10,10,7,6,1);
  gridLine(g,7,15,10,9,4);gridBox(g,4,22,20,5,4);
  gridBox(g,23,7,2,20,1);gridBox(g,26,7,2,20,1);gridLine(g,24,26,31,26,1);gridLine(g,24,29,31,29,1);
  gridLine(g,6,18,20,18,3);gridPut(g,18,16,5);gridPut(g,19,16,5);
  gridEllipse(g,8+wheel,27,4,4,1);gridEllipse(g,8+wheel,27,2,2,6);
  gridEllipse(g,20-wheel,27,4,4,1);gridEllipse(g,20-wheel,27,2,2,6);
  gridLine(g,10,12,15,16,7);return g;
}

function dryer(frame) {
  const g=grid(),shift=frame?1:0;
  gridBox(g,6+shift,3,21,27,1);gridBox(g,7+shift,4,19,25,2);
  gridBox(g,9+shift,6,15,4,3);gridPut(g,11+shift,8,5);gridPut(g,21+shift,8,5);
  gridEllipse(g,16+shift,19,8,8,1);gridEllipse(g,16+shift,19,6,6,4);gridEllipse(g,16+shift,19,4,4,3);
  if(frame){gridLine(g,13+shift,17,20+shift,21,5);gridLine(g,13+shift,22,19+shift,16,3);}
  else{gridLine(g,12+shift,20,20+shift,17,5);gridLine(g,14+shift,15,19+shift,23,3);}
  gridBox(g,9+shift,29,4,2,6);gridBox(g,21+shift,29,4,2,6);return g;
}

function suitcase(frame) {
  const g=grid(),shift=frame?1:0;
  gridBox(g,11+shift,4,10,3,1);gridBox(g,13+shift,2,6,3,2);
  gridBox(g,4+shift,7,25,20,1);gridBox(g,5+shift,8,23,18,2);
  gridLine(g,16+shift,8,16+shift,26,4);gridLine(g,6+shift,12,27+shift,12,3);
  gridBox(g,13+shift,15,7,5,6);gridPut(g,16+shift,17,1);gridPut(g,18+shift,17,1);
  gridBox(g,7+shift,27,4,2,7);gridBox(g,23+shift,27,4,2,7);
  gridPut(g,7+shift,9,5);gridPut(g,26+shift,24,5);return g;
}

function sprinkler(frame) {
  const g=grid(),flip=frame?-1:1;
  gridBox(g,11,14,11,13,1);gridBox(g,12,15,9,11,2);gridBox(g,14,16,5,9,3);
  gridBox(g,8,27,17,3,1);gridBox(g,6,29,21,2,2);
  gridLine(g,16,14,16,8,1);gridLine(g,12,8,20,8,1);gridPut(g,11,8,5);gridPut(g,21,8,5);
  for(let i=0;i<6;i++){
    const x=16+flip*(4+i*2),y=8-Math.floor(i*1.2);
    gridPut(g,x,y,4);if(i%2===0)gridPut(g,x,y-1,6);
  }
  gridLine(g,13,18,19,18,7);gridPut(g,15,21,5);return g;
}

export function makeIncidentSprites32() {
  return {
    incident_mattress:[mattress(0),mattress(1)],
    incident_forklift:[forklift(0),forklift(1)],
    incident_dryer:[dryer(0),dryer(1)],
    incident_suitcase:[suitcase(0),suitcase(1)],
    incident_sprinkler:[sprinkler(0),sprinkler(1)],
  };
}
