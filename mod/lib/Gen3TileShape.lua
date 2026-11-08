-- Emerald's native metatiles, scoped to their PRIMARY/SECONDARY tileset pair
local V=...
local M={}
local profiles=V and V.require('Gen3EmeraldInteriors') or dofile((os.getenv('DS_MOD_PATH') or '.')..'/lib/Gen3EmeraldInteriors.lua')

local emerald
local function emeraldShapes()
 if emerald==nil then
  local ok,mod=pcall(function()return V and V.require and V.require('Gen3EmeraldShapes') end)
  if not (ok and mod) then ok,mod=pcall(dofile,(os.getenv('DS_MOD_PATH') or '.')..'/lib/Gen3EmeraldShapes.lua') end
  emerald=ok and mod or false
 end
 return emerald or nil
end
function M.of(primary,secondary,mid,behavior,collision)
 local E=emeraldShapes()
 local shape=E and E.of(primary,secondary,mid,behavior,collision)
 if shape then return shape end
 if behavior==0x2A then return {kind='steps',height=6} end
 if behavior==0x61 then
  return {kind='ladder',down=(mid==0x285 or mid==0x2AF),ground=0x281}
 end
 if behavior and require('src.core.game3.collision').isSurfable(behavior) then
  return {kind='water',reviewedSurface=true,behavior=behavior}
 end
 local profile=profiles[secondary]
 local interiorProfile=profile and (primary=='building' or profile.primary==primary)
 if interiorProfile and (profile.surfaces or {})[mid] then
  return {kind='flat',reviewedSurface=true}
 end
 if interiorProfile and profile.fills and profile.fills[mid] then
  return {kind='flat',groundMid=profile.fills[mid]}
 end
 if interiorProfile and collision==7 then
  local ok,P=pcall(function()return V and V.require and V.require('Gen3Partition')end)
  local sp=ok and type(P)=='table' and P.spec(secondary,mid)
  if sp and not sp.mapsOnly then return {kind='partition',ground=profile.floor} end
 end
 if interiorProfile and profile.walls[mid] and (collision==7 or (profile.wallsAny and profile.wallsAny[mid])) then
  return {kind='roomWall',ground=profile.wallGround and profile.wallGround[mid] or profile.floor}
 end
 if primary=='general' and mid==3 then return {kind='sign',height=12,ground=1} end
 return {kind='flat'}
end
function M.column(cells,index)
 local c=cells[index];if not c then return end
 local indoor=c.shape.kind=='roomWall'
 local function member(n)return n and not n.prop and n.pair==c.pair and
  (indoor and n.shape.kind=='roomWall' or not indoor and (n.shape.kind=='roof' or n.shape.kind=='wall'))end
 if not member(c) then return end
 local y=c.cy;local first,last=y,y
 while cells[c.cx..':'..(first-1)] do
  local n=cells[c.cx..':'..(first-1)]
  if not member(n) or (not indoor and n.shape.kind=='wall' and cells[c.cx..':'..first].shape.kind=='roof') then break end
  first=first-1
 end
 while cells[c.cx..':'..(last+1)] do
  local n=cells[c.cx..':'..(last+1)]
  if not member(n) or (not indoor and n.shape.kind=='roof' and cells[c.cx..':'..last].shape.kind=='wall') then break end
  last=last+1
 end
 local roofs,walls=0,0
 for row=first,last do local a=cells[c.cx..':'..row];if a.shape.kind=='roof' then roofs=roofs+1 else walls=walls+1 end end
 local top=cells[c.cx..':'..first]
 local full=indoor and walls==1 and c.shape.fullHeight or nil
 local tall=indoor and c.shape.tall and walls*16 or nil
 return {first=first,last=last,roofs=roofs,walls=walls,front=(last+1)*16,back=first*16,height=tall or (full and 32) or math.min(walls*16,indoor and 32 or 64),indoor=indoor,tall=tall,
  rowStep=full and 16 or nil,lowerMid=full or nil,
  roofType=top.shape.roofType or 'gable',
  roofInset=0}
end
-- A building = all touching columns as ONE box; its facade starts at one voted map row.
local function hasOverArt(c)
 local ts=c.ts;local slot=ts and ts.overImageData and ts.midToSlot[c.mid]
 if not slot then return false end
 local x0,y0,n=slot%ts.cols*16,math.floor(slot/ts.cols)*16,0
 for y=0,15 do for x=0,15 do local _,_,_,a=ts.overImageData:getPixel(x0+x,y0+y);if a>.5 then n=n+1 end end end
 return n>=24
end
local function squareRoofBacks(cells)
 for _=1,8 do
  local add={}
  for _,c in pairs(cells)do local col=c.column
   if col and not col.indoor and c.cy==col.first and c.shape.kind=='roof' then
    for _,dx in ipairs({-1,1})do
     local x=c.cx+dx
     local side=cells[x..':'..(c.cy+1)]
     local n=cells[x..':'..c.cy]
     if side and side.column and not side.column.indoor and side.column.first==c.cy+1 and side.shape.kind=='roof'
       and n and not n.column and n.pair==c.pair and n.shape.kind~='tree' and n.shape.kind~='water' then
      add[#add+1]={n,side,c}
     end
    end
   end
  end
  if #add==0 then break end
  table.sort(add,function(a,b)return a[1].cx<b[1].cx end)
  for _,a in ipairs(add)do local n,side,src=a[1],a[2],a[3]
   if not n.column then
    n.shape={kind='roof',ground=src.shape.ground,roofType=src.shape.roofType,adopted=true}
    if not hasOverArt(n) or (n.collision or 0)~=0 then n.roofMid=src.roofMid or src.mid end
    local col=side.column
    local first,last,roofs=col.first-1,col.last,col.roofs+1
    local copy={};for k,v in pairs(col)do copy[k]=v end
    n.column=copy
    for y=first,last do local c=cells[n.cx..':'..y]
     if c and c.column then c.column.first=first;c.column.roofs=roofs;c.column.back=first*16 end
    end
   end
  end
 end
end
local CLEAN_TOP={[0x030]=0x028,[0x031]=0x029,[0x032]=0x029,[0x033]=0x02B, -- the Mart repeats 0x029; 0x02A is not roof art
 [0x050]=0x048,[0x051]=0x049,[0x052]=0x04A,[0x053]=0x04B}
local function cleanShopRoofs(cells)
 for _,c in pairs(cells)do
  if c.column and not c.column.indoor and c.shape.kind=='roof' then
   local below=cells[c.cx..':'..(c.cy+1)]
   local clean=below and CLEAN_TOP[below.mid]
   if clean and c.ts.midToSlot[clean] and not hasOverArt(c) then c.roofMid=clean end
  end
 end
end
local function emeraldBuildings(cells)
 squareRoofBacks(cells)
 cleanShopRoofs(cells)
 local cols={}
 for _,c in pairs(cells)do local col=c.column
  if col and not col.indoor then
   local k=c.pair..':'..c.cx..':'..col.first
   local u=cols[k]
   if not u then u={x=c.cx,first=col.first,last=col.last,pair=c.pair,cells={},roofs=col.roofs,walls=col.walls};cols[k]=u end
   u.cells[#u.cells+1]=c
  end
 end
 local byX={}
 for _,u in pairs(cols)do local k=u.pair..':'..u.x;local t=byX[k] or {};byX[k]=t;t[#t+1]=u end
 local function find(u)while u.parent do u=u.parent end;return u end
 for _,u in pairs(cols)do
  for _,v in ipairs(byX[u.pair..':'..(u.x+1)] or {})do
   local overlap=math.min(u.last,v.last)-math.max(u.first,v.first)+1
   if overlap>=2 and math.abs(u.last-v.last)<=1 and math.abs(u.first-v.first)<=1 then local a,b=find(u),find(v);if a~=b then b.parent=a end end
  end
 end
 local groups={}
 for _,u in pairs(cols)do local r=find(u);local g=groups[r] or {};groups[r]=g;g[#g+1]=u end
 local id=0
 for _,g in pairs(groups)do
  id=id+1
  local votes,line,n,lastRow,walls={},nil,0,-math.huge,0
  for _,u in ipairs(g)do
   walls=walls+u.walls;lastRow=math.max(lastRow,u.last)
   if u.walls>0 then
    local row=u.first+u.roofs
    votes[row]=(votes[row] or 0)+1
    if votes[row]>n or (votes[row]==n and row<line)then line,n=row,votes[row] end
   end
  end
  if walls==0 or not line then
   for _,u in ipairs(g)do for _,c in ipairs(u.cells)do c.column=nil end end
  else
   local rows=lastRow-line+1
   local height=math.min(rows*16,128)
   local back,left,right,art=math.huge,math.huge,-math.huge,0
   for _,u in ipairs(g)do
    for y=u.first,u.last do
     local c=cells[u.x..':'..y]
     if c and (c.collision or 0)~=0 then back=math.min(back,y*16);break end
    end
    left=math.min(left,u.x*16);right=math.max(right,(u.x+1)*16)
    art=math.max(art,math.max(0,line-u.first))
   end
   local front=(lastRow+1)*16
   if back>line*16 then back=line*16 end
   if back>front-16 then back=front-16 end
   local group={left=left,right=right,front=front,back=back,id=id}
   for _,u in ipairs(g)do
    local roofs=math.max(0,line-u.first)
    local wallRows=u.last-math.max(u.first,line)+1
    for _,c in ipairs(u.cells)do local col=c.column
     col.roofs=roofs;col.walls=math.max(0,wallRows);col.wallTop=line;col.rowStep=height/rows
     col.height=height;col.front=front;col.back=back;col.group=group;col.groupId=id;col.artRows=art
    end
   end
  end
 end
end
-- A wall-collision tile above a wall cell that the tileset's wall list lacks is that wall art's top half (clock, light band)
local function pixels(c,y,x)
 local ts=c.ts;local slot=ts.midToSlot[c.mid]
 return ts.imageData:getPixel(slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y)
end
local function void(c) -- black padding, or a tile with a black corner (tree and Pacifidlog walls)
 local ts=c.ts
 if not (ts and ts.imageData and ts.midToSlot[c.mid]) then return true end
 local n=0
 for y=0,15 do for x=0,15 do local r,g,b=pixels(c,y,x);if r+g+b<.15 then n=n+1 end end end
 return n>=12
end
local function bands(c,rows) -- the tile's top `rows` pixel rows are each one colour: a signature, or nil when decor or furniture is in them
 local sig={}
 for y=0,rows-1 do
  local r0,g0,b0=pixels(c,y,0);local off=0
  for x=1,15 do local r,g,b=pixels(c,y,x);if math.abs(r-r0)+math.abs(g-g0)+math.abs(b-b0)>.06 then off=off+1 end end
  if off>1 then return end
  sig[#sig+1]=string.format('%d,%d,%d',r0*31,g0*31,b0*31)
 end
 return table.concat(sig,';')
end
local function adoptTops(cells)
 local add,props,seen={},{},{}
 for _,c in pairs(cells)do
  local below=cells[c.cx..':'..(c.cy+1)]
  if c.shape.kind=='flat' and not c.prop and (c.collision or 0)==7 and not c.shape.reviewedSurface and not c.shape.groundMid
   and below and below.pair==c.pair and below.secondary==c.secondary and not void(c) then
   local s=below.shape
   local two=cells[c.cx..':'..(c.cy+2)]
   if not (two and not two.prop and two.shape.kind=='roomWall' and two.pair==c.pair) then
    if below.prop then props[#props+1]=c
    elseif s.kind=='roomWall' and not s.tall and not s.fullHeight and not s.sideArt and not s.trimTop then
     add[#add+1]={c,s.ground};local sig=bands(c,9);if sig then seen[sig]=true end
    end
   end
  end
 end
 for _,c in ipairs(props)do -- furniture against the wall: the room's plain top band continues over it
  local p=profiles[c.secondary]
  if p and seen[bands(c,9) or 0] and bands(c,16) then add[#add+1]={c,p.floor} end
 end
 for _,a in ipairs(add)do a[1].shape={kind='roomWall',ground=a[2],topAdopted=true} end
 M.adopted=#add
end
function M.layout(cells)
 adoptTops(cells)
 for key,c in pairs(cells)do
  local col=M.column(cells,key)
  c.column=col
  if col and col.indoor then
   if col.first<=1 and col.last<=1 then col.first=0;col.last=1;col.walls=2 end
   col.height=col.tall or 32;col.front=(col.last+1)*16;col.back=col.front-4
  end
 end
 emeraldBuildings(cells)
end
return M
