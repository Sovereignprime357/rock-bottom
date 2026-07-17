import { BUILDINGS } from '../data/props.js';
import { LANDMARK_FACADES, WORLD } from '../data/world.js';

export const FLAT_STRUCTURE_REASONS = Object.freeze({
  painted_surface:'painted plane with no world footprint',
  unreachable_backdrop:'scenery outside player-reachable space behind a solid boundary',
});

export let STRUCTURES;

const NAV_CLEARANCE = 0;
const EPSILON = 1e-8;
const MAX_MOTION_STEP = 8;
const PATH_TARGET_TOLERANCE = 48;

const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
const overlaps=(a,b)=>a.x<b.x+b.w-EPSILON&&a.x+a.w>b.x+EPSILON
  &&a.y<b.y+b.h-EPSILON&&a.y+a.h>b.y+EPSILON;
const finite=value=>Number.isFinite(value);

export function init_physicality() {
  STRUCTURES=Object.freeze([...BUILDINGS,...LANDMARK_FACADES]);
}

export function structureDoorAccepts(rect,structure,probe=rect) {
  if(!structure.doorGap)return false;
  const southFace=structure.y+structure.h,bottom=probe.y+probe.h,centerX=probe.x+probe.w/2;
  return finite(bottom)&&finite(centerX)
    // Preserve the shipped BUILDINGS convention exactly: the moving body's
    // bottom edge owns the south-door test. Facades declare and paint the same
    // aperture instead of quietly redefining every legacy doorway.
    &&bottom>southFace-30&&bottom<southFace+30
    &&centerX>structure.x+structure.w/2-30&&centerX<structure.x+structure.w/2+30;
}

export function structureBlocksRect(rect,structure,probe=rect) {
  return structure.solid===true&&overlaps(rect,structure)&&!structureDoorAccepts(rect,structure,probe);
}

// This is deliberately the only iteration over STRUCTURES in the module. Every
// collision consumer reaches the same merged source through this visitor.
function visitSolidStructures(visitor) {
  if(!Array.isArray(STRUCTURES))throw new Error('STRUCTURES unavailable before init_physicality');
  for(const structure of STRUCTURES){
    if(structure.solid!==true)continue;
    const result=visitor(structure);
    if(result!==undefined)return result;
  }
  return undefined;
}

function solidStructures() {
  const result=[];
  visitSolidStructures(structure=>{result.push(structure);});
  return result;
}

function findSolidStructure(predicate) {
  return visitSolidStructures(structure=>predicate(structure)?structure:undefined)||null;
}

export function firstBlockingStructure(rect,probe=rect) {
  return findSolidStructure(structure=>structureBlocksRect(rect,structure,probe));
}

function bodyBounds(body) {
  if(!finite(body?.w)||!finite(body?.h)||body.w<=0||body.h<=0
    ||!finite(WORLD?.w)||!finite(WORLD?.h)||body.w>WORLD.w||body.h>WORLD.h)return null;
  return {maxX:WORLD.w-body.w,maxY:WORLD.h-body.h};
}

function resolveMotionStep(body,newX,newY) {
  const startX=body.x,startY=body.y,w=body.w,h=body.h;
  const fullProbe={x:newX,y:newY,w,h};
  const xRect={x:newX,y:startY,w,h},yRect={x:startX,y:newY,w,h};
  // The legacy x-axis loop tested its overlap at startY but evaluated the door
  // with the full target Y. Keep that boundary behavior while centralizing it.
  let blockerX=firstBlockingStructure(xRect,fullProbe),blockerY=firstBlockingStructure(yRect);
  let resolvedX=blockerX?startX:newX,resolvedY=blockerY?startY:newY;
  let cornerBlocker=firstBlockingStructure({x:resolvedX,y:resolvedY,w,h});
  if(cornerBlocker&&!blockerX&&!blockerY){
    // Both axis-only probes can be clear while their combined diagonal clips a
    // corner. Keep one known-clear axis and deterministically reject the other.
    if(Math.abs(newX-startX)>=Math.abs(newY-startY)){blockerX=cornerBlocker;resolvedX=startX;}
    else{blockerY=cornerBlocker;resolvedY=startY;}
    cornerBlocker=firstBlockingStructure({x:resolvedX,y:resolvedY,w,h});
  }
  // This is defensive for overlapping solids: if a future geometry combination
  // invalidates the chosen slide, reject both axes rather than return penetration.
  if(cornerBlocker){
    resolvedX=startX;resolvedY=startY;
    if(!blockerX)blockerX=cornerBlocker;
    if(!blockerY)blockerY=cornerBlocker;
  }
  return {x:resolvedX,y:resolvedY,blockedX:!!blockerX,blockedY:!!blockerY,
    blocker:blockerX||blockerY||cornerBlocker||null};
}

export function resolveStructureMotion(body,newX,newY,stopOnBlock=false) {
  const bounds=bodyBounds(body),startX=body?.x,startY=body?.y;
  if(!bounds||!finite(startX)||!finite(startY)){
    return {x:startX,y:startY,blockedX:true,blockedY:true,blocked:true,blocker:null,failed:true};
  }
  const requestedX=finite(newX)?newX:startX,requestedY=finite(newY)?newY:startY;
  const targetX=clamp(requestedX,0,bounds.maxX),targetY=clamp(requestedY,0,bounds.maxY);
  const dx=targetX-startX,dy=targetY-startY;
  const steps=Math.max(1,Math.ceil(Math.max(Math.abs(dx),Math.abs(dy))/MAX_MOTION_STEP));
  const stepX=dx/steps,stepY=dy/steps;
  let x=startX,y=startY,blockedX=targetX!==requestedX,blockedY=targetY!==requestedY,blocker=null;
  for(let step=0;step<steps;step++){
    const result=resolveMotionStep({x,y,w:body.w,h:body.h},x+stepX,y+stepY);
    if(stopOnBlock&&(result.blockedX||result.blockedY)){
      blockedX=blockedX||result.blockedX;blockedY=blockedY||result.blockedY;
      if(!blocker&&result.blocker)blocker=result.blocker;
      break;
    }
    x=result.x;y=result.y;
    blockedX=blockedX||result.blockedX;blockedY=blockedY||result.blockedY;
    if(!blocker&&result.blocker)blocker=result.blocker;
  }
  return {x,y,blockedX,blockedY,blocked:blockedX||blockedY,blocker};
}

export function moveBodyAgainstStructures(body,newX,newY,stopOnBlock=false) {
  const result=resolveStructureMotion(body,newX,newY,stopOnBlock);
  if(finite(result.x)&&finite(result.y)){body.x=result.x;body.y=result.y;}
  return result;
}

function candidateKey(x,y) {
  return `${Math.round(x/EPSILON)*EPSILON},${Math.round(y/EPSILON)*EPSILON}`;
}

export function ensureClearPlacement(body) {
  const bounds=bodyBounds(body),origin={x:body?.x,y:body?.y};
  if(!bounds)return {moved:false,x:body?.x,y:body?.y,from:origin,blocker:null,failed:true};

  const referenceX=finite(origin.x)?origin.x:0,referenceY=finite(origin.y)?origin.y:0;
  const clampedX=clamp(referenceX,0,bounds.maxX),clampedY=clamp(referenceY,0,bounds.maxY);
  const originRect={x:referenceX,y:referenceY,w:body.w,h:body.h};
  const first=finite(origin.x)&&finite(origin.y)?firstBlockingStructure(originRect):null;
  const insideWorld=finite(origin.x)&&finite(origin.y)
    &&origin.x>=0&&origin.x<=bounds.maxX&&origin.y>=0&&origin.y<=bounds.maxY;
  if(insideWorld&&!first)return {moved:false,x:body.x,y:body.y,from:origin,blocker:null};

  const candidates=[],seen=new Set();
  let order=0;
  const addCandidate=(x,y)=>{
    if(!finite(x)||!finite(y))return;
    const cx=clamp(x,0,bounds.maxX),cy=clamp(y,0,bounds.maxY),key=candidateKey(cx,cy);
    if(seen.has(key))return;
    seen.add(key);
    const dx=cx-referenceX,dy=cy-referenceY;
    candidates.push({x:cx,y:cy,d2:dx*dx+dy*dy,order:order++});
  };

  // A lazy best-first frontier keeps the ordinary case to a handful of scans.
  // If a boundary lands inside a second solid, that solid contributes its own
  // four boundaries. Exact tangency is clear under strict AABB overlap, so the
  // saved coordinate is the actual nearest boundary rather than an arbitrary
  // safety margin beyond it.
  const addBoundaries=(structure,anchorX,anchorY)=>{
    addCandidate(anchorX,structure.y-body.h);       // north
    addCandidate(structure.x+structure.w,anchorY);  // east
    addCandidate(anchorX,structure.y+structure.h);  // south
    addCandidate(structure.x-body.w,anchorY);       // west
  };
  addCandidate(clampedX,clampedY);
  if(first)addBoundaries(first,clampedX,clampedY);
  const attemptLimit=Math.max(32,(STRUCTURES.length||1)*16);
  let winner=null,attempts=0;
  while(candidates.length&&attempts++<attemptLimit){
    candidates.sort((a,b)=>a.d2-b.d2||a.order-b.order);
    const candidate=candidates.shift();
    const rect={x:candidate.x,y:candidate.y,w:body.w,h:body.h};
    const blocker=firstBlockingStructure(rect);
    if(!blocker){winner=candidate;break;}
    addBoundaries(blocker,candidate.x,candidate.y);
  }

  if(!winner){
    // Pathological fallback only: all axis-aligned free-space cells have a corner
    // on a world/structure boundary. Build that finite search lazily, after the
    // bounded frontier has proved the ordinary route insufficient.
    const solids=solidStructures(),xs=[clampedX,0,bounds.maxX],ys=[clampedY,0,bounds.maxY];
    solids.forEach(structure=>{
      xs.push(clamp(structure.x-body.w,0,bounds.maxX),clamp(structure.x+structure.w,0,bounds.maxX));
      ys.push(clamp(structure.y-body.h,0,bounds.maxY),clamp(structure.y+structure.h,0,bounds.maxY));
    });
    xs.forEach(x=>ys.forEach(y=>addCandidate(x,y)));
    candidates.sort((a,b)=>a.d2-b.d2||a.order-b.order);
    winner=candidates.find(candidate=>!firstBlockingStructure({x:candidate.x,y:candidate.y,w:body.w,h:body.h}))||null;
  }
  if(!winner)return {moved:false,x:body.x,y:body.y,from:origin,blocker:first,failed:true};

  body.x=winner.x;body.y=winner.y;
  return {moved:body.x!==origin.x||body.y!==origin.y,x:body.x,y:body.y,from:origin,blocker:first};
}

function openInterval(origin,delta,low,high) {
  if(Math.abs(delta)<EPSILON)return origin>low+EPSILON&&origin<high-EPSILON?[-Infinity,Infinity]:null;
  let a=(low-origin)/delta,b=(high-origin)/delta;if(a>b)[a,b]=[b,a];return [a,b];
}

function segmentOpenRectRange(start,end,rect) {
  const dx=end.x-start.x,dy=end.y-start.y;
  const ix=openInterval(start.x,dx,rect.left,rect.right),iy=openInterval(start.y,dy,rect.top,rect.bottom);
  if(!ix||!iy)return null;
  const enter=Math.max(ix[0],iy[0],0),exit=Math.min(ix[1],iy[1],1);
  return enter<exit-EPSILON?[enter,exit]:null;
}

function expandedStructure(structure,w,h) {
  return {
    // Motion stops a body exactly tangent to a wall. Navigation corners must use
    // that same Minkowski boundary; extra clearance would classify a correctly
    // stopped actor as already inside the obstacle and make a detour impossible.
    left:structure.x-w/2-NAV_CLEARANCE,right:structure.x+structure.w+w/2+NAV_CLEARANCE,
    top:structure.y-h/2-NAV_CLEARANCE,bottom:structure.y+structure.h+h/2+NAV_CLEARANCE,
  };
}

function segmentBlockerInfo(start,end,w,h) {
  let best=null,bestEntry=Infinity;
  visitSolidStructures(structure=>{
    const range=segmentOpenRectRange(start,end,expandedStructure(structure,w,h));
    if(range&&range[0]<bestEntry-EPSILON){best=structure;bestEntry=range[0];}
  });
  return best?{structure:best,entry:bestEntry}:null;
}

function segmentBlocker(start,end,w,h) {
  return segmentBlockerInfo(start,end,w,h)?.structure||null;
}

export function firstSegmentBlockingStructure(body,target) {
  if(!finite(target?.x)||!finite(target?.y))return null;
  return segmentBlocker({x:body.x+body.w/2,y:body.y+body.h/2},target,body.w,body.h);
}

export function planStructureDetour(body,target,blocker) {
  if(!blocker||!finite(target?.x)||!finite(target?.y))return null;
  const start={x:body.x+body.w/2,y:body.y+body.h/2};
  const targetRect={x:target.x-body.w/2,y:target.y-body.h/2,w:body.w,h:body.h};
  if(firstBlockingStructure(targetRect))return null;
  const expanded=expandedStructure(blocker,body.w,body.h);
  const tl={x:expanded.left,y:expanded.top},tr={x:expanded.right,y:expanded.top};
  const br={x:expanded.right,y:expanded.bottom},bl={x:expanded.left,y:expanded.bottom};
  const inWorld=point=>point.x>=body.w/2&&point.x<=WORLD.w-body.w/2
    &&point.y>=body.h/2&&point.y<=WORLD.h-body.h/2;
  const crossesCurrent=(from,to)=>!!segmentOpenRectRange(from,to,expanded);
  const candidates=[[tl,tr],[tr,tl],[bl,br],[br,bl],[tl,bl],[bl,tl],[tr,br],[br,tr]]
    .map((path,order)=>({path,order}))
    .filter(candidate=>candidate.path.every(inWorld))
    // The two local legs must be usable now. The last leg may meet another
    // structure; normal collision will stop there and the next frame replans
    // around that nearest blocker instead of constructing a world-scale graph.
    .filter(candidate=>!segmentBlocker(start,candidate.path[0],body.w,body.h)
      &&!segmentBlocker(candidate.path[0],candidate.path[1],body.w,body.h)
      &&!crossesCurrent(candidate.path[1],target))
    .map(candidate=>({...candidate,length:
      Math.hypot(candidate.path[0].x-start.x,candidate.path[0].y-start.y)
      +Math.hypot(candidate.path[1].x-candidate.path[0].x,candidate.path[1].y-candidate.path[0].y)
      +Math.hypot(target.x-candidate.path[1].x,target.y-candidate.path[1].y)}))
    .sort((a,b)=>a.length-b.length||a.order-b.order);
  return candidates[0]?.path||null;
}

function moveToward(body,target,step) {
  const cx=body.x+body.w/2,cy=body.y+body.h/2,dx=target.x-cx,dy=target.y-cy,distance=Math.hypot(dx,dy);
  if(distance<=EPSILON)return {arrived:true,x:body.x,y:body.y,blockedX:false,blockedY:false,blocked:false,blocker:null};
  const travel=Math.min(step,distance),newX=body.x+dx/distance*travel,newY=body.y+dy/distance*travel;
  const movement=moveBodyAgainstStructures(body,newX,newY);
  const remaining=Math.hypot(target.x-(body.x+body.w/2),target.y-(body.y+body.h/2));
  return {arrived:remaining<=Math.max(EPSILON,step-travel+EPSILON)&&!movement.blocked,...movement};
}

function clearStructurePath(body) {
  body.structurePath=null;
  body.structurePathTarget=null;
}

function pathTargetDrifted(body,target) {
  return !body.structurePathTarget||Math.hypot(target.x-body.structurePathTarget.x,target.y-body.structurePathTarget.y)>PATH_TARGET_TOLERANCE;
}

export function commitActorStructureMotion(body,startX,startY,intendedX,intendedY,target=null,allowDetour=false,stopOnBlock=false) {
  const deltaX=finite(intendedX)&&finite(startX)?intendedX-startX:0;
  const deltaY=finite(intendedY)&&finite(startY)?intendedY-startY:0;
  body.x=startX;body.y=startY;
  const placement=ensureClearPlacement(body);
  if(placement.failed){clearStructurePath(body);return {x:body.x,y:body.y,blocked:true,failed:true,placement};}
  const baseX=body.x,baseY=body.y,step=Math.hypot(deltaX,deltaY);
  const validTarget=finite(target?.x)&&finite(target?.y);
  if(placement.moved)clearStructurePath(body);
  if(step<=EPSILON)return {x:body.x,y:body.y,blocked:false,placement};
  if(stopOnBlock)clearStructurePath(body);

  if(Array.isArray(body.structurePath)&&body.structurePath.length&&(!validTarget||pathTargetDrifted(body,target)))clearStructurePath(body);
  if(Array.isArray(body.structurePath)&&body.structurePath.length){
    const movement=moveToward(body,body.structurePath[0],step);
    if(movement.arrived&&!movement.blocked)body.structurePath.shift();
    if(!movement.blocked){
      if(!body.structurePath.length)clearStructurePath(body);
      return {x:body.x,y:body.y,blocked:false,detouring:true,placement};
    }
    body.x=baseX;body.y=baseY;clearStructurePath(body);
  }

  const direct=moveBodyAgainstStructures(body,baseX+deltaX,baseY+deltaY,stopOnBlock);
  if(!direct.blocked)return {...direct,blocked:false,placement};
  if(!allowDetour||!validTarget||!direct.blocker)return {...direct,blocked:true,placement};

  body.x=baseX;body.y=baseY;
  const path=planStructureDetour(body,target,direct.blocker);
  if(!path||!path.length){
    body.x=direct.x;body.y=direct.y;
    return {...direct,blocked:true,placement};
  }
  body.structurePath=path;
  body.structurePathTarget={x:target.x,y:target.y};
  const movement=moveToward(body,body.structurePath[0],step);
  if(movement.arrived&&!movement.blocked)body.structurePath.shift();
  if(!body.structurePath.length)clearStructurePath(body);
  return {x:body.x,y:body.y,blocked:movement.blocked,detouring:true,placement,blocker:movement.blocker||direct.blocker};
}
