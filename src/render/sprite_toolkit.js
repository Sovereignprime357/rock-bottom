const SUPPORTED_LOGICAL_SIZES = new Set([16, 32]);

function assertLogicalSize(logicalSize) {
  if (!SUPPORTED_LOGICAL_SIZES.has(logicalSize)) {
    throw new Error(`sprite logicalSize must be declared as 16 or 32 (received ${logicalSize})`);
  }
}

export function parseGrid(rows) {
  if (!Array.isArray(rows) || !rows.length) throw new Error('sprite grid needs at least one row');
  const width = rows[0].length;
  if (!width || rows.some(row => typeof row !== 'string' || row.length !== width)) {
    throw new Error('sprite grid string rows must have one explicit width');
  }
  return rows.map(row => row.split('').map(cell => {
    if (cell === '.') return 0;
    const index = Number.parseInt(cell, 10);
    if (!Number.isInteger(index)) throw new Error(`invalid palette cell ${JSON.stringify(cell)}`);
    return index;
  }));
}

export function applyVars(rows, vars) {
  return rows.map(row => {
    let output = row;
    for (const key in vars) output = output.split(key).join(vars[key]);
    return output;
  });
}

export function blankSpriteGrid(logicalSize) {
  assertLogicalSize(logicalSize);
  return Array.from({length:logicalSize}, () => Array(logicalSize).fill(0));
}

export function gridPut(grid, x, y, value) {
  if (Number.isInteger(y) && Number.isInteger(x) && grid[y] && x >= 0 && x < grid[y].length) {
    grid[y][x] = value;
  }
}

export function gridBox(grid, x, y, width, height, value) {
  for (let yy=y; yy<y+height; yy++) for (let xx=x; xx<x+width; xx++) gridPut(grid, xx, yy, value);
}

export function gridLine(grid, x1, y1, x2, y2, value) {
  const steps = Math.max(Math.abs(x2-x1), Math.abs(y2-y1));
  for (let step=0; step<=steps; step++) {
    const amount = step/(steps || 1);
    gridPut(grid, Math.round(x1+(x2-x1)*amount), Math.round(y1+(y2-y1)*amount), value);
  }
}

export function gridEllipse(grid, centerX, centerY, radiusX, radiusY, value) {
  if (radiusX <= 0 || radiusY <= 0) return;
  const minX=Math.floor(centerX-radiusX), maxX=Math.ceil(centerX+radiusX);
  const minY=Math.floor(centerY-radiusY), maxY=Math.ceil(centerY+radiusY);
  for (let y=minY; y<=maxY; y++) for (let x=minX; x<=maxX; x++) {
    const dx=(x-centerX)/radiusX, dy=(y-centerY)/radiusY;
    if (dx*dx+dy*dy <= 1) gridPut(grid,x,y,value);
  }
}

export function mirrorGrid(grid) {
  return grid.map(row => row.slice().reverse());
}

export function cloneGrid(grid) {
  return grid.map(row => row.slice());
}

export function anchorGridToBottom(grid) {
  const logicalSize = grid.length;
  assertLogicalSize(logicalSize);
  if (grid.some(row => !Array.isArray(row) || row.length !== logicalSize)) {
    throw new Error(`sprite grid must be ${logicalSize}x${logicalSize}`);
  }
  let bottom=-1;
  for (let y=0; y<logicalSize; y++) for (let x=0; x<logicalSize; x++) {
    if (grid[y][x]) bottom=Math.max(bottom,y);
  }
  if (bottom < 0 || bottom === logicalSize-1) return cloneGrid(grid);
  const output=blankSpriteGrid(logicalSize), shift=logicalSize-1-bottom;
  for (let y=0; y<logicalSize; y++) for (let x=0; x<logicalSize; x++) {
    if (grid[y][x]) gridPut(output,x,y+shift,grid[y][x]);
  }
  return output;
}

export function rasterize(grid, palette, options) {
  const logicalSize = options?.logicalSize;
  assertLogicalSize(logicalSize);
  if (!Array.isArray(grid) || grid.length !== logicalSize ||
      grid.some(row => !Array.isArray(row) || row.length !== logicalSize)) {
    throw new Error(`declared ${logicalSize}x${logicalSize} sprite received a mismatched grid`);
  }
  for (const row of grid) for (const index of row) {
    if (!Number.isInteger(index) || index < 0) throw new Error(`invalid palette index ${index}`);
    if (index && !palette[index]) throw new Error(`palette index ${index} is undeclared`);
  }

  const logical = document.createElement('canvas');
  logical.width=logicalSize;
  logical.height=logicalSize;
  const logicalContext=logical.getContext('2d');
  logicalContext.imageSmoothingEnabled=false;
  if (!options.noOutline) {
    logicalContext.fillStyle='rgba(0,0,0,.9)';
    for (let y=0; y<logicalSize; y++) for (let x=0; x<logicalSize; x++) {
      if (!grid[y][x]) continue;
      logicalContext.fillRect(x-1,y,1,1);
      logicalContext.fillRect(x+1,y,1,1);
      logicalContext.fillRect(x,y-1,1,1);
      logicalContext.fillRect(x,y+1,1,1);
    }
  }
  for (let y=0; y<logicalSize; y++) for (let x=0; x<logicalSize; x++) {
    const index=grid[y][x], color=palette[index];
    if (!index || !color || color === 'transparent') continue;
    logicalContext.fillStyle=color;
    logicalContext.fillRect(x,y,1,1);
  }

  const output=document.createElement('canvas');
  output.width=32;
  output.height=32;
  const outputContext=output.getContext('2d');
  outputContext.imageSmoothingEnabled=false;
  outputContext.drawImage(logical,0,0,32,32);
  return output;
}

export function assertSupportedLogicalSize(logicalSize) {
  assertLogicalSize(logicalSize);
  return logicalSize;
}
