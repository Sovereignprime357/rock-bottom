/* Generated from frozen rock_bottom_v19.html.
 * Source seams: tile palettes and market stalls.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { BUILDINGS } from '../data/props.js';
import { state } from '../core/runtime_ui.js';
import { H, TERRAIN_REGIONS, TILE, W, WORLD, ZONES } from '../data/world.js';
import { ctx, visibleWorldRect } from './canvas_geography.js';
import { gridDither, parseGrid, rasterize } from './sprite_toolkit.js';

export const GRIME_LOGICAL_SIZE = 16;
export const GRIME_CACHE_SIZE = 32;
export const GRIME_CELL_SIZE = 192;
export const GRIME_WORLD_WIDTH = 8600;
export const GRIME_WORLD_HEIGHT = 5600;
export const GRIME_GRID_COLUMNS = Math.ceil(GRIME_WORLD_WIDTH / GRIME_CELL_SIZE);
export const GRIME_GRID_ROWS = Math.ceil(GRIME_WORLD_HEIGHT / GRIME_CELL_SIZE);
export const GRIME_CELL_COUNT = GRIME_GRID_COLUMNS * GRIME_GRID_ROWS;
export const GRIME_SPRITE_MARGIN = 32;
export const GRIME_MAX_VIEW_DRAWS = 90;

export const GRIME_STATIC_FAMILIES = Object.freeze([
  'trash_cluster', 'puddle', 'oil_slick', 'mildew_patch', 'wire_tangle', 'bent_needle',
  'spent_stub', 'glass_shards', 'can_cluster', 'rat_hole', 'paper_scraps', 'storm_grate',
]);

export const GRIME_LOOP_FRAME_COUNTS = Object.freeze({
  flies: 3,
  sign_buzz: 2,
  grate_steam: 4,
  drip: 3,
  wire_tremor: 4,
  tv_glow: 3,
});

export const GRIME_LOOP_INTERVALS = Object.freeze({
  flies: 180,
  sign_buzz: 260,
  grate_steam: 240,
  drip: 320,
  wire_tremor: 160,
  tv_glow: 300,
});

export const GRIME_LOOP_FAMILIES = Object.freeze(Object.keys(GRIME_LOOP_FRAME_COUNTS));

function freezeGrid(grid) {
  for (const row of grid) Object.freeze(row);
  return Object.freeze(grid);
}

function grimeGrid(rows, dither) {
  const grid = parseGrid(rows);
  if (dither) {
    gridDither(
      grid,
      dither.x, dither.y, dither.width, dither.height,
      dither.first, dither.second, dither.replace,
    );
  }
  return freezeGrid(grid);
}

function grimeArt(palette, rows, dither) {
  return Object.freeze({
    logicalSize: GRIME_LOGICAL_SIZE,
    palette: Object.freeze(palette),
    grid: grimeGrid(rows, dither),
  });
}

function grimeLoopArt(palette, frames) {
  const frozenFrames = frames.map(frame => grimeGrid(frame.rows, frame.dither));
  return Object.freeze({
    logicalSize: GRIME_LOGICAL_SIZE,
    palette: Object.freeze(palette),
    frames: Object.freeze(frozenFrames),
  });
}

// Sixteen-logical, palette-indexed ground debris. Every family owns an ordered
// checker witness in a material patch; the checker breaks flat fills without
// spraying alpha noise into the transparent silhouette.
export const GRIME_STATIC_ART = Object.freeze({
  trash_cluster: grimeArt(
    ['transparent','#0a0805','#211b12','#49341e','#70502b','#8a3a3a','#d4c896','#4a5028'],
    [
      '................','................','.....222........','....23332.......',
      '...233333..44...','...233333.4554..','..123333214554..','..122332214444..',
      '...122221..44...','....1111........','....6..66.......','...66..66.......',
      '..........77....','.........777....','................','................',
    ],
    {x:4,y:3,width:5,height:5,first:2,second:3,replace:[2,3]},
  ),
  puddle: grimeArt(
    ['transparent','#0a0805','#202a27','#34413d','#58615a','#74505e','#d4c896','#4a5028'],
    [
      '................','................','................','................',
      '................','......222.......','....22333222....','...2333333332...',
      '..233333333332..','..233344333332..','...2333333332...','....22333322....',
      '......2222......','................','................','................',
    ],
    {x:4,y:7,width:8,height:4,first:2,second:3,replace:[2,3]},
  ),
  oil_slick: grimeArt(
    ['transparent','#080604','#171312','#2c2225','#4d3542','#6b4930','#d4c896','#4a5028'],
    [
      '................','................','................','................',
      '.......22.......','.....223322.....','....23333332....','...2333443322...',
      '..233344443332..','...2333444332...','....23333332....','.....223322.....',
      '.......22.......','................','................','................',
    ],
    {x:5,y:6,width:7,height:5,first:3,second:4,replace:[3,4]},
  ),
  mildew_patch: grimeArt(
    ['transparent','#0a0805','#1d2115','#303b20','#4a5028','#6a6438','#b39d60','#604020'],
    [
      '................','................','....22..........','...2332....22...',
      '..233332..2332..','..233333223332..','...2333333332...','....23333332....',
      '..22.233332.....','.233223332......','..2333322.......','...2332.........',
      '....22..........','................','................','................',
    ],
    {x:3,y:4,width:9,height:6,first:2,second:3,replace:[2,3]},
  ),
  wire_tangle: grimeArt(
    ['transparent','#0a0805','#26211c','#4b4032','#765d3a','#8a3a3a','#c08a43','#4a5028'],
    [
      '................','................','................','....222222......',
      '...23333332.....','..233....332....','..23..444.32....','..23.4334.32....',
      '..23.4334.32....','..23..444.32....','..233....332....','...23333332.....',
      '....222222.55...','...........555..','................','................',
    ],
    {x:5,y:6,width:4,height:4,first:3,second:4,replace:[3,4]},
  ),
  bent_needle: grimeArt(
    ['transparent','#0a0805','#2a2520','#5a5146','#8b7657','#8a3a3a','#d4c896','#4a5028'],
    [
      '................','................','................','................',
      '................','................','.............66.','............466.',
      '..111222333446..','..1122333444....','...11122255.....','..........55....',
      '................','................','................','................',
    ],
    {x:5,y:8,width:6,height:3,first:2,second:3,replace:[2,3]},
  ),
  spent_stub: grimeArt(
    ['transparent','#0a0805','#2b2118','#5a3b25','#8a5b35','#8a3a3a','#d4c896','#4a5028'],
    [
      '................','................','................','................',
      '................','................','...111111.......','..122223333344..',
      '..122223333344..','...111111.......','..........55....','.........555....',
      '................','................','................','................',
    ],
    {x:3,y:7,width:8,height:2,first:2,second:3,replace:[2,3]},
  ),
  glass_shards: grimeArt(
    ['transparent','#0a0805','#252b29','#4d5b55','#737b6b','#8a3a3a','#d4c896','#4a5028'],
    [
      '................','................','.......3........','......334.......',
      '.....3344.......','....33444...2...','...233444..233..','..2333444.2333..',
      '..233333..233...','...2333....22...','....22..433.....','.......4333.....',
      '......433.......','................','................','................',
    ],
    {x:5,y:5,width:4,height:4,first:3,second:4,replace:[3,4]},
  ),
  can_cluster: grimeArt(
    ['transparent','#0a0805','#292622','#51483a','#7d6748','#8a3a3a','#c7b77d','#4a5028'],
    [
      '................','................','................','...1111.........',
      '..122221..1111..','..123321.122221.','..123321.123321.','..123321.123321.',
      '..123321.123321.','..123321.123321.','..122221.123321.','...1111..122221.',
      '..........1111..','................','................','................',
    ],
    {x:3,y:5,width:3,height:6,first:2,second:3,replace:[2,3]},
  ),
  rat_hole: grimeArt(
    ['transparent','#080604','#17130f','#30271e','#59442e','#8a3a3a','#b89c63','#4a5028'],
    [
      '................','................','................','................',
      '......1111......','....11222211....','...1223333221...','..123333333321..',
      '..123333333321..','..123333333321..','..123333333321..','..122222222221..',
      '.11111111111111.','..44........44..','................','................',
    ],
    {x:4,y:6,width:8,height:5,first:2,second:3,replace:[2,3]},
  ),
  paper_scraps: grimeArt(
    ['transparent','#0a0805','#302a20','#65583f','#95845d','#8a3a3a','#d4c896','#4a5028'],
    [
      '................','................','..111111........','..1222231.......','..1233321.......',
      '..1233321..1111.','..1222221.122221','..111111..123321','......1111123321','.....12222122221',
      '.....12332111111','.....122221.....','.....111111.....','................','................','................',
    ],
    {x:3,y:3,width:4,height:4,first:2,second:3,replace:[2,3]},
  ),
  storm_grate: grimeArt(
    ['transparent','#080604','#1c1a16','#38342b','#615946','#8a3a3a','#b09b67','#4a5028'],
    [
      '................','................','................','..111111111111..',
      '.12222222222221.','.12333333333321.','.12323232323321.','.12323232323321.',
      '.12323232323321.','.12323232323321.','.12333333333321.','.12222222222221.',
      '..111111111111..','................','................','................',
    ],
    {x:3,y:5,width:10,height:6,first:2,second:3,replace:[2,3]},
  ),
});

const LOOP_PALETTES = Object.freeze({
  flies: Object.freeze(['transparent','#0a0805','#33251a','#655034','#8a3a3a','#d4c896']),
  sign_buzz: Object.freeze(['transparent','#0a0805','#342039','#663b68','#9c5b90','#d488d4','#d4c896']),
  grate_steam: Object.freeze(['transparent','#0a0805','#292b26','#52574d','#817e67','#b3a77c','#d4c896']),
  drip: Object.freeze(['transparent','#0a0805','#202825','#3b4943','#6b7162','#d4c896']),
  wire_tremor: Object.freeze(['transparent','#0a0805','#29231d','#59432f','#8a5a35','#d06030','#d4c896']),
  tv_glow: Object.freeze(['transparent','#0a0805','#28251f','#50452f','#796438','#a18143','#d4c896','#4a5028']),
});

export const GRIME_LOOP_ART = Object.freeze({
  flies: grimeLoopArt(LOOP_PALETTES.flies, [
    {rows:[
      '................','................','...1............','....1...........','...........1....','..........1.....',
      '................','.......22.......','......2222......','......2222......','.......22.......','................',
      '....1...........','...1............','................','................',
    ],dither:{x:7,y:8,width:2,height:2,first:2,second:3,replace:[2,3]}},
    {rows:[
      '................','................','....1...........','...1............','..........1.....','...........1....',
      '................','.......22.......','......2222......','......2222......','.......22.......','................',
      '.....1..........','....1...........','................','................',
    ],dither:{x:7,y:8,width:2,height:2,first:2,second:3,replace:[2,3]}},
    {rows:[
      '................','................','.....1..........','......1.........','.........1......','........1.......',
      '................','.......22.......','......2222......','......2222......','.......22.......','................',
      '...1............','....1...........','................','................',
    ],dither:{x:7,y:8,width:2,height:2,first:2,second:3,replace:[2,3]}},
  ]),
  sign_buzz: grimeLoopArt(LOOP_PALETTES.sign_buzz, [
    {rows:[
      '................','................','..111111111111..','.12222222222221.','.12333333333321.','.12344444444321.',
      '.12345544554321.','.12345544554321.','.12344444444321.','.12333333333321.','.12222222222221.',
      '..111111111111..','.......11.......','.......11.......','................','................',
    ],dither:{x:4,y:5,width:8,height:5,first:3,second:4,replace:[3,4]}},
    {rows:[
      '................','................','..111111111111..','.12222222222221.','.12333333333321.','.12334433443321.',
      '.12345544554321.','.12334433443321.','.12345544554321.','.12333333333321.','.12222222222221.',
      '..111111111111..','.......11.......','.......11.......','................','................',
    ],dither:{x:4,y:5,width:8,height:5,first:3,second:4,replace:[3,4]}},
  ]),
  grate_steam: grimeLoopArt(LOOP_PALETTES.grate_steam, [
    {rows:[
      '................','................','.......4........','......44........','......4.........','.......4........',
      '.......44.......','........4.......','................','................','................','..111111111111..',
      '.12232323232221.','.12323232323221.','..111111111111..','................',
    ],dither:{x:3,y:12,width:10,height:2,first:2,second:3,replace:[2,3]}},
    {rows:[
      '................','........4.......','.......44.......','.......4........','......4.........','......44........',
      '.......4........','.......44.......','................','................','................','..111111111111..',
      '.12232323232221.','.12323232323221.','..111111111111..','................',
    ],dither:{x:3,y:12,width:10,height:2,first:2,second:3,replace:[2,3]}},
    {rows:[
      '................','.......44.......','........4.......','.......4........','.......44.......','......4.........',
      '......44........','.......4........','................','................','................','..111111111111..',
      '.12232323232221.','.12323232323221.','..111111111111..','................',
    ],dither:{x:3,y:12,width:10,height:2,first:2,second:3,replace:[2,3]}},
    {rows:[
      '................','......4.........','......44........','.......4........','........4.......','.......44.......',
      '.......4........','......44........','................','................','................','..111111111111..',
      '.12232323232221.','.12323232323221.','..111111111111..','................',
    ],dither:{x:3,y:12,width:10,height:2,first:2,second:3,replace:[2,3]}},
  ]),
  drip: grimeLoopArt(LOOP_PALETTES.drip, [
    {rows:[
      '................','.......3........','.......3........','................','................','................',
      '................','................','................','................','................','......2222......',
      '.....222222.....','......2222......','................','................',
    ],dither:{x:6,y:11,width:4,height:3,first:2,second:3,replace:[2,3]}},
    {rows:[
      '................','................','.......3........','.......3........','.......3........','................',
      '................','................','................','................','................','......2222......',
      '.....222222.....','......2222......','................','................',
    ],dither:{x:6,y:11,width:4,height:3,first:2,second:3,replace:[2,3]}},
    {rows:[
      '................','................','................','................','.......3........','.......3........',
      '.......3........','................','................','................','.......4........','......2222......',
      '.....222222.....','......2222......','................','................',
    ],dither:{x:6,y:11,width:4,height:3,first:2,second:3,replace:[2,3]}},
  ]),
  wire_tremor: grimeLoopArt(LOOP_PALETTES.wire_tremor, [
    {rows:[
      '................','................','................','................','..22............','...2222.........',
      '......2222......','.........2222...','............22..','.........334....','........3344....','.........334....',
      '................','................','................','................',
    ],dither:{x:9,y:9,width:3,height:3,first:3,second:4,replace:[3,4]}},
    {rows:[
      '................','................','................','................','...22...........','..2222..........',
      '.....2222.......','........2222....','...........222..','.........334....','........3344....','.........334....',
      '................','................','................','................',
    ],dither:{x:9,y:9,width:3,height:3,first:3,second:4,replace:[3,4]}},
    {rows:[
      '................','................','................','................','..22............','....222.........',
      '.......222......','..........222...','............22..','.........334....','........3344....','.........334....',
      '................','................','................','................',
    ],dither:{x:9,y:9,width:3,height:3,first:3,second:4,replace:[3,4]}},
    {rows:[
      '................','................','................','................','...22...........','.....222........',
      '........222.....','..........222...','.............22.','.........334....','........3344....','.........334....',
      '................','................','................','................',
    ],dither:{x:9,y:9,width:3,height:3,first:3,second:4,replace:[3,4]}},
  ]),
  tv_glow: grimeLoopArt(LOOP_PALETTES.tv_glow, [
    {rows:[
      '................','................','....1......1....','.....1....1.....','...1111111111...','..122222222221..',
      '..123333333321..','..123454545321..','..123545454321..','..123454545321..','..123333333321..',
      '..122222222221..','...1111111111...','.....11..11.....','................','................',
    ],dither:{x:4,y:6,width:8,height:5,first:3,second:4,replace:[3,4]}},
    {rows:[
      '................','................','....1......1....','.....1....1.....','...1111111111...','..122222222221..',
      '..123333333321..','..123545454321..','..123454545321..','..123545454321..','..123333333321..',
      '..122222222221..','...1111111111...','.....11..11.....','................','................',
    ],dither:{x:4,y:6,width:8,height:5,first:3,second:4,replace:[3,4]}},
    {rows:[
      '................','................','....1......1....','.....1....1.....','...1111111111...','..122222222221..',
      '..123333333321..','..123445544321..','..123554455321..','..123445544321..','..123333333321..',
      '..122222222221..','...1111111111...','.....11..11.....','................','................',
    ],dither:{x:4,y:6,width:8,height:5,first:3,second:4,replace:[3,4]}},
  ]),
});

export let GRIME_STATIC_CACHE;
export let GRIME_LOOP_CACHE;
export let GRIME_CELLS;
export let GRIME_LAYOUT_METADATA;

export const GRIME_HASH_SALTS = Object.freeze({
  density: 0x45d9f3b,
  family: 0x9e3779b9,
  x: 0x7f4a7c15,
  y: 0x94d049bb,
  loopChance: 0x27d4eb2d,
  loopFamily: 0x165667b1,
  loopX: 0xd3a2646c,
  loopY: 0xfd7046c5,
  loopPhase: 0xb55a4f09,
  lane: 0x6c8e9cf5,
});

const GRIME_RASTER_OPTIONS = Object.freeze({logicalSize:GRIME_LOGICAL_SIZE,noOutline:true});
const GRIME_STATIC_SLOT_SALT = 0x85ebca6b;
const GRIME_VIEWPORT_WIDTH = 800;
const GRIME_VIEWPORT_HEIGHT = 600;

// Stable salted 32-bit avalanche over integer coordinates. drawGroundTile uses
// integer tile coordinates; grime placement uses integer coverage-cell coordinates.
export function tileCoordHash(tileX, tileY, salt=0) {
  let hash = (
    Math.imul(tileX | 0, 0x9e3779b1) ^
    Math.imul(tileY | 0, 0x85ebca6b) ^
    (salt | 0)
  ) >>> 0;
  hash ^= hash >>> 16;
  hash = Math.imul(hash, 0x7feb352d) >>> 0;
  hash ^= hash >>> 15;
  hash = Math.imul(hash, 0x846ca68b) >>> 0;
  hash ^= hash >>> 16;
  return hash >>> 0;
}

function gridSourceStats(grid, palette) {
  let painted = 0;
  let indexMask = 0;
  let hash = 0x811c9dc5;
  for (let y=0; y<grid.length; y++) for (let x=0; x<grid[y].length; x++) {
    const index = grid[y][x];
    if (index) painted++;
    indexMask |= 1 << index;
    hash ^= (index + 1 + x*17 + y*31) & 0xff;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return Object.freeze({
    width: grid[0].length,
    height: grid.length,
    painted,
    indexMask: indexMask >>> 0,
    gridHash: hash.toString(16).padStart(8,'0'),
    palette,
  });
}

function buildGrimeArtMetadata() {
  const statics = {};
  const loops = {};
  for (const family of GRIME_STATIC_FAMILIES) {
    const art = GRIME_STATIC_ART[family];
    statics[family] = gridSourceStats(art.grid, art.palette);
  }
  for (const family of GRIME_LOOP_FAMILIES) {
    const art = GRIME_LOOP_ART[family];
    const frames = art.frames.map(grid => gridSourceStats(grid, art.palette));
    loops[family] = Object.freeze({
      frameCount: frames.length,
      interval: GRIME_LOOP_INTERVALS[family],
      palette: art.palette,
      frames: Object.freeze(frames),
    });
  }
  return Object.freeze({
    logicalSize: GRIME_LOGICAL_SIZE,
    cacheSize: GRIME_CACHE_SIZE,
    statics: Object.freeze(statics),
    loops: Object.freeze(loops),
  });
}

export const GRIME_ART_METADATA = buildGrimeArtMetadata();

function layoutHashStep(hash, value) {
  hash ^= value >>> 0;
  return Math.imul(hash, 0x01000193) >>> 0;
}

function placementCoordinate(cellStart, cellExtent, col, row, salt) {
  const maxOffset = Math.max(0, cellExtent - GRIME_CACHE_SIZE);
  return cellStart + (tileCoordHash(col,row,salt) % (maxOffset + 1));
}

function placementLaneCoordinate(cellStart, cellExtent, col, row, salt, lane, laneCount) {
  const laneStart = Math.floor(cellExtent * lane / laneCount);
  const laneEnd = Math.floor(cellExtent * (lane + 1) / laneCount);
  const laneOffset = tileCoordHash(col,row,salt) % Math.max(1,laneEnd-laneStart-GRIME_CACHE_SIZE+1);
  return cellStart + laneStart + laneOffset;
}

function maxCandidateDraws(cells) {
  // An 800x600 viewport plus one 32px margin can touch at most 6x5 cells.
  const columns = Math.ceil((GRIME_VIEWPORT_WIDTH + GRIME_SPRITE_MARGIN*2) / GRIME_CELL_SIZE) + 1;
  const rows = Math.ceil((GRIME_VIEWPORT_HEIGHT + GRIME_SPRITE_MARGIN*2) / GRIME_CELL_SIZE) + 1;
  let maximum = 0;
  for (let startRow=0; startRow<GRIME_GRID_ROWS; startRow++) {
    const endRow = Math.min(GRIME_GRID_ROWS, startRow + rows);
    for (let startCol=0; startCol<GRIME_GRID_COLUMNS; startCol++) {
      const endCol = Math.min(GRIME_GRID_COLUMNS, startCol + columns);
      let count = 0;
      for (let row=startRow; row<endRow; row++) for (let col=startCol; col<endCol; col++) {
        const cell = cells[row*GRIME_GRID_COLUMNS+col];
        count += cell.statics.length + (cell.loop ? 1 : 0);
      }
      if (count > maximum) maximum = count;
    }
  }
  return Object.freeze({columns,rows,cells:columns*rows,draws:maximum});
}

export function buildGrimeLayout() {
  const cells = [];
  const staticFamilyCounts = {};
  const loopFamilyCounts = {};
  for (const family of GRIME_STATIC_FAMILIES) staticFamilyCounts[family] = 0;
  for (const family of GRIME_LOOP_FAMILIES) loopFamilyCounts[family] = 0;
  let staticCount = 0;
  let loopCount = 0;
  let layoutHash = 0x811c9dc5;

  for (let row=0; row<GRIME_GRID_ROWS; row++) for (let col=0; col<GRIME_GRID_COLUMNS; col++) {
    const cellX = col * GRIME_CELL_SIZE;
    const cellY = row * GRIME_CELL_SIZE;
    const width = Math.min(GRIME_CELL_SIZE, GRIME_WORLD_WIDTH-cellX);
    const height = Math.min(GRIME_CELL_SIZE, GRIME_WORLD_HEIGHT-cellY);
    const count = 2 + (tileCoordHash(col,row,GRIME_HASH_SALTS.density) % 4 === 0 ? 1 : 0);
    const hasLoop = tileCoordHash(col,row,GRIME_HASH_SALTS.loopChance) % 5 === 0;
    const recordCount = count + (hasLoop ? 1 : 0);
    const laneOffset = tileCoordHash(col,row,GRIME_HASH_SALTS.lane) % recordCount;
    const laneDirection = tileCoordHash(col,row,GRIME_HASH_SALTS.lane ^ 0xa5a5a5a5) & 1 ? 1 : -1;
    const statics = [];
    layoutHash = layoutHashStep(layoutHash,row);
    layoutHash = layoutHashStep(layoutHash,col);
    layoutHash = layoutHashStep(layoutHash,count);

    for (let slot=0; slot<count; slot++) {
      const slotSalt = Math.imul(slot+1,GRIME_STATIC_SLOT_SALT) >>> 0;
      const familyIndex = tileCoordHash(col,row,GRIME_HASH_SALTS.family ^ slotSalt) % GRIME_STATIC_FAMILIES.length;
      const family = GRIME_STATIC_FAMILIES[familyIndex];
      const lane = (laneOffset + laneDirection*slot + recordCount*2) % recordCount;
      const x = placementLaneCoordinate(cellX,width,col,row,GRIME_HASH_SALTS.x ^ slotSalt,lane,recordCount);
      const y = placementCoordinate(cellY,height,col,row,GRIME_HASH_SALTS.y ^ slotSalt);
      statics.push(Object.freeze({family,x,y}));
      staticFamilyCounts[family]++;
      staticCount++;
      layoutHash = layoutHashStep(layoutHash,familyIndex);
      layoutHash = layoutHashStep(layoutHash,x);
      layoutHash = layoutHashStep(layoutHash,y);
    }

    let loop = null;
    if (hasLoop) {
      const familyIndex = tileCoordHash(col,row,GRIME_HASH_SALTS.loopFamily) % GRIME_LOOP_FAMILIES.length;
      const family = GRIME_LOOP_FAMILIES[familyIndex];
      const lane = (laneOffset + laneDirection*count + recordCount*2) % recordCount;
      const x = placementLaneCoordinate(cellX,width,col,row,GRIME_HASH_SALTS.loopX,lane,recordCount);
      const y = placementCoordinate(cellY,height,col,row,GRIME_HASH_SALTS.loopY);
      const phase = tileCoordHash(col,row,GRIME_HASH_SALTS.loopPhase) % GRIME_LOOP_FRAME_COUNTS[family];
      loop = Object.freeze({
        family, x, y, phase,
        frameCount: GRIME_LOOP_FRAME_COUNTS[family],
        interval: GRIME_LOOP_INTERVALS[family],
      });
      loopFamilyCounts[family]++;
      loopCount++;
      layoutHash = layoutHashStep(layoutHash,familyIndex+GRIME_STATIC_FAMILIES.length);
      layoutHash = layoutHashStep(layoutHash,x);
      layoutHash = layoutHashStep(layoutHash,y);
      layoutHash = layoutHashStep(layoutHash,phase);
    }

    cells.push(Object.freeze({
      index: row*GRIME_GRID_COLUMNS+col,
      col, row, x:cellX, y:cellY, width, height,
      statics:Object.freeze(statics),
      loop,
    }));
  }

  const frozenCells = Object.freeze(cells);
  const candidateMaximum = maxCandidateDraws(frozenCells);
  if (frozenCells.length !== GRIME_CELL_COUNT || candidateMaximum.draws > GRIME_MAX_VIEW_DRAWS) {
    throw new Error(`invalid Phase 2 grime layout (${frozenCells.length} cells, ${candidateMaximum.draws} candidate draws)`);
  }
  const metadata = Object.freeze({
    worldWidth: GRIME_WORLD_WIDTH,
    worldHeight: GRIME_WORLD_HEIGHT,
    cellSize: GRIME_CELL_SIZE,
    columns: GRIME_GRID_COLUMNS,
    rows: GRIME_GRID_ROWS,
    cellCount: frozenCells.length,
    staticCount,
    loopCount,
    staticFamilyCounts: Object.freeze(staticFamilyCounts),
    loopFamilyCounts: Object.freeze(loopFamilyCounts),
    layoutHash: layoutHash.toString(16).padStart(8,'0'),
    spriteMargin: GRIME_SPRITE_MARGIN,
    drawBudget: GRIME_MAX_VIEW_DRAWS,
    maxCandidate: candidateMaximum,
    staticSources: GRIME_ART_METADATA.statics,
    loopSources: GRIME_ART_METADATA.loops,
    cells: frozenCells,
  });
  return Object.freeze({cells:frozenCells,metadata});
}

function buildGrimeCaches() {
  const statics = {};
  const loops = {};
  for (const family of GRIME_STATIC_FAMILIES) {
    const art = GRIME_STATIC_ART[family];
    statics[family] = rasterize(art.grid,art.palette,GRIME_RASTER_OPTIONS);
  }
  for (const family of GRIME_LOOP_FAMILIES) {
    const art = GRIME_LOOP_ART[family];
    const frames = art.frames.map(grid => rasterize(grid,art.palette,GRIME_RASTER_OPTIONS));
    loops[family] = Object.freeze(frames);
  }
  GRIME_STATIC_CACHE = Object.freeze(statics);
  GRIME_LOOP_CACHE = Object.freeze(loops);
}

export function grimeLoopFrameIndex(family, phase, visualNow) {
  const frameCount = GRIME_LOOP_FRAME_COUNTS[family];
  const interval = GRIME_LOOP_INTERVALS[family];
  if (!frameCount || !interval || !Number.isFinite(visualNow)) return 0;
  return (Math.floor(Math.max(0,visualNow)/interval) + (phase | 0)) % frameCount;
}

function grimeRecordVisible(record, left, top, right, bottom) {
  return record.x < right && record.x + GRIME_CACHE_SIZE > left &&
    record.y < bottom && record.y + GRIME_CACHE_SIZE > top;
}

function firstVisibleGrimeColumn(left) {
  return Math.max(0,Math.floor(left/GRIME_CELL_SIZE));
}

function lastVisibleGrimeColumn(right) {
  return Math.min(GRIME_GRID_COLUMNS-1,Math.floor((right-1)/GRIME_CELL_SIZE));
}

function firstVisibleGrimeRow(top) {
  return Math.max(0,Math.floor(top/GRIME_CELL_SIZE));
}

function lastVisibleGrimeRow(bottom) {
  return Math.min(GRIME_GRID_ROWS-1,Math.floor((bottom-1)/GRIME_CELL_SIZE));
}

export function grimeVisibleDrawCount(camX, camY) {
  if (!GRIME_CELLS) return 0;
  const left = camX-GRIME_SPRITE_MARGIN;
  const top = camY-GRIME_SPRITE_MARGIN;
  const right = camX+GRIME_VIEWPORT_WIDTH+GRIME_SPRITE_MARGIN;
  const bottom = camY+GRIME_VIEWPORT_HEIGHT+GRIME_SPRITE_MARGIN;
  const firstCol = firstVisibleGrimeColumn(left);
  const lastCol = lastVisibleGrimeColumn(right);
  const firstRow = firstVisibleGrimeRow(top);
  const lastRow = lastVisibleGrimeRow(bottom);
  if (firstCol > lastCol || firstRow > lastRow) return 0;
  let count = 0;
  for (let row=firstRow; row<=lastRow; row++) for (let col=firstCol; col<=lastCol; col++) {
    const cell = GRIME_CELLS[row*GRIME_GRID_COLUMNS+col];
    for (let i=0; i<cell.statics.length; i++) {
      if (grimeRecordVisible(cell.statics[i],left,top,right,bottom)) count++;
    }
    if (cell.loop && grimeRecordVisible(cell.loop,left,top,right,bottom)) count++;
  }
  return count;
}

export function drawFullMapGrime() {
  if (!GRIME_CELLS || !GRIME_STATIC_CACHE || !GRIME_LOOP_CACHE) return 0;
  const left = state.cam.x-GRIME_SPRITE_MARGIN;
  const top = state.cam.y-GRIME_SPRITE_MARGIN;
  const right = state.cam.x+W+GRIME_SPRITE_MARGIN;
  const bottom = state.cam.y+H+GRIME_SPRITE_MARGIN;
  const firstCol = firstVisibleGrimeColumn(left);
  const lastCol = lastVisibleGrimeColumn(right);
  const firstRow = firstVisibleGrimeRow(top);
  const lastRow = lastVisibleGrimeRow(bottom);
  if (firstCol > lastCol || firstRow > lastRow) return 0;
  let draws = 0;

  // Static pass owns the bottom of the Phase 2 layer.
  for (let row=firstRow; row<=lastRow; row++) for (let col=firstCol; col<=lastCol; col++) {
    const statics = GRIME_CELLS[row*GRIME_GRID_COLUMNS+col].statics;
    for (let i=0; i<statics.length; i++) {
      const stamp = statics[i];
      if (!grimeRecordVisible(stamp,left,top,right,bottom)) continue;
      ctx.drawImage(GRIME_STATIC_CACHE[stamp.family],stamp.x,stamp.y);
      draws++;
    }
  }

  // Secondary motion stays above every static stamp and uses visualNow alone.
  for (let row=firstRow; row<=lastRow; row++) for (let col=firstCol; col<=lastCol; col++) {
    const loop = GRIME_CELLS[row*GRIME_GRID_COLUMNS+col].loop;
    if (!loop || !grimeRecordVisible(loop,left,top,right,bottom)) continue;
    const frame = grimeLoopFrameIndex(loop.family,loop.phase,state.visualNow);
    ctx.drawImage(GRIME_LOOP_CACHE[loop.family][frame],loop.x,loop.y);
    draws++;
  }
  return draws;
}

export let TILE_PALETTES;

export function zoneAt(wx, wy) {
  for (const z of ZONES) {
    if (wx>=z.x && wx<z.x+z.w && wy>=z.y && wy<z.y+z.h) return z.id;
  }
  return 'default';
}

export function terrainAt(wx, wy) {
  const zid = zoneAt(wx, wy);
  if (zid !== 'default') return zid;
  for (const r of TERRAIN_REGIONS) {
    if (wx>=r.x && wx<r.x+r.w && wy>=r.y && wy<r.y+r.h) return r.palette;
  }
  return 'default';
}

export function drawGroundTile(x, y) {
  const cx = x + TILE/2, cy = y + TILE/2;
  const zid = terrainAt(cx, cy);
  const pal = TILE_PALETTES[zid] || TILE_PALETTES.default;
  const checker = ((x/TILE)+(y/TILE)) & 1;
  ctx.fillStyle = pal.base[checker];
  ctx.fillRect(x, y, TILE, TILE);
  // Salted integer-coordinate avalanche. World-pixel multiples formerly made
  // h % TILE equal zero, pinning several textures to every tile's left edge.
  const h = tileCoordHash(Math.floor(x/TILE),Math.floor(y/TILE),0xa341316c);
  // procedural grime patches
  if ((h % 97) < 12) {
    ctx.fillStyle = pal.grime;
    const gx = x + 6 + (h % 40);
    const gy = y + 8 + ((h>>>5) % 36);
    ctx.fillRect(gx, gy, 10 + ((h>>>3)%14), 6 + ((h>>>7)%10));
  }
  // crack lines
  if ((h % 89) < 6) {
    ctx.strokeStyle = pal.crack;
    ctx.lineWidth = 1;
    ctx.beginPath();
    const cx0 = x + (h%TILE);
    const cy0 = y + ((h>>>2)%TILE);
    ctx.moveTo(cx0, cy0);
    ctx.lineTo(cx0 + 8, cy0 + 4);
    ctx.lineTo(cx0 + 14, cy0 + 2);
    ctx.stroke();
  }
  // brick grout lines on marketplace
  if (pal.brick) {
    ctx.strokeStyle = 'rgba(40,20,10,.4)';
    ctx.lineWidth = 1;
    const off = (y / TILE) & 1 ? TILE/2 : 0;
    ctx.beginPath();
    for (let bx=0; bx<TILE; bx+=16) {
      ctx.moveTo(x+bx+off, y);
      ctx.lineTo(x+bx+off, y+TILE/2);
      ctx.moveTo(x+bx+off-8, y+TILE/2);
      ctx.lineTo(x+bx+off-8, y+TILE);
    }
    ctx.moveTo(x, y+TILE/2); ctx.lineTo(x+TILE, y+TILE/2);
    ctx.stroke();
  }
  // tile grid for laundromat
  if (pal.tile) {
    ctx.strokeStyle = 'rgba(40,60,90,.4)';
    ctx.lineWidth = 1;
    ctx.strokeRect(x+0.5, y+0.5, TILE-1, TILE-1);
    ctx.beginPath();
    ctx.moveTo(x+TILE/2, y); ctx.lineTo(x+TILE/2, y+TILE);
    ctx.moveTo(x, y+TILE/2); ctx.lineTo(x+TILE, y+TILE/2);
    ctx.stroke();
  }
  // weed clumps on the block
  if (pal.weed && (h % 211) < 8) {
    const wx = x + (h % TILE), wy = y + ((h>>>4) % TILE);
    ctx.fillStyle = '#2a3818';
    ctx.fillRect(wx, wy, 3, 4);
    ctx.fillStyle = '#3a5028';
    ctx.fillRect(wx+1, wy-1, 1, 2);
  }
  // v13 wave 6 — underpass: oil stains (black slick blobs) on top of the cracked concrete
  if (pal.oilstain && (h % 137) < 6) {
    const ox = x + 8 + (h % 36);
    const oy = y + 10 + ((h>>>2) % 30);
    ctx.fillStyle = 'rgba(8,6,4,.72)';
    ctx.beginPath();
    ctx.ellipse(ox, oy, 7 + ((h>>>3)%5), 4 + ((h>>>5)%3), 0, 0, Math.PI*2);
    ctx.fill();
    // iridescent rainbow sheen on top
    ctx.fillStyle = 'rgba(80,60,90,.25)';
    ctx.fillRect(ox-3, oy-1, 6, 1);
  }
  // v13 wave 6 — underpass: cracked-concrete bigger fracture lines
  if (pal.concrete && (h % 73) < 9) {
    ctx.strokeStyle = 'rgba(0,0,0,.55)';
    ctx.lineWidth = 1;
    const cx1 = x + (h%TILE), cy1 = y + ((h>>>4)%TILE);
    ctx.beginPath();
    ctx.moveTo(cx1, cy1);
    ctx.lineTo(cx1 + 16, cy1 + 6);
    ctx.lineTo(cx1 + 22, cy1 + 14);
    ctx.lineTo(cx1 + 12, cy1 + 22);
    ctx.stroke();
  }
  // v13 wave 6 — scrap yard: dirt mottling (warm clumps) reading as raked earth not pavement
  if (pal.dirt && (h % 53) < 14) {
    const dx = x + (h % TILE), dy = y + ((h>>>3) % TILE);
    ctx.fillStyle = 'rgba(100,60,28,.32)';
    ctx.fillRect(dx, dy, 4, 3);
    if ((h % 211) < 30) {
      ctx.fillStyle = 'rgba(60,40,20,.5)';
      ctx.fillRect(dx+1, dy+1, 2, 1);
    }
  }
  // puddles in alley
  if (pal.puddle && (h % 167) < 5) {
    const px2 = x + 10 + (h % 30);
    const py2 = y + 14 + ((h>>>3) % 24);
    ctx.fillStyle = 'rgba(40,55,70,.55)';
    ctx.beginPath();
    ctx.ellipse(px2, py2, 11, 5, 0, 0, Math.PI*2);
    ctx.fill();
    ctx.fillStyle = 'rgba(180,200,220,.18)';
    ctx.fillRect(px2-6, py2-1, 5, 1);
  }
  // v13 wave 8a — train yard: gravel ballast (small dark flecks)
  if (pal.gravel && (h % 41) < 18) {
    const gx = x + (h % TILE), gy = y + ((h>>>3) % TILE);
    ctx.fillStyle = 'rgba(0,0,0,.4)';
    ctx.fillRect(gx, gy, 2, 2);
    if ((h % 113) < 30) {
      ctx.fillStyle = 'rgba(120,100,80,.3)';
      ctx.fillRect(gx+1, gy+1, 1, 1);
    }
  }
  // v13 wave 8a — train yard: horizontal rail bands. each band is 4px tall every 48px on the tile.
  // we render the bands as part of the ground tile so it's free per-tile work.
  if (pal.tracks) {
    // two parallel rails per tile row, with crossties between
    const railY1 = y + 22;
    const railY2 = y + 40;
    // dark crosstie underneath (wood)
    ctx.fillStyle = 'rgba(40,28,16,.55)';
    for (let tx=0; tx<TILE; tx+=14) {
      ctx.fillRect(x+tx+2, railY1-3, 8, railY2-railY1+6);
    }
    // steel rails
    ctx.fillStyle = '#605c50';
    ctx.fillRect(x, railY1, TILE, 2);
    ctx.fillRect(x, railY2, TILE, 2);
    // shine highlight on the rail head
    ctx.fillStyle = 'rgba(180,170,150,.35)';
    ctx.fillRect(x, railY1, TILE, 1);
    ctx.fillRect(x, railY2, TILE, 1);
  }
  // v13 wave 8a — park: grass tufts + occasional dandelion
  if (pal.grass && (h % 31) < 14) {
    const gx = x + (h % TILE), gy = y + ((h>>>4) % TILE);
    ctx.fillStyle = '#3a6028';
    ctx.fillRect(gx, gy, 1, 3);
    ctx.fillRect(gx+1, gy-1, 1, 4);
    ctx.fillRect(gx-1, gy, 1, 2);
    if ((h % 211) < 9) {
      // dandelion head
      ctx.fillStyle = '#e8c040';
      ctx.fillRect(gx+1, gy-3, 2, 2);
    }
  }
  // v13 wave 8a — skid row: scattered trash flecks (cigarette butts, wrappers)
  if (pal.skidtrash && (h % 47) < 7) {
    const tx = x + (h % TILE), ty = y + ((h>>>3) % TILE);
    const flick = h & 1;
    ctx.fillStyle = flick ? '#5a4030' : '#a08868';
    ctx.fillRect(tx, ty, 3, 1);
    if ((h % 113) < 20) {
      ctx.fillStyle = '#d4c896';
      ctx.fillRect(tx+1, ty, 1, 1);
    }
  }
  // v13 wave 8a — old school: faint chalk smudges + hopscotch flecks
  if (pal.schoolyard && (h % 79) < 5) {
    const cx = x + (h % TILE), cy = y + ((h>>>2) % TILE);
    ctx.fillStyle = 'rgba(220,210,180,.25)';
    ctx.fillRect(cx, cy, 4, 1);
    ctx.fillRect(cx+1, cy+2, 2, 1);
  }
  // v14 — connective-region material accents.
  if (pal.deadgrass && (h % 43) < 10) {
    const gx = x + (h % TILE), gy = y + ((h>>>4) % TILE);
    ctx.fillStyle = '#5a5028';
    ctx.fillRect(gx, gy, 1, 4);
    ctx.fillRect(gx+2, gy+1, 1, 3);
    ctx.fillStyle = '#786438';
    ctx.fillRect(gx+1, gy, 1, 2);
  }
  if (pal.patch && (h % 101) < 8) {
    const px = x + 5 + (h % 28), py = y + 9 + ((h>>>3) % 28);
    ctx.fillStyle = 'rgba(8,7,5,.28)';
    ctx.fillRect(px, py, 18 + ((h>>>5)%16), 11 + ((h>>>7)%10));
    ctx.strokeStyle = 'rgba(94,78,54,.24)';
    ctx.strokeRect(px+.5, py+.5, 18 + ((h>>>5)%16), 11 + ((h>>>7)%10));
  }
  if (pal.wet && (h % 127) < 8) {
    const px = x + 10 + (h % 30), py = y + 12 + ((h>>>3) % 26);
    ctx.fillStyle = 'rgba(38,55,56,.5)';
    ctx.beginPath();
    ctx.ellipse(px, py, 13, 5, 0, 0, Math.PI*2);
    ctx.fill();
    ctx.fillStyle = 'rgba(168,180,166,.12)';
    ctx.fillRect(px-7, py-1, 7, 1);
  }
  if (pal.transit) {
    ctx.fillStyle = 'rgba(232,192,64,.12)';
    ctx.fillRect(x, y+TILE-5, TILE, 3);
  }
}

export function drawMarketStalls() {
  const z = ZONES.find(z=>z.id==='market');
  if (!z || !visibleWorldRect(z.x,z.y,z.w,z.h,48)) return;
  for (let i=0;i<4;i++) {
    const px = z.x + 80 + i*160;
    const py = z.y + 60;
    // base table
    ctx.fillStyle = '#3a2a1a';
    ctx.fillRect(px, py+10, 90, 22);
    ctx.fillStyle = '#5a4828';
    ctx.fillRect(px, py+10, 90, 6);
    // table legs
    ctx.fillStyle = '#1a1008';
    ctx.fillRect(px+2, py+30, 4, 8);
    ctx.fillRect(px+84, py+30, 4, 8);
    ctx.strokeStyle = '#1a1008';
    ctx.lineWidth = 1;
    ctx.strokeRect(px, py+10, 90, 22);
    // umbrella stripes
    const colors = [['#a8484a','#7a2a2c'],['#5a6028','#3a4018'],['#7a5028','#503018'],['#b8d040','#88a020']];
    const [base, dark] = colors[i];
    for (let s=0; s<13; s++) {
      ctx.fillStyle = (s & 1) ? base : dark;
      ctx.fillRect(px-8 + s*8.2, py-10, 8, 12);
    }
    // umbrella pole
    ctx.fillStyle = '#3a3020';
    ctx.fillRect(px+44, py+2, 2, 10);
    // wares on table
    ctx.fillStyle = ['#e8c040','#d488d4','#88c0ff','#d06030'][i];
    ctx.fillRect(px+18, py+14, 6, 6);
    ctx.fillRect(px+38, py+14, 6, 6);
    ctx.fillRect(px+58, py+14, 6, 6);
    ctx.fillStyle = ['#a08030','#8a5090','#5080a0','#a04020'][i];
    ctx.fillRect(px+18, py+18, 6, 2);
    ctx.fillRect(px+38, py+18, 6, 2);
    ctx.fillRect(px+58, py+18, 6, 2);
  }
}

export function init_tiles() {
  // ---------- Per-zone tile palettes (v10 visual overhaul) ----------
  TILE_PALETTES = {
    default:    { base:['#1a1810','#181610'], grime:'rgba(40,30,20,.55)', crack:'rgba(8,6,4,.4)' },
    block:      { base:['#22201a','#1f1d18'], grime:'rgba(80,60,30,.35)', crack:'rgba(0,0,0,.5)', weed:true },
    pawn:       { base:['#2a2818','#28261a'], grime:'rgba(60,50,30,.35)', crack:'rgba(8,6,4,.6)' },
    dealer:     { base:['#2a1a15','#241814'], grime:'rgba(140,40,30,.3)', crack:'rgba(0,0,0,.55)' },
    abandoned:  { base:['#1c1818','#181414'], grime:'rgba(80,30,30,.45)', crack:'rgba(0,0,0,.65)' },
    market:     { base:['#322a22','#2c241e'], grime:'rgba(168,80,30,.3)', crack:'rgba(0,0,0,.45)', brick:true },
    alley:      { base:['#161614','#131312'], grime:'rgba(20,60,80,.35)', crack:'rgba(0,0,0,.8)', puddle:true },
    church:     { base:['#262030','#221c2a'], grime:'rgba(80,60,100,.35)', crack:'rgba(0,0,0,.6)' },
    projects:   { base:['#1d1c20','#191820'], grime:'rgba(60,60,90,.3)', crack:'rgba(0,0,0,.6)' },
    // v13 wave 6 — underpass gets a heavier cracked-concrete palette: lighter base, oil stains, deeper cracks
    underpass:  { base:['#2a2a2d','#252528'], grime:'rgba(20,18,14,.55)', crack:'rgba(0,0,0,.85)', concrete:true, oilstain:true },
    laundromat: { base:['#3a3a48','#34344a'], grime:'rgba(120,160,200,.18)', crack:'rgba(0,0,0,.4)', tile:true },
    busstop:    { base:['#27251f','#23211c'], grime:'rgba(90,70,40,.32)', crack:'rgba(0,0,0,.58)', concrete:true, transit:true },
    // v13 wave 6 — scrap yard pushed warmer dirt brown so it reads as Yuri's home turf, not generic concrete
    scrap:      { base:['#3a2c1a','#322618'], grime:'rgba(120,60,30,.45)', crack:'rgba(50,30,15,.5)', dirt:true },
    // v14 draws coherent full-length rails in drawWorldFabric; the tile owns ballast only.
    trainyard:  { base:['#2c2a26','#26241f'], grime:'rgba(90,80,60,.4)', crack:'rgba(0,0,0,.55)', gravel:true },
    // v13 wave 8a — park gets a green grass palette + tufts/dandelions
    park:       { base:['#2e4a26','#28401f'], grime:'rgba(80,140,50,.18)', crack:'rgba(0,0,0,.25)', grass:true },
    // v13 wave 8a — skid row gets darker, oilier cracked asphalt than underpass + more trash flecks
    skidrow:    { base:['#1f1d18','#1b1915'], grime:'rgba(30,18,10,.55)', crack:'rgba(0,0,0,.85)', concrete:true, skidtrash:true },
    // v13 wave 8a — old school: weedy cracked playground concrete with chalk smudges
    oldschool:  { base:['#2a201c','#241a16'], grime:'rgba(120,70,40,.3)', crack:'rgba(0,0,0,.55)', schoolyard:true, weed:true },
    // v18 far-east materials. Tile geometry remains visual; declared STRUCTURES own collision.
    warehouse_row:{ base:['#292720','#25231e'], grime:'rgba(86,58,34,.42)', crack:'rgba(0,0,0,.76)', concrete:true, oilstain:true, patch:true },
    canal:        { base:['#252a27','#202522'], grime:'rgba(42,70,62,.42)', crack:'rgba(0,0,0,.72)', concrete:true, wet:true },
    the_lot:      { base:['#2b261d','#272219'], grime:'rgba(92,66,34,.38)', crack:'rgba(0,0,0,.66)', deadgrass:true, patch:true, weed:true },
    // v19 curb kingdoms. They are visually distinct but mechanically faction-neutral.
    blue_tarp_court:   { base:['#29333a','#252d33'], grime:'rgba(55,75,88,.42)', crack:'rgba(0,0,0,.72)', concrete:true, patch:true, wet:true },
    cart_cavalry_keep: { base:['#302c24','#29261f'], grime:'rgba(74,58,38,.48)', crack:'rgba(0,0,0,.78)', concrete:true, oilstain:true, skidtrash:true },
    copper_choir_yard: { base:['#39291e','#32241b'], grime:'rgba(130,68,35,.38)', crack:'rgba(54,28,14,.62)', dirt:true, oilstain:true, deadgrass:true },
    throne_ditch:      { base:['#292821','#24241f'], grime:'rgba(56,72,66,.48)', crack:'rgba(0,0,0,.8)', concrete:true, wet:true, deadgrass:true },
    // v14 outside-zone materials. They fill the connective world but never replace a zone palette.
    vacant:          { base:['#28231a','#242017'], grime:'rgba(96,66,34,.42)', crack:'rgba(0,0,0,.55)', dirt:true, deadgrass:true },
    service:         { base:['#211f1a','#1e1c18'], grime:'rgba(72,52,34,.42)', crack:'rgba(0,0,0,.72)', concrete:true, patch:true },
    drainage:        { base:['#201f1c','#1d1c19'], grime:'rgba(44,58,54,.45)', crack:'rgba(0,0,0,.78)', concrete:true, wet:true },
    rail_approach:   { base:['#302b22','#29251d'], grime:'rgba(95,70,42,.4)', crack:'rgba(0,0,0,.58)', gravel:true, deadgrass:true },
    dead_grass:      { base:['#292419','#252016'], grime:'rgba(95,76,38,.38)', crack:'rgba(0,0,0,.58)', dirt:true, deadgrass:true },
    school_outskirts:{ base:['#292019','#251b16'], grime:'rgba(100,64,36,.34)', crack:'rgba(0,0,0,.62)', schoolyard:true, deadgrass:true },
  };

  if (WORLD.w !== GRIME_WORLD_WIDTH || WORLD.h !== GRIME_WORLD_HEIGHT || W !== 800 || H !== 600) {
    throw new Error('Phase 2 grime coverage requires the ratified 8600x5600 world and 800x600 viewport');
  }
  buildGrimeCaches();
  const layout = buildGrimeLayout();
  GRIME_CELLS = layout.cells;
  GRIME_LAYOUT_METADATA = layout.metadata;
}
