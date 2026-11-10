-- Gen3FlyGround
local V=...
local R=V.require('Voxel3D')
local Mat=V.require('Mat4')
local M={
 CHUNK=64, -- cells per chunk side
 Y_MAP=-.6,
 Y_FILL=-.75,
 SEA=-3.2, -- the open sea plane
 SEA_MID=0x170,
 PLANE=26000,
 PLANE_CELL=650,
 TREE=28, -- px a forest stands above its floor
 STOREY=16, -- px per facade row of a building
 REAL_TREES=true,
 DECK_SLAB=8, -- px thick: a cycling-road deck is an overpass, not a block down to the ground
 NEAR=650, -- px around the flight focus where trees and buildings are real models
 log=true,
}
local function eng(name)return package.loaded[name] or require(name)end
local function now()return love.timer.getTime()end
local function note(fmt,...)if M.log then print('[FlyGround] '..string.format(fmt,...))end end
local floor=math.floor

local fill
function M.fill()
 if fill~=nil then return fill or nil end
 fill=false
 local ok,err=pcall(function()
  local b=assert(V.mod:read('assets/worldfill/fill.bin'))
  assert(b:sub(1,4)=='WFIL','not a world fill file')
  local ver,ox,oy,W,H,n,pos=love.data.unpack('<HhhHHH',b,5)
  assert(ver==1,'fill version '..tostring(ver))
  local pairs={}
  for i=1,n do local len=b:byte(pos);pairs[i]=b:sub(pos+1,pos+len);pos=pos+1+len end
  local cells=love.data.decompress('string','zlib',b:sub(pos))
  assert(#cells==W*H*2,'fill size')
  local src=V.mod:read('assets/worldfill/placements.lua')
  local place=src and assert((loadstring or load)(src,'@placements'))() or {}
  fill={ox=ox,oy=oy,W=W,H=H,pairs=pairs,cells=cells,place=place}
 end)
 if not ok then note('no world fill: %s',tostring(err));fill=false end
 return fill or nil
end
local dewfordTrees={0x1D4,0x1D5,0x1DC,0x1DD}
local function fillAt(F,x,y)
 local fx,fy=x-F.ox,y-F.oy
 if fx<0 or fy<0 or fx>=F.W or fy>=F.H then return nil end
 local i=(fy*F.W+fx)*2+1
 local lo,hi=F.cells:byte(i,i+1)
 local c=lo+hi*256
 if c==0 then return nil end
 local pair,mid=F.pairs[floor(c/1024)],c%1024
 if pair=='general__dewford' and mid==0x243 then mid=dewfordTrees[(y%2)*2+x%2+1] end
 return pair,mid
end
M.fillAt=fillAt
function M.placement(id)
 local F=M.fill();local p=F and F.place[id]
 if p then return p.ox,p.oy,p.overlay end
end

-- The flight atlas and the walking scene share Littleroot's coordinate origin.
local sourceMaps,origins
function M.origins(maps)
 if sourceMaps~=maps then
  local hub='EM_LITTLEROOT_TOWN'
  origins={[hub]={ox=0,oy=0}}
  for _,e in ipairs(eng('src.core.game3.map').computeWorld(maps,hub,99))do origins[e.id]=e end
  local F=M.fill()
  for id,e in pairs(F and F.place or {})do origins[id]=e end
  sourceMaps=maps
 end
 return origins
end

-- Shared index map, 0-based uint32 (1,2,3,1,3,4 per quad).
local mapData,mapQuads=nil,0
local function fullView(quads)
 if quads>mapQuads then
  local n=math.max(quads,mapQuads*2,4096)
  local parts,vals={},{}
  for q=0,n-1,50 do
   local k=0
   for j=q,math.min(n-1,q+49)do local b=j*4
    vals[k+1],vals[k+2],vals[k+3],vals[k+4],vals[k+5],vals[k+6]=b,b+1,b+2,b,b+2,b+3;k=k+6
   end
   parts[#parts+1]=love.data.pack('string',string.rep('I4',k),unpack(vals,1,k))
  end
  if mapData then mapData:release() end
  mapData=love.data.newByteData(table.concat(parts));mapQuads=n
 end
 return love.data.newDataView(mapData,0,quads*24)
end
local PACK=1200
local FMT=string.rep('f',PACK)
local function packFloats(f,n)
 local parts={}
 for s=1,n,PACK do
  local e=math.min(n,s+PACK-1)
  parts[#parts+1]=love.data.pack('string',e-s+1==PACK and FMT or string.rep('f',e-s+1),unpack(f,s,e))
 end
 return love.data.newByteData(table.concat(parts))
end

local G,releaseTrees,prepareBuildings
function M.state()return G end
local function chunkKey(cx,cy)return cx..':'..cy end
function M.begin(game,maps)
 local F=M.fill();if not F then return false end
 if G and G.game==game then return true end
 if G then M.release() end
 local Tiles=eng('src.core.game3.tileset_native')
 local size=eng('src.core.game3.connections').sizeOf
 G={game=game,maps={},chunks={},byNum={},order={},alloc={},filled={},t0=now(),quads=0,meshes=0,planMs=0,fillMs=0}
 local x0,y0,x1,y1=F.ox,F.oy,F.ox+F.W,F.oy+F.H
 for id,e in pairs(maps)do
  local def=e.def
  if def and not e.overlay then
   local w,h=size(def)
   if w>0 and h>0 then
    G.maps[#G.maps+1]={id=id,def=def,ox=e.ox,oy=e.oy,w=w,h=h}
    x0,y0,x1,y1=math.min(x0,e.ox),math.min(y0,e.oy),math.max(x1,e.ox+w),math.max(y1,e.oy+h)
   end
  end
 end
 table.sort(G.maps,function(a,b)return a.id<b.id end)
 local C=M.CHUNK
 for cy=floor(y0/C),floor((y1-1)/C)do for cx=floor(x0/C),floor((x1-1)/C)do
  local c={cx=cx,cy=cy,x0=cx*C,y0=cy*C,maps={},state='todo'}
  for _,m in ipairs(G.maps)do
   if m.ox<c.x0+C and m.ox+m.w>c.x0 and m.oy<c.y0+C and m.oy+m.h>c.y0 then c.maps[#c.maps+1]=m end
  end
  G.chunks[chunkKey(cx,cy)]=c;G.order[#G.order+1]=c;G.byNum[(cy+2048)*4096+cx+2048]=c
 end end
 for _,p in ipairs(F.pairs)do if not Tiles._pairs[p] then pcall(Tiles.prefetch,p,1)end end
 note('world: %d maps, %d chunks of %d cells, fill %dx%d at (%d,%d), %d fill pairs',#G.maps,#G.order,C,F.W,F.H,F.ox,F.oy,#F.pairs)
 return true
end
function M.release()
 if not G then return end
 for _,c in ipairs(G.order)do for _,p in ipairs(c.parts or {})do if p.mesh then pcall(p.mesh.release,p.mesh)end end;releaseTrees(c) end
 G=nil
end
function M.done()return G and G.allLive or false end

local function mapReady(m)
 local def=m.def
 if not def.midLayout then
  local Map=eng('src.core.game3.map')
  pcall(Map.ensureMidLayout,G.game,m.id,def)
 end
 local L=def.midLayout
 m.pair=m.pair or def.pair or (L and L.pair)
 if not (L and L.midAt and m.pair) then m.failed=true end
 return not m.failed
end
local want={}
local function guardRetain()
 local Tiles=eng('src.core.game3.tileset_native')
 local st=Tiles._stream
 if not st or st.flyGroundGuard then return end
 local orig=st.retain
 st.retain=function(self,wanted)
  if next(want) then
   local w={}
   for k,v in pairs(wanted or {})do w[k]=v end
   for k in pairs(want)do w[k]=true end
   return orig(self,w)
  end
  return orig(self,wanted)
 end
 st.flyGroundGuard=true
end
local function pairReady(p,priority)
 local Tiles=eng('src.core.game3.tileset_native')
 local ts=Tiles._pairs[p]
 if ts and ts.image then want[p]=nil;return ts end
 want[p]=true
 guardRetain()
 pcall(Tiles.prefetch,p,priority or 1)
 return nil
end
function M.pause()want={}end

-- Relief: the flight ground stands at the voxel world's own heights (Gen3Elevation fields, one offset per map).
local KIND={tree=1,roof=2,wall=3,water=4}
local abs,min,max=math.abs,math.min,math.max
local spec_
local function treeShape(m,x,y)
 local L=m.def.midLayout
 local mid=L:midAt(x,y)
 local sh
 local ok=pcall(function()
  local pair=m.pair
  local spec=V.require('Gen3Tilesets').resolve(pair,eng('src.import.gba.versions').TILESET_PAIRS)
  local beh=(eng('src.core.game3.scripting.interaction_scripts').behaviors[pair] or {})[mid]
  sh=V.require('Gen3TileShape').of(spec.primary,spec.secondary,mid,beh,L:collAt(x,y))
 end)
 if not ok or not sh or sh.kind~='tree' or sh.fortree or sh.palmCrown or sh.roadTree then return nil end
 if sh.canopy then return {canopy=true,ground=sh.ground or 1,mid=mid,shape=sh} end
 return {root=sh.root and true or false,ground=sh.ground or 1,mid=mid,shape=sh}
end
local function survey(m)
 local E=V.require('Gen3Elevation')
 local w,h=m.w,m.h
 local H,K,R,C,B,F,T,D={},{},{},{},{},{},{},{}
 local deckSet
 if m.pair and tostring(m.pair):find('mauville') then local ok,CR=pcall(V.require,'Gen3CyclingRoad');deckSet=ok and CR.DECK end
 local ok,f=pcall(E.field,m.def)
 if not ok then note('no heights for %s: %s',m.id,tostring(f));f=nil end
 local okP,Pin=pcall(V.require,'Gen3PinData')
 local drawn=f and okP and E.PINS_ON and not E.PIN_SKIP[m.def.id or m.id] and Pin.MAPS[m.def.id or m.id]
 local arrows=drawn and drawn.cells and drawn.arrows
 local P=E.PIN_PX or 16
 for y=0,h-1 do for x=0,w-1 do
  local i=y*w+x+1
  local c=f and f.cells[x..':'..y]
  local hh=c and c.height or 0
  H[i]=hh;K[i]=c and KIND[c.kind] or 0
  if deckSet and deckSet[m.def.midLayout:midAt(x,y)] then D[i]=true end
  local a=arrows and arrows[min(x,drawn.w-1)..':'..min(y,drawn.h-1)]
  if a then
   local lo,hi=a.lo*P,a.hi*P
   local d=a.dir
   if d=='N' then C[i]={hi,hi,lo,lo} elseif d=='S' then C[i]={lo,lo,hi,hi}
   elseif d=='E' then C[i]={lo,hi,hi,lo} elseif d=='W' then C[i]={hi,lo,lo,hi}
   else
    local k=d=='NW' and 1 or d=='NE' and 2 or d=='SE' and 3 or 4
    local t=a.inner and {hi,hi,hi,hi} or {lo,lo,lo,lo}
    if a.inner then t[(k+1)%4+1]=lo else t[k]=hi end
    C[i]=t
   end
  elseif c and c.high and c.low then
   local u=c.step and c.stairUp
   local lo,hi=c.low,c.high
   if u and u[2]>0 then C[i]={lo,lo,hi,hi} elseif u and u[1]>0 then C[i]={lo,hi,hi,lo} elseif u and u[1]<0 then C[i]={hi,lo,lo,hi}
   else C[i]={hi,hi,lo,lo} end
  elseif c and c.slope and c.height then
   local sl=c.slope;C[i]={hh+sl[1],hh+sl[2],hh+sl[3],hh+sl[4]}
  elseif K[i]==1 then
   R[i]=M.TREE
   local sh=M.REAL_TREES and treeShape(m,x,y)
   if sh then T[i]=sh end
  end
 end end
 -- a building: its roof rows span the whole footprint, the wall rows below them stand up as its south face
 for x=0,w-1 do
  local y=0
  while y<h do
   if K[y*w+x+1]==2 then
    local y0=y
    while y<h and K[y*w+x+1]==2 do y=y+1 end
    local r,n=y-y0,0
    while y<h and K[y*w+x+1]==3 and n<4 do y=y+1;n=n+1 end
    local up=M.STOREY*max(1,n)
    local base=H[(y-1)*w+x+1]
    for j=0,r-1 do local i=(y0+j)*w+x+1;R[i]=up;H[i]=base;C[i]=nil;B[i]={y0+j*(r+n)/r,y0+(j+1)*(r+n)/r} end
    for j=1,n do local i=(y0+r+j-1)*w+x+1;R[i]=up;H[i]=base;C[i]=nil;F[i]={y0+r+n,j} end
   else y=y+1 end
  end
 end
 local L=m.def.midLayout
 if m.pair and m.pair:match('^general__') then
  for y=0,h-1,2 do for x=0,w-1,2 do if L:midAt(x,y)==M.SEA_MID then m.sea=true;break end end;if m.sea then break end end
 end
 m.H,m.K,m.R,m.C,m.B,m.F,m.T,m.D,m.field,m.off=H,K,R,C,B,F,T,D,f,0
end
local function mapAt(x,y)
 local m=G.last
 if m and x>=m.ox and y>=m.oy and x<m.ox+m.w and y<m.oy+m.h then return m end
 local C=M.CHUNK
 local c=G.byNum[(floor(y/C)+2048)*4096+floor(x/C)+2048]
 if not c then return nil end
 for _,q in ipairs(c.maps)do
  if q.H and x>=q.ox and y>=q.oy and x<q.ox+q.w and y<q.oy+q.h then G.last=q;return q end
 end
end
local kinds={}
local function fillKind(pair,mid)
 local t=kinds[pair];if not t then t={};kinds[pair]=t end
 local k=t[mid]
 if k==nil then
  k=0
  pcall(function()
   local spec=V.require('Gen3Tilesets').resolve(pair,eng('src.import.gba.versions').TILESET_PAIRS)
   local beh=(eng('src.core.game3.scripting.interaction_scripts').behaviors[pair] or {})[mid]
   k=KIND[V.require('Gen3TileShape').of(spec.primary,spec.secondary,mid,beh,nil).kind] or 0
  end)
  t[mid]=k
 end
 return k
end
local function fillTop(x,y)
 local F=fill
 local p,mid=fillAt(F,x,y);if not p then return nil end
 local k=fillKind(p,mid)
 if k==4 then return M.Y_FILL end
 return (G.FH[(y-F.oy)*F.W+x-F.ox+1] or 0)+(k==1 and M.TREE or 0)+M.Y_FILL
end
local function topAt(x,y)
 local m=mapAt(x,y)
 if m then
  local i=(y-m.oy)*m.w+(x-m.ox)+1
  local o=m.off+M.Y_MAP
  if G.nearMode and m.claim and m.claim[i] then local t=(m.H[i] or 0)+o;return t,t,t,t end
  local c=m.C[i]
  if c then return c[1]+o,c[2]+o,c[3]+o,c[4]+o end
  local t=(m.H[i] or 0)+((G.nearMode and m.T[i]) and 0 or m.R[i] or 0)+o
  return t,t,t,t
 end
 local t=fillTop(x,y)
 if t then return t,t,t,t end
end
-- The fill between the maps continues the nearest map cell's floor (two-pass distance transform).
local function spread(pass)
 local F=fill;local W,Hh=F.W,F.H
 local D,FH=G.FD,G.FH
 if pass==1 then
  D,FH={},{}
  for i=1,W*Hh do D[i]=1e9;FH[i]=0 end
  for _,m in ipairs(G.maps)do if m.H then
   for y=max(0,m.oy-F.oy),min(Hh-1,m.oy+m.h-1-F.oy)do
    local row,my=y*W,(y+F.oy-m.oy)*m.w
    for x=max(0,m.ox-F.ox),min(W-1,m.ox+m.w-1-F.ox)do
     local i=my+(x+F.ox-m.ox)+1
     D[row+x+1]=0;FH[row+x+1]=(m.K[i]==4 and 0 or m.H[i] or 0)+m.off
    end
   end
  end end
  G.FD,G.FH=D,FH
 elseif pass==2 then
  for y=0,Hh-1 do local row=y*W
   for x=0,W-1 do local i=row+x+1;local d=D[i]
    if x>0 and D[i-1]+1<d then d=D[i-1]+1;FH[i]=FH[i-1] end
    if y>0 and D[i-W]+1<d then d=D[i-W]+1;FH[i]=FH[i-W] end
    D[i]=d
   end
  end
 else
  for y=Hh-1,0,-1 do local row=y*W
   for x=W-1,0,-1 do local i=row+x+1;local d=D[i]
    if x<W-1 and D[i+1]+1<d then d=D[i+1]+1;FH[i]=FH[i+1] end
    if y<Hh-1 and D[i+W]+1<d then d=D[i+W]+1;FH[i]=FH[i+W] end
    D[i]=d
   end
  end
  G.FD=nil
 end
end
local function reliefStep(deadline)
 local t0=now()
 G.surveyed=G.surveyed or 0
 while G.surveyed<#G.maps do
  if now()>deadline then return false end
  local m=G.maps[G.surveyed+1]
  if mapReady(m) then survey(m);prepareBuildings(m) end
  G.surveyed=G.surveyed+1
  G.reliefMs=(G.reliefMs or 0)+(now()-t0)*1000;t0=now()
 end
 if not G.aligned then
  -- every map on the open sea stands at 0 (the drawn heights are per map; chained across Hoenn they drift);
  -- the inland maps hang off those, seam by seam
  local Levels=V.require('TerrainLevels')
  local list={}
  for _,m in ipairs(G.maps)do if m.H then list[#list+1]=m;m.near={};m.off=m.sea and 0 or nil end end
  for i,a in ipairs(list)do for j=i+1,#list do
   local b=list[j]
   local side=(a.ox+a.w==b.ox or b.ox+b.w==a.ox) and a.oy<b.oy+b.h and b.oy<a.oy+a.h
   local top=(a.oy+a.h==b.oy or b.oy+b.h==a.oy) and a.ox<b.ox+b.w and b.ox<a.ox+a.w
   if side or top then
    local rb={x=b.ox,y=b.oy,w=b.w,h=b.h,floorField=b.field}
    Levels.align({{x=a.ox,y=a.oy,w=a.w,h=a.h,floorField=a.field},rb})
    local d=rb.floorOffset or 0
    a.near[#a.near+1]={b,-d};b.near[#b.near+1]={a,d}
   end
  end end
  -- an inland map takes the seam that keeps it nearest sea level
  for _=1,8 do
   local changed=false
   for _,m in ipairs(list)do if not m.sea then
    local best
    for _,e in ipairs(m.near)do
     local o=e[1].off and e[1].off+e[2]
     if o and (not best or abs(o)<abs(best)) then best=o end
    end
    if best and best~=m.off then m.off=best;changed=true end
   end end
   if not changed then break end
  end
  for _,m in ipairs(list)do m.off=m.off or 0;m.near=nil end
  G.aligned=true;G.pass=1
  G.reliefMs=(G.reliefMs or 0)+(now()-t0)*1000
  return false
 end
 spread(G.pass);G.pass=G.pass+1
 G.reliefMs=(G.reliefMs or 0)+(now()-t0)*1000
 if G.pass<=3 then return false end
 G.relief=true
 note('relief: %d maps surveyed, heights spread over the fill, %.0f ms',#G.maps,G.reliefMs)
 return true
end
function M.offset(id)
 if not (G and G.relief) then return 0 end
 for _,m in ipairs(G.maps)do if m.id==id then return m.off or 0 end end
 return 0
end
local SH_E,SH_W,SH_S,SH_N=.84,.72,.9,.68
local function emit(q,cx,cy,slot,x1,y1,z1,x2,y2,z2,x3,y3,z3,x4,y4,z4,sh)
 local du,dv=q.du,q.dv
 local u0,v0=(slot%q.cols)*du,floor(slot/q.cols)*dv
 local u1,v1=u0+du,v0+dv
 local f,n=q.f,q.n*24
 if abs(y1-y3)>abs(y2-y4) then -- fold along the flatter diagonal
  f[n+1],f[n+2],f[n+3],f[n+4],f[n+5],f[n+6]=x2,y2,z2,u1,v0,sh
  f[n+7],f[n+8],f[n+9],f[n+10],f[n+11],f[n+12]=x3,y3,z3,u1,v1,sh
  f[n+13],f[n+14],f[n+15],f[n+16],f[n+17],f[n+18]=x4,y4,z4,u0,v1,sh
  f[n+19],f[n+20],f[n+21],f[n+22],f[n+23],f[n+24]=x1,y1,z1,u0,v0,sh
 else
  f[n+1],f[n+2],f[n+3],f[n+4],f[n+5],f[n+6]=x1,y1,z1,u0,v0,sh
  f[n+7],f[n+8],f[n+9],f[n+10],f[n+11],f[n+12]=x2,y2,z2,u1,v0,sh
  f[n+13],f[n+14],f[n+15],f[n+16],f[n+17],f[n+18]=x3,y3,z3,u1,v1,sh
  f[n+19],f[n+20],f[n+21],f[n+22],f[n+23],f[n+24]=x4,y4,z4,u0,v1,sh
 end
 local k=q.n*2;q.cells[k+1],q.cells[k+2]=cx,cy
 q.n=q.n+1
end
-- a wall wherever this cell's edge stands above its neighbour's
-- one wall, top edge (x1,ya,z1)-(x2,yb,z2) down to (la,lb): a tall one repeats the tile per course
local function wall(q,x,y,slot,x1,ya,z1,x2,yb,z2,la,lb,sh,slab)
 la,lb=min(la,ya)-3,min(lb,yb)-3
 if slab then la,lb=max(la,ya-slab),max(lb,yb-slab) end
 local n=max(1,min(24,floor((max(ya-la,yb-lb)-3)/16+.5)))
 for k=0,n-1 do
  local t0,t1=k/n,(k+1)/n
  emit(q,x,y,slot,x1,ya+(la-ya)*t0,z1,x2,yb+(lb-yb)*t0,z2,x2,yb+(lb-yb)*t1,z2,x1,ya+(la-ya)*t1,z1,sh)
 end
end
-- a wall wherever this cell's edge stands above its neighbour's
local function walls(q,x,y,slot,nw,ne,se,sw,noSouth,slab)
 local X,Z=x*16,y*16
 local S=M.SEA
 local _,_,c,d=topAt(x,y-1);c,d=c or S,d or S
 if nw>d+.5 or ne>c+.5 then wall(q,x,y,slot,X+16,ne,Z,X,nw,Z,c,d,SH_N,slab)end
 if not noSouth then
  local a,b=topAt(x,y+1);a,b=a or S,b or S
  if sw>a+.5 or se>b+.5 then wall(q,x,y,slot,X,sw,Z+16,X+16,se,Z+16,a,b,SH_S,slab)end
 end
 local _,b2,c2=topAt(x-1,y);b2,c2=b2 or S,c2 or S
 if nw>b2+.5 or sw>c2+.5 then wall(q,x,y,slot,X,nw,Z,X,sw,Z+16,b2,c2,SH_W,slab)end
 local a3,_,_,d3=topAt(x+1,y);a3,d3=a3 or S,d3 or S
 if ne>a3+.5 or se>d3+.5 then wall(q,x,y,slot,X+16,se,Z+16,X+16,ne,Z,d3,a3,SH_E,slab)end
end
local curTrees
local shapeMemo={}
local function buildCells(m)
 local Tiles=eng('src.core.game3.tileset_native')
 local L=m.def.midLayout
 local ts=Tiles._pairs[m.pair]
 local spec=V.require('Gen3Tilesets').resolve(m.pair,eng('src.import.gba.versions').TILESET_PAIRS)
 local beh=eng('src.core.game3.scripting.interaction_scripts').behaviors[m.pair] or {}
 local Shapes=V.require('Gen3TileShape')
 local cells={}
 for y=0,m.h-1 do for x=0,m.w-1 do
  local mid=L:midAt(x,y) or 0
  local coll=L:collAt(x,y)
  local k=m.pair..mid..':'..tostring(coll)
  local sh=shapeMemo[k]
  if sh==nil then
   local ok,r=pcall(Shapes.of,spec.primary,spec.secondary,mid,beh[mid],coll)
   sh=ok and r or {kind='flat'};shapeMemo[k]=sh
  end
  cells[x..':'..y]={cx=x,cy=y,mid=mid,pair=m.pair,nativePair=m.pair,ts=ts,primary=spec.primary,secondary=spec.secondary,shape=sh,collision=coll,base=0,behavior=beh[mid]}
 end end
 return cells
end
-- the walking scene's own building models, found on the map's cells; their cells stand flat in the near take
function prepareBuildings(m)
 m.prepared=true;m.claim={};m.bmesh={};m.bqueue={}
 local ok,err=pcall(function()
  local t7=now()
  local cells=buildCells(m)
  m.cellMs=(now()-t7)*1000
  local list=V.require('BuildingModels').prepare(cells,m.def,{})
  m.cells=cells
  for _,bld in ipairs(list)do
   for _,c in ipairs(bld.claimed or {})do m.claim[c.cy*m.w+c.cx+1]=bld end
   if bld.claimed and #bld.claimed>0 then m.bqueue[#m.bqueue+1]=bld end
  end
 end)
 if not ok then note('buildings of %s failed: %s',m.id,tostring(err));m.claim={};m.bqueue={} end
 if #m.bqueue==0 then m.cells=nil end
end
local function addTree(ts,t,x,y,top)
 local NT=V.require('NativeTreeArt')
 local card
 local seed=x*73+y*139
 local tx,tz
 if t.canopy then
  local c=ts.canopyTreeCards;if not c then c={};ts.canopyTreeCards=c end
  local mm=(x+y)%2==0 and 0x00E or 0x00F
  card=c[mm]
  if card==nil then
   card=(ts.midToSlot[mm] and ts.midToSlot[mm+8] and NT.gen3({ts=ts,mid=mm,shape={art={{mm},{mm+8}},ground=t.ground}})) or false
   c[mm]=card
  end
  tx,tz=x*16+8+seed%7-3,y*16+11+math.floor(seed/7)%5-2
 elseif t.root then
  local sh=t.shape
  local tc=ts.flyTreeCards;if not tc then tc={};ts.flyTreeCards=tc end
  card=tc[t.mid]
  if card==nil then card=NT.gen3({ts=ts,mid=t.mid,shape=sh}) or false;tc[t.mid]=card end
  tx,tz=x*16+(sh.anchorX or 16),y*16+(sh.anchorZ or 12)
 end
 if card then
  NT.addInstance(card,curTrees.groups,tx,top,tz)
 end
end
local function mapCell(q,m,x,y,mid)
 local i=(y-m.oy)*m.w+(x-m.ox)+1
 local X,Z=x*16,y*16
 local nw,ne,se,sw=topAt(x,y)
 local slab=m.D and m.D[i] and M.DECK_SLAB or nil
 local claimed=curTrees and m.claim and m.claim[i]
 if claimed then mid=claimed.groundMid or 0x001 end
 local t=curTrees and m.T[i]
 if t then
  mid=t.ground
  if curTrees.ts then addTree(curTrees.ts,t,x,y,nw) end
 end
 local slot=q.toSlot[mid] or q.zero
 local face=not claimed and m.F[i]
 if face then
  local z,j,s=(face[1]+m.oy)*16,face[2],M.STOREY
  emit(q,x,y,slot,X,nw-s*(j-1),z,X+16,nw-s*(j-1),z,X+16,nw-s*j,z,X,nw-s*j,z,SH_S)
  return walls(q,x,y,slot,nw,ne,se,sw,true,slab)
 end
 local b=not claimed and m.B[i]
 if b then local z0,z1=(b[1]+m.oy)*16,(b[2]+m.oy)*16;emit(q,x,y,slot,X,nw,z0,X+16,ne,z0,X+16,se,z1,X,sw,z1,1)
 else emit(q,x,y,slot,X,nw,Z,X+16,ne,Z,X+16,se,Z+16,X,sw,Z+16,1)end
 walls(q,x,y,slot,nw,ne,se,sw,nil,slab)
end
local function fillCell(q,x,y,mid)
 local slot=q.toSlot[mid] or q.zero
 local X,Z=x*16,y*16
 local m=mapAt(x,y)
 if m then
  local t=(m.H[(y-m.oy)*m.w+(x-m.ox)+1] or 0)+m.off+M.Y_FILL
  return emit(q,x,y,slot,X,t,Z,X+16,t,Z,X+16,t,Z+16,X,t,Z+16,1)
 end
 local t=fillTop(x,y)
 emit(q,x,y,slot,X,t,Z,X+16,t,Z,X+16,t,Z+16,X,t,Z+16,1)
 walls(q,x,y,slot,t,t,t,t)
end
-- the real tree models of a chunk, one instanced batch per card mesh; 'rect' (cells) leaves the walking scene's own trees out
local function buildTrees(c,rect)
 local out={}
 local NT=V.require('NativeTreeArt')
 local Inst=V.require('ModelInstances')
 for _,g in pairs(c.treeGroups)do
  local pos=g.positions
  if rect then
   pos={}
   for _,p in ipairs(g.positions)do
    local cx,cy=floor(p[1]/16),floor(p[3]/16)
    if not (cx>=rect[1] and cx<=rect[3] and cy>=rect[2] and cy<=rect[4]) then pos[#pos+1]=p end
   end
  end
  local b=#pos>0 and Inst.new(g.mesh,pos)
  if b then out[#out+1]=b end
 end
 return out
end
function releaseTrees(c)
 for _,b in ipairs(c.trees or {})do pcall(b.release,b)end
 c.trees=nil
end
local function planChunk(c,deadline,prio)
 local F=fill
 local C=M.CHUNK
 local SEA=M.SEA_MID
 for _,m in ipairs(c.maps)do
  if not m.failed then
   if not m.pair or not m.def.midLayout then
    if now()>deadline then return false end
    mapReady(m)
   end
   if m.pair and not m.failed and not pairReady(m.pair,prio) then return false end
  end
 end
 if not c.fillPairs then
  local need={}
  for y=c.y0,c.y0+C-1 do for x=c.x0,c.x0+C-1 do local p=fillAt(F,x,y);if p then need[p]=true end end end
  c.fillPairs=need
 end
 local ready=true
 for p in pairs(c.fillPairs)do if not pairReady(p,prio) then ready=false end end
 if not ready then return false end
 local Tiles=eng('src.core.game3.tileset_native')
 local w=c.work
 if not w then w={parts={},byPair={},row=c.y0,trees={groups={}}};c.work=w end
 local parts,byPair=w.parts,w.byPair
 curTrees=c.near and w.trees or nil
 G.nearMode=c.near or false
 local function part(p)
  local q=byPair[p]
  if q then return q end
  local ts=Tiles._pairs[p]
  local iw,ih=ts.image:getDimensions()
  q={pair=p,f={},n=0,cells={},cols=ts.cols,toSlot=ts.midToSlot or {},du=16/iw,dv=16/ih,zero=(ts.midToSlot or {})[0] or 0}
  byPair[p]=q;parts[#parts+1]=q
  return q
 end
 while w.row<c.y0+C do
  local y=w.row
  local mi=w.mi or 1
  while mi<=#c.maps do
   local m=c.maps[mi]
   if not m.failed and y>=m.oy and y<m.oy+m.h then
    local L=m.def.midLayout
    local general=m.pair:match('^general__')~=nil
    local q=part(m.pair)
    if curTrees then
     curTrees.ts=Tiles._pairs[m.pair]
     if curTrees.ts and not curTrees.ts.imageData then curTrees.ts=nil end
    end
    local ax0,ax1=math.max(c.x0,m.ox),math.min(c.x0+C,m.ox+m.w)-1
    local x0=w.x or ax0
    local ok,err=pcall(function()
     for x=x0,ax1 do
      if curTrees and x>x0 and now()>deadline then w.mi,w.x=mi,x;return true end
      local mid=L:midAt(x-m.ox,y-m.oy) or 0
      if not (general and mid==SEA) then mapCell(q,m,x,y,mid)end
     end
     w.x=nil
    end)
    if not ok then note('ground of %s failed: %s',m.id,tostring(err));m.failed=true;w.x=nil end
    if w.x then return false end
   end
   mi=mi+1
  end
  w.mi=nil
  for x=c.x0,c.x0+C-1 do
   local p,mid=fillAt(F,x,y)
   if p then fillCell(part(p),x,y,mid)end
  end
  w.row=y+1
  if now()>deadline and w.row<c.y0+C then return false end
 end
 local keep={}
 for _,q in ipairs(parts)do if q.n>0 then keep[#keep+1]=q end end
 c.parts=keep;c.state='planned';c.work=nil
 curTrees=nil;G.nearMode=false
 if c.near then
  c.treeGroups=w.trees.groups
  if next(c.treeGroups) then c.trees=buildTrees(c,nil) end
 end
 return true
end

function M.step(hx,hz,budget)
 if not G then return end
 local t0=now()
 local deadline=t0+(budget or .003)
 local frame=G.frame or 0;G.frame=frame+1
 local i=1
 while i<=#G.alloc do
  local c=G.alloc[i]
  if c.allocFrame<frame and now()<deadline then
   for _,p in ipairs(c.parts)do
    if p.mesh and p.f then
     local ok,err=pcall(function()
      local data=packFloats(p.f,p.n*24)
      p.mesh:setVertices(data,1)
      data:release()
     end)
     if not ok then note('chunk %d,%d %s: %s',c.cx,c.cy,p.pair,tostring(err));p.mesh:release();p.mesh=nil end
     p.f=nil
     if p.mesh then G.quads=G.quads+p.n;G.meshes=G.meshes+1 end
    end
   end
   c.state='live';c.cutKey=nil;c.liveFrame=frame
   table.remove(G.alloc,i)
  else
   i=i+1
  end
 end
 G.fillMs=G.fillMs+(now()-t0)*1000
 for _,c in ipairs(G.order)do
  if c.state=='planned' then
   for _,p in ipairs(c.parts)do
    local ok,mesh=pcall(love.graphics.newMesh,R.FORMAT,p.n*4,'triangles','static')
    p.mesh=ok and mesh or nil
    if p.mesh then
     local view=fullView(p.n)
     if not pcall(p.mesh.setVertexMap,p.mesh,view,'uint32') then p.mesh:release();p.mesh=nil end
     view:release()
    end
   end
   c.state='alloc';c.allocFrame=frame;G.alloc[#G.alloc+1]=c
  end
 end
 local t1=now()
 if not G.relief and not reliefStep(deadline) then return end
 if (not G.allLive or G.nearPending) and now()<deadline then
  if not G.sortedAt or math.abs(G.sortedAt[1]-hx)+math.abs(G.sortedAt[2]-hz)>512 then
   local C16=M.CHUNK*16
   for _,c in ipairs(G.order)do
    local cx,cz=(c.x0*16+C16/2)-hx,(c.y0*16+C16/2)-hz
    c.d=cx*cx+cz*cz
   end
   table.sort(G.order,function(a,b)return a.d<b.d end)
   G.sortedAt={hx,hz}
  end
  local todo,rank=false,0
  for _,c in ipairs(G.order)do
   if c.state=='todo' then
    todo=true;rank=rank+1
    if now()>deadline then break end
    planChunk(c,deadline,1+rank*.01)
   end
  end
  if not G.allLive and not todo and #G.alloc==0 then
   local any=false
   for _,c in ipairs(G.order)do if c.state~='live' and not c.near then any=true;break end end
   if not any then
    G.allLive=true
    note('world laid: %d quads in %d meshes, %.1f s after the first take-off (plan %.0f ms, fill %.0f ms)',
     G.quads,G.meshes,now()-G.t0,G.planMs,G.fillMs)
   end
  end
 end
 -- chunks close to the flight get a second take with the real models
 if G.relief and G.allLive then
  local C16=M.CHUNK*16
  local r=M.NEAR+C16
  G.nearPending=false
  for _,c in ipairs(G.order)do
   if not c.near and c.state=='live' and not c.nearObj and c.hasT~=false then
    local dx,dz=c.x0*16+C16/2-hx,c.y0*16+C16/2-hz
    if dx*dx+dz*dz<=r*r then
     local any,ready=false,true
     for _,m in ipairs(c.maps)do
      if m.H and not m.failed then
       if not m.prepared then
        if not G.prepFrame or G.prepFrame~=G.frame then G.prepFrame=G.frame;local t2=now();prepareBuildings(m);G.prepMs=(G.prepMs or 0)+(now()-t2)*1000;if M.log and now()-t2>.01 then note('prep %s %.0f ms (cells %.0f, %dx%d)',m.id,(now()-t2)*1000,m.cellMs or 0,m.w,m.h) end end
        ready=m.prepared
       end
       if m.T and next(m.T) or (m.bqueue and #m.bqueue>0) or (m.bmesh and #m.bmesh>0) then any=true end
      end
     end
     if not ready then
     elseif any then
      local n={cx=c.cx,cy=c.cy,x0=c.x0,y0=c.y0,maps=c.maps,state='todo',near=true,parent=c,fillPairs=c.fillPairs,cutKey=nil}
      c.nearObj=n;G.order[#G.order+1]=n;G.sortedAt=nil
     else c.hasT=false end
    end
   end
  end
  for _,c in ipairs(G.order)do if c.near and c.state~='live' then G.nearPending=true;break end end
 end
 -- one building model per frame, nearest first
 if G.relief and G.allLive then
  local best,bm,bd
  for _,m in ipairs(G.maps)do if m.bqueue and #m.bqueue>0 then
   for k,bld in ipairs(m.bqueue)do
    local dx,dz=(m.ox+bld.cx+bld.width/2)*16-hx,(m.oy+bld.cy+bld.depth/2)*16-hz
    local d=dx*dx+dz*dz
    if d<=(M.NEAR+256)^2 and (not bd or d<bd) then best,bm,bd=k,m,d end
   end
  end end
  if best and now()<deadline+.004 then
   local bld=table.remove(bm.bqueue,best)
   local t3=now()
   if not bm.cellsTs then bm.cellsTs=true;local ts=eng('src.core.game3.tileset_native')._pairs[bm.pair];for _,c in pairs(bm.cells)do c.ts=ts end end
   bld.ts=eng('src.core.game3.tileset_native')._pairs[bm.pair] or bld.ts
   local ok,r=pcall(V.require('BuildingModels').mesh,bld,bm.cells)
   if now()-t3>.01 then note('bmesh %s %s %.0f ms',bm.id,tostring(bld.name),(now()-t3)*1000) end
   if ok and r then
    local i=(bld.cy+bld.depth-1)*bm.w+bld.cx+math.floor(bld.width/2)+1
    bm.bmesh[#bm.bmesh+1]={mesh=r.mesh,image=r.image,bld=bld,m=bm,y=(bm.H[i] or 0)+bm.off+M.Y_MAP}
    G.bmeshes=(G.bmeshes or 0)+1
   elseif not ok then note('building %s of %s: %s',tostring(bld.name),bm.id,tostring(r)) end
   if #bm.bqueue==0 then bm.cells=nil end
  end
 end
 G.planMs=G.planMs+(now()-t1)*1000
end
function M.coverage(hx,hz,d)
 if not G then return 0,0 end
 local live,all=0,0
 local C16=M.CHUNK*16
 for _,c in ipairs(G.order)do if not c.near then
  local x0,z0=c.x0*16,c.y0*16
  local dx=hx<x0 and x0-hx or (hx>x0+C16 and hx-x0-C16 or 0)
  local dz=hz<z0 and z0-hz or (hz>z0+C16 and hz-z0-C16 or 0)
  if dx*dx+dz*dz<=d*d then all=all+1;if c.state=='live' then live=live+1 end end
 end end
 return live,all
end

local function cutPart(p,rect)
 local idx,n={},0
 local cells=p.cells
 for q=0,p.n-1 do
  local x,y=cells[q*2+1],cells[q*2+2]
  if not (x>=rect[1] and x<=rect[3] and y>=rect[2] and y<=rect[4]) then
   local b=q*4
   idx[n+1],idx[n+2],idx[n+3],idx[n+4],idx[n+5],idx[n+6]=b,b+1,b+2,b,b+2,b+3;n=n+6
  end
 end
 p.hidden=n==0
 if n==0 then return end
 local parts={}
 for s=1,n,PACK do
  local e=math.min(n,s+PACK-1)
  parts[#parts+1]=love.data.pack('string',string.rep('I4',e-s+1),unpack(idx,s,e))
 end
 local data=love.data.newByteData(table.concat(parts))
 pcall(p.mesh.setVertexMap,p.mesh,data,'uint32')
 data:release()
end
function M.cut(rect)
 if not G then return end
 local key=rect and table.concat(rect,',') or '-'
 local C=M.CHUNK
 for _,c in ipairs(G.order)do
  if c.state=='live' and c.cutKey~=key and (c.liveFrame or -1)<(G.frame or 0)-1 then
   local hit=rect and not (rect[3]<c.x0 or rect[1]>c.x0+C-1 or rect[4]<c.y0 or rect[2]>c.y0+C-1)
   if (hit or c.cut) and c.treeGroups and next(c.treeGroups) then
    releaseTrees(c);c.trees=buildTrees(c,hit and rect or nil)
   end
   if hit or c.cut then
    for _,p in ipairs(c.parts)do
     if p.mesh then
      if hit then cutPart(p,rect)
      else local view=fullView(p.n);pcall(p.mesh.setVertexMap,p.mesh,view,'uint32');view:release();p.hidden=false end
     end
    end
    c.cut=hit or nil
   end
   c.cutKey=key
  end
 end
end

local sea={}
local function seaPair()
 local Tiles=eng('src.core.game3.tileset_native')
 if sea.pair and Tiles._pairs[sea.pair] and Tiles._pairs[sea.pair].image then return Tiles._pairs[sea.pair] end
 for p,ts in pairs(Tiles._pairs)do
  if type(p)=='string' and p:match('^general__') and ts.image and ts.midToSlot and ts.midToSlot[M.SEA_MID] then sea.pair=p;return ts end
 end
end
function M.refreshSea()
 local ts=seaPair();if not ts then return false end
 if not sea.canvas then
  local ok,cv=pcall(love.graphics.newCanvas,16,16,{mipmaps='manual'})
  if not ok then ok,cv=pcall(love.graphics.newCanvas,16,16) end
  if not ok then return false end
  cv:setFilter('linear','nearest');cv:setWrap('repeat','repeat')
  if cv:getMipmapCount()>1 then pcall(cv.setMipmapFilter,cv,'linear') end
  sea.canvas=cv
 end
 local slot=ts.midToSlot[M.SEA_MID]
 local iw,ih=ts.image:getDimensions()
 local sx,sy=(slot%ts.cols)*16,floor(slot/ts.cols)*16
 if not sea.quad or sea.quadFor~=ts.image then sea.quad=love.graphics.newQuad(sx,sy,16,16,iw,ih);sea.quadFor=ts.image end
 local ok=pcall(function()
  love.graphics.push('all')
  love.graphics.setCanvas(sea.canvas)
  love.graphics.clear(0,0,0,1)
  love.graphics.setShader()
  love.graphics.setBlendMode('alpha')
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(ts.image,sea.quad,0,0)
  if ts.overImage then
   local ow,oh=ts.overImage:getDimensions()
   if ow==iw and oh==ih then love.graphics.draw(ts.overImage,sea.quad,0,0)end
  end
  love.graphics.pop()
  if sea.canvas:getMipmapCount()>1 then sea.canvas:generateMipmaps() end
 end)
 return ok
end
local function seaMesh()
 if sea.mesh then return sea.mesh end
 local n=floor(M.PLANE/M.PLANE_CELL)
 local cell=M.PLANE_CELL
 local f,k={},0
 for y=0,n-1 do for x=0,n-1 do
  local X,Z=(x-n/2)*cell,(y-n/2)*cell
  local u0,v0,u1,v1=X/16,Z/16,(X+cell)/16,(Z+cell)/16
  local q={X,0,Z,u0,v0,1, X+cell,0,Z,u1,v0,1, X+cell,0,Z+cell,u1,v1,1, X,0,Z+cell,u0,v1,1}
  for j=1,24 do f[k+j]=q[j] end
  k=k+24
 end end
 local ok,mesh=pcall(love.graphics.newMesh,R.FORMAT,n*n*4,'triangles','static')
 if not ok then return nil end
 local data=packFloats(f,k);local view=fullView(n*n)
 local ok2=pcall(function()mesh:setVertices(data,1);mesh:setVertexMap(view,'uint32')end)
 data:release();view:release()
 if not ok2 then mesh:release();return nil end
 sea.mesh=mesh
 return mesh
end
function M.warm()
 seaMesh();M.refreshSea()
end

function M.draw(draw,ox,oz,fx,fz,reach,oy)
 if not G then return 0 end
 local mesh=seaMesh()
 if mesh and sea.canvas then
  local sx,sz=floor(fx/16)*16,floor(fz/16)*16
  draw(mesh,sea.canvas,Mat.translate(sx,M.SEA-(oy or 0),sz))
 end
 local Tiles=eng('src.core.game3.tileset_native')
 local model=Mat.translate(-ox,-(oy or 0),-oz)
 local hx,hz=fx+ox,fz+oz
 local C16=M.CHUNK*16
 local r2=(reach+C16)^2
 local nearR2=(M.NEAR+C16*.75)^2
 for _,c in ipairs(G.order)do if not c.near and c.nearObj then c.nearDraw=false;if c.nearObj.state=='live' and c.nearObj.cutKey then local dx,dz=c.x0*16+C16/2-hx,c.y0*16+C16/2-hz;c.nearDraw=dx*dx+dz*dz<=nearR2 end end end
 local drawn=0
 for _,m in ipairs(G.maps)do for _,b in ipairs(m.bmesh or {})do
  local bld=b.bld
  local x0,y0=m.ox+bld.cx,m.oy+bld.cy
  local ca=G.byNum[(floor(y0/M.CHUNK)+2048)*4096+floor(x0/M.CHUNK)+2048]
  local cb=G.byNum[(floor((y0+bld.depth-1)/M.CHUNK)+2048)*4096+floor((x0+bld.width-1)/M.CHUNK)+2048]
  if ca and cb and ca.nearDraw and cb.nearDraw then draw(b.mesh,b.image,Mat.translate(m.ox*16-ox,b.y-(oy or 0),m.oy*16-oz));drawn=drawn+1 end
 end end
 for _,c in ipairs(G.order)do
  local show=c.near and c.parent.nearDraw or (not c.near and not c.nearDraw)
  if show and c.state=='live' and c.cutKey then
   local dx,dz=c.x0*16+C16/2-hx,c.y0*16+C16/2-hz
   if dx*dx+dz*dz<=r2 then
    for _,p in ipairs(c.parts)do
     if p.mesh and not p.hidden then
      local ts=Tiles._pairs[p.pair]
      if ts and ts.image then
       draw(p.mesh,ts.image,model)
       if ts.overImage then
        local ow,oh=ts.overImage:getDimensions();local iw,ih=ts.image:getDimensions()
        if ow==iw and oh==ih then draw(p.mesh,ts.overImage,model)end
       end
       drawn=drawn+1
      end
     end
    end
    if c.trees and #c.trees>0 then
     local img=V.require('NativeTreeArt').image()
     for _,b in ipairs(c.trees)do draw(b,img,model) end
    end
   end
  end
 end
 return drawn
end

return M
