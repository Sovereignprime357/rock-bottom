import {
  blankSpriteGrid, cloneGrid, gridBox, gridDither, gridEllipse, gridLine, gridPut, mirrorGrid,
} from './sprite_toolkit.js';

const SIZE = 32;

function fresh() {
  return blankSpriteGrid(SIZE);
}

function finish(grid, label) {
  if (grid.length !== SIZE || grid.some(row => row.length !== SIZE)) {
    throw new Error(`${label} must be an explicit ${SIZE}x${SIZE} grid`);
  }
  for (const row of grid) for (const cell of row) {
    if (!Number.isInteger(cell) || cell < 0 || cell > 7) {
      throw new Error(`${label} uses undeclared palette index ${cell}`);
    }
  }
  return grid;
}

function put(grid, x, y, value) {
  gridPut(grid, x, y, value);
}

function box(grid, x, y, width, height, value) {
  gridBox(grid, x, y, width, height, value);
}

function line(grid, x1, y1, x2, y2, value) {
  gridLine(grid, x1, y1, x2, y2, value);
}

function thickLine(grid, x1, y1, x2, y2, value, horizontal=false) {
  line(grid, x1, y1, x2, y2, value);
  line(grid, x1+(horizontal ? 0 : 1), y1+(horizontal ? 1 : 0),
    x2+(horizontal ? 0 : 1), y2+(horizontal ? 1 : 0), value);
}

function enforceScreenRightShadow(grid) {
  // Right-facing art is derived from the left silhouette so equipment stays
  // registered. Undo only the mirrored hoodie checker, then restore the same
  // screen-right shadow transition used by every other direction.
  for (let y=18;y<22;y++) for (let x=12;x<14;x++) if (grid[y][x]===7) grid[y][x]=4;
  gridDither(grid,18,18,2,4,4,7,[4,7]);
  return grid;
}

function frontHead(grid) {
  const hair=1, skin=2, light=3, mouth=7;
  box(grid,11,2,3,1,hair); put(grid,12,1,hair);
  box(grid,16,2,5,1,hair); put(grid,19,1,hair); put(grid,21,3,hair);
  box(grid,9,3,13,2,hair); box(grid,8,5,16,4,hair);
  box(grid,9,6,14,7,skin); box(grid,10,12,12,2,skin);
  put(grid,8,8,skin); put(grid,23,9,skin);
  box(grid,9,6,4,2,hair); put(grid,14,6,hair); put(grid,20,6,hair);
  put(grid,11,8,hair); put(grid,12,8,hair);
  put(grid,19,9,hair); put(grid,20,9,hair);
  line(grid,15,8,14,11,light); put(grid,15,11,light); put(grid,16,11,skin);
  put(grid,11,10,light); put(grid,20,11,light);
  line(grid,13,12,17,13,mouth); put(grid,18,12,mouth);
  put(grid,12,13,hair); put(grid,20,13,hair);
  box(grid,14,14,5,2,skin); put(grid,13,14,hair);
  // v22 4.3 — the face keeps score: heavy brows, eye bags, hollow cheeks,
  // stubble on the chin. Mileage, not menace.
  put(grid,11,9,hair); put(grid,20,10,hair);
  put(grid,11,11,mouth); put(grid,20,12,mouth); put(grid,10,11,mouth);
  put(grid,14,14,mouth); put(grid,16,14,mouth); put(grid,18,14,mouth);
}

function backHead(grid) {
  const hair=1, skin=2, light=3;
  box(grid,11,2,4,1,hair); put(grid,12,1,hair);
  box(grid,17,2,5,1,hair); put(grid,20,1,hair);
  box(grid,9,3,14,3,hair); box(grid,8,6,16,7,hair);
  box(grid,10,7,12,5,skin);
  line(grid,9,6,13,11,hair); line(grid,22,5,19,12,hair);
  put(grid,15,7,light); put(grid,16,7,light);
  put(grid,12,10,hair); put(grid,18,11,hair); put(grid,20,9,hair);
  box(grid,14,13,5,3,skin); put(grid,13,14,hair);
}

function sideHead(grid) {
  const hair=1, skin=2, light=3, mouth=7;
  box(grid,11,2,6,1,hair); put(grid,12,1,hair); put(grid,18,2,hair);
  box(grid,9,3,11,3,hair); box(grid,8,6,13,6,hair);
  box(grid,8,7,11,7,skin); box(grid,10,13,9,2,skin);
  box(grid,9,6,5,2,hair); line(grid,18,4,20,10,hair);
  put(grid,7,9,skin); put(grid,6,10,skin); put(grid,7,11,skin);
  put(grid,10,9,hair); put(grid,11,9,hair);
  put(grid,8,11,light); put(grid,9,12,light);
  line(grid,7,13,11,13,mouth); put(grid,12,12,mouth);
  put(grid,16,12,hair); put(grid,18,11,hair);
  box(grid,13,14,5,2,skin);
  // v22 4.3 — profile mileage: brow shelf, sunken cheek, chin stubble.
  put(grid,8,10,hair); put(grid,10,12,mouth);
  put(grid,14,14,mouth); put(grid,16,14,mouth);
}

function drawFrontTorso(grid, frame, back=false) {
  const skin=2, shirt=4, undershirt=5, pants=6, stain=7, dark=1;
  box(grid,9,15,13,2,shirt); box(grid,7,17,17,7,shirt);
  box(grid,9,23,13,2,shirt); put(grid,7,23,0); put(grid,23,24,shirt);
  if (back) {
    line(grid,15,16,15,23,undershirt); put(grid,16,18,undershirt);
    line(grid,10,20,13,20,stain); put(grid,20,17,dark);
    // v22 4.3 — shoulder-blade creases and a hem losing interest.
    put(grid,12,18,stain); put(grid,19,18,stain);
    put(grid,10,23,stain); put(grid,17,23,stain);
  } else {
    box(grid,14,16,5,2,undershirt); line(grid,16,18,15,23,undershirt);
    put(grid,11,19,stain); put(grid,12,20,stain); line(grid,20,20,21,22,dark);
    // v22 4.3 — collar shadow, a crease off the pocket, one shaded flank.
    put(grid,10,17,stain); put(grid,19,17,stain);
    line(grid,13,21,12,23,stain);
    put(grid,22,18,stain); put(grid,21,20,stain); put(grid,22,21,stain); put(grid,21,23,stain);
  }

  // A small, screen-right checker transition keeps one implied key direction
  // across the four gait frames without soft alpha or a ninth color.
  gridDither(grid,20,18,2,4,shirt,stain,[shirt,stain]);

  const leftHand = frame===1 ? [4,24] : frame===3 ? [7,18] : [5,22];
  const rightHand = frame===3 ? [27,24] : frame===1 ? [24,18] : [26,21];
  thickLine(grid,8,17,leftHand[0]+1,leftHand[1]-1,shirt);
  box(grid,leftHand[0],leftHand[1]-1,3,3,skin);
  thickLine(grid,22,17,rightHand[0]-1,rightHand[1]-1,shirt);
  box(grid,rightHand[0]-1,rightHand[1]-1,3,3,skin);
  put(grid,leftHand[0],leftHand[1]+1,lightForSkin(frame));
  put(grid,rightHand[0]+1,rightHand[1]+1,lightForSkin(frame+1));

  if (frame===0) {
    thickLine(grid,12,24,11,29,pants); thickLine(grid,19,24,19,29,pants);
    box(grid,9,29,6,2,dark); box(grid,18,29,5,2,dark);
    box(grid,8,31,7,1,dark); box(grid,18,31,6,1,dark);
  } else if (frame===1) {
    thickLine(grid,12,24,8,29,pants); thickLine(grid,19,24,20,29,pants);
    box(grid,6,29,7,2,dark); box(grid,19,29,5,2,dark);
    box(grid,5,31,8,1,dark); box(grid,19,31,6,1,dark);
  } else if (frame===2) {
    thickLine(grid,11,24,9,28,pants); thickLine(grid,19,24,22,28,pants);
    box(grid,7,28,6,3,dark); box(grid,20,28,6,3,dark);
    box(grid,6,31,7,1,dark); box(grid,20,31,7,1,dark);
    put(grid,8,25,shirt); put(grid,22,25,shirt);
  } else {
    thickLine(grid,12,24,12,29,pants); thickLine(grid,19,24,23,29,pants);
    box(grid,10,29,5,2,dark); box(grid,21,29,6,2,dark);
    box(grid,9,31,6,1,dark); box(grid,21,31,8,1,dark);
  }
  put(grid,11,27,stain); put(grid,20,26,dark);
  put(grid,12,25,stain); put(grid,19,25,stain);
}

function lightForSkin(seed) {
  return seed%2 ? 3 : 2;
}

function drawSideTorso(grid, frame) {
  const skin=2, shirt=4, undershirt=5, pants=6, stain=7, dark=1;
  box(grid,11,15,9,2,shirt); box(grid,9,17,13,7,shirt);
  box(grid,11,23,11,2,shirt); put(grid,9,23,0); put(grid,21,24,shirt);
  line(grid,17,16,18,23,undershirt); put(grid,13,20,stain); put(grid,14,21,stain);
  // v22 4.3 — the back of the hoodie falls into shade; the front creases.
  put(grid,20,18,stain); put(grid,19,21,stain); put(grid,20,22,stain);
  put(grid,12,17,stain); line(grid,12,20,11,22,stain); put(grid,11,23,stain);

  gridDither(grid,18,18,2,4,shirt,stain,[shirt,stain]);

  const frontHand = frame===1 ? [3,23] : frame===3 ? [8,18] : [5,21];
  const rearHand = frame===3 ? [23,24] : frame===1 ? [21,18] : [23,21];
  thickLine(grid,10,17,frontHand[0]+1,frontHand[1]-1,shirt);
  box(grid,frontHand[0],frontHand[1]-1,3,3,skin);
  thickLine(grid,20,17,rearHand[0]-1,rearHand[1]-1,shirt);
  box(grid,rearHand[0]-1,rearHand[1]-1,3,3,skin);

  if (frame===0) {
    thickLine(grid,13,24,12,29,pants); thickLine(grid,18,24,19,29,pants);
    box(grid,9,29,6,2,dark); box(grid,18,29,5,2,dark);
    box(grid,8,31,7,1,dark); box(grid,18,31,6,1,dark);
  } else if (frame===1) {
    thickLine(grid,13,24,7,29,pants); thickLine(grid,18,24,20,29,pants);
    box(grid,5,29,7,2,dark); box(grid,19,29,5,2,dark);
    box(grid,4,31,8,1,dark); box(grid,19,31,6,1,dark);
  } else if (frame===2) {
    thickLine(grid,13,24,10,28,pants); thickLine(grid,18,24,22,28,pants);
    box(grid,8,28,6,3,dark); box(grid,21,28,5,3,dark);
    box(grid,7,31,7,1,dark); box(grid,21,31,6,1,dark);
    put(grid,9,24,shirt);
  } else {
    thickLine(grid,13,24,14,29,pants); thickLine(grid,18,24,24,29,pants);
    box(grid,12,29,5,2,dark); box(grid,22,29,7,2,dark);
    box(grid,11,31,6,1,dark); box(grid,22,31,8,1,dark);
  }
  put(grid,12,27,stain); put(grid,19,26,dark);
  put(grid,13,25,stain); put(grid,18,25,stain);
}

function makePlayerFrame(direction, frame) {
  if (direction === 'right') return finish(enforceScreenRightShadow(mirrorGrid(makePlayerFrame('left',frame))),`player right frame ${frame}`);
  const grid=fresh();
  if (direction === 'down') {
    frontHead(grid); drawFrontTorso(grid,frame,false);
  } else if (direction === 'up') {
    backHead(grid); drawFrontTorso(grid,frame,true);
  } else if (direction === 'left') {
    sideHead(grid); drawSideTorso(grid,frame);
  } else {
    throw new Error(`unknown player direction: ${direction}`);
  }
  return finish(grid,`player ${direction} frame ${frame}`);
}

export function makePlayer32() {
  return {
    down:[0,1,2,3].map(frame=>makePlayerFrame('down',frame)),
    up:[0,1,2,3].map(frame=>makePlayerFrame('up',frame)),
    left:[0,1,2,3].map(frame=>makePlayerFrame('left',frame)),
    right:[0,1,2,3].map(frame=>makePlayerFrame('right',frame)),
  };
}

export function makePlayerAttack32(player, direction, phase) {
  const grid=cloneGrid(player[direction][0]), skin=2, shirt=4;
  if (direction === 'left') {
    box(grid,1,16,10,11,0);
    if (phase) {
      thickLine(grid,11,17,3,13,shirt,true); box(grid,0,11,5,4,skin);
      put(grid,0,14,3); put(grid,4,11,3);
    } else {
      thickLine(grid,11,17,4,22,shirt); box(grid,1,20,5,4,skin);
      put(grid,1,23,3); put(grid,5,20,3);
    }
  } else if (direction === 'right') {
    return finish(enforceScreenRightShadow(mirrorGrid(makePlayerAttack32(player,'left',phase))),`player attack right ${phase}`);
  } else if (direction === 'down') {
    box(grid,4,16,7,10,0); box(grid,21,16,8,10,0);
    if (phase) {
      thickLine(grid,9,17,15,24,shirt); box(grid,14,23,5,4,skin);
      thickLine(grid,22,17,18,22,shirt); box(grid,17,21,4,4,skin);
    } else {
      thickLine(grid,9,17,12,24,shirt); box(grid,10,23,5,4,skin);
      thickLine(grid,22,17,19,22,shirt); box(grid,18,21,4,4,skin);
    }
  } else if (direction === 'up') {
    box(grid,4,16,7,10,0); box(grid,21,16,8,10,0);
    if (phase) {
      thickLine(grid,9,18,14,10,shirt); box(grid,13,8,5,4,skin);
      thickLine(grid,22,18,19,14,shirt); box(grid,18,12,4,4,skin);
    } else {
      thickLine(grid,9,18,11,12,shirt); box(grid,9,9,5,4,skin);
      thickLine(grid,22,18,19,14,shirt); box(grid,18,12,4,4,skin);
    }
  } else {
    throw new Error(`unknown attack direction: ${direction}`);
  }
  return finish(grid,`player attack ${direction} ${phase}`);
}

function gearFacing(direction) {
  return direction==='right' ? 'left' : direction;
}

export function makePlayerGear32(id, direction) {
  const facing=gearFacing(direction), grid=fresh(), side=facing==='left';
  const dark=1, yellow=2, brick=3, orange=4, cream=5, olive=6, pink=7;
  if (id === 'mesh_cap') {
    if (side) {
      box(grid,8,1,12,3,olive); line(grid,7,4,20,4,dark); box(grid,4,5,9,2,yellow);
      put(grid,11,2,dark); put(grid,14,2,dark); put(grid,17,2,dark); put(grid,19,5,olive);
    } else {
      box(grid,9,1,14,3,olive); line(grid,8,4,23,4,dark); box(grid,6,5,18,2,yellow);
      put(grid,12,2,dark); put(grid,16,2,dark); put(grid,20,2,dark); put(grid,22,5,olive);
    }
  } else if (id === 'ski_mask') {
    if (side) {
      box(grid,8,4,13,10,dark); box(grid,8,11,11,3,olive); box(grid,9,7,5,2,cream);
      put(grid,9,8,dark); box(grid,7,11,4,2,brick); put(grid,18,13,dark);
      put(grid,11,12,dark); put(grid,15,11,dark);
    } else {
      box(grid,8,4,16,10,dark); box(grid,9,11,14,3,olive);
      box(grid,10,7,5,2,cream); box(grid,18,8,4,2,cream); put(grid,11,8,dark); put(grid,20,9,dark);
      line(grid,13,12,18,13,brick);
      put(grid,10,12,dark); put(grid,15,11,dark); put(grid,20,12,dark);
    }
  } else if (id === 'helmet') {
    if (side) {
      box(grid,9,0,10,2,yellow); box(grid,7,2,14,3,orange); box(grid,4,5,18,2,yellow);
      line(grid,10,1,10,4,dark); line(grid,16,1,16,4,dark); put(grid,20,4,cream);
      put(grid,9,3,dark); put(grid,15,2,dark);
    } else {
      box(grid,10,0,11,2,yellow); box(grid,8,2,15,3,orange); box(grid,5,5,20,2,yellow);
      line(grid,11,1,11,4,dark); line(grid,19,1,19,4,dark); put(grid,23,4,cream);
      put(grid,10,3,dark); put(grid,17,2,dark);
    }
  } else if (id === 'cowboy') {
    if (side) {
      box(grid,10,0,8,2,brick); box(grid,8,2,12,3,orange); line(grid,4,5,23,5,brick);
      put(grid,8,1,orange); put(grid,19,4,dark); line(grid,11,3,17,3,yellow);
      put(grid,13,0,dark); put(grid,13,1,dark);
    } else {
      box(grid,11,0,10,2,brick); box(grid,8,2,15,3,orange); line(grid,3,5,27,5,brick);
      put(grid,9,1,orange); put(grid,22,4,dark); line(grid,11,3,20,3,yellow);
      put(grid,15,0,dark); put(grid,15,1,dark);
    }
  } else if (id === 'pigeon_crown') {
    if (side) {
      line(grid,7,4,21,4,yellow); box(grid,8,5,13,2,orange);
      line(grid,9,3,8,0,yellow); line(grid,14,3,15,0,yellow); line(grid,19,3,21,1,yellow);
      put(grid,15,1,pink); put(grid,20,2,cream);
    } else {
      line(grid,7,4,24,4,yellow); box(grid,8,5,16,2,orange);
      line(grid,9,3,8,0,yellow); line(grid,15,3,16,0,yellow); line(grid,22,3,24,0,yellow);
      put(grid,16,1,pink); put(grid,22,2,cream);
    }
  } else if (id === 'priest_collar') {
    if (side) {
      box(grid,11,14,9,3,dark); box(grid,12,14,3,2,cream); put(grid,18,16,olive);
    } else {
      box(grid,11,14,10,3,dark); box(grid,14,14,4,2,cream); put(grid,11,16,olive); put(grid,20,16,olive);
    }
  } else if (id === 'trench') {
    const x=side?9:7,w=side?14:18;
    box(grid,x,15,w,11,brick); box(grid,x+2,24,w-3,5,brick);
    line(grid,x+3,16,x+7,28,dark); line(grid,x+w-3,16,x+w-6,28,dark);
    line(grid,x+1,22,x+w-2,22,cream); put(grid,x+4,20,dark); put(grid,x+w-5,20,dark);
    put(grid,x+2,28,0); put(grid,x+w-3,28,0);
    // v22 4.3 — buckle, collar shadow, worn lapel edges, fraying hem.
    put(grid,x+Math.floor(w/2),22,yellow);
    line(grid,x+1,16,x+2,16,dark); line(grid,x+w-2,16,x+w-3,16,dark);
    put(grid,x+2,18,orange); put(grid,x+w-3,25,orange);
    put(grid,x+3,28,dark); put(grid,x+w-4,28,dark);
  } else if (id === 'windbreaker') {
    const x=side?9:7,w=side?14:18;
    box(grid,x,15,w,10,pink); line(grid,x+1,17,x+w-2,17,yellow);
    line(grid,x+Math.floor(w/2),16,x+Math.floor(w/2)-1,24,dark);
    box(grid,x+2,21,4,2,olive); box(grid,x+w-6,21,4,2,olive);
    put(grid,x+1,24,dark); put(grid,x+w-2,24,dark);
    // v22 4.3 — nylon crinkles; the fabric has opinions about being worn.
    put(grid,x+3,19,dark); put(grid,x+w-4,20,dark); put(grid,x+4,23,dark);
    line(grid,x+1,16,x+2,16,dark);
  } else if (id === 'bathrobe') {
    const x=side?9:7,w=side?14:18;
    box(grid,x,15,w,14,cream); line(grid,x+2,16,x+7,28,pink);
    line(grid,x+w-3,16,x+w-7,28,pink); box(grid,x,22,w,2,pink);
    line(grid,x+Math.floor(w/2),22,x+Math.floor(w/2),28,dark);
    put(grid,x+2,28,0); put(grid,x+w-3,28,0); put(grid,x+w-4,18,olive);
    // v22 4.3 — terry texture and a pocket that holds one former tissue.
    put(grid,x+3,18,pink); put(grid,x+w-4,19,pink); put(grid,x+4,25,pink); put(grid,x+w-5,26,pink);
    box(grid,x+2,24,3,2,pink); put(grid,x+3,24,dark);
  } else if (id === 'parka') {
    const x=side?8:6,w=side?16:20;
    box(grid,x,14,w,12,olive); box(grid,x+1,14,w-2,3,yellow);
    box(grid,x+2,17,w-4,2,dark); line(grid,x+Math.floor(w/2),17,x+Math.floor(w/2),25,orange);
    box(grid,x+1,23,5,3,brick); box(grid,x+w-6,23,5,3,brick);
    put(grid,x,19,yellow); put(grid,x+w-1,20,yellow); put(grid,x+2,26,olive);
    // v22 4.3 — clumped fur trim and a quilt seam. Insulation with a past.
    put(grid,x+3,15,dark); put(grid,x+7,14,dark); put(grid,x+w-5,15,dark);
    put(grid,x+3,21,dark); put(grid,x+7,21,dark); put(grid,x+w-6,21,dark);
  } else if (id === 'airpods') {
    if (side) {
      box(grid,5,8,2,4,cream); put(grid,4,8,dark); put(grid,6,12,cream);
    } else {
      box(grid,7,8,2,4,cream); put(grid,6,8,dark); put(grid,8,12,cream);
    }
  } else if (id === 'crocs') {
    const x=side?7:8;
    box(grid,x,29,8,3,brick); box(grid,x-1,31,8,1,brick);
    put(grid,x+2,30,dark); put(grid,x+5,30,dark); put(grid,x+7,29,0);
  } else if (id === 'walmart_sneak') {
    box(grid,7,29,8,3,cream); box(grid,18,29,7,3,cream);
    line(grid,8,30,13,30,dark); line(grid,19,30,23,30,dark);
    box(grid,6,31,10,1,dark); box(grid,18,31,9,1,dark);
    put(grid,10,29,yellow); put(grid,21,29,yellow);
  } else if (id === 'vibrams') {
    box(grid,7,29,8,3,orange); box(grid,18,29,7,3,orange);
    for(let x=6;x<11;x++) put(grid,x,31,x%2?yellow:orange);
    for(let x=23;x<28;x++) put(grid,x,31,x%2?yellow:orange);
    line(grid,9,29,13,29,dark); line(grid,19,29,23,29,dark);
  } else if (id === 'propane_torch') {
    const x=side?22:24;
    box(grid,x,18,5,11,orange); box(grid,x+1,19,3,8,brick);
    box(grid,x+1,15,3,4,dark); line(grid,x+2,15,x-1,12,dark);
    put(grid,x-2,11,yellow); put(grid,x-3,10,pink); put(grid,x+1,23,cream);
  } else if (id === 'crowbar') {
    // v22 wave 5.5 — municipal red bar, carried low in the tool hand; hooked
    // end up by the grip, flat pry foot at the ground. It says PROPERTY OF.
    const x=side?23:25;
    line(grid,x,17,x+2,28,brick); line(grid,x+1,17,x+3,28,brick);
    line(grid,x,17,x-3,14,brick); put(grid,x-3,15,brick); put(grid,x-4,15,dark);
    put(grid,x+2,29,dark); put(grid,x+3,29,dark);
    put(grid,x+1,20,cream); put(grid,x+2,24,dark);
  } else {
    throw new Error(`unknown player gear: ${id}`);
  }

  // Rear views expose straps, heels and coat seams instead of silently reusing the
  // front-facing layer. These marks are intentionally practical, not decorative.
  if (direction === 'up') {
    if (id === 'ski_mask') {
      box(grid,10,7,5,2,dark); box(grid,18,8,4,2,dark); line(grid,11,10,20,10,olive);
    } else if (['mesh_cap','helmet','cowboy','pigeon_crown'].includes(id)) {
      line(grid,11,3,20,3,dark); put(grid,15,4,cream); put(grid,16,4,cream);
    } else if (['trench','windbreaker','bathrobe','parka'].includes(id)) {
      line(grid,15,17,15,27,dark); put(grid,16,19,cream); put(grid,14,24,yellow);
    } else if (id === 'priest_collar') {
      box(grid,14,14,4,2,dark); put(grid,15,15,cream); put(grid,16,15,cream);
    } else if (id === 'airpods') {
      box(grid,7,8,2,4,0); box(grid,21,8,2,4,cream); put(grid,22,8,dark); put(grid,21,12,cream);
    } else if (id === 'crocs') {
      box(grid,8,29,8,3,0); box(grid,10,29,7,3,brick); line(grid,10,29,16,29,dark); put(grid,11,31,yellow);
    } else if (id === 'walmart_sneak') {
      line(grid,7,29,14,29,dark); line(grid,18,29,24,29,dark); put(grid,8,30,orange); put(grid,23,30,orange);
    } else if (id === 'vibrams') {
      box(grid,6,31,6,1,dark); box(grid,22,31,6,1,dark); put(grid,13,30,yellow); put(grid,20,30,yellow);
    } else if (id === 'propane_torch') {
      line(grid,9,17,25,23,dark); put(grid,16,20,cream); put(grid,17,20,cream);
    } else if (id === 'crowbar') {
      // rear: the bar rides across the back at a working angle, hook past the hip.
      line(grid,8,22,24,18,brick); line(grid,8,23,24,19,brick);
      put(grid,7,23,dark); put(grid,25,17,dark); put(grid,15,21,cream);
    }
  }
  if (side && id === 'walmart_sneak') {
    box(grid,18,29,9,3,0); box(grid,16,29,7,2,cream); box(grid,15,31,9,1,dark);
    box(grid,5,30,10,1,cream); box(grid,4,31,12,1,dark); line(grid,7,29,13,29,dark);
  } else if (side && id === 'vibrams') {
    box(grid,18,29,10,3,0); box(grid,16,29,7,2,orange); box(grid,15,31,9,1,dark);
    box(grid,5,30,10,1,orange); for(let x=4;x<10;x++) put(grid,x,31,x%2?yellow:orange);
  }
  const output=direction==='right' ? mirrorGrid(grid) : grid;
  return finish(output,`gear ${id} ${direction}`);
}

export function makeRoutePatch32(tier, direction) {
  if (!Number.isInteger(tier) || tier < 1 || tier > 4) throw new Error(`unknown route tier: ${tier}`);
  const facing=gearFacing(direction), grid=fresh(), side=facing==='left';
  const dark=1, yellow=2, orange=4, cream=5, pink=7;
  const pocketX=side?12:10;
  box(grid,pocketX,18,5,5,yellow); line(grid,pocketX,18,pocketX+4,18,dark);
  put(grid,pocketX+1,20,dark); put(grid,pocketX+3,21,orange);
  if (tier >= 2) {
    const x=side?18:19;
    box(grid,x,20,5,5,orange); line(grid,x+1,21,x+3,23,dark); put(grid,x+4,20,cream);
  }
  if (tier >= 3) {
    line(grid,side?9:7,24,side?18:16,24,pink);
    put(grid,side?10:8,23,cream); put(grid,side?15:13,25,yellow); put(grid,side?18:16,23,dark);
  }
  if (tier >= 4) {
    const x=side?20:22;
    box(grid,x,15,7,8,cream); box(grid,x+1,14,5,2,dark);
    line(grid,x+2,17,x+5,17,dark); line(grid,x+2,19,x+4,19,dark);
    put(grid,x+5,21,pink); put(grid,x+1,21,orange);
  }
  if (direction === 'up') {
    // Rear-facing patches show their stitching and the clipboard's blank back.
    line(grid,10,18,14,18,dark); put(grid,11,19,cream); put(grid,14,22,dark);
    if (tier >= 2) put(grid,21,21,cream);
    if (tier >= 4) { box(grid,23,17,4,4,cream); line(grid,23,21,26,21,dark); }
  }
  return finish(direction==='right'?mirrorGrid(grid):grid,`route patch ${tier} ${direction}`);
}

function handAndTip(direction, attack) {
  if (direction === 'left') return attack ? {hand:[4,18],tip:[0,13]} : {hand:[6,21],tip:[1,27]};
  if (direction === 'down') return attack ? {hand:[15,23],tip:[17,31]} : {hand:[25,20],tip:[27,31]};
  if (direction === 'up') return attack ? {hand:[15,10],tip:[16,0]} : {hand:[8,18],tip:[3,8]};
  throw new Error(`unknown weapon direction: ${direction}`);
}

function wheel(grid, centerX, centerY, radius, rim, hub) {
  for(let step=0; step<24; step++) {
    const angle=step*Math.PI/12;
    put(grid,Math.round(centerX+Math.cos(angle)*radius),Math.round(centerY+Math.sin(angle)*radius),rim);
  }
  line(grid,centerX-radius+1,centerY,centerX+radius-1,centerY,hub);
  line(grid,centerX,centerY-radius+1,centerX,centerY+radius-1,hub);
  put(grid,centerX,centerY,1);
}

export function makeWeaponLayer32(id, direction, attack) {
  if (direction === 'right') {
    return finish(mirrorGrid(makeWeaponLayer32(id,'left',attack)),`weapon ${id} right ${attack?1:0}`);
  }
  const grid=fresh(), {hand,tip}=handAndTip(direction,attack);
  const dark=1, yellow=2, brick=3, orange=4, cream=5, olive=6, pink=7;
  const shaft=value=>line(grid,hand[0],hand[1],tip[0],tip[1],value);
  if (id === 'fists') {
    const x=hand[0]-(direction==='left'?2:1), y=hand[1]-2;
    box(grid,x,y,6,5,cream); put(grid,x,y,dark); put(grid,x+2,y,dark); put(grid,x+4,y,dark);
    line(grid,x+1,y+4,x+5,y+4,yellow); put(grid,x+5,y+2,brick);
  } else if (id === 'pipe') {
    thickLine(grid,hand[0],hand[1],tip[0],tip[1],orange);
    put(grid,tip[0],tip[1],yellow); put(grid,tip[0]+1,tip[1],yellow);
    line(grid,hand[0]-1,hand[1]+1,hand[0]+2,hand[1]+1,dark);
  } else if (id === 'brick') {
    const x=tip[0]-(direction==='left'?0:2), y=tip[1]-2;
    line(grid,hand[0],hand[1],x+2,y+2,dark); box(grid,x,y,6,5,brick);
    line(grid,x,y+2,x+5,y+2,orange); put(grid,x+2,y+1,dark); put(grid,x+4,y+3,dark);
    put(grid,x+1,y+3,dark); put(grid,x+5,y,orange);
  } else if (id === 'cart_wheel') {
    line(grid,hand[0],hand[1],tip[0],tip[1],dark);
    wheel(grid,tip[0],tip[1],4,cream,olive);
  } else if (id === 'shoe') {
    shaft(dark); thickLine(grid,hand[0],hand[1],tip[0],tip[1],brick);
    const sx=tip[0]-(direction==='left'?0:3), sy=tip[1]-2;
    box(grid,sx,sy,7,4,brick); box(grid,sx-1,sy+3,9,2,dark);
    line(grid,sx+2,sy+1,sx+5,sy+1,cream);
    put(grid,sx+1,sy+2,dark); put(grid,sx+6,sy,dark);
  } else if (id === 'baguette') {
    thickLine(grid,hand[0],hand[1],tip[0],tip[1],cream);
    const dx=Math.sign(tip[0]-hand[0]), dy=Math.sign(tip[1]-hand[1]);
    for(let i=3;i<10;i+=3) put(grid,hand[0]+dx*i,hand[1]+dy*i,yellow);
    put(grid,tip[0],tip[1],brick); put(grid,hand[0],hand[1],brick);
  } else if (id === 'microphone') {
    line(grid,hand[0],hand[1],tip[0],tip[1],dark);
    line(grid,hand[0]+1,hand[1],tip[0]+1,tip[1],dark);
    gridEllipse(grid,tip[0],tip[1],3,3,pink); put(grid,tip[0],tip[1],dark);
    put(grid,tip[0]-1,tip[1]-1,cream);
  } else if (id === 'knife') {
    line(grid,hand[0],hand[1],tip[0],tip[1],brick);
    line(grid,hand[0]+1,hand[1],tip[0],tip[1],brick);
    const midX=Math.round((hand[0]+tip[0])/2), midY=Math.round((hand[1]+tip[1])/2);
    line(grid,midX,midY,tip[0],tip[1],cream); put(grid,tip[0],tip[1],yellow);
    line(grid,midX-2,midY+1,midX+2,midY+1,dark);
  } else if (id === 'broken_bottle') {
    line(grid,hand[0],hand[1],tip[0],tip[1],pink);
    const neckX=Math.round((hand[0]+tip[0])/2), neckY=Math.round((hand[1]+tip[1])/2);
    box(grid,hand[0]-2,hand[1]-2,5,5,olive); box(grid,hand[0]-1,hand[1]-1,3,3,dark);
    put(grid,tip[0],tip[1],cream); put(grid,tip[0]+1,tip[1]-1,pink); put(grid,tip[0]-1,tip[1]+1,yellow);
    put(grid,neckX+1,neckY,pink);
  } else {
    throw new Error(`unknown weapon: ${id}`);
  }
  return finish(grid,`weapon ${id} ${direction} ${attack?1:0}`);
}

export function makeAttackSmear32(direction, phase) {
  const grid=fresh(), main=phase?4:2, hot=phase?5:7;
  const arc=(points,value)=>{
    for(let index=1; index<points.length; index++) {
      line(grid,points[index-1][0],points[index-1][1],points[index][0],points[index][1],value);
    }
  };
  if (direction === 'right') {
    arc(phase ? [[4,7],[13,5],[23,8],[31,15]] : [[9,10],[17,9],[25,13]],main);
    arc(phase ? [[6,13],[16,12],[27,17],[31,22]] : [[10,15],[18,15],[27,19]],main);
    put(grid,phase?29:25,phase?10:17,hot); put(grid,phase?30:26,phase?23:20,hot);
  } else if (direction === 'left') {
    return finish(mirrorGrid(makeAttackSmear32('right',phase)),`attack smear left ${phase}`);
  } else if (direction === 'down') {
    arc(phase ? [[7,5],[9,14],[14,23],[20,31]] : [[10,9],[12,17],[16,26]],main);
    arc(phase ? [[18,4],[20,13],[24,22],[27,31]] : [[18,10],[20,18],[23,27]],main);
    put(grid,phase?6:9,phase?18:14,hot); put(grid,phase?28:24,phase?25:28,hot);
  } else if (direction === 'up') {
    return finish(makeAttackSmear32('down',phase).slice().reverse(),`attack smear up ${phase}`);
  } else {
    throw new Error(`unknown smear direction: ${direction}`);
  }
  return finish(grid,`attack smear ${direction} ${phase}`);
}

function cartWheel(grid, centerX, centerY) {
  wheel(grid,centerX,centerY,3,1,4);
  put(grid,centerX-1,centerY-2,2); put(grid,centerX+2,centerY+1,2);
}

export function makeCartUnderlay32(direction) {
  if (direction === 'right') return finish(mirrorGrid(makeCartUnderlay32('left')),`cart right`);
  const grid=fresh(), dark=1, metal=2, shine=3, hub=4;
  if (direction === 'left') {
    line(grid,3,15,24,15,shine); line(grid,5,27,23,27,metal);
    line(grid,3,15,6,27,metal); line(grid,24,15,23,27,metal);
    for(let x=7;x<=21;x+=3) line(grid,x,17,x+1,25,metal);
    line(grid,5,20,23,20,shine); line(grid,6,24,23,24,shine);
    line(grid,3,15,0,11,shine); line(grid,0,11,2,9,dark);
    cartWheel(grid,7,29); cartWheel(grid,22,29);
    put(grid,11,18,hub); put(grid,18,22,hub);
  } else {
    const narrow=direction==='up';
    const left=narrow?8:5, right=narrow?24:27;
    line(grid,left,15,right,15,shine); line(grid,left+2,27,right-2,27,metal);
    line(grid,left,15,left+3,27,metal); line(grid,right,15,right-3,27,metal);
    for(let x=left+4;x<=right-4;x+=3) line(grid,x,17,x,25,metal);
    line(grid,left+1,20,right-1,20,shine); line(grid,left+2,24,right-2,24,shine);
    line(grid,right-2,15,right+2,11,shine); put(grid,right+2,10,dark);
    cartWheel(grid,left+4,29); cartWheel(grid,right-4,29);
    put(grid,16,18,hub); put(grid,13,23,hub); put(grid,20,23,hub);
  }
  return finish(grid,`cart ${direction}`);
}
