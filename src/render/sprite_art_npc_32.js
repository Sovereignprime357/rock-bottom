import {
  blankSpriteGrid,
  cloneGrid,
  gridBox,
  gridDither,
  gridEllipse,
  gridLine,
  gridPut,
} from './sprite_toolkit.js';

const SIZE = 32;

function clearBox(grid, x, y, width, height) {
  gridBox(grid, x, y, width, height, 0);
}

function thickLine(grid, x1, y1, x2, y2, value, width=2) {
  gridLine(grid, x1, y1, x2, y2, value);
  if (width > 1) gridLine(grid, x1+1, y1, x2+1, y2, value);
}

function dots(grid, value, points) {
  for (const [x,y] of points) gridPut(grid,x,y,value);
}

function assertGrid32(grid, label) {
  if (!Array.isArray(grid) || grid.length !== SIZE ||
      grid.some(row => !Array.isArray(row) || row.length !== SIZE)) {
    throw new Error(`${label} must return one explicit 32x32 grid`);
  }
  return grid;
}

function colorsFor(opts) {
  return {
    dark: 1,
    hat: opts.hat ?? 1,
    skin: opts.skin ?? 3,
    shirt: opts.shirt ?? 4,
    pants: opts.pants ?? 6,
    accent: opts.accent ?? 5,
    coat: opts.shirt2 ?? opts.shirt ?? 4,
    accessory: opts.accColor ?? opts.accent ?? 5,
    boot: 6,
    // v22 wave 4.3 — per-identity ramp roles. shade is the fabric/skin shadow
    // step (defaults to outline dark); worn is a lighter lit/wear step, 0 = off.
    shade: opts.shade ?? 1,
    worn: opts.worn ?? 0,
  };
}

function drawHead(grid, opts, colors) {
  const y = opts.tall ? 0 : 2;
  const x = opts.thin ? 13 : 12;
  const width = opts.thin ? 7 : opts.wide ? 9 : 8;
  const {dark,hat,skin,shirt} = colors;

  // The head is deliberately angular and one pixel off-center. These people have
  // not agreed to pose for the municipal atlas.
  gridBox(grid,x+1,y+3,width-2,8,skin);
  gridBox(grid,x,y+5,width,5,skin);
  dots(grid,0,[[x,y+5],[x+width-1,y+9],[x+1,y+10]]);
  gridPut(grid,x-1,y+7,skin);
  gridPut(grid,x+width,y+6,skin);

  if (opts.hood) {
    gridBox(grid,x-2,y+1,width+4,4,hat);
    gridBox(grid,x-2,y+4,2,8,hat);
    gridBox(grid,x+width,y+4,2,7,hat);
    dots(grid,hat,[[x-1,y],[x+width,y+1],[x+2,y+1]]);
  } else if (opts.cap) {
    gridBox(grid,x-1,y,width+2,3,hat);
    gridBox(grid,x-2,y+2,width+6,2,hat);
    gridPut(grid,x+width+4,y+3,hat);
  } else if (opts.bald) {
    gridBox(grid,x+1,y+2,width-2,2,skin);
    dots(grid,hat,[[x+1,y+2],[x+width-2,y+2],[x+width-1,y+3]]);
  } else {
    gridBox(grid,x,y+1,width,4,hat);
    dots(grid,hat,[[x+1,y],[x+3,y+1],[x+width-1,y+2],[x-1,y+3]]);
    gridPut(grid,x+width-2,y+4,skin);
  }

  // Uneven eyes, a nose that chose a side, and either a line or a yell.
  gridPut(grid,x+2,y+6,dark);
  gridPut(grid,x+width-3,y+7,dark);
  gridPut(grid,x+Math.floor(width/2),y+8,dark);
  if (opts.yelling) {
    gridBox(grid,x+2,y+9,width-4,2,dark);
    gridPut(grid,x+3,y+9,skin);
  } else {
    gridLine(grid,x+3,y+10,x+width-3,y+10,dark);
    gridPut(grid,x+3,y+9,skin);
  }

  if (opts.beard) {
    gridBox(grid,x+1,y+9,width-2,3,hat);
    dots(grid,skin,[[x+2,y+9],[x+width-3,y+9]]);
    dots(grid,hat,[[x+2,y+12],[x+width-3,y+11],[x+4,y+12]]);
  }
  gridBox(grid,15,y+11,3,3,skin);
  gridPut(grid,18,y+12,shirt);

  // Faces carry their mileage: brow shadow under the hair/brim, one sunken
  // cheek, and the chin dropping shade onto the neck. Skipped where a beard
  // or a yell already owns those rows.
  const {shade} = colors;
  gridPut(grid,x+1,y+5,shade);
  gridPut(grid,x+width-2,y+5,shade);
  if (!opts.beard && !opts.yelling) gridPut(grid,x+width-2,y+9,shade);
  gridPut(grid,15,y+11,shade);
}

function drawTorso(grid, opts, frame, colors) {
  const {dark,skin,shirt,pants,accent,coat,boot} = colors;
  const top = opts.tall ? 11 : 13;
  const width = opts.thin ? 9 : opts.wide ? 17 : 13;
  const left = Math.floor(16-width/2);
  const right = left+width-1;
  const coats = opts.coats ?? 1;

  // Slumped shoulders and an uneven hem keep the shared body from reading as a
  // heroic paper doll even before an identity overlay arrives.
  gridBox(grid,left+2,top,width-3,2,shirt);
  gridBox(grid,left+1,top+2,width-1,9,shirt);
  gridBox(grid,left+2,top+11,width-3,2,shirt);
  gridPut(grid,left,top+3,shirt);
  gridPut(grid,right+1,top+4,shirt);
  gridPut(grid,left+2,top+12,0);
  gridPut(grid,right-1,top+12,0);

  if (coats >= 2) {
    gridBox(grid,left,top+2,3,10,coat);
    gridBox(grid,right-1,top+3,3,9,coat);
    gridLine(grid,left+3,top+1,15,top+8,coat);
    gridLine(grid,right-2,top+2,17,top+8,coat);
  }
  if (coats >= 3) {
    gridLine(grid,left-1,top+3,left+1,top+12,accent);
    gridLine(grid,right+2,top+4,right,top+12,accent);
    gridPut(grid,left-1,top+11,coat);
    gridPut(grid,right+2,top+12,coat);
  }

  // Arms counter-swing. Hands are deliberately at different heights.
  const leftHandY = frame === 1 ? top+12 : frame === 2 ? top+7 : top+10;
  const rightHandY = frame === 2 ? top+12 : frame === 1 ? top+7 : top+11;
  thickLine(grid,left+1,top+3,left-2,leftHandY,shirt);
  thickLine(grid,right,top+4,right+2,rightHandY,shirt);
  gridBox(grid,left-3,leftHandY,2,2,skin);
  gridBox(grid,right+2,rightHandY,2,2,skin);
  gridPut(grid,left-2,leftHandY+2,dark);
  gridPut(grid,right+3,rightHandY-1,dark);

  // Seams, missing button, and a repair that was accepted without inspection.
  gridLine(grid,16,top+2,16,top+11,dark);
  gridPut(grid,17,top+4,accent);
  gridPut(grid,15,top+7,dark);
  gridBox(grid,left+3,top+8,3,2,accent);
  gridPut(grid,left+4,top+8,shirt);

  // v22 wave 4.3 — the light has a side. Underarm shadow, a dithered shade
  // column down the right, hem wear, and an optional worn/lit step on the
  // left shoulder and flank. Single pixels: texture, not stripes.
  const {shade,worn} = colors;
  if (shade !== shirt) gridDither(grid,right-4,top+4,2,4,shirt,shade,[shirt,shade]);
  gridPut(grid,left+2,top+3,shade);
  gridPut(grid,right-2,top+4,shade);
  gridPut(grid,right-2,top+6,shade);
  gridPut(grid,right-3,top+9,shade);
  gridPut(grid,right-2,top+10,shade);
  gridPut(grid,left+4,top+11,shade);
  gridPut(grid,right-4,top+12,shade);
  if (worn) {
    gridPut(grid,left+3,top+2,worn);
    gridPut(grid,left+4,top+2,worn);
    gridPut(grid,left+2,top+5,worn);
    gridPut(grid,left+2,top+6,worn);
  }

  const hipY=25;
  gridBox(grid,12,hipY,9,3,pants);
  gridPut(grid,16,hipY+2,dark);
  gridPut(grid,13,hipY+1,shade);
  gridPut(grid,19,hipY+1,shade);
  if (frame === 0) {
    gridBox(grid,12,28,3,3,pants);
    gridBox(grid,18,28,3,3,pants);
    gridPut(grid,13,29,shade);
    gridPut(grid,19,29,shade);
    gridBox(grid,11,30,5,2,boot);
    gridBox(grid,18,30,5,2,boot);
  } else if (frame === 1) {
    thickLine(grid,14,27,10,30,pants,3);
    thickLine(grid,19,27,20,30,pants,2);
    gridBox(grid,8,30,6,2,boot);
    gridBox(grid,19,30,5,2,boot);
  } else {
    thickLine(grid,13,27,13,30,pants,2);
    thickLine(grid,19,27,23,30,pants,3);
    gridBox(grid,11,30,5,2,boot);
    gridBox(grid,21,30,6,2,boot);
  }
  gridPut(grid,frame === 1 ? 9 : 22,31,0);
}

function drawOptionAccessory(grid, opts, colors) {
  const {dark,accent,accessory,shirt} = colors;
  if (opts.accessory === 'cross') {
    gridLine(grid,16,15,16,21,accessory);
    gridLine(grid,13,18,19,18,accessory);
    gridPut(grid,16,22,dark);
  } else if (opts.accessory === 'kombucha') {
    gridBox(grid,23,18,3,7,accent);
    gridBox(grid,24,16,1,2,accessory);
    gridLine(grid,23,21,25,21,dark);
  } else if (opts.accessory === 'badge') {
    gridBox(grid,19,15,3,3,accessory);
    gridPut(grid,20,16,dark);
  } else if (opts.accessory === 'sash') {
    gridLine(grid,12,14,21,24,accessory);
    gridLine(grid,13,14,22,23,accessory);
    dots(grid,dark,[[15,17],[18,20],[20,22]]);
  } else if (opts.accessory === 'glasses') {
    gridBox(grid,13,8,3,3,accessory);
    gridBox(grid,18,8,3,3,accessory);
    gridLine(grid,16,9,18,9,accessory);
    gridPut(grid,14,9,dark);
    gridPut(grid,19,9,dark);
  }
  // One exposed shoulder seam keeps option-only variants from looking stamped.
  gridPut(grid,opts.thin ? 12 : 10,14,shirt);
}

function applySignature(id, grid, frame, opts, c) {
  const {dark,hat,skin,shirt,pants,accent,coat,accessory,boot,shade,worn} = c;
  switch (id) {
    case 'tony':
    case 'tony_coat_3':
    case 'tony_coat_2':
    case 'tony_coat_1':
    case 'tony_bare': { // Numbered coats read as separate, badly stacked garments.
      const layers = id === 'tony_bare' ? 0 : id === 'tony_coat_1' ? 1 : id === 'tony_coat_2' ? 2 : (opts.coats ?? 3);
      clearBox(grid,7,13,4,13); clearBox(grid,22,13,4,13);
      if (layers >= 1) { gridBox(grid,9,14,3,12,shirt); gridBox(grid,21,15,3,11,shirt); }
      if (layers >= 2) { gridLine(grid,8,15,8,27,coat); gridLine(grid,24,16,25,27,coat); }
      if (layers >= 3) { gridLine(grid,6,16,7,28,accent); gridLine(grid,26,17,27,28,accent); }
      gridLine(grid,12,14,16,23,dark); gridLine(grid,21,14,17,23,dark);
      dots(grid,accent,[[14,17],[19,18],[15,21],[18,22]]);
      if (!layers) { gridBox(grid,12,14,9,10,skin); gridLine(grid,16,15,16,23,dark); }
      // Each coat layer drops shade on the one beneath it. Depth, not decor.
      if (layers >= 1) dots(grid,shade,[[10,17],[10,22],[22,18],[22,23]]);
      if (layers >= 2) dots(grid,shade,[[9,16],[24,17]]);
      break;
    }
    case 'yuri': { // Bald crown, square beard, hubcap held like an invoice.
      clearBox(grid,12,2,9,3); gridBox(grid,13,4,7,2,skin);
      gridBox(grid,12,10,9,3,hat); dots(grid,skin,[[13,10],[19,10]]);
      gridEllipse(grid,26,21,4,4,accessory); gridEllipse(grid,26,21,2,2,dark); gridPut(grid,26,21,skin);
      thickLine(grid,21,17,24,20,skin); gridPut(grid,29,18,accessory);
      // Beard grain and a brow that has already decided about you.
      dots(grid,dark,[[14,11],[18,12],[16,11]]); dots(grid,shade,[[13,6],[19,6]]);
      break;
    }
    case 'pete': { // Apron, pocket, serving hatch residue and one hot-pocket unit.
      gridBox(grid,12,14,10,12,accessory); gridLine(grid,12,14,16,25,dark); gridLine(grid,21,14,17,25,dark);
      gridBox(grid,15,20,5,4,shirt); gridLine(grid,15,20,19,20,dark);
      gridBox(grid,25,18,6,4,coat); gridBox(grid,26,19,4,2,accent); gridPut(grid,30,18,dark);
      // Eleven minutes per weighing leaves marks: grease on the apron, a fold.
      dots(grid,shade,[[14,17],[19,19],[15,23],[18,24]]); gridLine(grid,17,15,17,19,shade);
      break;
    }
    case 'lurch': { // Seven feet of elbows, with the shoulders already apologizing.
      clearBox(grid,8,13,4,15); clearBox(grid,22,13,4,15);
      thickLine(grid,11,12,5,28,shirt,2); thickLine(grid,21,13,27,29,shirt,2);
      gridBox(grid,4,28,3,3,skin); gridBox(grid,27,29,3,2,skin);
      gridPut(grid,12,12,dark); gridPut(grid,21,13,dark);
      // Rim light so the dark mass reads as a person and not a doorway.
      gridLine(grid,13,13,13,17,worn); gridLine(grid,13,20,13,23,worn);
      dots(grid,worn,[[7,20],[25,19]]);
      break;
    }
    case 'sherri': { // Hard hair spikes and a phone already leaving the conversation.
      dots(grid,hat,[[10,1],[12,0],[15,1],[18,0],[21,2],[22,4]]);
      gridBox(grid,26,8,3,8,accessory); gridPut(grid,27,9,dark); thickLine(grid,22,15,26,13,skin);
      gridLine(grid,9,14,5,21,shirt); gridPut(grid,5,22,accent);
      // The phone lights one cheek; the other side stays hollow. Her narrow
      // coat gets a torn diagonal rather than the generic body's flat column.
      dots(grid,shade,[[12,6],[13,10],[20,9],[21,12],[20,16]]);
      gridLine(grid,12,17,10,23,shade);gridPut(grid,24,12,worn||accent);
      gridPut(grid,27,12,worn||accent);
      break;
    }
    case 'paulie': { // The face arrives before the rest of Paulie.
      clearBox(grid,10,2,13,12); gridBox(grid,10,3,13,10,skin);
      gridBox(grid,11,2,11,3,hat); gridBox(grid,12,6,3,3,dark); gridBox(grid,18,6,3,3,dark);
      gridPut(grid,13,7,skin); gridPut(grid,19,8,skin); gridLine(grid,15,10,20,10,dark);
      gridLine(grid,10,5,8,8,accent); gridLine(grid,22,4,24,9,accent); gridPut(grid,17,9,dark);
      // The face has topography now: brow furrow, eye bags, hollow cheeks.
      dots(grid,shade,[[14,5],[17,5],[13,9],[19,9],[21,11]]);
      gridLine(grid,11,11,12,12,shade);
      break;
    }
    case 'dave': { // Awake only by zoning: pillow, drool, one slipper, closed receipt eyes.
      gridLine(grid,13,8,15,8,dark); gridLine(grid,18,9,20,9,dark); gridPut(grid,19,12,accessory);
      gridBox(grid,7,15,5,7,coat); gridPut(grid,8,16,dark); gridPut(grid,7,21,0);
      clearBox(grid,19,30,5,2); gridBox(grid,19,30,4,2,accent); gridPut(grid,22,30,0);
      gridLine(grid,11,14,9,23,dark);
      // Slept-in shirt: two long rumples and knees gone pale from the bench.
      gridLine(grid,14,17,13,22,shade); gridLine(grid,18,16,19,21,shade);
      gridPut(grid,13,26,worn); gridPut(grid,19,27,worn);
      break;
    }
    case 'mom': { // Bottle, sensible tote, sensible shoes, no agreement among them.
      gridBox(grid,25,16,3,9,accent); gridBox(grid,26,14,1,2,accessory); gridLine(grid,25,20,27,20,dark);
      gridBox(grid,7,18,5,7,coat); gridLine(grid,8,18,10,15,dark); gridPut(grid,9,21,accent);
      gridBox(grid,10,30,6,2,boot); gridBox(grid,18,30,6,2,boot);
      break;
    }
    case 'priest': { // Collar, cross and a cassock hem that lost a vote.
      gridBox(grid,15,13,4,2,accessory); gridPut(grid,16,13,dark);
      gridLine(grid,16,17,16,23,accent); gridLine(grid,13,20,19,20,accent);
      gridBox(grid,11,23,11,6,shirt); dots(grid,0,[[11,28],[21,27],[16,28]]);
      break;
    }
    case 'priest_fallen': { // The collar is in a pocket. Everything else has come untucked.
      clearBox(grid,14,13,6,3); gridBox(grid,10,15,4,12,coat); gridBox(grid,20,14,4,13,coat);
      gridLine(grid,11,16,20,26,accent); gridLine(grid,21,16,12,25,dark);
      gridBox(grid,8,22,4,3,accessory); gridPut(grid,9,23,dark);
      dots(grid,hat,[[11,3],[21,4],[10,5]]); gridLine(grid,13,10,19,11,dark);
      break;
    }
    case 'conductor': { // Cap, ticket punch and an overworked timetable flap.
      gridBox(grid,10,1,12,4,hat); gridBox(grid,8,4,17,2,hat); gridBox(grid,14,2,3,2,accent);
      gridBox(grid,25,18,5,6,accessory); gridPut(grid,27,19,dark); gridPut(grid,29,22,dark);
      thickLine(grid,21,16,25,20,skin); gridBox(grid,8,17,4,7,coat);
      // Brim shadow and a coat crease from decades of the same lean.
      dots(grid,shade,[[11,6],[19,6]]); gridLine(grid,10,19,10,23,shade);
      break;
    }
    case 'larry': { // The yell gets its own architecture.
      clearBox(grid,13,10,8,4); gridBox(grid,12,9,10,5,dark); gridBox(grid,14,10,6,2,skin);
      thickLine(grid,10,16,3,9,shirt,3); thickLine(grid,22,17,29,8,shirt,3);
      gridBox(grid,1,7,4,4,skin); gridBox(grid,28,6,4,4,skin); dots(grid,dark,[[2,7],[30,7]]);
      // Deep-red shade: arm undersides, heaving chest, fists flushed at the edge.
      gridLine(grid,9,17,4,12,shade); gridLine(grid,23,18,28,11,shade);
      dots(grid,shade,[[14,12],[19,12],[2,10],[29,9],[14,19],[18,20]]);
      break;
    }
    case 'stripe': { // Hood aperture, severe stripe, suspicious soap package.
      gridBox(grid,11,5,11,8,hat); gridBox(grid,13,7,7,5,skin); dots(grid,dark,[[14,9],[19,10]]);
      thickLine(grid,10,14,22,26,accessory,2); gridLine(grid,9,15,21,27,dark);
      gridBox(grid,25,19,6,6,accent); gridBox(grid,26,20,4,3,accessory); gridPut(grid,28,22,dark);
      // Hood folds; the aperture is deeper than the face inside it.
      dots(grid,shade,[[12,6],[20,7],[13,11],[19,12]]);
      break;
    }
    case 'cop': { // Broad cap, gut, badge, baton, coffee; one boot remains administratively open.
      gridBox(grid,9,1,14,4,hat); gridBox(grid,7,4,19,2,hat); gridPut(grid,16,3,accessory);
      gridBox(grid,10,15,14,10,shirt); gridBox(grid,20,16,3,3,accessory); gridPut(grid,21,17,dark);
      gridLine(grid,26,17,29,27,dark); gridLine(grid,27,17,30,27,dark);
      gridBox(grid,5,19,4,5,coat); gridPut(grid,6,20,skin); clearBox(grid,20,31,3,1);
      // The gut has an underside and the shirt has a pocket seam.
      gridLine(grid,12,24,21,24,shade); dots(grid,shade,[[12,17],[12,18],[18,21]]);
      break;
    }
    case 'biggu': { // Tall AND big. The arms have their own commute.
      gridBox(grid,8,12,17,5,shirt); thickLine(grid,8,15,2,29,shirt,4); thickLine(grid,24,16,30,29,shirt,4);
      gridBox(grid,1,28,4,3,skin); gridBox(grid,29,28,3,3,skin); gridBox(grid,11,23,12,5,coat);
      dots(grid,dark,[[8,15],[24,17],[13,24],[21,26]]);
      // The slab gets a weather side: chest fold, arm undersides, hem shadow.
      gridLine(grid,9,16,20,14,shade); gridLine(grid,8,17,3,28,shade);
      gridLine(grid,26,18,29,27,shade); dots(grid,shade,[[13,27],[17,27],[21,27]]);
      gridLine(grid,10,13,14,13,worn);
      break;
    }
    case 'cubscout': { // Oversized pack and sash; the knees have filed a separate report.
      gridBox(grid,7,14,5,11,coat); gridPut(grid,6,17,coat); thickLine(grid,12,14,21,25,accessory,2);
      dots(grid,dark,[[14,17],[17,20],[20,23]]); gridBox(grid,24,18,4,5,accent);
      clearBox(grid,13,27,3,2); clearBox(grid,19,27,3,2); gridPut(grid,12,28,skin); gridPut(grid,22,28,skin);
      break;
    }
    case 'jogger': { // Headband, bent limbs, stopwatch and absolutely no grace.
      gridLine(grid,11,5,22,5,accent); gridPut(grid,21,4,accent);
      clearBox(grid,7,15,5,11); clearBox(grid,22,15,5,11);
      thickLine(grid,11,15,5,21,shirt,2); thickLine(grid,22,15,29,11,shirt,2);
      gridPut(grid,29,10,accessory); gridPut(grid,30,11,dark);
      if (frame === 0) { clearBox(grid,11,28,5,4); gridLine(grid,14,27,8,31,pants); }
      // Rib shadow and sweat-dark collar replace the old clean pastel read.
      gridLine(grid,13,15,12,21,shade);gridLine(grid,18,15,20,21,shade);
      dots(grid,shade,[[14,14],[15,15],[18,15],[19,16]]);
      gridPut(grid,7,22,dark);gridPut(grid,28,12,dark);
      break;
    }
    case 'busker': { // Crooked guitar body, two strings, empty case corner.
      gridLine(grid,10,14,24,28,hat); gridLine(grid,11,14,25,28,hat);
      gridEllipse(grid,22,22,5,6,accent); gridEllipse(grid,22,22,2,3,dark); gridPut(grid,22,22,skin);
      gridLine(grid,24,28,30,30,coat); gridLine(grid,25,29,31,31,coat);
      break;
    }
    case 'dogwalker': { // Leash resolves into a resentful little dog, not a loose pixel.
      gridLine(grid,21,19,29,25,dark); gridLine(grid,22,19,30,25,accessory);
      gridBox(grid,25,26,6,4,coat); gridBox(grid,28,24,3,3,coat); gridPut(grid,30,24,hat);
      gridPut(grid,31,26,dark); gridBox(grid,25,30,2,2,dark); gridBox(grid,29,30,2,2,dark);
      gridPut(grid,24,27,coat);
      // Paisley: one upright ear, pale muzzle, sweater seam and a tail with a
      // permanent administrative kink. Still tiny; no mascot face.
      gridPut(grid,29,23,hat);gridPut(grid,28,24,dark);gridPut(grid,31,25,accessory);
      gridLine(grid,25,27,29,27,shade);gridPut(grid,27,28,shade);
      gridLine(grid,24,27,22,25,coat);gridPut(grid,22,24,dark);
      break;
    }
    case 'vapelord': { // The device is enormous; the cloud is paperwork-shaped.
      gridBox(grid,24,17,3,8,accessory); gridPut(grid,25,16,dark); gridPut(grid,26,18,accent);
      gridLine(grid,22,13,25,16,skin); dots(grid,accent,[[23,9],[26,8],[28,6],[29,4],[25,5],[30,9],[27,11]]);
      gridLine(grid,11,14,8,25,hat); gridPut(grid,7,25,hat);
      break;
    }
    case 'mayorscousin': { // Too many lapels, two pins, loafers that disagree.
      gridLine(grid,11,14,16,22,coat); gridLine(grid,22,14,17,22,coat);
      gridBox(grid,12,15,3,3,accent); gridPut(grid,13,16,dark); gridPut(grid,20,16,accessory);
      gridBox(grid,8,18,4,8,coat); gridBox(grid,22,18,4,8,coat); gridPut(grid,22,31,0);
      // The jacket was pressed once, in a previous administration.
      dots(grid,shade,[[13,18],[20,18],[14,22],[19,23]]);
      gridLine(grid,13,23,15,23,shade); gridPut(grid,12,15,worn);
      break;
    }
    case 'phoneguy': { // Phone, face, cord, power bank: one continuous employment condition.
      gridBox(grid,22,5,5,11,accessory); gridBox(grid,23,6,3,7,dark); gridPut(grid,24,7,accent);
      thickLine(grid,20,14,23,13,skin); gridLine(grid,26,15,28,25,dark); gridLine(grid,28,25,24,27,dark);
      gridBox(grid,22,24,4,5,accent); gridPut(grid,23,25,dark);
      break;
    }
    case 'launderlady': { // Basket first, resident second.
      gridBox(grid,8,19,19,8,accessory); gridLine(grid,9,20,25,20,dark); gridLine(grid,10,23,25,23,dark);
      for (let x=11;x<25;x+=4) gridPut(grid,x,25,dark);
      dots(grid,accent,[[11,18],[15,17],[20,18],[24,17]]);
      break;
    }
    case 'metermaid': { // Ticket book and the meter she has begun carrying personally.
      gridBox(grid,23,16,6,8,accessory); gridLine(grid,24,18,27,18,dark); gridLine(grid,24,21,27,21,dark);
      gridLine(grid,7,17,5,30,dark); gridEllipse(grid,5,15,3,4,accent); gridPut(grid,5,15,dark);
      gridBox(grid,4,29,3,3,dark); gridPut(grid,17,16,accessory);
      break;
    }
    case 'foodtruck': { // Apron, order pad and a spatula used as a zoning instrument.
      gridBox(grid,12,15,10,11,accessory); gridLine(grid,13,15,16,25,dark); gridLine(grid,21,15,18,25,dark);
      gridBox(grid,15,20,5,4,accent); gridLine(grid,24,15,29,8,dark); gridBox(grid,28,6,3,5,accessory);
      gridPut(grid,30,6,dark);
      break;
    }
    case 'priestson': { // Sideways cap, borrowed collar, cassette player with one earbud.
      gridBox(grid,10,2,12,3,hat); gridBox(grid,8,4,9,2,hat); gridPut(grid,7,5,hat);
      gridBox(grid,15,13,4,2,accessory); gridBox(grid,23,19,5,5,accent); gridPut(grid,25,20,dark);
      gridLine(grid,24,19,22,10,dark); gridPut(grid,21,9,accessory);
      break;
    }
    case 'karaoke': { // Machine, microphone and its cable crossing the shoes.
      gridBox(grid,8,20,13,9,hat); gridBox(grid,10,22,9,3,accent); gridPut(grid,14,23,dark);
      gridBox(grid,25,11,3,5,accessory); gridLine(grid,24,16,21,20,dark);
      gridLine(grid,27,16,30,29,dark); gridLine(grid,30,29,23,31,dark);
      // Shirt creases above the machine; knobs and speaker holes on it.
      gridLine(grid,13,16,12,19,shade); gridPut(grid,19,15,shade);
      dots(grid,dark,[[10,27],[12,27],[16,27],[18,27]]);
      break;
    }
    case 'barb': { // Cardigan, hard purse, reading glasses kept below the eyes.
      gridBox(grid,9,14,16,12,shirt); gridLine(grid,16,14,16,26,dark); dots(grid,accent,[[15,17],[17,20],[15,23]]);
      gridBox(grid,24,19,7,7,accessory); gridLine(grid,25,19,28,16,dark); gridPut(grid,27,22,dark);
      gridLine(grid,13,11,20,11,accent);
      // Knit rows and a ribbed hem; the collar catches what light there is.
      for (let x=10;x<=22;x+=4){gridPut(grid,x,17,shade);gridPut(grid,x+2,21,shade);}
      dots(grid,shade,[[11,25],[15,25],[19,25],[23,25]]);
      gridLine(grid,12,14,15,14,worn);
      break;
    }
    case 'pinky': { // Long uneven braids and knees that bend in different jurisdictions.
      gridLine(grid,11,5,8,20,hat); gridLine(grid,21,5,25,22,hat); dots(grid,accent,[[8,20],[25,22],[9,18],[24,19]]);
      gridLine(grid,10,15,8,26,shirt); gridLine(grid,23,15,25,25,shirt);
      if (frame === 2) gridPut(grid,25,24,0);
      break;
    }
    case 'math': { // Crooked glasses and a board whose equation has become a floor plan.
      gridBox(grid,12,8,4,3,accessory); gridBox(grid,18,8,4,3,accessory); gridLine(grid,16,9,18,9,accessory);
      gridBox(grid,23,17,8,9,accent); gridLine(grid,24,20,29,20,dark); gridLine(grid,24,23,27,23,dark);
      dots(grid,dark,[[25,18],[28,22],[29,24]]);
      break;
    }
    case 'brendan': { // Junior cap, oversized radio, flashlight and uncertain authority.
      gridBox(grid,10,2,12,3,hat); gridBox(grid,9,4,16,2,hat); gridPut(grid,16,3,accessory);
      gridBox(grid,24,15,5,8,accent); gridPut(grid,25,16,dark); gridPut(grid,28,14,accessory);
      gridLine(grid,23,17,30,11,dark); gridPut(grid,30,10,accessory); gridBox(grid,18,15,3,3,accessory);
      break;
    }
    case 'train_hopper': { // Pack, bedroll, beard and a carabiner with no assignment.
      gridBox(grid,7,13,6,14,accent); gridBox(grid,6,15,2,9,accent); gridBox(grid,7,12,6,3,coat);
      gridLine(grid,8,13,11,25,dark); gridBox(grid,5,12,8,3,hat);
      gridLine(grid,23,16,27,26,accessory); gridPut(grid,28,27,accessory); gridPut(grid,27,28,dark);
      break;
    }
    case 'philosopher': { // Cane, enormous coat pockets and spectacles slightly below events.
      gridLine(grid,25,17,28,31,dark); gridPut(grid,27,31,dark); gridPut(grid,29,31,dark);
      gridBox(grid,9,18,5,6,accessory); gridBox(grid,20,18,5,6,accessory); gridPut(grid,11,20,dark);
      gridLine(grid,13,9,16,9,accent); gridLine(grid,18,10,21,10,accent); gridPut(grid,17,9,accent);
      // Wool folds catch light above the pockets and drop shade below them.
      dots(grid,worn,[[12,16],[12,20],[20,16],[21,22]]);
      dots(grid,shade,[[10,24],[22,24],[15,15]]);
      break;
    }
    case 'lease_guy': { // Clipboard on one side, unreasonable key ring on the other.
      gridBox(grid,22,15,8,11,accessory); gridLine(grid,24,17,28,17,dark); gridLine(grid,24,20,28,20,dark); gridLine(grid,24,23,27,23,dark);
      gridLine(grid,10,17,5,23,accent); gridEllipse(grid,4,24,3,3,accent); gridPut(grid,4,24,dark);
      dots(grid,accent,[[1,27],[4,29],[7,27],[2,22]]); gridLine(grid,2,24,6,28,dark);
      break;
    }
    case 'gutter_greg': { // Crooked hook plus the rubber duck entered as inventory.
      gridLine(grid,10,16,5,29,accessory); gridLine(grid,6,29,3,28,accessory); gridPut(grid,3,27,accessory);
      gridBox(grid,24,22,6,5,accent); gridBox(grid,26,20,3,3,accent); gridPut(grid,29,21,dark); gridPut(grid,30,24,boot);
      gridLine(grid,13,11,20,12,hat);
      break;
    }
    case 'blue_tarp_guard': { // A tarp worn as weather and job description.
      clearBox(grid,6,0,22,17); gridBox(grid,8,1,18,5,hat); gridLine(grid,5,6,29,6,hat);
      gridLine(grid,6,7,8,24,hat); gridLine(grid,28,7,25,24,hat); gridBox(grid,10,7,14,5,hat);
      gridBox(grid,13,8,8,5,skin); dots(grid,dark,[[15,10],[19,11]]); dots(grid,accent,[[8,4],[25,3],[6,7]]);
      // Tarps crease where weather won. Two folds and shade under the aperture.
      gridLine(grid,11,2,13,5,dark); gridLine(grid,22,1,20,5,dark);
      dots(grid,dark,[[12,13],[21,13]]);
      break;
    }
    case 'receipt_guard': { // Receipt sash and a loose end that keeps itemizing the pavement.
      thickLine(grid,9,13,23,28,hat,3); dots(grid,dark,[[13,17],[16,20],[19,23],[22,26]]);
      gridBox(grid,24,14,5,13,hat); gridLine(grid,25,17,28,17,dark); gridLine(grid,25,21,27,21,dark);
      gridLine(grid,27,27,30,31,hat); gridPut(grid,29,29,dark);
      break;
    }
    case 'wire_guard': { // Coils cross the body; the spool is treated as a sidearm.
      for (const y of [16,19,22,25]) { gridLine(grid,10,y,23,y,accessory); gridPut(grid,9,y-1,accessory); gridPut(grid,24,y+1,accessory); }
      gridEllipse(grid,27,20,4,5,accent); gridEllipse(grid,27,20,2,3,dark); gridPut(grid,27,20,skin);
      gridLine(grid,28,25,31,31,accessory);
      // The body behind the coils drops into shadow; the coils gain weight.
      dots(grid,dark,[[12,17],[18,18],[13,20],[17,23],[14,26]]);
      break;
    }
    case 'darryl_under_blue': { // The tarp is the silhouette. Darryl is a face-shaped exception.
      clearBox(grid,3,0,27,27); gridBox(grid,5,1,23,5,hat); gridLine(grid,2,6,31,6,hat);
      gridLine(grid,3,7,5,29,hat); gridLine(grid,30,7,27,30,hat); gridBox(grid,7,7,20,9,hat);
      gridBox(grid,12,9,10,6,skin); dots(grid,dark,[[14,11],[20,12],[17,14]]);
      gridLine(grid,7,16,26,16,accent); dots(grid,accent,[[5,4],[27,3],[3,8],[30,9]]);
      gridBox(grid,10,17,14,10,coat); gridPut(grid,11,26,0); gridPut(grid,23,25,0);
      // The roof plastic hangs in folds, not a sheet. Weather has a texture.
      gridLine(grid,8,2,10,14,dark); gridLine(grid,25,2,23,14,dark);
      dots(grid,dark,[[13,17],[20,18],[12,23],[21,24]]);
      break;
    }
    case 'general_receipt': { // Paper crown, epaulettes and a scroll with more rank than ink.
      clearBox(grid,8,0,18,6); gridLine(grid,10,4,14,0,hat); gridLine(grid,14,0,17,4,hat); gridLine(grid,17,4,21,0,hat); gridLine(grid,21,0,24,4,hat);
      gridLine(grid,9,5,25,5,hat); gridBox(grid,7,14,6,5,hat); gridBox(grid,22,14,6,5,hat);
      gridBox(grid,13,15,9,11,hat); dots(grid,dark,[[15,17],[19,17],[16,21],[20,23]]);
      gridBox(grid,27,18,4,13,hat); gridLine(grid,28,20,30,20,dark); gridLine(grid,28,24,30,24,dark); gridPut(grid,29,30,dark);
      break;
    }
    case 'bishop_wire': { // Wire mitre and a crozier bent into an antenna.
      clearBox(grid,10,0,13,6); gridLine(grid,12,5,16,0,accessory); gridLine(grid,16,0,21,5,accessory); gridLine(grid,13,5,20,5,accessory);
      gridPut(grid,16,1,accent); gridLine(grid,24,13,28,30,accessory); gridEllipse(grid,28,11,3,3,accessory); gridPut(grid,28,11,dark);
      for (const y of [17,21,25]) gridLine(grid,10,y,22,y,accessory);
      break;
    }
    case 'curb_emperor': { // Crown, lawn-chair struts, three coats and no elevation.
      clearBox(grid,8,0,18,6); gridLine(grid,9,5,9,1,hat); gridLine(grid,9,1,13,4,hat); gridLine(grid,13,4,16,0,hat);
      gridLine(grid,16,0,20,4,hat); gridLine(grid,20,4,24,1,hat); gridLine(grid,24,1,24,5,hat); gridLine(grid,9,5,24,5,hat);
      gridLine(grid,7,14,27,31,accessory); gridLine(grid,27,14,7,31,accessory); gridLine(grid,6,18,28,18,accessory);
      gridBox(grid,7,14,6,7,coat); gridBox(grid,22,14,6,7,coat); gridLine(grid,11,14,16,26,hat); gridLine(grid,23,14,18,26,hat);
      // Separate coat from chair: one shadowed lapel, one warm worn rim, and
      // a sagging seat band. The X remains lawn furniture, not texture noise.
      gridLine(grid,12,15,15,24,shade);gridLine(grid,21,15,18,24,worn||accent);
      gridLine(grid,10,26,23,26,dark);gridPut(grid,16,27,dark);
      gridDither(grid,17,18,3,3,hat,shade,[hat,shade]);
      break;
    }
    case 'price_guy': { // Brim, black coat and one tag. The face remains an accounting error.
      clearBox(grid,9,1,17,13); gridBox(grid,11,2,12,4,dark); gridBox(grid,7,6,20,3,dark); gridBox(grid,12,8,10,5,coat);
      dots(grid,accent,[[14,10],[20,11]]); gridBox(grid,9,13,16,15,dark); gridLine(grid,8,14,5,30,dark); gridLine(grid,25,14,29,30,dark);
      gridBox(grid,20,18,5,4,accessory); gridPut(grid,22,20,dark); gridLine(grid,22,18,24,16,accessory);
      // One-step edge light: the void gains a coat without gaining a face.
      gridLine(grid,10,14,7,29,worn); gridLine(grid,11,3,21,3,worn);
      dots(grid,worn,[[10,13],[24,15],[9,7],[25,7]]);
      break;
    }
    default:
      break;
  }
  return grid;
}

function makeFrame(opts, frame) {
  const grid=blankSpriteGrid(SIZE);
  const colors=colorsFor(opts);
  drawHead(grid,opts,colors);
  drawTorso(grid,opts,frame,colors);
  drawOptionAccessory(grid,opts,colors);
  applySignature(opts.signature || '',grid,frame,opts,colors);
  return assertGrid32(grid,opts.signature || 'npc');
}

export function makeNpc32(opts={}) {
  return [makeFrame(opts,0),makeFrame(opts,1),makeFrame(opts,2)];
}

export function makeSleepingDave32() {
  const makeFrame=(frame)=>{
    const grid=blankSpriteGrid(SIZE);
    // Pillow, horizontal body, bent knees, one slipper, breath and drool. Dave
    // occupies the same bottom-anchored square while declining verticality.
    gridBox(grid,3,22,8,7,2);
    gridPut(grid,4,21,2); gridPut(grid,10,23,0);
    gridBox(grid,9,21,8,7,5);
    gridBox(grid,16,23,10,6,6);
    gridLine(grid,22,23,28,27,6); gridLine(grid,25,25,30,29,6);
    gridBox(grid,27,28,5,3,7); gridPut(grid,31,28,0);
    gridBox(grid,9,18+(frame?1:0),8,5,3);
    gridBox(grid,10,17+(frame?1:0),6,2,2);
    gridLine(grid,11,20+(frame?1:0),13,20+(frame?1:0),1);
    gridLine(grid,14,21+(frame?1:0),16,21+(frame?1:0),1);
    gridPut(grid,17,22+(frame?1:0),7);
    gridBox(grid,7,28,19,3,4);
    dots(grid,1,[[9,29],[15,30],[21,29]]);
    gridPut(grid,frame ? 6 : 5,20,7);
    gridPut(grid,frame ? 5 : 6,19,7);
    gridPut(grid,3,31,2); gridPut(grid,29,31,7);
    // v22 4.3 — the blanket has folds and the pillow has been fought with.
    dots(grid,1,[[18,25],[21,26],[24,25],[11,23],[13,24]]);
    dots(grid,1,[[5,24],[7,25]]);
    return assertGrid32(grid,'dave_sleep');
  };
  return [makeFrame(0),makeFrame(1)].map(cloneGrid);
}
