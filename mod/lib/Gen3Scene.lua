-- Native FireRed art in the depth/shadow renderer
local V=...
local R=V.require('Voxel3D')
local Shadow=V.require('ShadowMap')
local Mat=V.require('Mat4')
local Shapes=V.require('Gen3TileShape')
local Pairs=V.require('Gen3Tilesets')
local Furniture=V.require('Gen3Furniture')
local Stairs=V.require('Gen3Stairs')
local SpriteAnchor=V.require('Gen3SpriteAnchor')
local Roof=V.require('Gen3RoofDetails')
local Outdoor=V.require('Gen3Outdoor')
local Terrain=V.require('Gen3Terrain')
local Mass=V.require('Gen3Mass')
local Elevation=V.require('Gen3Elevation')
local BattleClear=V.require('Gen3BattleClear')
local camArm={}
local Distance=V.require('RenderDistance')
local DebugWalk=V.require('DebugWalk')
local Boundary=V.require('Gen3Boundary')
local BoundarySelect=V.require('BoundaryScenery')
local SceneCache=V.require('Gen3SceneCache')
local Budget=V.require('BuildBudget')
local SceneStream=V.require('SceneStream')
local Forest=V.require('Gen3Forest')
local Interior=V.require('InteriorDiorama')
local TreeStyle=V.require('TreePresentation')
local Standing=V.require('Gen3Objects')
local Landmarks=V.require('LandmarkModels')
local RockSprites=V.require('Gen3RockSprites')
local Canopy=V.require('Gen3Canopy')
local Decks=V.require('Gen3Decks')
local BuildingModels=V.require('BuildingModels')
local VoxelBuildings=V.require('Gen3VoxelBuildings')
local Map=require('src.core.game3.map')
local Tiles=require('src.core.game3.tileset_native')
local Sprites=require('src.core.game3.ow_sprites')
local Player=require('src.core.game3.player')
local Objects=require('src.core.game3.objects')
local Versions=require('src.import.gba.versions')
local M={builds=0}
local SEA_LEVEL_MAPS={EM_SLATEPORT_CITY=true}
local CANOPY_HEIGHT=32
local FORTREE_V2=true
local WATER_LAP=.06
local DECK_THICKNESS=6
local DECK_FAMILY={general__fortree={[0x210]=1,[0x211]=1,[0x212]=1,[0x213]=1,[0x214]=1,[0x215]=1,[0x216]=1,[0x217]=1,[0x218]=1,[0x219]=1,[0x21A]=1,[0x21B]=1,[0x21C]=1,[0x21D]=1,
 [0x256]=1}}
local function isDeck(c)
 if c.shape and (c.shape.underWater or c.shape.underGrass) then return true end
 if not c.floor then return false end
 if c.floor.layer==15 and (c.collision==0 or (c.collision or 0)>7) then return true end -- cave bridges carry a map-specific collision code (Victory Road: 43), never 1..7
 if c.collision~=0 then return false end
 local fam=DECK_FAMILY[c.pair];return fam and fam[c.mid] or false
end
function M.context()return Map.currentDef()end
local cache,spriteMeshes={ },{}
local savedCanvas,saved=false,false
local PROBE={}
local function quad(v,i,p,uv,shade,anchor)
 Budget.tick()
 if M.probeBox and PROBE.cell then
  M.probeCell=PROBE.cell
  local B=M.probeBox
  for _,a in ipairs(p)do if a[1]>B[1] and a[1]<B[2] and a[3]>B[3] and a[3]<B[4] then
   local k=M.probeCell.cx..','..M.probeCell.cy..' y'..math.floor(p[1][2])..'..'..math.floor(p[3][2])..' sh'..tostring(shade)
   M.probeSeen=M.probeSeen or {}
   if not M.probeSeen[k] then M.probeSeen[k]=true;print('[EM box]',k,string.format('%03X',M.probeCell.mid or 0),M.probeCell.shape and M.probeCell.shape.kind,'base',M.probeCell.base) end
   break end end
 end
 if M.probeY and p[1][2]>=M.probeY then
  local k=math.floor(p[1][1]/16)..','..math.floor(p[1][3]/16)
  M.probeHits=M.probeHits or {};M.probeHits[k]=(M.probeHits[k] or 0)+1
 end
 local base=#v
 local s=shade or 1
 for k=1,#p do
  local a,t=p[k],uv[k]
  local vertex={a[1],a[2],a[3],t[1],t[2],s}
  if anchor then vertex[7],vertex[8],vertex[9]=anchor[1],anchor[2],anchor[3]end
  v[base+k]=vertex
 end
 local n=#i
 i[n+1],i[n+2],i[n+3],i[n+4],i[n+5],i[n+6]=base+1,base+2,base+3,base+1,base+3,base+4
end
local uvMemo=setmetatable({},{__mode='k'})
local function uvFor(ts,mid)
 if mid==nil or ts==nil then return end
 local memo=uvMemo[ts];if not memo then memo={};uvMemo[ts]=memo end
 local hit=memo[mid];if hit~=nil then return hit or nil end
 local slot=ts.midToSlot[mid];if not slot then memo[mid]=false;return end
 local x,y=slot%ts.cols,math.floor(slot/ts.cols)
 local l,r=(x+.005)/ts.cols,(x+.995)/ts.cols
 local t,b=(y+.005)/ts.rows,(y+.995)/ts.rows
 hit={{l,t},{r,t},{r,b},{l,b}};memo[mid]=hit
 return hit
end
local PIER_THICK=3
local NO_SLOPE={0,0,0,0}
local SLOPE_EDGE={['-1:0']={1,4,2,3},['1:0']={2,3,1,4},['0:-1']={1,2,4,3},['0:1']={4,3,1,2}}
local function plane(v,i,x,z,uv,h)
 quad(v,i,{{x,h or 0,z},{x+16,h or 0,z},{x+16,h or 0,z+16},{x,h or 0,z+16}},uv)
end
local FLIGHT_TREADS={general__mauville={[0x2D4]=8},general__mossdeep={[0xAF]=2,[0xCF]=2},general__lilycove={[0xAF]=2,[0xCF]=2},general__sootopolis={[0x244]=2,[0x245]=2}}
local FLIGHT_TREADS_DEFAULT=4
local function flightAxis(c,cells)
 local f=c.floor
 if not(f and f.step) or c.shape.kind~='flat' or c.base==nil then return nil end
 local B=c.base
 for _,ax in ipairs({{{0,-1},{0,1}},{{-1,0},{1,0}}})do
  local a=cells[(c.cx+ax[1][1])..':'..(c.cy+ax[1][2])]
  local b=cells[(c.cx+ax[2][1])..':'..(c.cy+ax[2][2])]
  if a and b then
   local da,db=(a.base or 0)-B,(b.base or 0)-B
   if da>.5 and db<-.5 then return {up=ax[1],down=ax[2],rise=da,dhi=a,dlo=b} end
   if db>.5 and da<-.5 then return {up=ax[2],down=ax[1],rise=db,dhi=b,dlo=a} end
   local open=ax[1][1]==0 and a.collision~=7 and b.collision~=7 and not (a.shape and (a.shape.kind=='cliff' or a.shape.kind=='rock'))
    and not (b.shape and (b.shape.kind=='cliff' or b.shape.kind=='rock'))
   if open and da-db>.5 and da>-.5 and db<.5 then return {up=ax[1],down=ax[2],rise=da-db,dhi=a,dlo=b} end
   if open and db-da>.5 and db>-.5 and da<.5 then return {up=ax[2],down=ax[1],rise=db-da,dhi=b,dlo=a} end
  end
 end
 return nil
end
local function flightTreads(c,fl,cells,b,uv)
 local sm=c.floor and c.floor.stepMid
 if sm then uv=uvFor(c.ts,sm) or uv end
 local T=(FLIGHT_TREADS[c.pair] and FLIGHT_TREADS[c.pair][sm or c.mid]) or FLIGHT_TREADS_DEFAULT
 local B,R=c.base,fl.rise
 if fl.dlo and fl.dhi and fl.dlo.base and fl.dhi.base and fl.dlo.base<B-.5 and not (fl.dlo.floor and fl.dlo.floor.step) and not (fl.dhi.floor and fl.dhi.floor.step) then
  B=fl.dlo.base;R=fl.dhi.base-B
 end
 local x0,z0=c.cx*16,c.cy*16
 local across=fl.up[1]~=0 -- flight runs east-west: width is z
 local function P(t,w,h)
  local d=t
  if fl.up[1]>0 or fl.up[2]>0 then d=t else d=16-t end
  if across then return x0+d,h,z0+w end
  return x0+w,h,z0+d
 end
 local function vt(f) return uv[1][2]+(uv[3][2]-uv[1][2])*f end
 local function ut(f) return uv[1][1]+(uv[2][1]-uv[1][1])*f end
 local function Q(p,uvs,shade)quad(b.v,b.i,p,uvs,shade)end
 local dlo=fl.dlo
 if dlo and dlo.base and dlo.base<B-.5 then
  plane(b.v,b.i,x0,z0,uvFor(dlo.ts,dlo.mid) or uv,dlo.base)
  local rv0=vt(1-.5/T)
  local dx,dy,dz=P(0,0,dlo.base);local ex,ey,ez=P(0,16,dlo.base);local fx,fy,fz=P(0,16,B);local gx,gy,gz=P(0,0,B)
  Q({{dx,dy,dz},{ex,ey,ez},{fx,fy,fz},{gx,gy,gz}},{{ut(0),rv0},{ut(1),rv0},{ut(1),rv0},{ut(0),rv0}},.78)
 end
 for k=0,T-1 do
  local t0,t1=16*k/T,16*(k+1)/T
  local H=B+(k+1)*R/T
  local v0,v1=vt(1-t0/16),vt(1-t1/16)
  local ax,ay,az=P(t0,0,H);local bx,by,bz=P(t0,16,H);local cx_,cy,cz=P(t1,16,H);local dx,dy,dz=P(t1,0,H)
  Q({{ax,ay,az},{bx,by,bz},{cx_,cy,cz},{dx,dy,dz}},{{ut(0),v0},{ut(1),v0},{ut(1),v1},{ut(0),v1}},1)
  local lo=B+k*R/T
  local rv=vt(1-(k+.5)/T)
  local rx,ry,rz=P(t0,0,lo);local sx,sy,sz=P(t0,16,lo)
  Q({{rx,ry,rz},{sx,sy,sz},{sx,H,sz},{rx,H,rz}},{{ut(0),rv},{ut(1),rv},{ut(1),rv},{ut(0),rv}},.78)
  for _,side in ipairs({{0,ut(.5/16)},{16,ut(15.5/16)}})do
   local sw=side[1]
   local n=across and cells[(c.cx)..':'..(c.cy+(sw==0 and -1 or 1))] or cells[(c.cx+(sw==0 and -1 or 1))..':'..c.cy]
   local nb=n and n.base or 0
   if n and nb<H-.5 and not (n.shape and n.shape.kind=='cliff') then
    local low=nb
    if low<H then
     local px0,py0,pz0=P(t0,sw,low);local px1,py1,pz1=P(t1,sw,low)
     local px2,py2,pz2=P(t1,sw,H);local px3,py3,pz3=P(t0,sw,H)
     Q({{px0,py0,pz0},{px1,py1,pz1},{px2,py2,pz2},{px3,py3,pz3}},{{side[2],vt(1-t0/16)},{side[2],vt(1-t1/16)},{side[2],vt(1-t1/16)},{side[2],vt(1-t0/16)}},.7)
    end
   end
  end
 end
end
local wallColumn
local function swatch(ts,u,v)
 u=(math.floor(u*ts.cols*16)+.5)/(ts.cols*16)
 v=(math.floor(v*ts.rows*16)+.5)/(ts.rows*16)
 return {{u,v},{u,v},{u,v},{u,v}}
end
local wallColumns=setmetatable({},{__mode='k'})
function wallColumn(ts,mid,fallback)
 if not ts.imageData then return fallback end
 local cache=wallColumns[ts];if not cache then cache={};wallColumns[ts]=cache end
 if cache[mid]~=nil then return cache[mid] or fallback end
 local slot=ts.midToSlot[mid];if not slot then cache[mid]=false;return fallback end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local best,score
 local stat,means={},{}
 for x=1,14 do
  local sum,sq,n=0,0,0
  for y=0,15 do
   local ok,r,g,b,a=pcall(ts.imageData.getPixel,ts.imageData,ox+x,oy+y)
   if ok and (a or 0)>.5 then local l=.3*r+.59*g+.11*b;sum=sum+l;sq=sq+l*l;n=n+1 end
  end
  if n>=12 then local mean=sum/n;stat[x]={mean,sq/n-mean*mean};means[#means+1]=mean end
 end
 table.sort(means)
 local med=means[math.ceil(#means/2)]
 for x=1,14 do local st=stat[x]
  if st then
   local s=st[2]*4+(st[1]<.3 and 1 or 0)+2*math.abs(st[1]-med)+math.abs(x-7.5)*.002
   if not score or s<score then best,score=x+.5,s end
  end
 end
 cache[mid]=best or false
 return best or fallback
end
local AMBIENT={dust=true,feet_water=true,ripple=true,splash=true,tracks=true,hot_springs=true,emote=true}
function M.nativeEffects(anims)
 for _,a in ipairs(anims or {})do if type(a)~='table' or not AMBIENT[a.kind] then return true end end
 return false
end
function M.nativeRequired(game)
 local def=Map.currentDef()
 if not (def and def.midLayout) then return true end
 local spec=Pairs.resolve(def.midLayout.pair,Versions.TILESET_PAIRS)
 if not Pairs.supports(def,spec) then return true end
 local Shop=require('src.ui.game3.shop_menu')
 local Fx=require('src.core.game3.field_effects')
 local Special=require('src.core.game3.special_field_anim')
 local Transition=package.loaded['src.core.game3.battle_transition']
 local Warp=require('src.core.game3.warp')
 local escalator=Warp.isEscalatorActive and Warp.isEscalatorActive()
 return (Transition and Transition.isActive and Transition.isActive())
  or (Special.isActive and Special.isActive() and not (escalator or Special.isEscalatorMoving and Special.isEscalatorMoving())) or M.nativeEffects(Fx._anims)
  or (Shop.isShopCamera and Shop.isShopCamera()) or (def.cave==1 and (game.session.flashLevel or 0)>0)
end
local function releaseGeometry(cache)
 for _,part in ipairs(cache.parts or {})do
  if part.under then part.under:release() end
  if part.over then part.over:release() end
  if part.canopy then part.canopy:release() end
  if part.roof then part.roof:release() end
  if part.plants then part.plants:release() end
  if part.water then part.water:release() end
  for _,water in ipairs(part.waters or {})do water.mesh:release()end
 end
 for _,bld in ipairs(cache.buildingModels or {})do
  if bld.mesh then bld.mesh:release()end;if bld.image then bld.image:release()end
  if bld.imageData and bld.imageData.release then bld.imageData:release()end
 end
 for _,batch in ipairs(cache.treeInstances or {})do batch:release()end
 if cache.leaves then cache.leaves:release() end
 V.require('Gen3Lamp').release(cache)
end
local stream=SceneStream.new(releaseGeometry,3)
stream.keepStale=true
M.streaming=stream.stats
-- The engine keeps few tilesets resident: a re-decoded pair must not restart a build.
local tileMemo,tileOwner={},nil
local function tileIdentity(regions)
 if tileOwner~=Tiles._pairs then tileMemo,tileOwner={},Tiles._pairs end
 local tiles,memo={},{}
 for _,r in ipairs(regions)do
  local pair=r.def.midLayout.pair
  if pair then
   local ts=tileMemo[pair] or Tiles._pairs[pair]
   tiles[pair],memo[pair]=ts,ts
  end
 end
 tileMemo=memo
 return tiles
end
local TILE_WAIT=180
M.TILE_PATIENCE=8
M.TILE_PATIENCE_NEIGHBOUR=2
local tileWait,frames=0,0
local tilesetWaiting={}
local function tilesetsReady(req)
 local ready,decoded=true,false
 for i,r in ipairs(req.regions)do
  local pair=r.def.midLayout.pair
  local reach=i==1 or not req.x0 or (r.x<=req.x1+1 and r.x+r.w>=req.x0-1 and r.y<=req.z1+1 and r.y+r.h>=req.z0-1)
  if pair and reach and not req.tiles[pair]then
   ready=false
   local since=tilesetWaiting[pair] or frames;tilesetWaiting[pair]=since
   local patience=i==1 and 0 or M.TILE_PATIENCE_NEIGHBOUR
   if frames-since>=patience and not decoded then decoded=true;Tiles.get(pair)
   else Tiles.prefetch(pair,0)end
  end
 end
 if ready then tilesetWaiting={}end
 return ready
end
M.NEAR=14
local CROWN={edges=.45}
M.NEAR_NORTH=8
M.NEAR_STREAM=.005
M.STREAM=.008
M.DEBUG_REACH=32
M.DEBUG_PAD=16
M.DEBUG_COLD=.120
local function walkGate(cam)
 return DebugWalk.on() and not (cam and (cam.battle or cam.replay))
end
local function directNeighbours()
 local ids={}
 for _,n in ipairs(Map.neighborList or {})do if n.map then ids[n.map]=true end end
 for _,n in pairs(Map.neighbors or {})do if n.map then ids[n.map]=true end end
 return ids
end
local function debugRegions(def)
 local ids=directNeighbours()
 local world={}
 for _,e in ipairs(Map.world or {})do if ids[e.id]then world[#world+1]=e end end
 return Boundary.regions(def,world)
end
local function tourBounds(regions,bx,bz)
 local x0,z0,x1,z1=BoundarySelect.bounds(regions,M.DEBUG_PAD)
 local reach=M.DEBUG_REACH
 if x1-x0>reach*2+6 or z1-z0>reach*2+6 then
  return math.max(x0,bx-reach),math.max(z0,bz-reach),math.min(x1,bx+reach+6),math.min(z1,bz+reach+6)
 end
 return x0,z0,x1,z1
end
local function request(game,cam,near)
 local replay=cam and cam.replay
 local def=replay and replay.def or Map.currentDef();if not def or not def.midLayout then return false end
 local px,pz=replay and replay.frame.x or Player.px or 0,replay and replay.frame.y or Player.py or 0
 local bx,bz=math.floor(px/96)*6,math.floor(pz/96)*6
 local debugWalk=walkGate(cam)
 Distance.forceFull=debugWalk
 local budget=Distance.radius()
 local radius=budget and math.ceil(budget/16)or 64
 if not replay then
  if debugWalk then
   Map.refreshWorld(game,M.DEBUG_REACH,M.DEBUG_REACH,Map.current)
  else
   Map.refreshWorld(game,radius*2+12,radius*2+12,Map.current)
  end
 end
 local regions
 if replay then
  regions={{def=def,x=0,y=0,w=def.midLayout.width,h=def.midLayout.height}}
 elseif debugWalk then
  regions=debugRegions(def)
 else
  regions=Boundary.regions(def,Map.world)
 end
 if not replay then Boundary.setWorld(game.data.maps) end
 local x0,z0,x1,z1=bx-radius,bz-radius,bx+radius+6,bz+radius+6
 if debugWalk then x0,z0,x1,z1=tourBounds(regions,bx,bz)
 elseif not budget then x0,z0,x1,z1=BoundarySelect.bounds(regions,16)end
 if near and not debugWalk and not replay and near<radius then
  radius=near;budget=near*16
  local north=(cam and (cam.level or 0)<6) and M.NEAR_NORTH or 0
  x0,z0,x1,z1=math.max(x0,bx-radius),math.max(z0,bz-radius-north),math.min(x1,bx+radius+6),math.min(z1,bz+radius+6-north)
 end
 local tiles=tileIdentity(regions)
 local context=SceneCache.key(regions,0,0,0,0,tiles,cam)
 local key=SceneCache.key(regions,x0,z0,x1,z1,tiles,cam)
 return {game=game,cam=cam,replay=replay,def=def,regions=regions,key=key,tiles=tiles,
  context=not (replay or cam.battle) and context or nil,
  x0=x0,z0=z0,x1=x1,z1=z1,px=px,pz=pz,radius=radius,budget=budget}
end
local VOID_BY_MAP=V.require('InteriorDiorama').VOID_BY_MAP
local CABINS=V.require('InteriorDiorama').CABINS
local RISER_PX={[0]={1,8},[0x263]={2,8},[0x264]={2,8},[0x26F]={2,8},[0x277]={2,8}}
local WALL_TRIM={EM_NEW_MAUVILLE_INSIDE={[0x26E]=8}}
local Reef=V.require('Gen3Reef')
local SHAPE_BY_MAP=V.require('Gen3ShapesByMap').shapes
local shiftedLathes=setmetatable({},{__mode='k'})
local function shiftedLathe(o,dx,dy)
 local by=shiftedLathes[o];if not by then by={};shiftedLathes[o]=by end
 local k=dx..':'..dy
 if not by[k] then
  local l={};for key,v in pairs(o.lathe)do l[key]=v end
  l.x0,l.x1,l.y0,l.y1=o.lathe.x0+dx,o.lathe.x1+dx,o.lathe.y0+dy,o.lathe.y1+dy
  local sh={};for key,v in pairs(o)do sh[key]=v end
  sh.lathe=l;by[k]=sh
 end
 return by[k]
end
local RAIL_EDGE={[0x316]=true,[0x31E]=true,[0x321]=true,[0x315]=true,[0x320]=true,[0x322]=true}
local RAIL_POSTS={[0x315]=true,[0x316]=true,[0x31E]=true}
local RAIL_ROCK={[0x312]=true,[0x314]=true}
local OPEN_SKY={EM_LILYCOVE_CITY_DEPARTMENT_STORE_ROOFTOP=true,EM_TRAINER_HILL_ROOF=true,EM_BIRTH_ISLAND_HARBOR=true,EM_NAVEL_ROCK_HARBOR=true,
 EM_BIRTH_ISLAND_EXTERIOR=true,EM_FARAWAY_ISLAND_ENTRANCE=true,EM_FARAWAY_ISLAND_INTERIOR=true,EM_NAVEL_ROCK_EXTERIOR=true}
M.OPEN_SKY=OPEN_SKY
local firstArea=false
function M.firstArea()return firstArea end
local function build(req,cache,previous)
 local cam,replay,def,regions=req.cam,req.replay,req.def,req.regions
 local x0,z0,x1,z1=req.x0,req.z0,req.x1,req.z1
 firstArea=M.NEAR~=nil and req.budget~=nil and req.radius==M.NEAR and not cam.battle and not replay and not req.upgrade
 cache.firstAreaBuilt=firstArea
 V.require('Gen3Objects').newBuild();V.require('Gen3Mass').newBuild();V.require('Gen3Terrain').newBuild();V.require('Gen3Planter').newBuild()
 local M=cache -- Publish geometry and its metadata together, never halfway.
 local marks={};cache.buildTimes=marks
 local CamClear=V.require('Gen3CamClear');cache.solid=CamClear.new() -- (solid tops for the camera arm, see Gen3CamClear)
 local function mark(name)marks[#marks+1]=name..' '..math.floor(stream.stats.buildMs or 0)end
 M.sceneDef=def
 M.distance={radius=req.radius,full=not req.budget,regions=#regions,bounds={x0,z0,x1,z1}}
 M.fadeExtent=req.budget or math.max(math.abs(x0*16-req.px),math.abs(x1*16-req.px),math.abs(z0*16-req.pz),math.abs(z1*16-req.pz))
 local cells,groups,signature={}, {}, {replay and replay.scene.map or Map.current,x0,z0,x1,z1}
 M.fillCounts={forest=0,water=0,mountain=0,ground=0}
 for cy=z0,z1 do for cx=x0,x1 do
  Budget.tick()
  local mid,pair,isVoid
  if replay then
   local tile=replay.scene.tiles and replay.scene.tiles[cx..','..cy]
   isVoid=cx<0 or cy<0 or cx>=def.midLayout.width or cy>=def.midLayout.height
   if tile then mid,pair,isVoid=tile[1],tile[2],false
   elseif not isVoid then mid,pair=def.midLayout:midAt(cx,cy),def.midLayout.pair end
  else mid,pair,isVoid=Map.worldMidAt(cx,cy,def)end
  if mid and not isVoid and def.id and VOID_BY_MAP[def.id] and VOID_BY_MAP[def.id][mid] then isVoid=true end
  local fillShape,biome
  if isVoid and Pairs.outdoor(def) then
   local m,p,shape,kind=Boundary.resolve(regions,cx,cy)
   if m then mid,pair,fillShape,biome=m,p,shape,kind;M.fillCounts[kind]=M.fillCounts[kind]+1 end
  end
  if mid and pair and not (isVoid and not Pairs.outdoor(def)) then
   local ts=groups[pair]
   if not ts then
    ts=Tiles._pairs[pair] or Tiles.get(pair);groups[pair]=ts
   end
   if ts and ts.midToSlot[mid] then
    local spec=Pairs.resolve(pair,Versions.TILESET_PAIRS)
    local collision,regionId
    for _,region in ipairs(regions)do
     local lx,ly=cx-region.x,cy-region.y
     if lx>=0 and ly>=0 and lx<region.w and ly<region.h then collision=region.def.midLayout:collAt(lx,ly);regionId=region.def.id;break end
    end
    local c={mid=mid,behavior=(require('src.core.game3.scripting.interaction_scripts').behaviors[pair] or {})[mid],collision=collision,pair=pair,nativePair=pair,cx=cx,cy=cy,ts=ts,primary=spec.primary,secondary=spec.secondary,
     shape=fillShape or Shapes.of(spec.primary,spec.secondary,mid,
      (require('src.core.game3.scripting.interaction_scripts').behaviors[pair] or {})[mid],collision),boundary=biome}
    V.require('GlassMask').door(ts,c.mid,c.behavior)
    if c.mid==0x201 and spec.secondary=='facility' and def.id and def.id:find('MT_PYRE') and c.shape and c.shape.kind=='roomWall' then c.mid=0x2F7 end
    do local ov=def.id and not isVoid and cx>=0 and cy>=0 and cx<def.midLayout.width and cy<def.midLayout.height and SHAPE_BY_MAP[def.id];local o=ov and ov[mid]
     if type(o)=='function' then o=o(cx,cy,collision) end
     if not o and ov and ov.at then o=ov.at(cx,cy,mid,collision) end
     if o and not (o.kind=='extrude' and (collision or 0)==0) and not (o.kind=='obwall' and (collision or 0)==0 and not o.walkOk) then c.shape=o;c.noFurniture=o.noFurniture end end
    if not (def.id and not isVoid and cx>=0 and cy>=0 and cx<def.midLayout.width and cy<def.midLayout.height) then
     for _,region in ipairs(regions)do
      local lx,ly=cx-region.x,cy-region.y
      if region.def~=def and region.def.id and lx>=0 and ly>=0 and lx<region.w and ly<region.h then
       local rs=SHAPE_BY_MAP[region.def.id];local o=rs and rs[mid]
       if region.def.id=='EM_SLATEPORT_CITY' then
        local market=V.require('Gen3Market').shape(lx,ly,mid)
        if market then c.shape=market;c.noFurniture=true end
       end
       if type(o)=='table' and o.kind=='lathe' and o.lathe and (region.x~=0 or region.y~=0) then c.shape=shiftedLathe(o,region.x,region.y) end
       break
      end
     end
    end
    if Reef.maps[regionId] and c.primary=='general' and Reef.tiles[mid] then
     c.shape={kind='water',reef=true,level=0}
    end
    if c.shape and (c.shape.kind=='obwall' or c.shape.kind=='partition' or c.shape.noFurniture) then c.noFurniture=true end
    cells[cx..':'..cy]=c
    signature[#signature+1]=pair..'/'..mid..'/'..tostring(collision)..(biome or '')
   else signature[#signature+1]='?' end
  else signature[#signature+1]='-' end
 end end
 Tiles.get(def.midLayout.pair)
 for pair,ts in pairs(groups)do signature[#signature+1]=pair..tostring(ts) end
 -- ground only, never yaw: see Gen3SceneCache
 if cam and cam.battle then signature[#signature+1]=table.concat({'battle',cam.center[1],cam.center[2]},':')end
 local sig=SceneCache.key(regions,x0,z0,x1,z1,Tiles._pairs,cam) or table.concat(signature,';')
 if firstArea then sig=sig..';first' end
 if previous and previous.signature==sig then return previous end
 Reef.join(cells)
 cache.signature=sig;cache.parts={};cache.cells=cells
 local treeGroups={}
 mark('cells')
 if CROWN.edges then
  local leafy={}
  for _,c in pairs(cells)do
   local sh=c.shape
   if sh and (c.collision or 0)~=0 and (sh.kind=='flat' or sh.kind=='wall') and not sh.reviewedSurface and not (c.prop or c.bldModel or c.civic) and c.ts and c.ts.imageData then
    local ts=c.ts;local t=leafy[ts];if not t then t={};leafy[ts]=t end
    local r=t[c.mid]
    if r==nil then
     r=false
     local slot,gs=ts.midToSlot[c.mid],ts.midToSlot[0x001]
     if slot and gs then
      local ground={}
      for y=0,15 do for x=0,15 do local rr,gg,bb=ts.imageData:getPixel(gs%ts.cols*16+x,math.floor(gs/ts.cols)*16+y);ground[math.floor(rr*255)*65536+math.floor(gg*255)*256+math.floor(bb*255)]=true end end
      local n=0
      for y=0,15 do for x=0,15 do
       local px,py=slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y
       local rr,gg,bb=ts.imageData:getPixel(px,py)
       if ts.overImageData then local r2,g2,b2,a2=ts.overImageData:getPixel(px,py);if a2>.5 then rr,gg,bb=r2,g2,b2 end end
       if gg>rr*1.1 and gg>bb*1.05 and not ground[math.floor(rr*255)*65536+math.floor(gg*255)*256+math.floor(bb*255)] then n=n+1 end
      end end
      r=n>=CROWN.edges*256
     end
     t[c.mid]=r
    end
    if r then
     for dy=-1,1 do for dx=-1,1 do
      local n=cells[(c.cx+dx)..':'..(c.cy+dy)]
      if n and n~=c and n.shape and n.shape.kind=='tree' then c.shape={kind='flat',reviewedSurface=true,groundMid=0x001,crownEdge=true};c.column=nil;goto done end
     end end
     ::done::
    end
   end
  end
 end
 local bldModels=BuildingModels.prepare(cells,def,regions);M.buildingCount=#bldModels
 mark('buildings')
 M.forestTrees=Forest.prepare(cells)
 Elevation.daisPrepare(cells,def)
 Decks.prepare(cells,def)
 local setBack=Decks.MAPS[def.id or ''] and true or false
 M.stairCount=Stairs.prepare(cells)
 Stairs.flatten(cells)
 local props=Furniture.extract(cells)
 cache.openings={}
 for _,p in ipairs(props)do if p.recipe.noGround and p.recipe.down then
  cache.openings[#cache.openings+1]={p.cx*16,p.cy*16,(p.cx*16)+p.w,(p.cy*16)+p.d}
 end end
 for _,c in pairs(cells)do if c.stairs and c.stairs.owner==c and c.stairs.r.down then
  local s=c.stairs;cache.openings[#cache.openings+1]={s.cx*16,s.cy*16,(s.cx+s.width)*16,(s.cy+#s.r.rows)*16}
 end end
 Shapes.layout(cells)
 Outdoor.groundProps(cells)
 M.bankCount=Standing.bank(cells,Pairs.outdoor(def))
 M.rockJoined=Standing.joinRock(cells,Pairs.outdoor(def))
 mark('prepares')
 M.objectCount=#Standing.prepare(cells,Pairs.outdoor(def))
 V.require('Gen3TreeStamps').claim(cells)
 Elevation.bind(cells,regions)
 -- PLATEAU RULE: on hand-drawn maps Gen3Blocks builds the rock; hill/rock/mass builders skip it.
 M.blocksCount=V.require('Gen3Blocks').prepare(cells,regions,def)
 for _,c in pairs(cells)do if c.shape and c.shape.level and c.base~=c.shape.level then c.base=c.shape.level;c.floorHigh=nil end end
 if def and SEA_LEVEL_MAPS[def.id] then
  local w,h=def.midLayout.width,def.midLayout.height
  for _,c in pairs(cells)do
   if c.shape and c.shape.kind=='water' and not c.shape.river and (c.base or 0)~=0 then c.base=0;c.floorHigh=nil end
  end
  for _=1,8 do
   local turn={}
   for _,c in pairs(cells)do
    if c.shape and c.shape.kind=='cliff' and (c.mid==0x164 or c.mid==0x16C) and c.cx>=0 and c.cy>=0 and c.cx<w and c.cy<h then
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
      if n and n.shape and n.shape.kind=='water' and not n.shape.river then turn[#turn+1]={c,n};break end
     end
    end
   end
   if #turn==0 then break end
   for _,t in ipairs(turn)do local c,n=t[1],t[2];c.shape=n.shape;c.mid=n.mid;c.base=0;c.floorHigh=nil end
  end
 end
 do
  local seen={}
  for _,c0 in pairs(cells)do if c0.shape and c0.shape.river and not seen[c0] then
   local comp,st,low={},{c0},nil;seen[c0]=true
   while #st>0 do
    local c=table.remove(st);comp[#comp+1]=c
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.shape then
      if n.shape.river then if not seen[n] then seen[n]=true;st[#st+1]=n end
      elseif n.shape.underWater then
      elseif (n.collision or 0)==0 or (n.shape.kind=='water' and not n.shape.river and (n.base or 0)==0) then
       low=math.min(low or 1e9,n.base or 0)
      end
     end
    end
   end
   low=low or 0
   for _,c in ipairs(comp)do if c.floor and c.floor.cls=='WATER' and c.base then low=math.min(low,c.base) end end
   for _,c in ipairs(comp)do c.base=low;c.floorHigh=nil end
   for _,c in ipairs(comp)do for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and n.shape and n.shape.underWater then n.riverLevel=low end
   end end
  end end
  for _=1,4 do for _,c in pairs(cells)do if c.shape and c.shape.underWater and not c.riverLevel then
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and n.riverLevel then c.riverLevel=n.riverLevel;break end end
  end end end
 end
 do
  local fix={}
  for _,c in pairs(cells)do if c.shape and c.shape.kind=='water' and not c.shape.river and (c.collision or 0)~=0 and (c.base or 0)>0 then
   local low
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and n.shape and n.shape.kind=='water' and (n.collision or 0)==0 then low=math.min(low or 1e9,n.base or 0) end
   end
   if low and low<(c.base or 0) then fix[c]=low end
  end end
  for c,h in pairs(fix)do c.base=h;c.floorHigh=nil end
 end
 do
  local fix={}
  for _,c in pairs(cells)do if c.shape and c.shape.seaRock and (c.base or 0)>0 then
   local low
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and n.shape and n.shape.kind=='water' then low=math.min(low or 1e9,n.base or 0) end
   end
   if low and low<(c.base or 0) then fix[c]=low end
  end end
  for c,h in pairs(fix)do c.base=h;c.floorHigh=nil end
 end
 for _,c in pairs(cells)do
  if c.mid==0x002 and c.primary=='general' and c.shape and c.shape.kind=='flat' and not c.shape.groundMid then
   local n=cells[c.cx..':'..(c.cy-1)]
   if n and (n.base or 0)<(c.base or 0)-4 then
    local sh={};for k,v in pairs(c.shape)do sh[k]=v end;sh.groundMid=0x001;c.shape=sh
   end
  end
 end
 if def.id=='EM_ROUTE110' then
  local SEA={[0x150]=true,[0x151]=true,[0x158]=true,[0x159]=true,[0x173]=true}
  for _,c in pairs(cells)do if c.pair=='general__mauville' and (SEA[c.mid] or (c.shape and c.shape.kind=='water' and not c.shape.cyclingRoad and c.cx<7)) then c.base=0;c.floorHigh=nil end end
 end
 mark('objects')
 do local low={}
  for _,c in pairs(cells)do local o=c.object or c.objectTop
   if o and c.shape and c.shape.seaRock then low[o]=math.min(low[o] or 1e9,c.base or 0) end end
  for _,c in pairs(cells)do local o=c.object or c.objectTop
   if o and low[o] and c.shape and c.shape.seaRock then c.base=low[o];c.floorHigh=nil end end
 end
 V.require('Gen3CyclingRoad').settle(cells)
 Elevation.daisSettle(cells,def)
 Decks.settle(cells,def)
 for _=1,256 do local moved=false
  for _,c in pairs(cells)do
   if c.shape and c.shape.kind=='water' and (c.collision or 0)~=0 and (c.base or 0)>0 then
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.shape and n.shape.kind=='water' and (n.base or 0)<c.base then c.base=n.base or 0;moved=true end
    end
   end
  end
  if not moved then break end
 end
 V.require('Gen3Rock').mapId=def and def.id
 V.require('Gen3Rock').cave(def)
 if V.require('Gen3Rock').CAVES[def.id or ''] then
  for _,c in pairs(cells)do
   local k=c.shape and c.shape.kind
   if (k=='flat' or k=='rock') and c.collision==7 and not (c.prop or c.stairs or c.object or c.objectTop or c.civic or c.bldModel or c.column or c.noFurniture)
     and c.cx>=0 and c.cy>=0 and c.cx<def.midLayout.width and c.cy<def.midLayout.height and c.ts and c.ts.midToSlot[c.mid] then
    c.shape={kind='caveWall',height=28,ground=c.shape.ground,cap=c.mid,side=c.mid,fromBlocked=tonumber(def.mapType)~=9}
   end
   if c.collision==7 and (k=='caveWall' or k=='cliff' or k=='flat' or k=='rock') and not c.prop then
    for dx=-1,1 do
     local m=cells[(c.cx+dx)..':'..(c.cy-1)]
     if m and m.collision==114 then c.shape={kind='flat',reviewedSurface=true};c.noFurniture=true;k=nil;break end
    end
   end
   if c.prop and (k=='cliff' or k=='caveWall') and c.cx>=0 and c.cy>=0 and c.cx<def.midLayout.width and c.cy<def.midLayout.height then
    c.shape={kind='flat',ground=c.shape.ground,reviewedSurface=true};k=nil
   end
   if (k=='cliff' or k=='caveWall') and c.collision~=nil and c.collision~=7 and c.collision~=255 and not (c.prop or c.stairs)
     and c.cx>=0 and c.cy>=0 and c.cx<def.midLayout.width and c.cy<def.midLayout.height then
    c.shape={kind='flat',reviewedSurface=true}
   end
  end
  V.require('Gen3Cave').settle(def,cells)
 end
 mark('settle')
 local bedPlanter=V.require('Gen3Planter').prepare(cells,def)
 M.massCount=#Mass.prepare(cells,Pairs.outdoor(def))
 V.require('Gen3Planter').restore(bedPlanter)
 if Decks.MAPS[def.id or ''] then for _,c in pairs(cells)do c.mass=nil end end
 if def and (tonumber(def.mapType)==4 or tonumber(def.mapType)==9) and V.require('Gen3Blocks').pinned(def) then for _,c in pairs(cells)do if c.mass and not c.blocks and not c.looseStone then c.mass.blocksOwned=true end end end
 cache.floorRegions=regions
 do
  local SLOPE_KIND={flat=true,grass=true,flowers=true,sand=true}
  local function open(c)
   local f=c and c.floor
   return f and (f.group or f.connector) and c.base and SLOPE_KIND[c.shape and c.shape.kind or ''] and (c.collision or 0)==0
    and not (f.step or c.stairs or c.mass or c.bldModel or c.civic or c.column or c.object or c.objectTop or c.boundary) and c
  end
  for _,c in pairs(cells)do c.slope=nil;if c.floor then c.floor.slope=nil end end
  local corner={}
  local function at(i,j)
   local k=i..':'..j;local h=corner[k]
   if h==nil then
    h=false
    local ka,kb,kd,ke=cells[(i-1)..':'..(j-1)],cells[i..':'..(j-1)],cells[(i-1)..':'..j],cells[i..':'..j]
    local a,b,d,e=open(ka),open(kb),open(kd),open(ke)
    if not (a and b and d and e) then
     local n,sum,g,one,relief,ledgeOnly=0,0,nil,true,false,true
     for _,q in ipairs({{a,ka},{b,kb},{d,kd},{e,ke}})do
      if q[1] then
       n=n+1;sum=sum+q[1].base
       local f=q[1].floor
       if f.relief then relief=true end
       if not f.connector then if g==nil then g=f.group elseif f.group~=g then one=false end end
      elseif not (q[2] and q[2].shape and q[2].shape.kind=='ledge') then ledgeOnly=false end
     end
     if n>=2 and n<4 and one and relief and ledgeOnly and ((a and b) or (d and e) or (a and d) or (b and e)) then h=sum/n end
    end
    if a and b and d and e then
     local g,one=nil,true
     for _,q in ipairs({a,b,d,e})do local f=q.floor
      if not f.connector then if g==nil then g=f.group elseif f.group~=g then one=false end end
     end
     if one and (a.floor.relief or b.floor.relief or d.floor.relief or e.floor.relief) then
      h=(a.base+b.base+d.base+e.base)/4
     end
    end
    corner[k]=h
   end
   return h
  end
  for _,c in pairs(cells)do if open(c) then
   local i,j=c.cx,c.cy
   local nw,ne,se,sw=at(i,j),at(i+1,j),at(i+1,j+1),at(i,j+1)
   if nw or ne or se or sw then
    local s={nw and nw-c.base or 0,ne and ne-c.base or 0,se and se-c.base or 0,sw and sw-c.base or 0}
    if s[1]~=0 or s[2]~=0 or s[3]~=0 or s[4]~=0 then c.slope=s;c.floor.slope=s end
   end
  end end
  for _,c in pairs(cells)do
   local lg=c.floor and c.floor.ledge
   if lg and c.base and (c.collision or 0)==0 and not c.boundary then
    local s={lg[1],lg[2],lg[3],lg[4]};c.slope=s;c.floor.slope=s
   end
  end
 end
 for _=1,2 do
  for _,c in pairs(cells)do
   if c.shape and c.shape.kind=='ledge' and c.floor and not c.floor.ledgeLow and c.base then
    for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.shape and n.shape.kind=='ledge' and n.floor and n.floor.ledgeLow and math.abs((n.base or 0)-c.base)<=8 then
      c.base=n.base;c.floor.height=n.base;c.floor.ledgeLow=n.floor.ledgeLow;break
     end
    end
   end
  end
 end
 mark('mass')
 V.require('Gen3Blocks').restoreHeights(cells)
 M.propCount=#props
 for _,p in ipairs(props)do p.stageHidden=BattleClear.hits(cam,p.cx*16,p.cy*16,p.cx*16+p.w,p.cy*16+p.d)end
 for _,c in pairs(cells)do
  Budget.tick()
  local col=c.column;local group=col and col.group
  c.stageHidden=BattleClear.hits(cam,c.cx*16,c.cy*16,c.cx*16+(c.shape.kind=='tree' and 32 or 16),c.cy*16+32)
  if col then col.stageHidden=group and BattleClear.hits(cam,group.left,group.back,group.right,group.front)or c.stageHidden end
 end
 M.cliffCount=0
 local batches={};local leaf,li={},{}
 local lampNight={lamps={},quad=quad}
 local kinds=stream.stats.kinds
 for _,c in pairs(cells)do
  Budget.tick()
  local kindT0=kinds and os.clock()
  local ts,x,z,shape=c.ts,c.cx*16,c.cy*16,c.shape
  local b=batches[c.pair]
  if not b then b={pair=c.nativePair,secondary=c.secondary,v={},i={},rv={},ri={},pv={},pi={},wv={},wi={},roofMids={},skipOver={},underSkip={},deckV={},cv={},ci={}};batches[c.pair]=b end
  local uv=V.require('Gen3Parapet').floorUV(c,uvFor) or uvFor(ts,c.mid)
  local ledgeUV=c.floor and (c.floor.ledge or c.floor.bareDrop) and not c.boundary and V.require('Gen3Blocks').ledgeFaceUV(c,cells,uvFor) or nil
  if ledgeUV and c.floor.ledge then uv=ledgeUV end
  local column=c.column
  if c.mass and not c.blocks and not c.blocksSkip and not c.stageHidden and Mass.usable(c.mass,cells) then
   Mass.append(c.mass,cells,function(v,t,shade)quad(b.v,b.i,v,t,shade)end,uvFor,c)
  end
  local starts={#b.v,#b.rv,#b.pv,#b.wv,#leaf}
  PROBE.cell=c
  local flight=flightAxis(c,cells)
  if c.bedPlanter then
   if not c.stageHidden then V.require('Gen3Planter').appendBed(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,function(p,t,sh)quad(b.cv,b.ci,p,t,sh)end,uvFor,cells)end
  elseif shape.kind=='deckFace' or shape.kind=='deckBack' or shape.kind=='deckMixed' or shape.kind=='deckFloor' or shape.kind=='deckEdge' or shape.kind=='deckHead' or shape.kind=='deckRamp' then
   if not c.stageHidden then Decks.append(def,c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor,cells) end
  elseif c.stairs or shape.kind=='steps' or shape.kind=='ladder' then
   if shape.kind=='ladder' and not shape.down then
    -- floor under a ladder: the floor tile beside it (a fixed mid is water in some cave tilesets)
    local g
    for _,d in ipairs({{0,1},{0,-1},{-1,0},{1,0}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.ts and n.mid and n.shape and n.shape.kind~='ladder' and n.shape.kind~='water' and not n.blocks then g=n;break end
    end
    plane(b.v,b.i,x,z,(g and uvFor(g.ts,g.mid)) or uvFor(ts,shape.ground) or uv)
   end
   if shape.kind=='steps' and shape.down then
    local hi,lo=cells[c.cx..':'..(c.cy-1)],cells[c.cx..':'..(c.cy+1)]
    local top,bot=(hi and hi.base) or 16,(lo and lo.base) or 0
    local b0=c.base or 0
    local function px(a,q)return {uv[1][1]+(uv[3][1]-uv[1][1])*a/16,uv[1][2]+(uv[3][2]-uv[1][2])*q/16}end
    local function sub(y0,y1)return {px(0,y0),px(16,y0),px(16,y1),px(0,y1)}end
    for n=0,3 do
     local h=top-(top-bot)*n/4-b0
     local low=bot-b0
     local zz=n*4
     local a,d=z+zz,z+zz+4
     local p=px(8,zz+2);local pu={p,p,p,p}
     quad(b.v,b.i,{{x,h,a},{x+16,h,a},{x+16,h,d},{x,h,d}},sub(zz,zz+4),1)
     quad(b.v,b.i,{{x,low,d},{x+16,low,d},{x+16,h,d},{x,h,d}},pu,.85)
     quad(b.v,b.i,{{x,low,a},{x,low,d},{x,h,d},{x,h,a}},pu,.72)
     quad(b.v,b.i,{{x+16,low,d},{x+16,low,a},{x+16,h,a},{x+16,h,d}},pu,.8)
    end
    for _,dx in ipairs({-1,1})do
     local n=cells[(c.cx+dx)..':'..c.cy]
     local nuv=n and n.collision==7 and not (n.shape and n.shape.kind=='steps') and uvFor(n.ts,n.mid)
     if nuv then
      local q={nuv[1][1]+(nuv[3][1]-nuv[1][1])*.5,nuv[1][2]+(nuv[3][2]-nuv[1][2])*.8};local t={q,q,q,q}
      local x0,x1,y0,y1,z0,z1=x+dx*16+.5,x+dx*16+15.5,bot-b0,top-b0-.5,z+.5,z+15.5
      quad(b.v,b.i,{{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},t,.85)
      quad(b.v,b.i,{{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},t,.95)
      local xe=dx<0 and x1 or x0
      quad(b.v,b.i,{{xe,y1,z0},{xe,y1,z1},{xe,y0,z1},{xe,y0,z0}},t,.75)
     end
    end
   else
   Stairs.append(c,function(p,t,shade)quad(b.v,b.i,p,t,shade)end,uvFor)
   end
  elseif shape.ashPine then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   if not c.stageHidden and V.require('Gen3AshPine').is(c) then V.require('Gen3AshPine').append(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor) end
  elseif shape.lamp then
   local Lamp=V.require('Gen3Lamp')
   local on=Lamp.is(c,cells)
   plane(b.v,b.i,x,z,(on and uvFor(ts,shape.ground)) or uv)
   if on and not c.stageHidden then Lamp.append(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor,cells,lampNight) end
  elseif Stairs.wallKind(c) then
   local w=cells[(c.cx-1)..':'..c.cy]
   Stairs.appendWall(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor,w and w.mid)
  elseif shape.kind=='stand' then
   local st=shape.stand
   local function sub(y0,y1)
    local L,T,R,B=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
    return {{L,T+(B-T)*y0/16},{R,T+(B-T)*y0/16},{R,T+(B-T)*y1/16},{L,T+(B-T)*y1/16}}
   end
   local F=(st.board+1)*16
   if c.cy==st.board then
    quad(b.v,b.i,{{x,st.h0,F},{x+16,st.h0,F},{x+16,0,F},{x,0,F}},uv,.9)
   elseif c.cy<st.board then
    local k=st.board-c.cy
    local tread=16-st.riser
    local hb=st.h0+(k-1)*st.riser
    local zr=F-(k-1)*tread
    quad(b.v,b.i,{{x,hb+st.riser,zr},{x+16,hb+st.riser,zr},{x+16,hb,zr},{x,hb,zr}},sub(tread,16),.84)
    quad(b.v,b.i,{{x,hb+st.riser,zr-tread},{x+16,hb+st.riser,zr-tread},{x+16,hb+st.riser,zr},{x,hb+st.riser,zr}},sub(0,tread),1)
    local up=cells[c.cx..':'..(c.cy-1)]
    if not (up and up.shape and up.shape.kind=='stand') then
     local zb=zr-tread;local top=hb+st.riser
     local sw=swatch(ts,uv[1][1]+(uv[2][1]-uv[1][1])*.5,uv[1][2]+(uv[3][2]-uv[1][2])*.1)
     quad(b.v,b.i,{{x+16,top,zb},{x,top,zb},{x,0,zb},{x+16,0,zb}},sw,.6)
    end
   end
  elseif shape.kind=='rail' then
   local B=c.base or 0
   local function sub(t,l,tp,r,bt)
    local function p(px,py)return {t[1][1]+(t[2][1]-t[1][1])*px/16,t[1][2]+(t[3][2]-t[1][2])*py/16}end
    return {p(l,tp),p(r,tp),p(r,bt),p(l,bt)}
   end
   local low
   for _,d in ipairs({{0,1},{0,-1},{1,0},{-1,0},{0,2},{0,-2}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and n.mid==0x001 and (n.collision or 0)==0 then low=math.min(low or 1e9,n.base or 0) end
   end
   low=(low or 0)-B
   quad(b.v,b.i,{{x,low,z},{x+16,low,z},{x+16,low,z+16},{x,low,z+16}},uvFor(ts,0x001) or uv,1)
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and not (n.shape and n.shape.kind=='rail') then
     local nb=(n.base or 0)-B
     local t=uvFor(n.ts,n.mid)
     if t and nb>low+.5 then
      local ax,az=x+(d[1]>0 and 16 or 0),z+(d[2]>0 and 16 or 0)
      local bx,bz=ax+(d[1]==0 and 16 or 0),az+(d[2]==0 and 16 or 0)
      local y=low
      while y<nb do
       local h=math.min(16,nb-y)
       local v0=t[3][2]-(t[3][2]-t[1][2])*h/16
       quad(b.v,b.i,{{ax,y,az},{bx,y,bz},{bx,y+h,bz},{ax,y+h,az}},{{t[1][1],t[3][2]},{t[2][1],t[3][2]},{t[2][1],v0},{t[1][1],v0}},.78)
       y=y+h
      end
     end
    end
   end
   if shape.top and not c.stageHidden then
    local below=cells[c.cx..':'..(c.cy+1)]
    local bt=below and RAIL_EDGE[below.mid] and uvFor(below.ts,below.mid)
    local edge=sub(uv,1,11,15,12)
    quad(b.v,b.i,{{x,0,z+11},{x+16,0,z+11},{x+16,0,z+16},{x,0,z+16}},sub(uv,0,11,16,16),1)
    quad(b.v,b.i,{{x,0,z+16},{x+16,0,z+16},{x+16,-3,z+16},{x,-3,z+16}},bt and sub(bt,0,0,16,3) or edge,.92)
    quad(b.v,b.i,{{x+16,0,z+11},{x,0,z+11},{x,-3,z+11},{x+16,-3,z+11}},edge,.7)
    quad(b.v,b.i,{{x,-3,z+16},{x+16,-3,z+16},{x+16,-3,z+11},{x,-3,z+11}},edge,.55)
    for _,dx in ipairs({-1,1})do
     local n=cells[(c.cx+dx)..':'..c.cy]
     if not (n and ((n.shape and n.shape.kind=='rail' and n.shape.top) or RAIL_ROCK[n.mid])) then
      local sx=dx<0 and x or x+16
      if dx<0 then quad(b.v,b.i,{{sx,0,z+11},{sx,0,z+16},{sx,-3,z+16},{sx,-3,z+11}},edge,.76)
      else quad(b.v,b.i,{{sx,0,z+16},{sx,0,z+11},{sx,-3,z+11},{sx,-3,z+16}},edge,.82) end
     end
    end
    if below and RAIL_POSTS[below.mid] and bt then
     for _,col in ipairs({3,11})do
      local t=sub(bt,col,5,col+1,6)
      local a,e,za,zb=x+col,x+col+2,z+13,z+15
      quad(b.v,b.i,{{a,-3,zb},{e,-3,zb},{e,low,zb},{a,low,zb}},t,.9)
      quad(b.v,b.i,{{e,-3,za},{a,-3,za},{a,low,za},{e,low,za}},t,.62)
      quad(b.v,b.i,{{a,-3,za},{a,-3,zb},{a,low,zb},{a,low,za}},t,.74)
      quad(b.v,b.i,{{e,-3,zb},{e,-3,za},{e,low,za},{e,low,zb}},t,.8)
     end
    end
   end
  elseif shape.kind=='obwall' then
   do
    local g=shape.ground
    local vg=shape.ob and shape.ob.voidGround
    if vg then local n=cells[c.cx..':'..(c.cy-1)]
     if not n or ((n.collision or 0)~=0 and n.shape.kind=='obwall') then g=vg end end
    if shape.overArt then b.skipOver[#b.skipOver+1]=#b.v;plane(b.v,b.i,x,z,uv)
    else plane(b.v,b.i,x,z,uvFor(ts,g) or uv) end
   end
   if not c.stageHidden then
    local over=shape.overArt
    V.require('Gen3ObliqueWall').append(c,cells,function(p,t,sh)local k=#b.v;quad(b.v,b.i,p,t,sh);if over then b.underSkip[#b.underSkip+1]=k end end,uvFor)
   end
  elseif shape.kind=='boat' then
   local Boat=V.require('Gen3Boat')
   if c.boatSea==nil then
    local group,stack,sea={},{c},nil;local seen={[c]=true}
    while #stack>0 do
     local a=table.remove(stack);group[#group+1]=a
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
      if n and n.shape and not seen[n] then
       if n.shape.kind=='boat' then seen[n]=true;stack[#stack+1]=n
       elseif n.shape.kind=='water' then sea=math.min(sea or (n.base or 0),n.base or 0) end
      end
     end
    end
    for _,a in ipairs(group)do a.boatSea=sea or 0;if #group>=4 then a.base=a.boatSea;a.floorHigh=nil end end
   end
   local cb=0
   plane(b.wv,b.wi,x,z,uvFor(ts,Boat.SEA) or uv,.05-cb)
   if not c.stageHidden then Boat.append(c,cells,function(p,t,sh)for _,q in ipairs(p)do q[2]=q[2]-cb end;quad(b.v,b.i,p,t,sh)end,uvFor) end
  elseif shape.kind=='marketSign' then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   if not c.stageHidden then V.require('Gen3Market').sign(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor) end
  elseif shape.kind=='marketPot' then
   local q=#b.v
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   b.skipOver[#b.skipOver+1]=q
   if not c.stageHidden then V.require('Gen3Market').append(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor) end
  elseif shape.kind=='lathe' then
   local q=#b.v
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   b.skipOver[#b.skipOver+1]=q
   local L=V.require('Gen3Lathe')
   if not c.stageHidden and L.owns(c,shape.lathe) then
    (shape.lathe.tower and L.tower or L.append)(c,cells,shape.lathe,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor)
   end
  elseif shape.kind=='extrude' then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   local Planter=V.require('Gen3Planter')
   if not c.stageHidden and Planter.owns(c) then Planter.append(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,function(p,t,sh)quad(b.cv,b.ci,p,t,sh)end,uvFor,cells)
   elseif not c.stageHidden and shape.dock then V.require('Gen3DryDock').append(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor)
   elseif not c.stageHidden then
    local sp=shape.sidePx and uvFor(ts,shape.sidePx[1])
    local st=sp and (function()local u,v=sp[1][1]+(sp[2][1]-sp[1][1])*(shape.sidePx[2]+.5)/16,sp[1][2]+(sp[3][2]-sp[1][2])*(shape.sidePx[3]+.5)/16;return {{u,v},{u,v},{u,v},{u,v}} end)()
    V.require('Gen3Fence').extrude(c,cells,function(p,t,sh)
     if st and not (p[1][2]==p[2][2] and p[2][2]==p[3][2]) then t=st end
     quad(b.v,b.i,p,t,sh)end,uvFor,shape.h or 6,shape.light,shape.cool,shape.maskGround)
   end
  elseif shape.kind=='posts' then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   local overPosts=V.require('Gen3Fence').overInk(c)
   if not c.stageHidden and V.require('Gen3Fence').posts(c,function(p,t,sh)local k=#b.v;quad(b.v,b.i,p,t,sh);if overPosts then b.underSkip[#b.underSkip+1]=k end end,uvFor)==0 then
    V.require('Gen3Fence').extrude(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor,shape.h or 6,shape.light)
   end
  elseif shape.kind=='pier' then
   local H=(shape.h or 16)-(c.base or 0)
   if shape.land then plane(b.v,b.i,x,z,uv,H-.3)
   else plane(b.wv,b.wi,x,z,uvFor(ts,shape.water or 0x170) or uv,.05-(c.base or 0)) end
   local slot=ts.midToSlot[c.mid]
   if slot and ts.imageData and not c.stageHidden then
    local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
    local wood,joint={}, {}
    for py=0,15 do for px=0,15 do
     local r,g,bl=ts.imageData:getPixel(ox+px,oy+py)
     wood[py*16+px]=not (bl>r+.08 and bl>g)
    end end
    for py=0,15 do for px=0,15 do
     if not wood[py*16+px] then
      local l,rr
      for k=1,2 do if px-k>=0 and wood[py*16+px-k] then l=px-k;break end end
      for k=1,2 do if px+k<=15 and wood[py*16+px+k] then rr=px+k;break end end
      if l and rr and rr-l<=3 then joint[py*16+px]=l end
     end
    end end
    local function deckCell(dx,dz)
     local n=cells[(c.cx+dx)..':'..(c.cy+dz)]
     return n and n.shape and (n.shape.kind=='pier' or (n.shape.land==true)) or (n and (n.collision or 0)==0 and n.shape and n.shape.kind=='flat' and math.abs((n.base or 0)-(c.base or 0)-H)<2)
    end
    local function on(px,py)
     if px<0 then return deckCell(-1,0) and wood[py*16+15] end
     if px>15 then return deckCell(1,0) and wood[py*16] end
     if py<0 then return deckCell(0,-1) end
     if py>15 then return deckCell(0,1) end
     return wood[py*16+px] or joint[py*16+px]~=nil
    end
    local L,T,R,B=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
    local function span(a,e,r0,r1)return {{L+(R-L)*a/16,T+(B-T)*r0/16},{L+(R-L)*e/16,T+(B-T)*r0/16},{L+(R-L)*e/16,T+(B-T)*r1/16},{L+(R-L)*a/16,T+(B-T)*r1/16}} end
    local function tex(px,py)local u,v=L+(R-L)*(px+.5)/16,T+(B-T)*(py+.5)/16;return {{u,v},{u,v},{u,v},{u,v}} end
    local y1,y0=H,H-PIER_THICK
    for py=0,15 do for px=0,15 do
     local l=joint[py*16+px]
     if l then
      quad(b.v,b.i,{{x+px,y1-1,z+py},{x+px+1,y1-1,z+py},{x+px+1,y1-1,z+py+1},{x+px,y1-1,z+py+1}},tex(l,py),.42)
      quad(b.v,b.i,{{x+px,y0,z+py+1},{x+px+1,y0,z+py+1},{x+px+1,y0,z+py},{x+px,y0,z+py}},tex(l,py),.5)
     end
    end end
    for py=0,15 do
     local px=0
     while px<16 do
      if wood[py*16+px] then
       local e=px;while e<15 and wood[py*16+e+1] do e=e+1 end
       quad(b.v,b.i,{{x+px,y1,z+py},{x+e+1,y1,z+py},{x+e+1,y1,z+py+1},{x+px,y1,z+py+1}},span(px,e+1,py,py+1),1)
       quad(b.v,b.i,{{x+px,y0,z+py+1},{x+e+1,y0,z+py+1},{x+e+1,y0,z+py},{x+px,y0,z+py}},tex(px,py),.5)
       local jl,jr=px>0 and joint[py*16+px-1],e<15 and joint[py*16+e+1]
       if not on(px-1,py) then quad(b.v,b.i,{{x+px,y1,z+py},{x+px,y1,z+py+1},{x+px,jl and y1-1 or y0,z+py+1},{x+px,jl and y1-1 or y0,z+py}},tex(px,py),.72) end
       if not on(e+1,py) then quad(b.v,b.i,{{x+e+1,y1,z+py+1},{x+e+1,y1,z+py},{x+e+1,jr and y1-1 or y0,z+py},{x+e+1,jr and y1-1 or y0,z+py+1}},tex(e,py),.8) end
       for k=px,e do
        if not on(k,py+1) then quad(b.v,b.i,{{x+k,y1,z+py+1},{x+k+1,y1,z+py+1},{x+k+1,y0,z+py+1},{x+k,y0,z+py+1}},tex(k,py),.85) end
        if not on(k,py-1) then quad(b.v,b.i,{{x+k+1,y1,z+py},{x+k,y1,z+py},{x+k,y0,z+py},{x+k+1,y0,z+py}},tex(k,py),.62) end
       end
       px=e+1
      else px=px+1 end
     end
    end
    if shape.post then
     local puv=uvFor(ts,shape.post[1])
     if puv then
      local u,v=puv[1][1]+(puv[3][1]-puv[1][1])*(shape.post[2]+.5)/16,puv[1][2]+(puv[3][2]-puv[1][2])*(shape.post[3]+.5)/16
      local t={{u,v},{u,v},{u,v},{u,v}}
      local low=-(c.base or 0)
      for _,pxl in ipairs(shape.posts or {9})do
       local x0,x1,z0,z1=x+pxl,x+pxl+3,z+10,z+13
       quad(b.v,b.i,{{x0,y0,z1},{x1,y0,z1},{x1,low,z1},{x0,low,z1}},t,.9)
       quad(b.v,b.i,{{x1,y0,z0},{x0,y0,z0},{x0,low,z0},{x1,low,z0}},t,.6)
       quad(b.v,b.i,{{x0,y0,z0},{x0,y0,z1},{x0,low,z1},{x0,low,z0}},t,.7)
       quad(b.v,b.i,{{x1,y0,z1},{x1,y0,z0},{x1,low,z0},{x1,low,z1}},t,.8)
      end
     end
    end
   end
  elseif shape.kind=='fence' then
   if shape.waterGround then plane(b.wv,b.wi,x,z,uvFor(ts,shape.ground) or uv,.05)
   else plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv) end
   if not c.stageHidden then
    local Fence=V.require('Gen3Fence');local over=Fence.overInk(c)
    Fence.append(c,function(p,t,sh)local k=#b.v;quad(b.v,b.i,p,t,sh);if over then b.underSkip[#b.underSkip+1]=k end end,uvFor)
   end
  elseif shape.kind=='hang' then
   local ez=shape.edge*16
   if shape.rail then
    plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
    if not c.stageHidden then
     quad(b.v,b.i,{{x,16,ez},{x+16,16,ez},{x+16,0,ez},{x,0,ez}},uv,.9)
     quad(b.v,b.i,{{x+16,16,ez-.6},{x,16,ez-.6},{x,0,ez-.6},{x+16,0,ez-.6}},uv,.7)
    end
   elseif not c.stageHidden then
    local d=c.cy-shape.edge
    quad(b.v,b.i,{{x,-d*16,ez},{x+16,-d*16,ez},{x+16,-(d+1)*16,ez},{x,-(d+1)*16,ez}},uv,.86)
    local sd=M.sceneDef
    if c.cx==0 and sd and sd.midLayout then
     local W=sd.midLayout.width*16
     local left,right,mid=uvFor(ts,0x2EC),uvFor(ts,0x2EE),uvFor(ts,0x2ED)
     local y0,y1=-(d+1)*16,-d*16
     for zz=0,ez-16,16 do
      if left then quad(b.v,b.i,{{0,y1,zz},{0,y1,zz+16},{0,y0,zz+16},{0,y0,zz}},left,.72) end
      if right then quad(b.v,b.i,{{W,y1,zz+16},{W,y1,zz},{W,y0,zz},{W,y0,zz+16}},right,.76) end
     end
     if mid then for xx=0,W-16,16 do quad(b.v,b.i,{{xx+16,y1,0},{xx,y1,0},{xx,y0,0},{xx+16,y0,0}},mid,.62) end end
    end
   end
  elseif shape.kind=='partition' then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   if not c.stageHidden then V.require('Gen3Partition').append(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor) end
  elseif shape.leagueGate then
   local Gate=V.require('Gen3LeagueGate')
   local q=#b.v
   plane(b.v,b.i,x,z,uvFor(ts,Gate.ground(c)) or uv)
   if Gate.overArt(c.mid) then b.skipOver[#b.skipOver+1]=q end
   if not c.stageHidden and Gate.owns(c,cells) then
    Gate.append(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,
     function(p,t,sh)local k=#b.v;quad(b.v,b.i,p,t,sh);b.underSkip[#b.underSkip+1]=k end,uvFor)
   end
  elseif shape.cyclingRoad then
   local deckFirst,groundFirst=#b.v+1,nil
   V.require('Gen3CyclingRoad').append(c,cells,ts,{
    solid=function(p,t,shade)quad(b.v,b.i,p,t,shade)end,
    ground=function(p,t,shade)groundFirst=groundFirst or #b.v+1;quad(b.v,b.i,p,t,shade)end,
    water=function(p,t,shade)quad(b.wv,b.wi,p,t,shade)end},uvFor)
   if shape.cyclingRoad=='deck' then b.deckV[#b.deckV+1]={c.cx,c.cy,deckFirst,(groundFirst or #b.v+1)-1} end
  elseif c.civic or c.bldModel then
   plane(b.v,b.i,x,z,(c.bldModel and c.bldModel.groundMid and uvFor(ts,c.bldModel.groundMid)) or uvFor(ts,shape.ground) or uvFor(ts,c.civic and c.civic.variant=='saffron' and 0x2E5 or 1) or uv)
  elseif shape.reef then
   plane(b.wv,b.wi,x,z,shape.nativeReefFloor and uv or uvFor(ts,0x170) or uv,.05)
   Reef.append(c,cells,uv,function(v,t,sh)quad(b.v,b.i,v,t,sh)end)
  elseif shape.kind=='water' then
   plane(b.wv,b.wi,x,z,uv,.05)
  elseif shape.kind=='interiorFloor' then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
  elseif (shape.kind=='caveWall' or shape.kind=='rock') and c.blocks then
   M.cliffCount=M.cliffCount+1
   if not c.stageHidden then V.require('Gen3Blocks').append(c,cells,function(v,t,sh)quad(b.v,b.i,v,t,sh)end,uvFor) end
  elseif shape.kind=='caveWall' and c.mass and Mass.usable(c.mass,cells) then
   local g=Mass.ground(c.mass,cells,c) or shape.ground
   plane(b.v,b.i,x,z,uvFor(ts,g) or uvFor(ts,shape.ground) or uv,c.base or 0)
   if c.mass.owner==c and not c.stageHidden then Mass.append(c.mass,cells,function(v,t,shade)quad(b.v,b.i,v,t,shade)end,uvFor)end
  elseif shape.kind=='caveWall' and c.caveFlat then
   local top=(c.base or 0)+Mass.FACE
   plane(b.v,b.i,x,z,uv,top)
  elseif shape.kind=='caveWall' then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   if not c.stageHidden then V.require('Gen3Cave').wall(cells,c,function(v,t,shade)quad(b.v,b.i,v,t,shade)end,uvFor)end
  elseif shape.kind=='rock' then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   if not c.stageHidden then V.require('Gen3Cave').rock(c,function(v,t,shade,anchor)quad(anchor and b.pv or b.v,anchor and b.pi or b.i,v,t,shade,anchor)end,uvFor)end
  elseif shape.kind=='cliff' and c.blocks then
   M.cliffCount=M.cliffCount+1
   if not c.stageHidden then V.require('Gen3Blocks').append(c,cells,function(v,t,sh)quad(b.v,b.i,v,t,sh)end,uvFor) end
  elseif shape.kind=='cliff' then
   M.cliffCount=M.cliffCount+1
   if c.mass and Mass.usable(c.mass,cells) then
    local g,wet=Mass.ground(c.mass,cells,c)
    local seaUnder,level=false,false
    g=g or shape.ground
    if not wet then
     local sea,land
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
      if n and n.shape then
       if n.shape.kind=='water' and (n.base or 0)==0 then sea=n
       elseif (n.collision or 0)==0 and (n.base or 0)<8 then land=true end
      end
     end
     if sea and not land then g,wet,seaUnder=sea.mid,true,true end
    end
    if not wet then
     local votes,best,bn={},nil,0
     local same=false
     local anyLevel=false
     for dy=-1,1 do for dx=-1,1 do
      local n=(dx~=0 or dy~=0) and cells[(c.cx+dx)..':'..(c.cy+dy)]
      if n and n.shape and (n.shape.kind=='flat' or n.shape.kind=='grass') and (n.collision or 0)==0 and n.ts==ts and not n.boundary
       and math.abs((n.base or 0)-(c.base or 0))<8 then anyLevel=true end
     end end
     for dy=-1,1 do for dx=-1,1 do
      local n=(dx~=0 or dy~=0) and cells[(c.cx+dx)..':'..(c.cy+dy)]
      if n and n.shape and (n.shape.kind=='flat' or n.shape.kind=='grass') and (n.collision or 0)==0 and n.ts==ts and not n.boundary
       and (not anyLevel or math.abs((n.base or 0)-(c.base or 0))<8) then
       if n.mid==g then same=true end
       votes[n.mid]=(votes[n.mid] or 0)+1
       if votes[n.mid]>bn then best,bn=n.mid,votes[n.mid] end
       if math.abs((n.base or 0)-(c.base or 0))<8 then level=true end
      end
     end end
     if best and not same then g=best end
    end
    local gu=uvFor(ts,g) or uvFor(ts,1) or uv
    local cb=c.base or 0
    if not wet and not level and cb>=8 then gu=uv end
    local rh=c.mass.rock and c.mass.rock.H and c.mass.rock.H[c]
    local under=(rh and math.abs(rh-cb)<.5) and .3 or 0
    if wet then plane(b.wv,b.wi,x,z,gu,seaUnder and .05-cb or .05) else plane(b.v,b.i,x,z,gu,cb-under) end
    if not seaUnder and not wet then
     for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
      local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
      if n and n.shape and (n.shape.kind=='cliff' or n.shape.kind=='caveWall') and (n.base or 0)<cb-.5 then
       local nb=n.base or 0
       local ax,az=x+(d[1]>0 and 16 or 0),z+(d[2]>0 and 16 or 0)
       local bx,bz=ax+(d[1]==0 and 16 or 0),az+(d[2]==0 and 16 or 0)
       quad(b.v,b.i,{{ax,nb,az},{bx,nb,bz},{bx,cb,bz},{ax,cb,az}},gu,.78)
      end
     end
    end
    for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.mass~=c.mass and n.shape.kind~='cliff' and n.shape.kind~='caveWall' and n.shape.kind~='water' and n.shape.kind~='steps' and not n.stairs then
      local nb=n.base or 0
      if nb~=cb and not seaUnder then
       local ax,az=x+(d[1]>0 and 15.5 or d[1]<0 and .5 or 0),z+(d[2]>0 and 15.5 or d[2]<0 and .5 or 0)
       local bx,bz=ax+(d[1]==0 and 16 or 0),az+(d[2]==0 and 16 or 0)
       if nb<cb then
        local y1=cb
        while y1>nb+.01 do
         local y0=math.max(nb,y1-16);local rows=y1-y0
         local v0=uv[3][2]-(uv[3][2]-uv[1][2])*rows/16;local vb=uv[3][2]
         quad(b.v,b.i,{{ax,y0,az},{bx,y0,bz},{bx,y1,bz},{ax,y1,az}},{{uv[1][1],vb},{uv[2][1],vb},{uv[2][1],v0},{uv[1][1],v0}},.78)
         y1=y0
        end
       else
        quad(b.v,b.i,{{ax,math.min(nb,cb),az},{bx,math.min(nb,cb),bz},{bx,math.max(nb,cb),bz},{ax,math.max(nb,cb),az}},gu,.78)
       end
      end
     end
    end
   elseif not shape.bank then plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv) end
   if shape.seaRock then
    local wmid
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.shape and n.shape.kind=='water' and n.ts==ts then wmid=n.mid;break end end
    if wmid then plane(b.wv,b.wi,x,z,uvFor(ts,wmid) or uv,.05) end
   end
   if c.mass and Mass.usable(c.mass,cells) then
   else
    Terrain.append(cells,c,function(v,t,shade)quad(b.v,b.i,v,t,shade)end,uvFor)
   end
  elseif c.prop then
   if not c.prop.recipe.noGround then
    local r=c.prop.recipe;local floorMid=r.ground
    if r.floorFrom=='neighbour' and r.pixelGround then
     local ok={};for _,m in ipairs(r.pixelGround)do ok[m]=true end
     for _,d in ipairs({{0,1},{-1,0},{1,0},{0,-1},{0,2},{-2,0},{2,0},{0,-2}})do
      local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
      if n and not n.prop and ok[n.mid] then floorMid=n.mid;break end
     end
    end
    plane(b.v,b.i,x,z,uvFor(ts,floorMid) or uvFor(ts,1) or uv)
   end
  elseif shape.kind=='tree' and shape.canopy then
   local CANOPY_TREES=true
   local CANOPY_LOG=false
   if c.canopyBottom==nil then
    local group,seen,queue,head={}, {[c]=true},{c},1
    local low,lowBlocked
    while queue[head]do local a=queue[head];head=head+1;group[#group+1]=a
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
      if n and not seen[n] then
       if n.shape and n.shape.canopy then seen[n]=true;queue[#queue+1]=n
       elseif (n.collision or 0)==0 and n.base and not (n.shape and n.shape.cyclingRoad=='deck') then low=math.min(low or n.base,n.base)
       elseif a.shape.fortree and n.base and not n.bldModel then lowBlocked=math.min(lowBlocked or n.base,n.base) end
      end
     end
    end
    if lowBlocked and low then low=math.min(low,lowBlocked) end
    if not low then for _,a in ipairs(group)do low=math.min(low or (a.base or 0),a.base or 0)end end
    table.sort(group,function(a,b)if a.cy~=b.cy then return a.cy<b.cy end return a.cx<b.cx end)
    local inside=function(a)return a.cx>=0 and a.cy>=0 and def and def.midLayout and a.cx<def.midLayout.width and a.cy<def.midLayout.height end
    local fortreeMap=(def and def.id)=='EM_FORTREE_CITY'
    local function fortreeWood(a)return a.shape.fortree or (fortreeMap and inside(a)) end
    local near,q,qh={}, {},1
    for _,a in ipairs(group)do
     local f
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
      if n and not (n.shape and n.shape.canopy) and (n.collision or 0)==0 and n.base and not (n.shape and n.shape.cyclingRoad=='deck') then f=math.min(f or n.base,n.base) end
     end
     if f then near[a]=f;q[#q+1]=a end
    end
    while q[qh]do local a=q[qh];qh=qh+1
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
      if n and seen[n] and near[n]==nil then near[n]=near[a];q[#q+1]=n end
     end
    end
    local lowIn
    for _,a in ipairs(group)do if fortreeWood(a) and inside(a) then
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
      if n and inside(n) and not (n.shape and n.shape.canopy) and n.base then
       if (n.collision or 0)==0 and not (n.shape and n.shape.cyclingRoad=='deck') then lowIn=math.min(lowIn or n.base,n.base)
       elseif a.shape.fortree and not n.bldModel then lowIn=math.min(lowIn or n.base,n.base) end -- (as lowBlocked above)
      end
     end
    end end
    for _,a in ipairs(group)do
     if def.id=='EM_ROUTE119' then a.canopyBottom=a.base or 0
     elseif fortreeWood(a) then a.canopyBottom=lowIn or low else a.canopyBottom=near[a] or low end
    end
   end
   local fv2=FORTREE_V2 and def and def.id=='EM_FORTREE_CITY'
   local treeY=c.canopyBottom
   if fv2 then treeY=isDeck(c) and (c.base or 0) or c.canopyBottom end
   local lift=treeY-(c.base or 0) -- vertices are lifted by c.base later
   local H=CANOPY_HEIGHT+lift
   local art=uvFor(ts,shape.topMid or c.mid) or uvFor(ts,c.mid) or uv
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv,lift)
   local card
   local outside=fv2 and (not (c.cx>=0 and c.cy>=0 and c.cx<def.midLayout.width and c.cy<def.midLayout.height)
    or shape.palmCrown or ((c.mid==0x241 or c.mid==0x25C) and (cells[c.cx..':'..(c.cy-1)] or {}).shape and cells[c.cx..':'..(c.cy-1)].shape.palmCrown))
   if CANOPY_TREES and (def.id=='EM_ROUTE119' or fv2 or (not shape.fortree and (def and def.id)~='EM_FORTREE_CITY' and not shape.palmCrown)) and not outside and not c.stageHidden then
    local top=(c.cx+c.cy)%2==0 and 0x00E or 0x00F
    local big=not fv2 and ts.midToSlot[0x1CE] and ts.midToSlot[0x1CF] and ts.midToSlot[0x1D4] and ts.midToSlot[0x1D5] and ts.midToSlot[0x1DC] and ts.midToSlot[0x1DD]
    local bigX
    if big then
     local function can(dx,dy)local n=cells[(c.cx+dx)..':'..(c.cy+dy)];return n and n.shape and n.shape.canopy and not n.shape.palmCrown end
     local k=0;while can(-k-1,0) and k<512 do k=k+1 end
     local rowHere=c.cy%2==0 or not can(0,-1)
     if rowHere and k%2==0 then bigX=can(1,0) and 16 or 8 end
     ts.canopyTreeCards=ts.canopyTreeCards or {}
     card=ts.canopyTreeCards.big
     if card==nil then
      card=V.require('NativeTreeArt').gen3({ts=ts,mid=0x1DC,shape={art={{0x1CE,0x1CF},{0x1D4,0x1D5},{0x1DC,0x1DD}},artTipRows=1,ground=shape.ground}})or false
      ts.canopyTreeCards.big=card
     end
     if not card then big=nil end
    end
    if big then
     if bigX then
      local seed=c.cx*73+c.cy*139
      local tx,tz=x+bigX+seed%5-2,z+11+math.floor(seed/7)%5-2
      if not V.require('NativeTreeArt').addInstance(card,treeGroups,tx,treeY,tz) then
       V.require('NativeTreeArt').appendModel(card,leaf,li,0,tx,lift,tz)
      end
     end
     card=nil;outside=true
    elseif ts.midToSlot[top] and ts.midToSlot[top+8] then
     ts.canopyTreeCards=ts.canopyTreeCards or {}
     local ck=fv2 and 'fv2'..top or top
     card=ts.canopyTreeCards[ck]
     if card==nil then
      card=V.require('NativeTreeArt').gen3({ts=ts,mid=top,shape={art={{top},{top+8}},ground=fv2 and 0 or shape.ground}})or false
      ts.canopyTreeCards[ck]=card
     end
    end
   end
   if card then
    local seed=c.cx*73+c.cy*139
    local tx,tz=x+8+seed%7-3,z+11+math.floor(seed/7)%5-2
    for _,rz in ipairs({tz})do
     if not V.require('NativeTreeArt').addInstance(card,treeGroups,tx,treeY,rz) then
      V.require('NativeTreeArt').appendModel(card,leaf,li,0,tx,lift,rz)
     end
    end
   elseif not outside then
    quad(b.v,b.i,{{x,H,z},{x+16,H,z},{x+16,H,z+16},{x,H,z+16}},art,1)
   end
   if CANOPY_LOG then print('canopy',c.cx,c.cy,card and 'tree' or 'box') end
   if (card or outside) and not fv2 then
    local g=uvFor(ts,shape.ground) or uv
    for _,d in ipairs({{0,1,.82},{0,-1,.62},{-1,0,.7},{1,0,.7}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     local nb=n and n.shape and n.shape.canopy and n.canopyBottom
     local nk=n and n.shape and n.shape.kind
     if not nb and n and (nk=='water' or nk=='grass' or nk=='tree' or (nk=='flat' or nk=='flowers' or nk=='sand') and (n.collision or 0)==0) and not (n.mass or n.bldModel or n.civic or n.column) then
      nb=n.base or 0
     end
     if nb and nb<treeY then
      local x0,z0,x1,z1
      if d[2]==1 then x0,z0,x1,z1=x,z+16,x+16,z+16 elseif d[2]==-1 then x0,z0,x1,z1=x+16,z,x,z
      elseif d[1]==-1 then x0,z0,x1,z1=x,z,x,z+16 else x0,z0,x1,z1=x+16,z+16,x+16,z end
      local yb=nb-(c.base or 0)
      while yb<lift-.01 do
       local yt=math.min(lift,yb+16)
       quad(b.v,b.i,{{x0,yt,z0},{x1,yt,z1},{x1,yb,z1},{x0,yb,z0}},g,d[3])
       yb=yt
      end
     end
    end
   end
   do
    local g=uvFor(ts,shape.ground) or uv
    for _,d in ipairs({{0,1,.82},{0,-1,.62},{-1,0,.7},{1,0,.7}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     local nk=n and n.shape and n.shape.kind
     if n and not (n.shape and n.shape.canopy) and (nk=='flat' or nk=='grass' or nk=='flowers' or nk=='sand') and not (n.mass or n.bldModel or n.civic or n.column)
       and (n.base or 0)>treeY+.01 and not (fv2 and V.require('Gen3Fortree').bridgeDrop(n)) then -- no wall under a rope bridge
      local x0,z0,x1,z1
      if d[2]==1 then x0,z0,x1,z1=x+16,z+16,x,z+16 elseif d[2]==-1 then x0,z0,x1,z1=x,z,x+16,z
      elseif d[1]==-1 then x0,z0,x1,z1=x,z+16,x,z else x0,z0,x1,z1=x+16,z,x+16,z+16 end
      local yb,top=lift,(n.base or 0)-(c.base or 0)
      while yb<top-.01 do
       local yt=math.min(top,yb+16)
       quad(b.v,b.i,{{x0,yt,z0},{x1,yt,z1},{x1,yb,z1},{x0,yb,z0}},g,d[3])
       yb=yt
      end
     end
    end
   end
   local function open(dx,dz)
    if card then return false end
    local n=cells[(c.cx+dx)..':'..(c.cy+dz)]
    return not (n and n.shape and n.shape.canopy and n.canopyBottom==c.canopyBottom)
   end
   for y0=lift,(outside and lift-16 or H-16),16 do
    local y1=y0+16
    if open(0,1) then quad(b.v,b.i,{{x,y1,z+16},{x+16,y1,z+16},{x+16,y0,z+16},{x,y0,z+16}},{art[1],art[2],art[3],art[4]},.82) end
    if open(0,-1) then quad(b.v,b.i,{{x+16,y1,z},{x,y1,z},{x,y0,z},{x+16,y0,z}},{art[1],art[2],art[3],art[4]},.62) end
    if open(-1,0) then quad(b.v,b.i,{{x,y1,z},{x,y1,z+16},{x,y0,z+16},{x,y0,z}},{art[1],art[2],art[3],art[4]},.7) end
    if open(1,0) then quad(b.v,b.i,{{x+16,y1,z+16},{x+16,y1,z},{x+16,y0,z},{x+16,y0,z+16}},{art[1],art[2],art[3],art[4]},.7) end
   end
   if shape.palmCrown and not fv2 then
    local crown=uvFor(ts,c.mid) or uv
    local y0,y1=H+16,H+32
    local function rows(u,r0,r1) local t,bt=u[1][2],u[3][2]
     local a,bb=t+(bt-t)*r0/16,t+(bt-t)*r1/16
     return {{u[1][1],a},{u[2][1],a},{u[3][1],bb},{u[4][1],bb}} end
    local tips=uvFor(ts,c.mid-8)
    tips=tips and rows(tips,8,16) or crown
    for _,zz in ipairs({z,z+8})do
     quad(b.v,b.i,{{x,y1,zz},{x+16,y1,zz},{x+16,y1,zz+8},{x,y1,zz+8}},tips,1)
    end
    quad(b.v,b.i,{{x,y1,z+16},{x+16,y1,z+16},{x+16,y0,z+16},{x,y0,z+16}},crown,.82)
    quad(b.v,b.i,{{x+16,y1,z},{x,y1,z},{x,y0,z},{x+16,y0,z}},crown,.62)
    quad(b.v,b.i,{{x,y0,z+16},{x+16,y0,z+16},{x+16,y0,z},{x,y0,z}},crown,.45)
    local function crownAt(dx) local n=cells[(c.cx+dx)..':'..c.cy]; return n and n.shape and n.shape.palmCrown end
    if not crownAt(-1) then quad(b.v,b.i,{{x,y1,z},{x,y1,z+16},{x,y0,z+16},{x,y0,z}},crown,.7) end
    if not crownAt(1) then quad(b.v,b.i,{{x+16,y1,z+16},{x+16,y1,z},{x+16,y0,z},{x+16,y0,z+16}},crown,.7) end
    local s=cells[c.cx..':'..(c.cy+1)]
    if crownAt(-1) and crownAt(1) and s and (s.mid==0x241 or s.mid==0x25C) then
     local bark=uvFor(ts,0x241) or crown
     local a,e=x+2,x+14
     local za,ze=z+2,z+14
     quad(b.v,b.i,{{a,y0,ze},{e,y0,ze},{e,H,ze},{a,H,ze}},bark,.82)
     quad(b.v,b.i,{{e,y0,za},{a,y0,za},{a,H,za},{e,H,za}},bark,.62)
     quad(b.v,b.i,{{a,y0,za},{a,y0,ze},{a,H,ze},{a,H,za}},bark,.7)
     quad(b.v,b.i,{{e,y0,ze},{e,y0,za},{e,H,za},{e,H,ze}},bark,.7)
    end
   end
  elseif shape.kind=='tree' then
   plane(b.v,b.i,x,z,(shape.planeOwn and uv) or uvFor(ts,shape.ground) or uv)
   local fv2=FORTREE_V2 and def and def.id=='EM_FORTREE_CITY'
   local fortreeOutside=fv2 and not (c.cx>=0 and c.cy>=0 and c.cx<def.midLayout.width and c.cy<def.midLayout.height)
   if shape.root and not c.stageHidden then
    local native=V.require('NativeTreeArt')
    local tx,tz=x+(shape.anchorX or 16),z+(shape.anchorZ or 12)
    local gy=fv2 and (fortreeOutside and 0 or -(c.base or 0)) or 0
    local card=native.gen3(fv2 and {ts=c.ts,pair=c.pair,mid=c.mid,shape=setmetatable({ground=0},{__index=c.shape})} or c)
    if not native.addInstance(card,treeGroups,tx,(fv2 and not fortreeOutside) and 0 or (c.base or 0),tz)then native.appendModel(card,leaf,li,0,tx,gy,tz)end
   end
  elseif column and not column.indoor and VoxelBuildings.enabled then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   if c.cy==column.first and not column.stageHidden then
    VoxelBuildings.append(cells,c,function(v,t,shade)quad(b.v,b.i,v,t,shade)end)
   end
  elseif column and column.indoor and c.secondary=='lab' and column.first<=1 then
   plane(b.v,b.i,x,z,uvFor(ts,0x289) or uv)
  elseif column then
   if not (column.indoor and CABINS[def.id or ''] and not cells[c.cx..':'..(column.first-1)]) then
    plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   end
   if not column.stageHidden then
   if column.indoor or c.cy>=(column.wallTop or column.first+column.roofs) then
    local row=c.cy-(column.wallTop or column.first+column.roofs)
    local step=column.rowStep or column.height/column.walls
    local top=column.height-row*step
    local low=top-step
    local trimTop=shape.trimTop or (WALL_TRIM[def.id or ''] and WALL_TRIM[def.id][c.mid])
    if row==0 and trimTop then
     local k=trimTop/16
     top=top-step*k
     local v=uv[1][2]+(uv[4][2]-uv[1][2])*k
     uv={{uv[1][1],v},{uv[2][1],v},uv[3],uv[4]}
    end
    local front=column.front
    if not column.indoor then V.require('GlassMask').facade(ts,c.mid)end
    local slant=c.secondary=='pokemon_center' and (c.mid==0x208 or c.mid==0x20F)
    if slant then
     for px=0,15 do
      local k=c.mid==0x208 and 15-px or px
      if k<16 then
       local u0=uv[1][1]+(uv[2][1]-uv[1][1])*px/16;local u1=uv[1][1]+(uv[2][1]-uv[1][1])*(px+1)/16
       local v0=uv[1][2]+(uv[4][2]-uv[1][2])*k/16
       local t0=top-(top-low)*k/16
       quad(b.v,b.i,{{x+px,t0,front},{x+px+1,t0,front},{x+px+1,low,front},{x+px,low,front}},{{u0,v0},{u1,v0},{u1,uv[3][2]},{u0,uv[4][2]}})
      end
     end
    else
    quad(b.v,b.i,{{x,top,front},{x+16,top,front},{x+16,low,front},{x,low,front}},uv)
    end
    if not slant then
    do
     -- Every building is a closed box, so a turned camera never looks into an open shell.
     local u,t=(uv[1][1]+uv[2][1])*.5,uv[1][2]
     local solid=swatch(ts,u,t)
     local own=uv
     local function band(px)
      if column.indoor and not shape.sideArt then return own end
      px=wallColumn(ts,c.mid,px)
      local bu=uv[1][1]+(uv[2][1]-uv[1][1])*px/16
      return {{bu,uv[1][2]},{bu,uv[2][2]},{bu,uv[3][2]},{bu,uv[4][2]}}
     end
     local tiled=column.indoor and not shape.sideArt
     local function face(pts,t,sh)
      if not tiled then quad(b.v,b.i,pts(top,low),t,sh);return end
      local y=top
      while y>low+.01 do
       local yb=math.max(low,y-16);local f=(y-yb)/16
       local T,B=t[1][2],t[1][2]+(t[4][2]-t[1][2])*f
       quad(b.v,b.i,pts(y,yb),{{t[1][1],T},{t[2][1],T},{t[3][1],B},{t[4][1],B}},sh);y=yb
      end
     end
     for _,dx in ipairs({-1,1})do
      if Roof.sideVisible(cells,c,dx)then local sx=dx<0 and x or x+16
       face(function(a,bb)return {{sx,a,column.back},{sx,a,column.front},{sx,bb,column.front},{sx,bb,column.back}}end,band(dx<0 and 2.5 or 13.5),.82)
      end
     end
     local wallArt=band(2.5)
     if (column.indoor or column.roofs==0) and c.cy==math.max(column.first,column.wallTop or column.first) then
      local cap=column.indoor and solid or band(8)
      quad(b.v,b.i,{{x,top,column.back},{x+16,top,column.back},{x+16,top,column.front},{x,top,column.front}},cap,.95)
     end
     if (not column.indoor or column.lowerMid) and c.cy==column.last and low>.01 then
      local base=band(2.5)
      if column.lowerMid then base=uvFor(ts,column.lowerMid) or base end
      quad(b.v,b.i,{{x,low,column.front},{x+16,low,column.front},{x+16,0,column.front},{x,0,column.front}},base,.9)
      for _,ddx in ipairs({-1,1})do if Roof.sideVisible(cells,c,ddx)then local sx=ddx<0 and x or x+16
       quad(b.v,b.i,{{sx,low,column.back},{sx,low,column.front},{sx,0,column.front},{sx,0,column.back}},base,.8)
      end end
      quad(b.v,b.i,{{x+16,low,column.back},{x,low,column.back},{x,0,column.back},{x+16,0,column.back}},base,.7)
     end
     face(function(a,bb)return {{x+16,a,column.back},{x,a,column.back},{x,bb,column.back},{x+16,bb,column.back}}end,wallArt,.7)
    end
    end
   else
    do
     local rm=c.roofMid or c.mid
     local below=cells[c.cx..':'..(c.cy+1)]
     local topRow=c.cy==column.first and column.roofs>=2 and below and below.shape.kind=='roof'
     local walk=((c.collision or 0)==0 or topRow) and not c.roofMid
     if walk and b.roofMids[rm]~=true then b.roofMids[rm]='over' else b.roofMids[rm]=true end
    end
    uv=uvFor(ts,c.roofMid or c.mid)
    local row=c.cy-column.first
    local isFront=column.roofType=='front'
    local artBack=isFront and (Roof.ridge(column)) or column.back
    local artRows=math.max(column.artRows or column.roofs,1)
    local up=(column.first+column.roofs-1)-c.cy
    local z1=column.front-(column.front-artBack)*up/artRows
    local z0=column.front-(column.front-artBack)*(up+1)/artRows
    local function roofY(a)return Roof.height(column,a) end
    local fu=Roof.sideVisible(cells,c,-1) and .78 or Roof.sideVisible(cells,c,1) and .22 or .5
    local fv=row==0 and .8 or row==column.roofs-1 and .3 or .5
    local fillUv=uv
    do local belowRoof=cells[c.cx..':'..(c.cy+1)]
     if b.roofMids[c.roofMid or c.mid]=='over' and belowRoof and belowRoof.shape.kind=='roof' then
      fillUv=uvFor(ts,belowRoof.roofMid or belowRoof.mid) or uv;fv=.5
     end
    end
    local roofFill=swatch(ts,fillUv[1][1]+(fillUv[2][1]-fillUv[1][1])*fu,fillUv[1][2]+(fillUv[3][2]-fillUv[1][2])*fv)
    for j=row==0 and math.floor((column.roofInset or 0)/4) or 0,3 do
     local a,bz=z0+(z1-z0)*j/4,z0+(z1-z0)*(j+1)/4
     local t0,t1=uv[1][2]+(uv[3][2]-uv[1][2])*j/4,uv[1][2]+(uv[3][2]-uv[1][2])*(j+1)/4
     local q={{uv[1][1],t0},{uv[2][1],t0},{uv[3][1],t1},{uv[4][1],t1}}
     quad(b.rv,b.ri,{{x,roofY(a),a},{x+16,roofY(a),a},{x+16,roofY(bz),bz},{x,roofY(bz),bz}},q)
     local function eave(A,B,dx,dz)
      V.require('RoofEaves').edge(A,B,dx,dz,q,function(v,t,shade)quad(b.rv,b.ri,v,t,shade)end)
     end
     if Roof.sideVisible(cells,c,-1)then eave({x,roofY(bz),bz},{x,roofY(a),a},-2,0)end
     if Roof.sideVisible(cells,c,1)then eave({x+16,roofY(a),a},{x+16,roofY(bz),bz},2,0)end
     if not isFront and row==0 and j==math.floor((column.roofInset or 0)/4)then eave({x,roofY(a),a},{x+16,roofY(a),a},0,-2)end
     if isFront and row==0 and j==0 then
      local zb=column.back
      local zr=artBack
      quad(b.v,b.i,{{x,roofY(zb),zb},{x+16,roofY(zb),zb},{x+16,roofY(zr),zr},{x,roofY(zr),zr}},roofFill,.8)
      if a>zr+.01 then quad(b.v,b.i,{{x,roofY(zr),zr},{x+16,roofY(zr),zr},{x+16,roofY(a),a},{x,roofY(a),a}},roofFill,1) end
      eave({x,roofY(zb),zb},{x+16,roofY(zb),zb},0,-2)
      if Roof.sideVisible(cells,c,-1)then eave({x,roofY(a),a},{x,roofY(zr),zr},-2,0);eave({x,roofY(zr),zr},{x,roofY(zb),zb},-2,0)end
      if Roof.sideVisible(cells,c,1)then eave({x+16,roofY(zr),zr},{x+16,roofY(a),a},2,0);eave({x+16,roofY(zb),zb},{x+16,roofY(zr),zr},2,0)end
     end
     if row==column.roofs-1 and j==3 then eave({x+16,roofY(bz),bz},{x,roofY(bz),bz},0,2)end
     local north=not isFront and row==0 and j==math.floor((column.roofInset or 0)/4)
     local south=row==column.roofs-1 and j==3
     for _,side in ipairs({-1,1})do if Roof.sideVisible(cells,c,side)then
      local xx=side<0 and x or x+16
      for _,endcap in ipairs({{north,a,-2},{south,bz,2}})do if endcap[1]then
       V.require('RoofEaves').corner({xx,roofY(endcap[2]),endcap[2]},side*2,endcap[3],q,
        function(v,t,shade)quad(b.rv,b.ri,v,t,shade)end)
      end end
     end end
     local wallCell=cells[c.cx..':'..column.last]
     local sideMid=wallCell.mid
     local side=uvFor(ts,sideMid) or uvFor(ts,wallCell.mid)
     local u=(side[1][1]+side[2][1])*.5
     local t=side[1][2]+(side[3][2]-side[1][2])*.2
     local solid=swatch(ts,u,t)
     for _,dx in ipairs({-1,1})do
      if Roof.sideVisible(cells,c,dx) then
       local sx=dx<0 and x or x+16
       local foot=column.indoor and 0 or column.height
       quad(b.v,b.i,{{sx,roofY(a),a},{sx,roofY(bz),bz},{sx,foot,bz},{sx,foot,a}},solid,.82)
       if isFront and row==0 and j==0 then
        local zb,zr=column.back,artBack
        quad(b.v,b.i,{{sx,roofY(zb),zb},{sx,roofY(zr),zr},{sx,foot,zr},{sx,foot,zb}},solid,.82)
        if a>zr+.01 then quad(b.v,b.i,{{sx,roofY(zr),zr},{sx,roofY(a),a},{sx,foot,a},{sx,foot,zr}},solid,.82) end
       end
      end
     end
     if not isFront and row==0 and j==math.floor((column.roofInset or 0)/4) then
      local foot=column.indoor and 0 or column.height
      quad(b.v,b.i,{{x+16,roofY(a),a},{x,roofY(a),a},{x,foot,a},{x+16,foot,a}},solid,.74)
     end
    end
   end
   end
  elseif shape.kind=='sign' or shape.kind=='fence' or shape.kind=='ledge' or shape.kind=='flowers' or shape.kind=='shrub' or shape.kind=='grass' or shape.kind=='awning' then
   local gu=uvFor(ts,shape.ground) or uv
   if not (shape.kind=='ledge' and Outdoor.ledgeFloor(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,gu)) then plane(b.v,b.i,x,z,gu) end
   local plant=shape.kind=='flowers' or shape.kind=='shrub' or shape.kind=='grass'
   if not c.stageHidden then Outdoor.append(c,function(vertices,tex,shade,anchor)quad(plant and b.pv or b.v,plant and b.pi or b.i,vertices,tex,shade,anchor)end,uvFor,cells)end
  elseif c.object or c.objectTop then
   local o=c.object or c.objectTop
   if o.water then plane(b.wv,b.wi,x,z,uvFor(ts,o.ground) or uv,.05) else plane(b.v,b.i,x,z,uvFor(ts,c.objGround or o.ground) or uv) end
   if c.objectOwner and not c.stageHidden and not (o.merged and c.mass and Mass.usable(c.mass,cells)) then Standing.append(o,function(v,t,shade)quad(b.v,b.i,v,t,shade)end,function(v,t,shade)quad(leaf,li,v,t,shade,{0,0,0})end) end
  else
   if shape.planks then V.require('Gen3Fence').extrude(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor,1,shape.planks)
   elseif not flight then
    local drop=FORTREE_V2 and def and def.id=='EM_FORTREE_CITY' and V.require('Gen3Fortree').bridgeDrop(c) -- a rope bridge's planks are real boxes; its leaf layer hangs below
    if drop then b.skipOver[#b.skipOver+1]=#b.v end
    plane(b.v,b.i,x,z,(shape.groundMid and uvFor(ts,shape.groundMid)) or uv,drop or nil) end
   if shape.underWater then plane(b.wv,b.wi,x,z,uvFor(ts,shape.underWater) or uv,.05+(c.riverLevel or 0)-(c.base or 0)) end
  end
  if shape.underGrass then
   local bank=cells[c.cx..':'..(c.cy+(c.mid>=0x218 and 1 or -1))]
   if bank then plane(b.v,b.i,x,z,uvFor(ts,0x001),(bank.base or 0)-(c.base or 0)) end
  end
  local base=c.base or 0
  if shape.kind=='cliff' or shape.kind=='caveWall' then base=0 end
  if shape.level then base=shape.level end
  -- Over-player art is in the 3D model: do not also paint it flat on the ground.
  local Cable=V.require('Gen3CableCar')
  if Cable.skipsOver(c) then for q=starts[1],#b.v-4,4 do b.skipOver[#b.skipOver+1]=q end end
  if shape.ashTop then b.skipOver[#b.skipOver+1]=starts[1] end
  if shape.lampTop and V.require('Gen3Lamp').isTop(c,cells) then b.skipOver[#b.skipOver+1]=starts[1] end
  if Cable.owns(M.sceneDef and M.sceneDef.id,c) then Cable.append(M.sceneDef.id,c,function(p,t,s)quad(b.v,b.i,p,t,s)end,uvFor) end
  local walkCanopy=not c.stageHidden and Canopy.applies(c)
  if (c.object or c.objectTop or c.treeOwned or (shape.kind=='tree' and not shape.canopy) or walkCanopy) and #b.v>=starts[1]+4 then
   local v1,v2,v3,v4=b.v[starts[1]+1],b.v[starts[1]+2],b.v[starts[1]+3],b.v[starts[1]+4]
   if v1[2]==v2[2] and v2[2]==v3[2] and v3[2]==v4[2] and math.abs(v3[1]-v1[1])==16 and math.abs(v3[3]-v1[3])==16 then
    b.skipOver[#b.skipOver+1]=starts[1]
   end
  end
  if setBack and shape.kind~='deckFace' and shape.kind~='deckBack' and shape.kind~='deckEdge' and shape.kind~='deckHead' and shape.kind~='deckRamp' and not c.stageHidden then Decks.skirt(def,c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor) end
  if FORTREE_V2 and def and def.id=='EM_FORTREE_CITY' and not c.stageHidden then V.require('Gen3Fortree').append(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor) end
  local sl=c.slope
  if sl and base==c.base then
   local function off(px,pz)
    local u,w=math.max(0,math.min(1,(px-x)/16)),math.max(0,math.min(1,(pz-z)/16))
    return (sl[1]*(1-u)+sl[2]*u)*(1-w)+(sl[4]*(1-u)+sl[3]*u)*w
   end
   for k=starts[1]+1,#b.v do local v=b.v[k];v[2]=v[2]+off(v[1],v[3]) end
   for k=starts[3]+1,#b.pv do local v=b.pv[k]
    if v[7] and v[9] and v[9]~=0 then local o=off(v[7],v[8]);v[2]=v[2]+o;v[9]=v[9]+o
    else v[2]=v[2]+off(v[1],v[3]) end
   end
  end
  Elevation.lift(b.v,starts[1],base,setBack);Elevation.lift(b.rv,starts[2],base,setBack)
  if walkCanopy then local cs=#b.cv;Canopy.append(c,function(v,t,shade)quad(b.cv,b.ci,v,t,shade)end,uvFor,cells);Elevation.lift(b.cv,cs,base,setBack) end
  Elevation.lift(b.pv,starts[3],base,setBack);Elevation.lift(b.wv,starts[4],base,setBack)
  Elevation.lift(leaf,starts[5],base,setBack)
  if flight then flightTreads(c,flight,cells,b,uv) end
  if shape.kind=='water' and not shape.cyclingRoad then
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and (n.shape.kind=='water' or n.shape.seaRock) and (n.base or 0)<base then
     local ax,az=x+(d[1]>0 and 16 or 0),z+(d[2]>0 and 16 or 0)
     local bx,bz=ax+(d[1]==0 and 16 or 0),az+(d[2]==0 and 16 or 0)
     local lo,hi=(n.base or 0)+.05,base+.05
     local y=lo
     while y<hi-.01 do
      local yt=math.min(hi,y+16)
      quad(b.v,b.i,{{ax,y,az},{bx,y,bz},{bx,yt,bz},{ax,yt,az}},uv,.78)
      y=yt
     end
    end
   end
  end
  if not setBack and shape.kind~='rail' and shape.kind~='cliff' and shape.kind~='caveWall' and shape.kind~='water' and shape.kind~='pier' and not c.stairs and shape.kind~='steps' and not shape.cyclingRoad and not flight and not (shape.kind=='ledge' and Outdoor.ownsFaces(c)) then
   local deck=isDeck(c)
   local ftree=FORTREE_V2 and def and def.id=='EM_FORTREE_CITY' and shape.kind=='tree' and shape.canopy and not deck
   local base=ftree and (c.canopyBottom or base) or base
   if not deck and (c.collision or 0)~=0 then
    for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and (n.base or 0)==base and (isDeck(n) or (n.shape and n.shape.cyclingRoad=='deck')) then deck=true;break end
    end
   end
   local lowest,lowN
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    local inBand=n and n.civic and n.shape.kind=='cliff'
    if n and (n.shape.kind~='cliff' or inBand) and n.shape.kind~='caveWall' and n.shape.kind~='steps' and not n.stairs and not (ftree and n.shape.kind=='tree') then
     local low=n.base or 0
     if FORTREE_V2 and def and def.id=='EM_FORTREE_CITY' and n.shape.kind=='tree' and shape.kind~='tree' and n.cx>=0 and n.cy>=0
      and n.cx<def.midLayout.width and n.cy<def.midLayout.height then low=n.canopyBottom or 0 end
     local uv=uv
     if n.civic then
      for k=1,8 do for _,sx in ipairs({-k,k})do
       local q=cells[(n.cx+sx)..':'..n.cy]
       if q and q.shape and q.shape.kind=='cliff' and not q.civic then uv=uvFor(q.ts,q.mid) or uv;goto found end
      end end
      ::found::
     end
     if ledgeUV and c.floor and c.floor.bareDrop and not (n.floor and n.floor.ledge) and not n.stairs and not (n.floor and n.floor.step) then uv=ledgeUV end
     if low<base then
      if not lowest or low<lowest then lowest,lowN=low,n end
      local ax,az=x+(d[1]>0 and 16 or 0),z+(d[2]>0 and 16 or 0)
      local bx,bz=ax+(d[1]==0 and 16 or 0),az+(d[2]==0 and 16 or 0)
      local function band(y0,y1,rows)
       if c.primary=='secret_base' then
        local px=RISER_PX[c.mid] or RISER_PX[0]
        local u=uv[1][1]+(uv[2][1]-uv[1][1])*(px[1]+.5)/16
        local v=uv[1][2]+(uv[3][2]-uv[1][2])*(px[2]+.5)/16
        quad(b.v,b.i,{{ax,y0,az},{bx,y0,bz},{bx,y1,bz},{ax,y1,az}},{{u,v},{u,v},{u,v},{u,v}},.78)
        return
       end
       local v0=uv[3][2]-(uv[3][2]-uv[1][2])*rows/16
       local vb=uv[3][2]
       quad(b.v,b.i,{{ax,y0,az},{bx,y0,bz},{bx,y1,bz},{ax,y1,az}},{{uv[1][1],vb},{uv[2][1],vb},{uv[2][1],v0},{uv[1][1],v0}},.78)
      end
      local cs,ns,e=c.slope or NO_SLOPE,n.slope or NO_SLOPE,SLOPE_EDGE[d[1]..':'..d[2]]
      local sloped=not deck and not ftree and c.primary~='secret_base' and low==(n.base or 0) and base==c.base
       and (cs[e[1]]~=0 or cs[e[2]]~=0 or ns[e[3]]~=0 or ns[e[4]]~=0)
      if deck and (shape.planks or (FORTREE_V2 and def and def.id=='EM_FORTREE_CITY' and V.require('Gen3Fortree').bridgeDrop(c))) then -- a Fortree rope bridge has no side wall
      elseif deck then
       local t=math.min(DECK_THICKNESS,base-low)
       band(base-t,base,t)
      elseif sloped then
       local ta,tb,ba,bb=base+cs[e[1]],base+cs[e[2]],low+ns[e[3]],low+ns[e[4]]
       if ta-ba>.01 or tb-bb>.01 then
        local vb,span=uv[3][2],uv[3][2]-uv[1][2]
        local va,vbb=vb-span*math.min(16,math.max(0,ta-ba))/16,vb-span*math.min(16,math.max(0,tb-bb))/16
        quad(b.v,b.i,{{ax,ba,az},{bx,bb,bz},{bx,tb,bz},{ax,ta,az}},{{uv[1][1],vb},{uv[2][1],vb},{uv[2][1],vbb},{uv[1][1],va}},.78)
       end
      else
       local y=low
       while y<base do
        local h=math.min(16,base-y)
        band(y,y+h,h);y=y+h
       end
      end
     end
    end
   end
   if deck and lowest then
    local y=base-math.min(DECK_THICKNESS,base-lowest)
    quad(b.v,b.i,{{x,y,z+16},{x+16,y,z+16},{x+16,y,z},{x,y,z}},uv,.6)
    if lowN.shape.kind=='water' then
     plane(b.wv,b.wi,x,z,uvFor(ts,lowN.mid) or uv,.05)
    else
     plane(b.v,b.i,x,z,uvFor(ts,lowN.mid) or uv,lowest)
    end
   end
  end
  if kinds then
   local k=(shape and shape.kind or '?')..(c.mass and '+mass' or '')..((c.object or c.objectTop) and '+object' or '')..(c.prop and '+prop' or '')..(c.bldModel and '+bld' or '')
   local e=kinds[k] or {0,0};kinds[k]=e;e[1]=e[1]+os.clock()-kindT0;e[2]=e[2]+1
  end
 end
 local labWall={}
 for _,c in pairs(cells)do if c.secondary=='lab' and c.cy==0 and c.mid~=0 then
  local b=batches[c.pair];local uv=uvFor(c.ts,0x69)
  if uv and not labWall[c.cx] then
   labWall[c.cx]=true;local x=c.cx*16
   quad(b.v,b.i,{{x,32,32},{x+16,32,32},{x+16,16,32},{x,16,32}},uv)
   local u,t=(uv[1][1]+uv[2][1])*.5,uv[1][2]+(uv[3][2]-uv[1][2])*.8
   quad(b.v,b.i,{{x,16,32},{x+16,16,32},{x+16,0,32},{x,0,32}},swatch(c.ts,u,t))
  end
 end end
 local propMemo={}
 local function memoFor(p)
  for _,m in ipairs(propMemo[p.recipe] or {})do if m.ts==p.ts and m.pair==p.pair then
   local same=true
   for k,sig in pairs(m.reads)do
    local tx,ty=k:match('^(-?%d+):(-?%d+)$')
    if Furniture.sig(p,tonumber(tx),tonumber(ty))~=sig then same=false;break end
   end
   if same then return m end
  end end
 end
 for _,p in ipairs(props)do if not p.stageHidden then
  local b=batches[p.pair]
  local start,plantStart=#b.v,#b.pv
  local cutout=p.recipe.cutout
  local tv,ti=cutout and b.pv or b.v,cutout and b.pi or b.i
  local memo=p.recipe.kind=='pixel' and memoFor(p)
  if memo then
   local dx,dz=(p.cx-memo.cx)*16,(p.cy-memo.cy)*16
   local q=memo.quads
   for j=1,#q,4 do
    Budget.tick()
    local base,n=#tv,#ti
    for k=0,3 do local r=q[j+k];tv[base+k+1]={r[1]+dx,r[2],r[3]+dz,r[4],r[5],r[6]} end
    ti[n+1],ti[n+2],ti[n+3],ti[n+4],ti[n+5],ti[n+6]=base+1,base+2,base+3,base+1,base+3,base+4
   end
  else
   local rec=p.recipe.kind=='pixel' and {} or nil
   p.reads=rec and {} or nil
   Furniture.append(p,function(vertices,uv,shade,anchor)
    quad(tv,ti,vertices,uv,shade,anchor)
    if rec and (anchor or #vertices~=4) then rec=nil end -- (a swaying card is not copied)
    if rec then
     local s=shade or 1
     for k=1,4 do local a,t=vertices[k],uv[k];rec[#rec+1]={a[1],a[2],a[3],t[1],t[2],s} end
    end
   end,uvFor)
   if rec then
    local l=propMemo[p.recipe] or {};propMemo[p.recipe]=l
    if #l<8 then l[#l+1]={ts=p.ts,pair=p.pair,cx=p.cx,cy=p.cy,quads=rec,reads=p.reads} end
    p.reads=nil
   end
  end
  Elevation.lift(b.v,start,p.groundHeight or 0,setBack);Elevation.lift(b.pv,plantStart,p.groundHeight or 0,setBack)
 end end
 mark('cellgeo')
 cache.buildingModels={}
 for _,bld in ipairs(bldModels or {})do
  local m=BuildingModels.mesh(bld,cells)
  if m and bld.voxels then CamClear.addModel(cache.solid,bld.voxels.quads,bld.cx*16,bld.groundHeight or 0,(bld.cy+bld.depth)*16,Budget.tick)end
  if m and not firstArea then m.panes=V.require('GlassMask').building(m,cells,bld)end
  if m then cache.buildingModels[#cache.buildingModels+1]=m end
  Budget.check()
 end
 mark('bldmesh '..#(bldModels or {}))
 for _,b in pairs(batches)do
  local part={pair=b.pair,secondary=b.secondary,roofMids=b.roofMids}
  cache.parts[#cache.parts+1]=part
  local function upload(name,vertices,indices,format)
   if #vertices==0 then return end
   local mesh,err=R.newMesh(vertices,indices,format)
   assert(mesh,('field mesh %s/%s (%d vertices): %s'):format(b.pair,name,#vertices,tostring(err or 'unavailable')))
   part[name]=mesh
   Budget.check()
  end
  CamClear.addQuads(cache.solid,b.v,b.i,b.deckV,Budget.tick)
  if #b.underSkip>0 then
   local skip={};for _,base in ipairs(b.underSkip)do skip[base]=true end
   local keep={}
   for k=1,#b.i,6 do
    local first=math.min(b.i[k],b.i[k+1],b.i[k+2],b.i[k+3],b.i[k+4],b.i[k+5])-1
    if not skip[first] then for j=0,5 do keep[#keep+1]=b.i[k+j] end end
   end
   upload('under',b.v,keep);part.underIdx=keep
  else upload('under',b.v,b.i);part.underIdx=b.i end
  if #b.deckV>0 then part.deckV=b.deckV end
  upload('roof',b.rv,b.ri)
  upload('canopy',b.cv,b.ci)
  if (#b.skipOver>0 or #b.underSkip>0) and #b.v>0 then
   local skip={}
   for _,base in ipairs(b.skipOver)do skip[base]=true end
   local keep={}
   local n=#b.i
   for k=1,n,6 do
    local first=math.min(b.i[k],b.i[k+1],b.i[k+2],b.i[k+3],b.i[k+4],b.i[k+5])-1
    if not skip[first] then for j=0,5 do keep[#keep+1]=b.i[k+j] end end
   end
   upload('over',b.v,keep);part.overIdx=keep
  end
  upload('plants',b.pv,b.pi,R.TREE_FORMAT)
  part.waters={};local levels={}
  for j=1,#b.wv,4 do
   local q1,q3=b.wv[j],b.wv[j+2]
   local mx,mz=(q1[1]+q3[1])/2,(q1[3]+q3[3])/2
   for k=0,3 do local v=b.wv[j+k]
    v[1]=v[1]+(v[1]>mx and WATER_LAP or v[1]<mx and -WATER_LAP or 0)
    v[3]=v[3]+(v[3]>mz and WATER_LAP or v[3]<mz and -WATER_LAP or 0)
   end
   local h=b.wv[j][2];local group=levels[h]
   if not group then group={v={},i={}};levels[h]=group end
   local base=#group.v
   for k=0,3 do group.v[#group.v+1]=b.wv[j+k]end
   for _,k in ipairs({1,2,3,1,3,4})do group.i[#group.i+1]=base+k end
  end
  for h,g in pairs(levels)do
   local mesh=assert(R.newMesh(g.v,g.i));part.waters[#part.waters+1]={mesh=mesh,height=h};Budget.check()
  end
 end
 mark('geometry')
 cache.treeInstances={}
 V.require('NativeTreeArt').buildInstances(treeGroups,leaf,li,cache.treeInstances)
 Budget.check();cache.leaves=R.newMesh(leaf,li)
 V.require('Gen3Lamp').finish(cache,lampNight)
 cache.terrainKey=SceneCache.key(regions,x0,z0,x1,z1,Tiles._pairs,cam)
 return cache
end
-- Crossing a map edge must not wait for a cold build: the connected map is built while the player is still near its edge.
M.WARM_REACH=10
M.WARM_REACH_TOUR=14
M.WARM=.003
local Connections=require('src.core.game3.connections')
local aheadMemo={}
local function aheadRequest(game,cam,entry,reach)
 local def=entry.def
 local maps=game.data and game.data.maps
 if not (def.midLayout and maps)then return end
 local tour=walkGate(cam)
 local memo=aheadMemo
 if memo.from~=Map.current or memo.reach~=reach then memo={from=Map.current,reach=reach};aheadMemo=memo end
 local m=memo[entry.id]
 if not m then
  local world=Map.computeWorld(maps,entry.id,Map.WORLD_HOPS,reach,reach,function(id,d)Map.ensureMidLayout(game,id,d)end)
  local list,ids={},{}
  for _,conn in ipairs(Connections.each(def))do
   local d=maps[conn.map];if d then list[#list+1]={dir=conn.dir,map=conn.map,mapId=conn.map,def=d,offset=conn.offset};ids[conn.map]=true end
  end
  local regions={{def=def,x=0,y=0,w=def.midLayout.width,h=def.midLayout.height}}
  for _,e in ipairs(world)do
   if e.def.midLayout and (not tour or ids[e.id])then regions[#regions+1]={def=e.def,x=e.ox,y=e.oy,w=e.def.midLayout.width,h=e.def.midLayout.height}end
  end
  m={world=world,list=list,regions=regions};memo[entry.id]=m
 end
 -- where the player will stand on the other side: the nearest cell of that map
 local rw,rh=def.midLayout.width,def.midLayout.height
 local cx=math.max(entry.ox,math.min(entry.ox+rw-1,math.floor(((Player.px or 0)+8)/16)))
 local cz=math.max(entry.oy,math.min(entry.oy+rh-1,math.floor(((Player.py or 0)+8)/16)))
 local px,pz=(cx-entry.ox)*16,(cz-entry.oy)*16
 local radius,budget,x0,z0,x1,z1=M.NEAR,M.NEAR*16
 if tour then
  radius,budget=64,nil
  x0,z0,x1,z1=tourBounds(m.regions,math.floor(px/96)*6,math.floor(pz/96)*6)
 else
  local bx,bz=math.floor(px/96)*6,math.floor(pz/96)*6
  local north=(cam.level or 0)<6 and M.NEAR_NORTH or 0
  x0,z0,x1,z1=bx-radius,bz-radius-north,bx+radius+6,bz+radius+6-north
 end
 local tiles=tileIdentity(m.regions)
 local context=SceneCache.key(m.regions,0,0,0,0,tiles,cam)
 local key=SceneCache.key(m.regions,x0,z0,x1,z1,tiles,cam)
 if not (key and context)then return end
 return {game=game,cam=cam,def=def,regions=m.regions,key=key,tiles=tiles,context=context,x0=x0,z0=z0,x1=x1,z1=z1,px=px,pz=pz,
  radius=radius,budget=budget,world=m.world,list=m.list,id=entry.id}
end
local function aheadHooks(r)
 return {
  enter=function(p)
   if not p.adopted then p.saved={Map.world,Map.neighborList,Map.current};Map.world,Map.neighborList,Map.current=r.world,r.list,r.id end
   if p.value.firstAreaBuilt~=nil then firstArea=p.value.firstAreaBuilt end
  end,
  leave=function(p)
   local s=p.saved
   if s then Map.world,Map.neighborList,Map.current=s[1],s[2],s[3];p.saved=nil end
  end}
end
local function warmAhead(game,cam)
 if cam.battle or cam.replay or M.flySlice or not Map.world then return end
 local tour=walkGate(cam)
 local budget=Distance.radius()
 local reach=tour and M.DEBUG_REACH or (budget and math.ceil(budget/16) or 64)*2+12
 local px,pz=math.floor(((Player.px or 0)+8)/16),math.floor(((Player.py or 0)+8)/16)
 local near={}
 for _,e in ipairs(Map.world)do
  local L=e.def.midLayout
  if e.id~=Map.current and L then
   local dx=math.max(e.ox-px,0,px-(e.ox+L.width-1));local dz=math.max(e.oy-pz,0,pz-(e.oy+L.height-1))
   local d=math.max(dx,dz)
   if d<=(tour and M.WARM_REACH_TOUR or M.WARM_REACH) then
    local direct=tour
    for _,n in ipairs(Map.neighborList or {})do if n.map==e.id then direct=true end end
    if direct then near[#near+1]={e=e,d=d}end
   end
  end
 end
 table.sort(near,function(a,b)return a.d<b.d end)
 for _,n in ipairs(near)do
  local req=aheadRequest(game,cam,n.e,reach)
  if req and not stream:has(req.context)then
   local ready=true
   for i,r in ipairs(req.regions)do
    local pair=r.def.midLayout.pair
    local touches=i==1 or (r.x<=req.x1+1 and r.x+r.w>=req.x0-1 and r.y<=req.z1+1 and r.y+r.h>=req.z0-1)
    if pair and touches and not req.tiles[pair]then ready=false;Tiles.prefetch(pair,1)end
   end
   if ready then
    stream:warm(req.key,req.context,function(candidate)return build(req,candidate,nil)end,M.WARM,aheadHooks(req))
    return
   end
  end
 end
end
local SCENE_FIELDS={'sceneDef','distance','fadeExtent','fillCounts','forestTrees','stairCount','propCount','cliffCount','objectCount'}
local function prepare(game,vw,vh,cam)
 local req=request(game,cam);if not req then return false end
 local debugWalk=walkGate(cam)
 stream.capacity=debugWalk and 3 or 4
 -- Cold build is spread over frames; until ready, prepare returns false and the flat map draws.
 local same=stream.active~=nil and req.context~=nil and req.context==stream.context
 local near=not debugWalk and M.NEAR and req.context and not same and not cam.battle
 if near then for _,e in ipairs(stream.kept)do if e.key==req.key and e.context==req.context then near=nil;break end end end
 if near then req=request(game,cam,M.NEAR) or req end
 if same and not near and not debugWalk and stream.active.firstAreaBuilt and not cam.battle then
  req.upgrade=true
 end
 frames=frames+1
 local ready=true
 if req.context and not same then ready=tilesetsReady(req)end
 local scene
 if not ready and tileWait<TILE_WAIT then
  tileWait=tileWait+1
 else
  if ready then tileWait=0 end
  local Fade=require('src.ui.game3.fade')
  local cold=M.flySlice or debugWalk and M.DEBUG_COLD or near and .120 or (Fade.active and (Fade.t or 0)>=8) and .060 or .040
  if not same and not M.flySlice and M.lastFieldCanvas and directNeighbours()[M.lastFieldMap] then cold=M.STREAM end
  if M.flySlice and same and stream.active then
   scene=stream.active
  else
   local slice=(stream.active and stream.active.nearOnly) and M.NEAR_STREAM or M.STREAM
   local bounds=same and stream.active.distance and stream.active.distance.bounds
   if bounds then
    local margin=math.min(req.px/16-bounds[1],bounds[3]-req.px/16,req.pz/16-bounds[2],bounds[4]-req.pz/16)
    if margin<10 and req.key~=stream.key then
     stream:cancelWarm()
     slice=.040
    end
   end
   scene=stream:update(req.key,req.context,function(candidate,previous)return build(req,candidate,previous)end,slice,cold,
    function()
     local tiles=tileIdentity(req.regions)
     return SceneCache.key(req.regions,0,0,0,0,tiles,req.cam),SceneCache.key(req.regions,req.x0,req.z0,req.x1,req.z1,tiles,req.cam)
    end)
  end
 end
 if Tiles._pairs[req.def.midLayout.pair]then Tiles.get(req.def.midLayout.pair)end
 M.prepares=stream.stats.started;M.builds=stream.stats.completed;M.cacheHits=stream.stats.hits
 if not scene then
  cache={}
  for _,name in ipairs(SCENE_FIELDS)do M[name]=nil end
  return false
 end
 if near and stream.pending==nil and scene.nearOnly==nil then scene.nearOnly=true end
 if stream.pending==nil and not (near or req.upgrade) then pcall(warmAhead,game,cam)end
 cache=scene
 for _,name in ipairs(SCENE_FIELDS)do M[name]=cache[name]end
 return true
end
local function panesOf(ts,image)
 if not ts then return nil end
 return V.require('GlassMask').panes(ts,image)
end
local overInk=setmetatable({},{__mode='k'})
local function ink(ts,mid)
 local t=overInk[ts];if not t then t={};overInk[ts]=t end
 if t[mid]==nil then
  local n=0
  local slot=ts.overImageData and ts.midToSlot and ts.midToSlot[mid]
  if slot then
   local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
   for y=0,15 do for x=0,15 do local _,_,_,a=ts.overImageData:getPixel(ox+x,oy+y);if a>.5 then n=n+1 end end end
  end
  t[mid]=n
 end
 return t[mid]
end
local function eyeUnderCrown()
 local def=M.sceneDef;if not def then return false end
 local Player=require('src.core.game3.player')
 local cx,cy=math.floor(((Player.px or 0)+8)/16),math.floor(((Player.py or 0)+8)/16)
 local ok,mid,pair,isVoid=pcall(Map.worldMidAt,cx,cy,def)
 if ok and mid and not isVoid then local ts=Tiles._pairs[pair];if ts and ink(ts,mid)>=48 then return true end end
 if cache.cells then for dy=-1,1 do for dx=-1,1 do
  local c=cache.cells[(cx+dx)..':'..(cy+dy)];if c and c.shape and c.shape.kind=='tree' then return true end
 end end end
 return false
end
local function terrain(draw)
 local original=draw
 local lit=false
 local function draw(mesh,image,panes)
  -- Each mesh sets its own panes, so later sprites never inherit a tileset's windows.
  if original==R.draw and panes~=lit then R.glassMaskNow(panes);lit=panes end
  local previous=R.surfaceDetail
  R.surfaceDetail=TreeStyle.surfaces:get()=='detailed'
  local ok,err=pcall(original,mesh,image)
  R.surfaceDetail=previous
  if not ok then error(err,0)end
 end
 local under=original==R.draw and V.require('Gen3Integration').level==6 and eyeUnderCrown()
 local function crowns(mesh,image)
  R.nearCut=under and 20 or nil
  local ok,err=pcall(draw,mesh,image)
  R.nearCut=nil
  if not ok then error(err,0)end
 end
 for _,p in ipairs(cache.parts)do
  local ts=Tiles._pairs[p.pair]
  if ts then
   if p.deckV and p.under and p.underIdx then M.deckCut(p) end
   draw(p.under,ts.image,panesOf(ts,ts.image))
   if ts.overImage then draw(p.over or p.under,ts.overImage,panesOf(ts,ts.overImage))end
   if p.canopy then draw(p.canopy,ts.overImage or ts.image)end
   if p.plants then local img=Outdoor.image(ts,math.floor((require('src.core.game3.tileset_anim').counter or 0)/16)) or ts.image;draw(p.plants,img)end
   if p.roof then
    local material=Roof.image(ts,p.secondary,Shapes.of,p.roofMids)
    draw(p.roof,material or ts.image)
    if not material and ts.overImage then draw(p.roof,ts.overImage)end
   end
  end
 end
 for _,bld in ipairs(cache.buildingModels or {})do draw(bld.mesh,bld.image,bld.panes)end
 crowns(cache.leaves,V.require('NativeTreeArt').image())
 for _,batch in ipairs(cache.treeInstances or {})do crowns(batch,V.require('NativeTreeArt').image())end
 if original==R.draw and lit then R.glassMaskNow(nil);lit=nil end
end
local function waterMeshes()
 local out={}
 for _,p in ipairs(cache.parts)do
  local ts=Tiles._pairs[p.pair]
  if ts then for _,water in ipairs(p.waters or {})do out[#out+1]={water.mesh,ts.image,nil,water.height}end end
 end
 return out
end
local reflectPlane
local dustMesh,dustImage
local function rideDust(game,cam)
 local exports=game and game.mods and game.mods.exports
 local ride=exports and exports.DRAMATIC_SKY_RIDE
 if not (ride and type(ride.groundParticles)=='function')then return end
 local ok,particles=pcall(ride.groundParticles)
 if not ok or type(particles)~='table' or #particles==0 then return end
 if not dustMesh then
  local v,i={},{}
  quad(v,i,{{-1,2,0},{1,2,0},{1,0,0},{-1,0,0}},{{0,0},{1,0},{1,1},{0,1}})
  dustMesh=R.newMesh(v,i)
  local data=love.image.newImageData(1,1);data:setPixel(0,0,.72,.62,.43,1)
  dustImage=love.graphics.newImage(data)
 end
 if not dustMesh then return end
 for _,p in ipairs(particles)do
  if type(p.x)=='number' and type(p.z)=='number' then
   local t=math.max(0,math.min(1,(tonumber(p.age)or 0)/math.max(.001,tonumber(p.life)or .4)))
   local model=Mat.mul(Mat.translate(p.x,M.groundAt(p.x,p.z)+.3+t*3,p.z),
    Mat.mul(Mat.rotateY(cam.level>=6 and -cam.yaw or 0),Mat.scale(1-t,1-t,1)))
   R.draw(dustMesh,dustImage,model)
  end
 end
end
M.ACTOR_DEPTH=2
M.ACTOR_LEAN=.55
M.FLAT_GFX={[141]=true}
local flatMeshes={}
function M.fastMesh(verts,map)
 if #verts==0 then return nil end
 local ok,mesh=pcall(love.graphics.newMesh,R.FORMAT,#verts,'triangles','static')
 if not ok then return nil end
 if not pcall(mesh.setVertices,mesh,verts) then mesh:release();return nil end
 if map and #map>0 and not pcall(mesh.setVertexMap,mesh,map) then mesh:release();return nil end
 return mesh
end
local function cardMesh(spr,frame,mirror)
 local q=spr.quads[frame];if not q then return end
 local padding=SpriteAnchor.framePadding(spr,frame)
 local key=tostring(spr)..':'..tostring(spr.image)..':'..frame..':'..tostring(mirror)..':'..padding
 local mesh=spriteMeshes[key]
 if not mesh then
  local qx,qy,qw,qh=q:getViewport();local iw,ih=spr.image:getDimensions()
  local l,r=qx/iw,(qx+qw)/iw;if mirror then l,r=r,l end
  local v,i={},{}
  quad(v,i,{{-qw/2,qh-padding,0},{qw/2,qh-padding,0},{qw/2,-padding,0},{-qw/2,-padding,0}},{{l,qy/ih},{r,qy/ih},{r,(qy+qh)/ih},{l,(qy+qh)/ih}})
  local D=M.ACTOR_DEPTH
  if D>0 and spr.imageData then
   quad(v,i,{{qw/2,qh-padding,-D},{-qw/2,qh-padding,-D},{-qw/2,-padding,-D},{qw/2,-padding,-D}},{{r,qy/ih},{l,qy/ih},{l,(qy+qh)/ih},{r,(qy+qh)/ih}},.9)
   local data=spr.imageData
   local function solid(px,py)
    if px<0 or py<0 or px>=qw or py>=qh then return false end
    local ok,_,_,_,a=pcall(data.getPixel,data,qx+px,qy+py)
    return ok and (a or 0)>.5
   end
   for py=0,qh-1 do for px=0,qw-1 do
    if solid(px,py) then
     local sx=mirror and (qw-1-px) or px
     local x0,x1=-qw/2+sx,-qw/2+sx+1
     local y1,y0=qh-padding-py,qh-padding-py-1
     local u,t=(qx+px+.5)/iw,(qy+py+.5)/ih
     local c={{u,t},{u,t},{u,t},{u,t}}
     if not solid(px-1,py) then local ex=mirror and x1 or x0
      quad(v,i,{{ex,y1,0},{ex,y1,-D},{ex,y0,-D},{ex,y0,0}},c,.8) end
     if not solid(px+1,py) then local ex=mirror and x0 or x1
      quad(v,i,{{ex,y1,-D},{ex,y1,0},{ex,y0,0},{ex,y0,-D}},c,.8) end
     if not solid(px,py-1) then quad(v,i,{{x0,y1,0},{x1,y1,0},{x1,y1,-D},{x0,y1,-D}},c,.95) end
     if not solid(px,py+1) then quad(v,i,{{x0,y0,-D},{x1,y0,-D},{x1,y0,0},{x0,y0,0}},c,.7) end
    end
   end end
  end
  mesh=M.fastMesh(v,i);spriteMeshes[key]=mesh
 end
 return mesh
end
M.cardMesh=cardMesh
local function actor(gid,x,z,facing,phase,flip,opts,cam,draw)
 if not (cache.cells and cache.cells[math.floor((x+8)/16)..':'..math.floor((z+8)/16)]) then return end
 local spr=Sprites.getDraw(gid);if not spr then return end
 if M.FLAT_GFX[tonumber(gid) or -1] then
  if draw==Shadow.draw or reflectPlane then return end
  local frame=Sprites.pose(spr,'down',0,false,opts)
  local q=spr.quads[frame] or spr.quads[0];if not q then return end
  local key=tostring(spr.image)..':'..frame
  local mesh=flatMeshes[key]
  if not mesh then
   local qx,qy,qw,qh=q:getViewport();local iw,ih=spr.image:getDimensions()
   local v,i={},{}
   quad(v,i,{{-qw/2,0,-qh},{qw/2,0,-qh},{qw/2,0,0},{-qw/2,0,0}},{{qx/iw,qy/ih},{(qx+qw)/iw,qy/ih},{(qx+qw)/iw,(qy+qh)/ih},{qx/iw,(qy+qh)/ih}})
   mesh=R.newMesh(v,i);flatMeshes[key]=mesh
  end
  local floor=M.groundAt(x+8,z+16-.001,opts.elevation)
  local c=cache.cells[math.floor((x+8)/16)..':'..math.floor((z+8)/16)]
  if c and c.shape and c.shape.kind=='water' then floor=c.base or floor end
  draw(mesh,spr.image,Mat.translate(x+8,floor+.15,z+16),0)
  return
 end
 if M.logActors then
  local k=tostring(gid)..':'..math.floor(x/16)..':'..math.floor(z/16)
  if not M.logActors[k] then M.logActors[k]=true;print('[EM actor]',gid,math.floor(x/16),math.floor(z/16),spr.quads and spr.quads[0] and select(3,spr.quads[0]:getViewport()),spr.quads and spr.quads[0] and select(4,spr.quads[0]:getViewport())) end
 end
 local solid=Landmarks.mesh(gid,spr) or RockSprites.mesh(gid,spr)
 local mesh=solid
 if not solid then
  facing=V.require('Gen3Integration').worldDirection(facing,-(cam.level>=6 and cam.yaw or 0))
  local frame,mirror=Sprites.pose(spr,facing,phase,flip,opts)
  mesh=cardMesh(spr,frame,mirror);if not mesh then return end
 end
 local yaw=solid and 0 or (cam.level>=6 and -cam.yaw or 0)
 local floor=M.groundAt(x+8,z+16-.001,opts.elevation)
 local setBack=(M.sceneDef and Decks.MAPS[M.sceneDef.id or '']) and floor or 0
 local contact=cache.cells[math.floor((x+8)/16)..':'..math.floor((z+8)/16)]
 if contact and contact.prop then floor=contact.prop.groundHeight or floor end
 floor=floor+Furniture.flightHeight(cache.cells,x+8,z+8)
 local height=floor+(opts.lift or 0)
 if draw~=Shadow.draw and not reflectPlane and (opts.depthOffset or 0)==0 then
  V.require("ActorContact").draw(x+8,z+16+setBack-(solid and Landmarks.SCALE[tonumber(gid) or 0] and 8 or 0),floor,height-floor,spr.width*(solid and Landmarks.SCALE[tonumber(gid) or 0] or 1))
 end
 local viewAngle=cam.level>=6 and (cam.pitch or 0) or (V.require('VoxelState').angle or 0)
 local lean=((opts.upright or solid) and 0 or M.ACTOR_LEAN)*viewAngle
 local pose=lean~=0 and Mat.mul(Mat.rotateY(yaw),Mat.rotateX(-lean)) or Mat.rotateY(yaw)
 local base=Mat.mul(Mat.translate(x+8,height,z+16+setBack+(opts.depthOffset or 0)),pose)
 local grow=solid and Landmarks.SCALE[tonumber(gid) or 0]
 if grow then pose=Mat.mul(pose,Mat.scale(grow,grow,grow));base=Mat.mul(base,Mat.scale(grow,grow,grow)) end
 local caster=Shadow.snug(base)
 if reflectPlane then height=2*reflectPlane-height+V.require('Water').CAST_RAISE end
 local model=reflectPlane and Mat.mul(Mat.translate(x+8,height,z+16+setBack+(opts.depthOffset or 0)),pose) or base
 if reflectPlane then model=Mat.mul(model,Mat.scale(1,-1,1))end
 if draw==Shadow.draw then
  draw(mesh,spr.image,caster)
 else
  draw(mesh,spr.image,model,solid and 0 or (opts.pull or 7),caster)
 end
end
function M.debugRaw(cx,cy)return cache.cells and cache.cells[cx..':'..cy] end
function M.builtBounds()return M.distance and M.distance.bounds or nil end
function M.readyFor(id)return M.sceneDef~=nil and M.sceneDef.id==id end
function M.groundAt(x,z,elev)
 for _,r in ipairs(cache.floorRegions or {})do
  local lx,lz=x-r.x*16,z-r.y*16
  if lx>=0 and lz>=0 and lx<r.w*16 and lz<r.h*16 then
   if elev==3 or elev==1 then
    local dc=cache.cells and cache.cells[(r.x+math.floor(lx/16))..':'..(r.y+math.floor(lz/16))]
    if dc and dc.shape and dc.shape.cyclingRoad=='deck' then return r.floorOffset or 0 end
   end
   return V.require('TerrainLevels').at(r.floorField,lx,lz)+(r.floorOffset or 0)
  end
 end
 return 0
end
function M.deckCut(p)
 local e=Player.elevation
 local pcx,pcy=math.floor(((Player.px or 0)+8)/16),math.floor(((Player.py or 0)+8)/16)
 local want
 if e~=4 then
  for _,r in ipairs(p.deckV)do if math.abs(r[1]-pcx)<=1 and math.abs(r[2]-pcy)<=1 then want=pcx..':'..pcy;break end end
 end
 if want==p.cutKey then return end
 p.cutKey=want
 local function apply(mesh,idx,cut)
  if not mesh then return end
  if not cut then mesh:setVertexMap(idx);return end
  local map,n={},0
  for k=1,#idx,6 do
   if not cut[idx[k]] then for j=0,5 do n=n+1;map[n]=idx[k+j] end end
  end
  mesh:setVertexMap(map)
 end
 if not want then apply(p.under,p.underIdx);apply(p.over,p.overIdx);return end
 local cut={}
 for _,r in ipairs(p.deckV)do if math.abs(r[1]-pcx)<=4 and math.abs(r[2]-pcy)<=4 then for v=r[3],r[4]do cut[v]=true end end end
 apply(p.under,p.underIdx,cut);apply(p.over,p.overIdx,cut)
end
local function actors(game,cam,draw)
 if cam.replay then
  local frame=cam.replay.frame
  for _,a in ipairs(frame.actors or {})do
   if a.graphicsId and not (a.id==255 and cam.level==6) then
    local support,offset=Furniture.support(cache.cells,a.graphicsId,a.x,a.y,(a.walkPhase or 0)==0)
    local z=a.id==255 and frame.y or a.y
    actor(a.graphicsId,a.x,z,a.facing,a.walkPhase,a.stepFlip,
     {frame=a.frame,bow=a.bow,fieldMove=a.fieldMove,depthOffset=offset or 0,lift=support+(z-a.y)},cam,draw)
   end
  end
  return
 end
 local space=package.loaded['src.core.game3.scripting.space']
 local Fly=V.require('Gen3FlyOver')
 local flying=Fly.active()
 for _,eo in ipairs(Objects.forDraw())do if not (flying and eo.mon and Fly.hidesFollowers())then
  local gid=eo.graphicsId or (eo.def and (eo.def.graphicsId or eo.def.graphics))
  if space and space.resolveObjectGraphicsId and eo.def then gid=space.resolveObjectGraphicsId(eo.def) or gid end
  local support,depthOffset=Furniture.support(cache.cells,gid,eo.px or eo.cellX*16,eo.py or eo.cellY*16,not eo.moving)
  actor(gid,(eo.px or eo.cellX*16)+(eo.raiseX or 0),eo.py or eo.cellY*16,
   eo.facing or 'down',Objects.walkPhase(eo),eo.stepFlip,
   {bow=(eo.bowFrames or 0)>0 or eo.raiseHand,elevation=eo.elevation,frame=eo.customFrame,upright=tonumber(gid)==92 or tonumber(gid)==94,depthOffset=depthOffset or 0,lift=support-(eo.raiseY or 0)},cam,draw)
 end end
 -- Connected maps use the engine's ghost snapshots; never advance those actors here.
 local Ghosts=require('src.core.game3.ghosts')
 for _,entry in ipairs(Map.world or {})do
  if entry.id~=Map.current then
   local live=Ghosts.forDraw(entry.id)
   if live then
    for _,eo in ipairs(live)do
     actor(eo.graphicsId or (eo.def and (eo.def.graphicsId or eo.def.graphics)),
      (eo.px or eo.cellX*16)+entry.ox*16,(eo.py or eo.cellY*16)+entry.oy*16,
      eo.facing or 'down',Objects.walkPhase(eo),eo.stepFlip,{},cam,draw)
    end
   else
    local event=space and space.bundle and space.bundle.events and space.bundle.events[entry.id]
    local defs=event and (event.objects or event.objectEvents) or entry.def.objects or {}
    local bounds=Objects.layoutBounds(entry.def)
    for _,obj in ipairs(defs)do
     local x,y=tonumber(obj.x) or 0,tonumber(obj.y) or 0
     local visible=not obj.flag or obj.flag==0 or (space and space.objectVisible and space.objectVisible(obj))
     if visible and (not bounds or (x>=0 and y>=0 and x<bounds.w and y<bounds.h)) then
      actor(obj.graphicsId or obj.graphics,(entry.ox+x)*16,(entry.oy+y)*16,
       tostring(obj.facing or 'down'):lower(),0,false,{},cam,draw)
     end
    end
   end
  end
 end
 if cam.level~=6 and Player.isVisible() and not (flying and Fly.hidesPlayer()) then
  actor(Sprites.playerGraphicsId(game),(Player.px or 0)+(Player.spriteXOffset or 0),Player.py or 0,
   Player.facing,Player.walkPhase(),Player.drawFlip(),
   {fieldMove=(Player.fieldMoveAnim or 0)>0,elevation=Player.elevation,lift=-(Player.spriteYOffset or 0)-(Player.jumpSpriteY and Player.jumpSpriteY()or 0)},cam,draw)
 end
end
-- Drawing these never advances their timers or script state.
local effectCanvases={}
local function fieldEffects(draw,cam)
 local g=love.graphics
 local function effect(name,w,h,paint,verts,base)
  local c=effectCanvases[name]
  if not c then c=g.newCanvas(w,h);c:setFilter('nearest','nearest');effectCanvases[name]=c end
  g.push('all');g.setCanvas(c);g.origin();g.setShader();g.setScissor();g.setDepthMode();g.setBlendMode('alpha');g.clear(0,0,0,0);g.setColor(1,1,1,1)
  local ok,err=pcall(paint);g.pop();if not ok then error(err,0)end
  local v,i={},{};quad(v,i,verts,{{0,0},{1,0},{1,1},{0,1}})
  Elevation.lift(v,0,base or 0)
  local mesh=R.newMesh(v,i);draw(mesh,c);mesh:release()
 end
 local fx=require('src.core.game3.field_effects')
 for i,a in ipairs(fx._anims or {})do if a.kind=='dust' then
  local x,z=a.cx*16,a.cy*16
  local yaw=cam and cam.level>=6 and cam.yaw or 0
  local dx,dz=8*math.cos(yaw),8*math.sin(yaw)
  effect('landing-dust-'..i,16,8,function()fx.drawFront(x,z+8,nil)end,
   {{x+8-dx,8,z+16-dz},{x+8+dx,8,z+16+dz},{x+8+dx,0,z+16+dz},{x+8-dx,0,z+16-dz}},M.groundAt(x+8,z+16-.001))
 end end
 for i,a in ipairs(fx._anims or {})do if a.kind=='emote' then
  local sheet=fx._sheets and fx._sheets[a.sheet or 'emoticons']
  local q=sheet and sheet.quads and sheet.quads[a.frame]
  local t=a.targetObj
  if q and t then
   local x=t.px or (t.cellX and t.cellX*16) or (t.x and t.x*16) or 0
   local z=t.py or (t.cellY and t.cellY*16) or (t.y and t.y*16) or 0
   local yaw=cam and cam.level>=6 and cam.yaw or 0
   local dx,dz=8*math.cos(yaw),8*math.sin(yaw)
   local lift=24-(a.yOffset or 0)
   local ground=M.groundAt(x+8,z+16-.001)
   local back=(M.sceneDef and Decks.MAPS[M.sceneDef.id or '']) and ground or 0
   local zz=z+15+back
   effect('emote-'..i,16,16,function()g.draw(sheet.image,q,0,0)end,
    {{x+8-dx,lift+16,zz-dz},{x+8+dx,lift+16,zz+dz},{x+8+dx,lift,zz+dz},{x+8-dx,lift,zz-dz}},ground)
  end
 end end
 local doors=require('src.core.game3.doors');local a=doors._activeAnim
 if a then
  local x,z=a.x*16,a.y*16+16.15
  effect('door',32,48,function()doors.draw(x,a.y*16-32,32,48)end,
   {{x,48,z},{x+32,48,z},{x+32,0,z},{x,0,z}},M.groundAt(x+8,z))
 end
 local heal=require('src.core.game3.pokecenter_heal')
 if heal.isActive()then
  local prop,screen
  for _,c in pairs(cache.cells or {})do if c.prop then
   if c.prop.recipe.name=='center_healer'then prop=c.prop end
   if c.prop.recipe.name=='center_screen'then screen=c.prop end
  end end
  if prop then
   local x,z,h=prop.cx*16,prop.cy*16,prop.recipe.h+.18+(prop.groundHeight or 0)
   effect('heal-balls',32,24,function()g.translate(-80,-28);heal.drawBalls()end,
    {{x+3,h,z+12},{x+29,h,z+12},{x+29,h,z+28},{x+3,h,z+28}})
   if screen then
    local sx,sz=screen.cx*16,screen.cy*16+(screen.recipe.frontOffset or 32.2)+.04
    effect('heal-monitor',32,16,function()g.translate(-112,-16);heal.drawMonitor()end,
     {{sx+2,28,sz},{sx+30,28,sz},{sx+30,12,sz},{sx+2,12,sz}},screen.groundHeight or 0)
   end
  end
 end
end
function M.restore()
 R.battleOcclusion(nil)
 R.fog=nil
 R.interior=nil
 R.tint={1,1,1}
 reflectPlane=nil
 if saved then
  pcall(R.endScene);love.graphics.pop();love.graphics.setCanvas(savedCanvas)
  saved,savedCanvas=false,nil
 end
end
local function presentField(canvas,vw,vh)
 local Renderer=require('src.render.Renderer')
 if Renderer.setWorldOverride and Renderer.frameRects and not require('src.core.game3.display').planesBroken then Renderer:setWorldOverride(canvas) end
 love.graphics.push('all');love.graphics.origin();love.graphics.setShader();love.graphics.setColor(1,1,1,1)
 love.graphics.setBlendMode('alpha','premultiplied');love.graphics.draw(canvas,0,0,0,vw/canvas:getWidth(),vh/canvas:getHeight())
 love.graphics.pop()
end
function M.draw(game,vw,vh,cam)
 local Fly=V.require('Gen3FlyOver')
 local flying=Fly.active() and not cam.battle and not cam.replay
 M.flySlice=flying and Fly.slice() or nil
 local built=prepare(game,vw,vh,cam)
 if not built and not flying then
  if M.lastFieldCanvas and not (cam.battle or cam.replay) and directNeighbours()[M.lastFieldMap] then
   presentField(M.lastFieldCanvas,vw,vh)
   return true
  end
  return false
 end
 -- Script camera panning belongs to the flat renderer; it must not move the 3D eye.
 local focus=cam.replay and cam.replay.frame or Player
 local cx,cz=(focus.px or focus.x or 0)+8,(focus.py or focus.y or 0)+8
 if cam.battle and cam.center then cx,cz=cam.center[1],cam.center[2]end
 if flying then cx,cz=Fly.focus()end
 local camBack=0
 if cam.level>=6 and not flying and M.sceneDef and Decks.MAPS[M.sceneDef.id or ''] and not cam.battle then camBack=M.groundAt(cx,cz+8-.001);cz=cz+camBack end
 local width,height=love.graphics.getCanvas():getDimensions()
 local Renderer=require('src.render.Renderer')
 local Display=require('src.core.game3.display')
 local override=Renderer.setWorldOverride and Renderer.frameRects and not Display.planesBroken
 if override then
  local rect=Renderer:frameRects()
  width=math.max(1,math.floor(rect.vuw*rect.dpiX+.5))
  height=math.max(1,math.floor(rect.vuh*rect.dpiY+.5))
 end
 M.renderWidth,M.renderHeight=width,height
 local Options=V.require('Gen3SceneOptions')
 local renderWidth,renderHeight=width,height
 local def=M.sceneDef or Map.currentDef()
 if not def then return false end
 local indoor
 if Pairs.outdoor then indoor=not Pairs.outdoor(def)
 else indoor=def.environment=='INDOOR' or def.mapType==8 or def.mapType==4 end
 if def.id and OPEN_SKY[def.id] then indoor=false end
 local nativeBackground=def.mapType==4 and {.045,.030,.034,1} or Interior.background
 local background=Options.environment(indoor,indoor and nativeBackground or {.60,.79,.82,1})
 local plate=cam.battle and cam.plate
 if plate then background=plate.color end
 local S=V.require('VoxelState')
 S.level=cam.level;S.angle=math.rad(S.ANGLES_DEG[cam.level+1] or 35)
 R.canopyFacing=cam.battle or cam.level>=6
 if cam.level>=6 then
  local dist=cam.level==6 and 0 or 75
  local dx,dz=math.sin(cam.yaw),-math.cos(cam.yaw)
  local ground=M.groundAt(cx,cz-camBack+8-.001,Player.elevation)
  local ey=48+ground
  if cam.level==6 then
   ey=ground+SpriteAnchor.eyeHeight(Sprites.getDraw(Sprites.playerGraphicsId(game)))
     -(Player.spriteYOffset or 0)-(Player.jumpSpriteY and Player.jumpSpriteY()or 0)
  end
  local exports=game and game.mods and game.mods.exports
  local ride=exports and exports.DRAMATIC_SKY_RIDE
  if not cam.battle and not cam.replay and ride and type(ride.currentAltitude)=='function' then
   local ok,height=pcall(ride.currentAltitude)
   if ok and type(height)=='number' then ey=ey+math.max(0,math.min(512,height))end
  end
  if dist>0 and not cam.battle and not cam.replay and not flying and cache.solid then
   local Clear=V.require('Gen3CamClear')
   dist=Clear.ease(camArm,Clear.arm(cache.solid,cx,cz,dx,dz,ey,dist),love.timer.getDelta(),90,cache)
  end
  local focusDistance=cam.level==6 and 24 or 70
  R.camera={eye={cx-dx*dist,ey,cz-dz*dist},focus={cx+dx*focusDistance,ey-focusDistance*math.tan(cam.pitch),cz+dz*focusDistance},fov=math.rad(62)}
  if cam.battle then
   local bc={dist=80,height=24,look=36,lookY=-8,fov=38,pitchUnits=40}
   local dist=cam.dist or bc.dist
   local height=(cam.height or bc.height)+((cam.pitch or .38)-.38)*bc.pitchUnits
   local look,lookY=cam.look or bc.look,cam.lookY or bc.lookY
   R.camera={eye={cx-dx*dist,ground+height,cz-dz*dist},focus={cx+dx*look,ground+lookY,cz+dz*look},fov=math.rad(cam.fov or bc.fov)}
  end
 else
  R.camera=Interior.camera(Interior.forMap(def,3),S.angle,vw/vh)
  if R.camera then cx,cz=R.camera.focus[1],R.camera.focus[3]end
 end
 if flying then R.camera=Fly.camera(R.camera,cx,cz,M.groundAt(cx,cz-camBack+8-.001,Player.elevation),vw,vh,cam)end
 local atmosphere=V.require("NativeAtmosphere")
 local atmosphereMap=atmosphere.gen3(def,Map.current)
 if atmosphere.kind(atmosphereMap)=="forest" then V.require("DayNight").applyRig(false) end
 R.orbitGround=M.groundAt(cx,cz-camBack+8-.001,Player.elevation)
 R.viewProjection(cx,cz,vw,vh)
 R.orbitGround=nil
 savedCanvas=love.graphics.getCanvas();love.graphics.push('all');saved=true
 if not plate and built and Shadow.begin(cx,cz,vw,vh) then
  local room=not cam.battle and Interior.forMap(def,3) or nil
  Shadow.roomClip(room and room.bounds)
  terrain(Shadow.draw)
  for _,d in ipairs(waterMeshes())do Shadow.draw(d[1],d[2])end
  if not cam.battle then
   Shadow.sprites(true);actors(game,cam,Shadow.draw);Shadow.sprites(false)
  end
  Shadow.finish('firered')
 end
 local room=not cam.battle and Interior.forMap(def,3) or nil
 Interior.setOpenings(room,cache.openings)
 Interior.configure(room)
 local bounds=built and M.distance.bounds
 R.fog=not indoor and bounds and Distance.haze(background,M.fadeExtent,{cx,0,cz},
  {bounds[1]*16,bounds[2]*16,(bounds[3]+1)*16,(bounds[4]+1)*16})or nil
 R.fog=atmosphere.fog(atmosphereMap) or R.fog
 if flying then R.fog=Fly.fog(background,R.fog,cx,cz)end
 R.glassNight=(not indoor) and V.require('DayNight').windowLight() or 0
 R.glassMask=nil
 if not R.beginScene(renderWidth,renderHeight,cx,cz,vw,vh,background,'firered') then M.restore();return false end
 R.battleOcclusion(nil)
 if plate then
  if plate.image then R.backdrop(plate.image,plate.offset)end
 else
  Options.underlay(indoor,cx,cz,background)
  Interior.draw(room)
  if built then terrain(R.draw)end
  if flying then Fly.drawGround(R.draw)end
 end
 local water=not plate and built and waterMeshes()or {}
 if cam.battle then
  for _,d in ipairs(water)do R.draw(d[1],d[2])end
  V.require('Gen3StadiumModels').draw(game,cam,cx,cz,M.groundAt)
 else
  local waterLevels={}
  for _,d in ipairs(water)do local h=d[4];waterLevels[h]=waterLevels[h]or{};local group=waterLevels[h];group[#group+1]=d end
  for h,group in pairs(waterLevels)do
   V.require('WaterSurfacePass').draw(group,function()actors(game,cam,R.draw)end,function()
    reflectPlane=h
    local ok,err=pcall(actors,game,cam,R.draw)
    reflectPlane=nil
    if not ok then error(err,0)end
   end)
  end
  if built then actors(game,cam,R.draw)end
  if not cam.replay and built then rideDust(game,cam);fieldEffects(R.draw,cam)end
  if flying then Fly.drawRider(R.draw,cam)end
  if not indoor and built then V.require('Gen3Lamp').draw(cache,R,V.require('DayNight').windowLight()) end
 end
 R.battleOcclusion(nil)
 if not plate and built then atmosphere.draw(atmosphereMap) end
 local canvas=Options.finish(R.endScene(),width,height)
 if flying then Fly.overlay(canvas,width,height,renderWidth,renderHeight)end
 R.fog=nil
 R.tint={1,1,1}
 love.graphics.pop();love.graphics.setCanvas(savedCanvas);saved=false;savedCanvas=nil
 if not (cam.battle or cam.replay or flying) then
  M.lastFieldCanvas,M.lastFieldMap=canvas,Map.current
 else M.lastFieldCanvas=nil end
 presentField(canvas,vw,vh)
 return true
end
function M.invalidate()M.lastFieldCanvas=nil;Boundary.clear();stream:clear();cache={}end
function M.release()
 M.lastFieldCanvas=nil
 -- The debug radius override must not outlive the scene that set it.
 Distance.forceFull=false
 if dustMesh then dustMesh:release();dustMesh=nil end
 if dustImage then dustImage:release();dustImage=nil end
 for _,c in pairs(effectCanvases)do c:release()end;effectCanvases={}
 stream:clear();cache={}
 for _,mesh in pairs(spriteMeshes)do if mesh then mesh:release() end end
 spriteMeshes={}
 Landmarks.release()
 Roof.release();Outdoor.release()
 R.invalidate();Shadow.invalidate();V.require('GlassMask').invalidate();V.require('Gen3Lamp').invalidate()
 V.require('Gen3SceneOptions').release()
end
return M
