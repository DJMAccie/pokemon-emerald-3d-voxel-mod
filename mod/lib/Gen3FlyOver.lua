-- Gen3FlyOver
local V=...
local Path=V.require('Gen3FlyPath')
local Mat=V.require('Mat4')
local R=V.require('Voxel3D')
local Pairs=V.require('Gen3Tilesets')
local Ground=V.require('Gen3FlyGround')
local M={
 SLICE=.014,
 HIDDEN_SLICE=.12,
 COVER=.45,
 CLEAR=.25, -- s the white then takes to clear
 HOLD_AT=.30,
 YAW_FOLLOW=true,
 MOUNT_W=104,
 SCALE_REF=1.2,
 BEAT_CYCLE=.42,
 BOB=1.2,
 SQUASH=.05,
 LIFT=.7,
 SEA=-3.2,
 HOVER=6,
 MARGIN=1100,
 BORDER=12,
 CARPET_MS=.003, -- s per frame spent laying flat ground
 GROUND_HIDDEN_MS=.012,
 WAIT_MAX=6,
 TIMEOUT=30,
 log=false,
}
local S,armed=nil,nil
local pre,integ
local popOriginal
local function eng(name)return package.loaded[name] or require(name)end
local function now()return love.timer.getTime()end
local function note(fmt,...)print('[FlyOver] '..string.format(fmt,...))end
local slowLines=0
local function slow(what,t0,limit)
 local ms=(now()-t0)*1000
 if ms>(limit or 12) and slowLines<40 then slowLines=slowLines+1;note('slow %s: %.0f ms',what,ms)end
end

function M.active()return S~=nil end
function M.frame(drawn)
 local s=S;if not s then return end
 if drawn then s.undrawn=0;return end
 s.undrawn=(s.undrawn or 0)+1
 if s.undrawn>40 then M.abort('the 3D view is not drawing') end
end
function M.hidesPlayer()return S~=nil end
function M.hidesFollowers()return S~=nil end
function M.state()return S end -- QA drivers read the flight

local function size(def)return eng('src.core.game3.connections').sizeOf(def)end
local sections
local function sectionTable()
 if sections~=nil then return sections or nil end
 sections=false
 pcall(function()
  local root=eng('src.import.gba.extract_island1').CACHE_ROOT
  local cache=eng('src.core.game3.dataset').cache()
  local src=cache and cache:read(root..'/region_map/map_sections.lua')
  local pack=src and assert(load(src,'=map_sections','t',{}))()
  if pack and pack.sections then sections=pack.sections end
 end)
 return sections or nil
end
local function regionCentre(def)
 local secs=sectionTable();if not (secs and def) then return nil end
 local id=def.regionMapSectionId or def.region_map_section_id
 local s=secs[tonumber(id) or -1]
 if not s and type(id)=='string' then for _,r in pairs(secs)do if r.id==id then s=r;break end end end
 if not (s and s.x and s.y) then return nil end
 return s.x+(s.width or 1)/2,s.y+(s.height or 1)/2
end
local HUB='EM_LITTLEROOT_TOWN'
local function layout(game,rootId)
 local Map=eng('src.core.game3.map')
 local maps=game.data.maps
 local out={[rootId]={id=rootId,def=maps[rootId],ox=0,oy=0}}
 for _,e in ipairs(Map.computeWorld(maps,rootId,99,nil,nil,function()end))do out[e.id]=e end
 return out
end
local function place(game,world,id)
 if world[id] then return world[id] end
 local def=game.data.maps[id];if not def then return nil end
 local px,py,overlay=Ground.placement(id)
 if px then local e={id=id,def=def,ox=px,oy=py,placed=true,overlay=overlay};world[id]=e;return e end
 local rx,ry=regionCentre(def);if not rx then return nil end
 local samples={}
 for _,e in pairs(world)do
  local cx,cy=regionCentre(e.def)
  if cx and Pairs.outdoor(e.def) then local w,h=size(e.def);samples[#samples+1]={cx,cy,e.ox+w/2,e.oy+h/2}end
 end
 local fit=Path.fit(samples);if not fit then return nil end
 local w,h=size(def);local ox,oy=Path.place(fit,rx,ry,w,h)
 local e={id=id,def=def,ox=ox,oy=oy,placed=true};world[id]=e
 return e
end
local function worldFrom(game,from,dest)
 local world=layout(game,HUB)
 local st=world[from] or place(game,world,from)
 local de=world[dest] or place(game,world,dest)
 if not (st and de) then return nil end
 local out={}
 for id,e in pairs(world)do out[id]={id=id,def=e.def,ox=e.ox-st.ox,oy=e.oy-st.oy,placed=e.placed}end
 return out,world,st
end
local function groundMaps(game,hub)
 local maps={}
 for id,e in pairs(hub)do
  if e.def and Pairs.outdoor(e.def) and not e.overlay then maps[id]={def=e.def,ox=e.ox,oy=e.oy}end
 end
 local F=Ground.fill()
 for id,p in pairs(F and F.place or {})do
  local def=game.data.maps[id]
  if not maps[id] and not p.overlay and def and Pairs.outdoor(def) then maps[id]={def=def,ox=p.ox,oy=p.oy}end
 end
 return maps
end
local function supported(game,id)
 local def=game.data.maps[id];if not def then return false end
 pcall(eng('src.core.game3.map').ensureMidLayout,game,id,def)
 if not (def.midLayout and def.midLayout.pair) then return false end
 if not Pairs.outdoor(def) then return false end
 local spec=Pairs.resolve(def.midLayout.pair,eng('src.import.gba.versions').TILESET_PAIRS)
 return Pairs.supports(def,spec) and true or false
end

M.ROWS={down=0,left=1,right=2,up=3}
local flyerManifest
local function flyers()
 if flyerManifest~=nil then return flyerManifest or nil end
 flyerManifest=false
 local ok,src=pcall(V.mod.read,V.mod,'assets/flyers/manifest.lua')
 local chunk=ok and src and (loadstring or load)(src,'@assets/flyers/manifest.lua')
 if chunk then local okT,t=pcall(chunk);if okT and type(t)=='table' then flyerManifest=t end end
 return flyerManifest or nil
end
local function bakedSprite(nat,shiny)
 local entry=flyers();entry=entry and entry[nat]
 if not entry then return nil end
 local name=('%03d-%s.png'):format(nat,shiny and 'shiny' or 'normal')
 local ok,spr=pcall(function()
  local bytes=assert(V.mod:read('assets/flyers/'..name))
  local data=love.image.newImageData(love.filesystem.newFileData(bytes,name))
  local img=love.graphics.newImage(data);img:setFilter('nearest','nearest')
  local iw,ih=img:getDimensions()
  local quads={}
  for r=0,3 do for c=0,entry.frames-1 do
   quads[r*entry.frames+c]=love.graphics.newQuad(c*entry.fw,r*entry.fh,entry.fw,entry.fh,iw,ih)
  end end
  return {image=img,imageData=data,quads=quads,width=entry.fw,height=entry.fh,frameCount=4*entry.frames,groundPadding=0}
 end)
 if not ok then note('flight sheet %s failed: %s',name,tostring(spr));return nil end
 return {spr=spr,sheet=entry,nat=nat,shiny=shiny}
end
local function mountSprite(game,mon)
 local Sprites=eng('src.core.game3.ow_sprites')
 if mon and mon.species then
  local shinyMon=false
  pcall(function()shinyMon=eng('src.core.game3.summary_data').isShiny(mon) and true or false end)
  local okN,nat=pcall(function()return eng('src.core.game3.pokemon').national(mon.species)end)
  local m=bakedSprite(okN and tonumber(nat) or tonumber(mon.species),shinyMon)
  if m then return m end
 end
 local ex=V.mod and V.mod.exports
 if mon and mon.species and ex and type(ex.resolveGen3Sprite)=='function' then
  local shiny=false
  pcall(function()shiny=eng('src.core.game3.summary_data').isShiny(mon) and true or false end)
  local ok,gid=pcall(ex.resolveGen3Sprite,mon.species,nil,shiny)
  local spr=ok and gid and Sprites.getDraw(gid)
  if spr and spr.quads and spr.quads[0] then return {spr=spr,gid=gid} end
 end
 local Fx=eng('src.core.game3.field_effects')
 local sheet=Fx.loadSheet and Fx.loadSheet('fly_bird',64,64,5)
 if sheet and sheet.image and sheet.quads and sheet.quads[0] then
  return {spr={image=sheet.image,quads=sheet.quads,frameCount=sheet.frames or 1,inanimate=true},bird=true}
 end
 return nil
end

local function segRectDist(a,b,x0,z0,x1,z1)
 local best=math.huge
 for i=0,24 do
  local s=i/24
  local x,z=a[1]+(b[1]-a[1])*s,a[3]+(b[3]-a[3])*s
  local dx=x<x0 and x0-x or (x>x1 and x-x1 or 0)
  local dz=z<z0 and z0-z or (z>z1 and z-z1 or 0)
  best=math.min(best,math.sqrt(dx*dx+dz*dz))
 end
 return best
end
local fullIndex={}
local function fullMap(cells)
 local idx=fullIndex[cells]
 if idx then return idx end
 idx={}
 for q=0,cells-1 do local b=q*4;local n=q*6;idx[n+1],idx[n+2],idx[n+3],idx[n+4],idx[n+5],idx[n+6]=b+1,b+2,b+3,b+1,b+3,b+4 end
 fullIndex[cells]=idx
 return idx
end
local BAND=12
local function allocBands(m)
 local gw=m.w+2*M.BORDER
 local total=m.h+2*M.BORDER
 m.alloc={}
 for r0=0,total-1,BAND do
  local rows=math.min(BAND,total-r0)
  local ok,mesh=pcall(love.graphics.newMesh,R.FORMAT,gw*rows*4,'triangles','static')
  if ok and not pcall(mesh.setVertexMap,mesh,fullMap(gw*rows)) then mesh:release();ok=false end -- its index buffer too: written later, in place
  m.alloc[#m.alloc+1]=ok and mesh or false
 end
 m.nextBand=1
end
local function carpetPlan(s)
 local Tiles=eng('src.core.game3.tileset_native')
 local list={}
 for id,e in pairs(s.world)do
  local def=e.def
  if def and Pairs.outdoor(def) then
   local w,h=size(def)
   local x0,z0,x1,z1=e.ox*16,e.oy*16,(e.ox+w)*16,(e.oy+h)*16
   local d=segRectDist(s.a,s.b,x0,z0,x1,z1)
   if w>0 and h>0 and d<=M.MARGIN+s.H then
    local cx,cz=(x0+x1)/2,(z0+z1)/2
    list[#list+1]={id=id,def=def,ox=e.ox,oy=e.oy,w=w,h=h,row=-M.BORDER,v={},bands={},
     order=math.sqrt((cx-s.a[1])^2+(cz-s.a[3])^2)}
   end
  end
 end
 table.sort(list,function(p,q)return p.order<q.order end)
 for k,m in ipairs(list)do
  m.seq=k
  local def=m.def
  local pair=def.pair or (def.midLayout and def.midLayout.pair)
  if pair and not Tiles._pairs[pair] then pcall(Tiles.prefetch,pair,1)end
  allocBands(m)
 end
 return {maps=list}
end
local function cutBand(m,band,rect)
 local B=M.BORDER
 local gw=m.w+2*B
 local x0,y0=m.ox-B,m.oy-B+band.row0
 local x1,y1=x0+gw-1,y0+band.rows-1
 if not rect or rect[3]<x0 or rect[1]>x1 or rect[4]<y0 or rect[2]>y1 then
  if band.cut then pcall(band.mesh.setVertexMap,band.mesh,fullMap(gw*band.rows));band.cut=false end
  band.hidden=false
  return
 end
 local idx,n=nil,0
 idx={}
 for y=0,band.rows-1 do
  local gy=y0+y
  local rowIn=gy>=rect[2] and gy<=rect[4]
  for x=0,gw-1 do
   local gx=x0+x
   if not (rowIn and gx>=rect[1] and gx<=rect[3]) then
    local b=(y*gw+x)*4
    idx[n+1],idx[n+2],idx[n+3],idx[n+4],idx[n+5],idx[n+6]=b+1,b+2,b+3,b+1,b+3,b+4;n=n+6
   end
  end
 end
 band.hidden=n==0
 band.cut=true
 if n>0 then pcall(band.mesh.setVertexMap,band.mesh,idx)end
end
local function applyCut(m,rect)
 for _,band in ipairs(m.bands)do cutBand(m,band,rect)end
end
local function buildRows(m,ts,deadline,rect)
 local L=m.def.midLayout
 local B=M.BORDER
 local iw,ih=ts.image:getDimensions()
 local cols=ts.cols
 local toSlot=ts.midToSlot or {}
 local zero=toSlot[0] or 0
 local Y=-.6
 local YB=-1-.05*(m.seq or 0)
 local ox,oz=m.ox*16,m.oz or m.oy*16
 local du,dv=16/iw,16/ih
 local gw=m.w+2*B
 m.bands=m.bands or {}
 m.overOk=ts.overImage and select(1,ts.overImage:getDimensions())==iw and select(2,ts.overImage:getDimensions())==ih
 while m.row<m.h+B do
  local v=m.v
  local y=m.row
  local rowIn=y>=0 and y<m.h
  for x=-B,m.w-1+B do
   local ok,mid=pcall(L.midAt,L,x,y)
   local slot=(ok and mid and toSlot[mid]) or zero
   local u0,v0=(slot%cols)*du,math.floor(slot/cols)*dv
   local X,Z=ox+x*16,oz+y*16
   local YY=(rowIn and x>=0 and x<m.w) and Y or YB
   local n=#v
   v[n+1]={X,YY,Z,u0,v0,1};v[n+2]={X+16,YY,Z,u0+du,v0,1};v[n+3]={X+16,YY,Z+16,u0+du,v0+dv,1};v[n+4]={X,YY,Z+16,u0,v0+dv,1}
  end
  m.row=m.row+1
  m.bandRows=(m.bandRows or 0)+1
  local last=m.row>=m.h+B
  if m.bandRows>=BAND or last then
   local rows=m.bandRows
   local t0=now()
   local full=fullMap(gw*rows)
   local t1=now()
   local mesh=m.alloc and m.alloc[m.nextBand]
   m.nextBand=(m.nextBand or 1)+1
   if mesh then
    if not pcall(mesh.setVertices,mesh,m.v) then mesh:release();mesh=nil;m.alloc[m.nextBand-1]=false end
   else
    mesh=V.require('Gen3Scene').fastMesh(m.v,full)
   end
   local t2=now()
   if mesh then
    local band={mesh=mesh,row0=m.row-rows+B,rows=rows,pooled=m.alloc and m.alloc[m.nextBand-1]==mesh}
    m.bands[#m.bands+1]=band
    cutBand(m,band,rect)
   end
   if (now()-t0)*1000>8 then note('band %s: index %.1f ms, mesh %.1f ms (%d vertices), cut %.1f ms',m.id,(t1-t0)*1000,(t2-t1)*1000,#m.v,(now()-t2)*1000)end
   m.v={};m.bandRows=0
  end
  if now()>deadline then return last end
 end
 return true
end
local function cutRect(s)
 local b=V.require('Gen3Scene').builtBounds()
 if not b then return nil end
 local sx,sz=s.shift[1]/16,s.shift[2]/16
 return {b[1]+sx+1,b[2]+sz+1,b[3]+sx-1,b[4]+sz-1} -- one cell in: the raised ground is a hollow shell at its cut edge
end
local function carpetStep(s)
 local c=s.carpet;if not c then return end
 local Map=eng('src.core.game3.map');local Tiles=eng('src.core.game3.tileset_native')
 local rect=cutRect(s)
 local key=rect and table.concat(rect,',') or '-'
 if key~=c.cutKey then
  c.cutKey=key
  local t0=now()
  for _,m in ipairs(c.maps)do if m.bands then applyCut(m,rect)end end
  slow('re-cutting the ground',t0)
 end
 if c.done then return end
 local deadline=now()+M.CARPET_MS
 local waiting=false
 for _,m in ipairs(c.maps)do
  if not m.done and not m.failed then
   if not m.def.midLayout then pcall(Map.ensureMidLayout,s.game,m.id,m.def)end
   local L=m.def.midLayout
   m.pair=m.pair or m.def.pair or (L and L.pair)
   local ts=m.pair and Tiles._pairs[m.pair]
   if not (L and L.midAt and m.pair) then m.failed=true
   elseif not (ts and ts.image) then waiting=true
   else
    local t0=now()
    local ok,done=pcall(buildRows,m,ts,deadline,rect)
    slow('ground rows '..m.id,t0)
    if not ok then m.failed=true;note('ground for %s failed: %s',m.id,tostring(done))
    elseif done then m.done=true;if not (m.bands and #m.bands>0) then m.failed=true end end
   end
   if now()>deadline then return end
  end
 end
 if not waiting then c.done=true end
end
local function releaseCarpet(s)
 if s and s.ground then Ground.pause() end
 local c=s and s.carpet;if not c then return end
 for _,m in ipairs(c.maps)do
  for _,mesh in ipairs(m.alloc or {})do if mesh then pcall(mesh.release,mesh)end end
  for _,band in ipairs(m.bands or {})do if not band.pooled then band.mesh:release()end end
  m.bands,m.alloc=nil,nil
 end
 s.carpet=nil
end

local function restorePlayer()
 local Player=eng('src.core.game3.player')
 Player.flyRide=false;Player.spriteXOffset=0;Player.spriteYOffset=0;Player.fieldMoveAnim=0
end
local function computePose(s)
 local a,b,hov=s.a,s.b,M.HOVER
 local seat=s.seat or 22
 local mon,ply,riding,monVisible,focus
 if s.phase=='mount' then
  local u=s.t/Path.MOUNT
  local k=Path.smooth(u/.6)
  local fx,fy,fz=a[1]-s.dir[1]*150,a[2]+120,a[3]-s.dir[2]*150
  mon={fx+(a[1]-fx)*k,fy+(a[2]+hov-fy)*k+18*math.sin(math.pi*k),fz+(a[3]-fz)*k}
  if u<.6 then ply={a[1],a[2],a[3]};riding=false
  else local hu=Path.smooth((u-.6)/.4);ply={a[1],a[2]+(hov+seat)*hu+10*math.sin(math.pi*hu),a[3]};riding=true end
  monVisible=true;s.h=0;focus={a[1],a[3]}
 elseif s.phase=='fly' then
  local sp=Path.progress(s.t,s.T);local h=Path.altitude(s.t,s.T,s.H)
  local p=Path.at(a,b,sp,h)
  mon={p[1],p[2]+hov,p[3]};ply={p[1],p[2]+hov+seat,p[3]}
  riding,monVisible,s.h,s.sp=true,true,h,sp;focus={p[1],p[3]}
 else
  local u=s.t/Path.DISMOUNT
  if u<.4 then
   local hu=Path.smooth(u/.4)
   mon={b[1],b[2]+hov,b[3]};ply={b[1],b[2]+(hov+seat)*(1-hu)+10*math.sin(math.pi*hu),b[3]};riding=hu<.98
  else
   local k=(u-.4)/.6
   mon={b[1]+s.dir[1]*220*k,b[2]+hov+170*k*k,b[3]+s.dir[2]*220*k};ply={b[1],b[2],b[3]};riding=false
  end
  monVisible=u<.97;s.h=0;focus={b[1],b[3]}
 end
 local sx,sz=s.shift[1],s.shift[2]
 s.pose={mon={mon[1]-sx,mon[2],mon[3]-sz},player={ply[1]-sx,ply[2],ply[3]-sz},riding=riding,monVisible=monVisible}
 s.focus={focus[1]-sx,focus[2]-sz-8}
end
local function swap(s)
 local Map=eng('src.core.game3.map')
 local t0=now()
 s.swapping=true
 local ok,err=pcall(s.onFlownOff)
 s.swapping=false
 s.onFlownOff=nil
 s.swapped=true
 s.swapMs=(now()-t0)*1000
 if not ok then error('swap: '..tostring(err),0)end
 note('swapped to %s mid-air in %.0f ms',tostring(Map.current),s.swapMs)
end
local function showPopup(s)
 local p=s.popup;s.popup=nil
 if p and popOriginal then pcall(popOriginal,p[1],p[2])end
end
local function finish(s)
 local Player=eng('src.core.game3.player')
 S=nil
 restorePlayer()
 releaseCarpet(s)
 if s.onDone then
  local ok,err=pcall(s.onDone)
  if not ok then note('landing callback failed: %s',tostring(err))end
 else
  local Field=eng('src.core.game3.field');Field.locked=false;Field._flyLanding=false
 end
 Player.setVisible(true);Player.facing='down'
 showPopup(s)
 note('landed on %s (%d,%d) after %.1f s (swap %.0f ms, town built after %s s)',tostring(eng('src.core.game3.map').current),
  Player.cellX or -1,Player.cellY or -1,now()-s.started,s.swapMs or -1,s.readyAt and string.format('%.1f',s.readyAt) or 'never')
end

function M.abort(why)
 local s=S;if not s then return end
 S=nil
 note('abort: %s',tostring(why))
 restorePlayer();releaseCarpet(s)
 if not s.swapped and s.onFlownOff then
  local ok,err=pcall(s.onFlownOff)
  if not ok then note('engine fly-out failed: %s',tostring(err))end
 elseif s.onDone then
  pcall(s.onDone);eng('src.core.game3.player').setVisible(true)
 elseif s.swapped then
  local Field=eng('src.core.game3.field');Field.locked=false;Field._flyLanding=false
  eng('src.core.game3.player').setVisible(true)
 end
 showPopup(s)
end

function M.start(plan,onFlownOff)
 local game=plan.game
 if pre then local G=Ground.state();note('town map prewarm ended after %d steps, %.1f s: %d quads laid',pre.steps or 0,now()-pre.t0,G and G.quads or 0)end
 pre=nil
 local Map=eng('src.core.game3.map');local Player=eng('src.core.game3.player')
 local Scene=V.require('Gen3Scene')
 local world,hub,st=worldFrom(game,Map.current,plan.dest.map)
 local de=world and world[plan.dest.map];assert(de,'no world place for '..tostring(Map.current)..' -> '..tostring(plan.dest.map))
 local ax,az=(Player.px or 0)+8,(Player.py or 0)+16
 local ay=Scene.groundAt(ax,az-.001,Player.elevation) or 0
 local bx,bz=(de.ox+plan.dest.x)*16+8,(de.oy+plan.dest.y)*16+16
 local dx,dz=bx-ax,bz-az
 local L=math.sqrt(dx*dx+dz*dz)
 local ux,uz=0,-1;if L>1 then ux,uz=dx/L,dz/L end
 local seed=7;for ch in (tostring(Map.current)..tostring(plan.dest.map)):gmatch('.')do seed=(seed*31+ch:byte())%2147483647 end
 local s={game=game,plan=plan,dest=plan.dest,world=world,de=de,from=Map.current,
  a={ax,ay,az},b={bx,0,bz},L=L,T=Path.duration(L),H=Path.height(L),dir={ux,uz},yaw=math.atan2(ux,-uz),
  phase='mount',t=0,clock=0,waited=0,onFlownOff=onFlownOff,swapped=false,
  shift={0,0},destShift={de.ox*16,de.oy*16},started=now()}
 s.clouds=Path.clouds({ax,0,az},{bx,0,bz},s.H,seed)
 s.mount=mountSprite(game,plan.mon)
 s.hubOrigin={st.ox*16,st.oy*16}
 local okG,ground=pcall(Ground.begin,game,groundMaps(game,hub))
 if okG and ground then s.ground=true else
  if not okG then note('whole-world ground failed: %s',tostring(ground))end
  s.carpet=carpetPlan(s)
 end
 local okW,errW=pcall(M.warm,s);if not okW then note('warm failed: %s',tostring(errW))end
 computePose(s)
 S=s
 note('%s -> %s (%d,%d): %.0f px, %.1f s, %.0f px up%s, %s, rider %s',tostring(Map.current),plan.dest.map,
  plan.dest.x,plan.dest.y,L,s.T,s.H,de.placed and ', placed by the fill or the region map' or '',
  s.ground and ('whole-world ground'..(Ground.done() and ' (laid)' or '')) or (#s.carpet.maps..' maps of ground'),
  s.mount and (s.mount.bird and 'fly bird' or s.mount.sheet and ('sheet %d %s%s'):format(s.mount.nat,s.mount.sheet.source,
   s.mount.shiny and ' shiny' or '') or tostring(s.mount.gid)) or 'none')
end

local function whiteAt(s)
 if s.phase~='fly' then return 0 end
 local d=math.abs(s.t-s.T*Path.SWAP)
 return math.max(0,math.min(1,(M.COVER+M.CLEAR-d)/M.CLEAR))*.92
end
function M.slice()
 local s=S;if not s then return nil end
 return whiteAt(s)>=.9 and M.HIDDEN_SLICE or M.SLICE
end

local function stepRider(s,dt)
 local e=s.mount and s.mount.sheet
 if not e then return end
 local T=s.phase=='fly' and s.T or s.phase=='mount' and Path.MOUNT or Path.DISMOUNT
 local mult,glide=Path.beatRate(s.phase,s.t,T,s.h or 0,s.H)
 local cycle
 if e.durations then cycle=0;for _,d in ipairs(e.durations)do cycle=cycle+d end;cycle=cycle/60
 else cycle=M.BEAT_CYCLE*math.sqrt(Path.mountScale(e.height)) end
 s.beat=s.beat or {beat=0}
 local row=M.ROWS[s.row or 'up'] or 3
 s.col=Path.beatStep(s.beat,dt,{mult=mult,glide=glide,cycle=cycle,frames=e.frames,durations=e.durations,
  glideFrame=e.glide and e.glide[row+1] or 0})
 local y=s.pose and s.pose.mon[2] or 0
 local climb=(s.lastY and dt>0) and (y-s.lastY)/dt or 0
 s.lastY=y
 s.pitch=Path.pitchStep(s.pitch,climb,dt)
 local k=M.MOUNT_W*Path.mountScale(e.height)/M.SCALE_REF/math.max(1,e.fw)
 s.bob=glide and 0 or M.BOB*k*math.sin(2*math.pi*s.beat.beat)
end

local function groundStep(s)
 local t0=now()
 local hx,hz=s.focus[1]+s.shift[1]+s.hubOrigin[1],s.focus[2]+s.shift[2]+s.hubOrigin[2]
 Ground.step(hx,hz,whiteAt(s)>=.9 and M.GROUND_HIDDEN_MS or M.CARPET_MS)
 local rect=cutRect(s)
 if rect then local ox,oy=s.hubOrigin[1]/16,s.hubOrigin[2]/16;rect={rect[1]+ox,rect[2]+oy,rect[3]+ox,rect[4]+oy}end
 Ground.cut(rect)
 Ground.refreshSea()
 slow('ground',t0)
 if M.log or M.qaGround then
  local d=1500+2.4*(s.h or 0)
  local live,all=Ground.coverage(hx,hz,d)
  if live<all and not s.groundGap then s.groundGap=true;note('ground: %d of %d chunks within %.0f px laid at t=%.2f (%s)',live,all,d,s.clock,s.phase)end
  if live==all and s.groundGap then s.groundGap=false;note('ground: all %d chunks within reach laid at t=%.2f (%s)',all,s.clock,s.phase)end
 end
end
function M.update(dt,game)
 local s=S;if not s then return end
 local tUpdate=now()
 local Map=eng('src.core.game3.map');local Player=eng('src.core.game3.player')
 local Scene=V.require('Gen3Scene')
 dt=math.max(0,math.min(tonumber(dt) or 0,.05))
 s.clock=s.clock+dt
 if s.clock>M.TIMEOUT then return M.abort('timeout') end
 if s.swapped and not s.shifted and Map.current==s.dest.map then s.shift=s.destShift;s.shifted=true end
 if s.shifted and not s.ready and Scene.readyFor(s.dest.map) then
  s.ready=true;s.readyAt=now()-s.started
  s.b[2]=Scene.groundAt(s.dest.x*16+8,s.dest.y*16+16-.001) or 0
 end
 if s.phase=='mount' then
  s.t=s.t+dt
  if s.t>=Path.MOUNT then s.phase,s.t='fly',0 end
 elseif s.phase=='fly' then
  local input=game and game.input
  if input and input.wasPressed and input:wasPressed('b') and not s.skip then
   s.skip=true
   if not s.swapped then s.t=math.max(s.t,s.T*Path.SWAP-M.COVER*.5) end
  end
  local ready=s.ready or s.waited>=M.WAIT_MAX
  local rate=Path.rate(s.t,s.T,ready)
  if s.swapped and not ready and s.t>=s.T*Path.SWAP+M.HOLD_AT then rate=0 end
  if rate<1 then s.waited=s.waited+dt end
  s.t=s.t+dt*rate
  if not s.swapped and s.t>=s.T*Path.SWAP then swap(s);if s.swapped and Map.current==s.dest.map then s.shift=s.destShift;s.shifted=true end end
  if s.skip and s.swapped and ready and s.t<s.T*(1-Path.FALL)-.01 then s.t=s.T*(1-Path.FALL)-.01 end
  if s.t>=s.T then s.phase,s.t='dismount',0 end
 elseif s.phase=='dismount' then
  s.t=s.t+dt
  if s.t>=Path.DISMOUNT then
   if not s.swapped then swap(s) end
   computePose(s);return finish(s)
  end
 end
 computePose(s)
 stepRider(s,dt)
 Player.flyRide=s.pose.riding and true or false
 if s.ground then groundStep(s) else carpetStep(s) end
 slow('update',tUpdate,16)
end

function M.focus()
 local s=S;if not s then return nil end
 return s.focus[1],s.focus[2]
end
local function upFor(yaw,pitch)
 local cp=math.cos(pitch)
 local fx,fy,fz=math.sin(yaw)*cp,-math.sin(pitch),-math.cos(yaw)*cp
 local rx,rz=math.cos(yaw),math.sin(yaw)
 return {-rz*fy,rz*fx-rx*fz,rx*fy}
end
function M.camera(normal,cx,cz,ground,vw,vh,cam)
 local s=S;if not s then return normal end
 local base=normal
 if not base then
  local Voxel=V.require('VoxelState')
  local a,focal=Voxel.angle or 0,Voxel.FOCAL or 1
  local dist=focal*vh*1.18
  base={eye={cx,ground+dist*math.cos(a),cz+dist*math.sin(a)},focus={cx,ground,cz},fov=2*math.atan(1/(2*focal))}
 end
 local lift=(s.h or 0)*M.LIFT
 if lift>0 then
  base={eye={base.eye[1],base.eye[2]+lift,base.eye[3]},focus={base.focus[1],base.focus[2]+lift,base.focus[3]},fov=base.fov,up=base.up}
 end
 local w=s.phase=='fly' and Path.blend(s.t,s.T) or 0
 local o0=Path.toOrbit(base.eye,base.focus)
 if w<=0 then
  s.view={yaw=o0.yaw,pitch=o0.pitch,w=0,eye=base.eye,up=upFor(o0.yaw,o0.pitch)}
  return normal
 end
 local o1=Path.flightOrbit(s.pose.mon,s.dir[1],s.dir[2],s.h or 0,M.YAW_FOLLOW)
 if M.qaView then o1={f={s.pose.mon[1],0,s.pose.mon[3]},yaw=0,pitch=M.qaView.pitch,dist=M.qaView.dist} end
 local o=Path.blendOrbit(o0,o1,w)
 o.pitch=math.max(-1.5707,math.min(1.5707,o.pitch))
 local eye,focus=Path.fromOrbit(o)
 local up=upFor(o.yaw,o.pitch)
 s.view={yaw=o.yaw,pitch=o.pitch,w=w,eye=eye,up=up}
 return {eye=eye,focus=focus,fov=base.fov+(math.rad(60)-base.fov)*w,up=up}
end
function M.fog(background,normal,cx,cz)
 local s=S;if not (s and s.view) then return normal end
 local w=s.view.w or 0
 if w<=0 then return normal end
 local reach=M.qaView and M.qaView.reach or 1500+2.4*(s.h or 0)
 local start1,density1=reach*.7,7/(reach*.3)
 local start0,density0=400,7/120
 if normal and normal.start and not normal.bounds then start0,density0=normal.start,normal.density or density0 end
 return {color=background,start=start0+(start1-start0)*w,density=density0+(density1-density0)*w,heightK=0,origin={cx,0,cz}}
end
local seaMesh,seaImage
local function sea()
 if seaMesh then return seaMesh,seaImage end
 local d=love.image.newImageData(1,1);d:setPixel(0,0,.26,.39,.88,1)
 seaImage=love.graphics.newImage(d)
 local n,cell=20,600
 local v,idx={},{}
 for y=0,n-1 do for x=0,n-1 do
  local X,Z=(x-n/2)*cell,(y-n/2)*cell
  local b=#v
  v[b+1]={X,0,Z,.5,.5,1};v[b+2]={X+cell,0,Z,.5,.5,1};v[b+3]={X+cell,0,Z+cell,.5,.5,1};v[b+4]={X,0,Z+cell,.5,.5,1}
  idx[#idx+1]=b+1;idx[#idx+1]=b+2;idx[#idx+1]=b+3;idx[#idx+1]=b+1;idx[#idx+1]=b+3;idx[#idx+1]=b+4
 end end
 seaMesh=V.require('Gen3Scene').fastMesh(v,idx)
 return seaMesh,seaImage
end
function M.drawGround(draw)
 local s=S
 if s and s.ground then
  local reach=M.qaView and M.qaView.reach or (1500+2.4*(s.h or 0))*1.1+600
  local n=Ground.draw(draw,s.hubOrigin[1]+s.shift[1],s.hubOrigin[2]+s.shift[2],s.focus[1],s.focus[2],reach,Ground.offset(s.shifted and s.dest.map or s.from))
  s.groundDrawn=n
  return
 end
 if not (s and s.carpet) then return end
 local mesh,image=sea()
 if mesh then draw(mesh,image,Mat.translate(s.focus[1],M.SEA,s.focus[2]))end
 local Tiles=eng('src.core.game3.tileset_native')
 local model=(s.shift[1]~=0 or s.shift[2]~=0) and Mat.translate(-s.shift[1],0,-s.shift[2]) or nil
 for _,m in ipairs(s.carpet.maps)do
  if m.bands and #m.bands>0 then
   local ts=Tiles._pairs[m.pair]
   if ts and ts.image then
    for _,band in ipairs(m.bands)do
     if not band.hidden then
      draw(band.mesh,ts.image,model)
      if m.overOk then draw(band.mesh,ts.overImage,model)end
     end
    end
   end
  end
 end
end
local function facingFor(rel)
 rel=(rel+math.pi)%(2*math.pi)-math.pi
 if math.abs(rel)<math.pi/4 then return 'up' elseif math.abs(rel)>3*math.pi/4 then return 'down' elseif rel>0 then return 'right' end
 return 'left'
end
local function flap(s)
 if s.phase=='fly' and (s.h or 0)>.9*s.H and (s.clock%2.4)>.7 then return 0,false end
 local period=s.phase=='fly' and .34 or .24
 local c=(s.clock/period)%1
 if c<.25 then return 0,false elseif c<.5 then return 1,false elseif c<.75 then return 0,false end
 return 1,true
end
local shadowMesh,shadowImages
local function shadow()
 if shadowMesh then return shadowMesh,shadowImages end
 local bayer={{0,8,2,10},{12,4,14,6},{3,11,1,9},{15,7,13,5}}
 shadowImages={}
 for level=1,4 do
  local d=love.image.newImageData(24,12)
  for y=0,11 do for x=0,23 do
   local ex,ey=(x+.5-12)/12,(y+.5-6)/6
   local inside=ex*ex+ey*ey<=1
   local on=inside and bayer[y%4+1][x%4+1]<level*3
   d:setPixel(x,y,.08,.08,.12,on and 1 or 0)
  end end
  local img=love.graphics.newImage(d);img:setFilter('nearest','nearest');shadowImages[level]=img
 end
 local v={{-12,0,-6,0,0,1},{12,0,-6,1,0,1},{12,0,6,1,1,1},{-12,0,6,0,1,1}}
 shadowMesh=V.require('Gen3Scene').fastMesh(v,{1,2,3,1,3,4})
 return shadowMesh,shadowImages
end
function M.drawRider(draw,cam)
 local s=S;if not (s and s.pose) then return end
 local Scene=V.require('Gen3Scene');local Sprites=eng('src.core.game3.ow_sprites');local Player=eng('src.core.game3.player')
 local Integration=V.require('Gen3Integration')
 local view=s.view or {yaw=0,pitch=.8,w=0}
 local Voxel=V.require('VoxelState')
 local rest=(cam.level>=6) and Scene.ACTOR_LEAN*(cam.pitch or 0) or Scene.ACTOR_LEAN*(Voxel.angle or 0)
 local lean=rest+(view.pitch*.85-rest)*(view.w or 0)
 local pose=Mat.mul(Mat.rotateY(-view.yaw),Mat.rotateX(-lean))
 local m=s.mount
 local sheet=m and m.sheet
 local facing=sheet and Path.rowFor(s.yaw-view.yaw,s.row) or facingFor(s.yaw-view.yaw)
 s.row=facing
 local p=s.pose.mon
 local bob=s.bob or 0
 local width=M.MOUNT_W
 if sheet then width=M.MOUNT_W*Path.mountScale(sheet.height)/M.SCALE_REF end
 local ground=Scene.groundAt(p[1],p[3]-.001) or 0
 local up=p[2]-ground
 if up<200 and s.pose.monVisible then
  local mesh,imgs=shadow()
  local level=math.max(1,math.min(4,4-math.floor(up/50)))
  local ss=sheet and math.max(1,width*.5/24) or 1
  if mesh then draw(mesh,imgs[level],Mat.mul(Mat.translate(p[1],ground+.35,p[3]-2),Mat.scale(ss,1,ss)))end
 end
 local playerPull=10
 if m and s.pose.monVisible then
  local spr=m.spr
  local frame,mirror=0,false
  if sheet then frame=M.ROWS[facing]*sheet.frames+(s.col or 0)
  elseif not m.bird then local ph,fl=flap(s);frame,mirror=Sprites.pose(spr,facing,ph,fl)end
  local q=spr.quads[frame] or spr.quads[0]
  local mesh=q and Scene.cardMesh(spr,frame,mirror)
  if mesh then
   local _,_,qw,qh=q:getViewport()
   local model
   if sheet then
    local k=width/math.max(1,qw)
    s.seat=(sheet.seat and sheet.seat[M.ROWS[facing]+1] or qh*.42)*k
    local side=facing=='right' and 1 or facing=='left' and -1 or 0
    local c=qh/2
    local sq=1-M.SQUASH*(.5+.5*math.cos(2*math.pi*((s.beat and s.beat.beat) or 0)))
    local tilt=Mat.mul(Mat.translate(0,c,0),Mat.mul(Mat.rotateZ((s.pitch or 0)*side),Mat.mul(Mat.scale(1,sq,1),Mat.translate(0,-c,0))))
    model=Mat.mul(Mat.translate(p[1],p[2]+bob,p[3]),Mat.mul(pose,Mat.mul(Mat.scale(k,k,k),tilt)))
    if facing=='down' then playerPull=4 end
   else
    local k=math.max(1,M.MOUNT_W/math.max(1,qw))
    s.seat=qh*k*.42
    model=Mat.mul(Mat.translate(p[1],p[2],p[3]),Mat.mul(pose,Mat.scale(k,k,k)))
   end
   draw(mesh,spr.image,model,7)
  end
 end
 if Integration.level==6 and (view.w or 0)<.35 then return end
 local gid=Sprites.playerGraphicsId(s.game)
 local spr=gid and Sprites.getDraw(gid)
 if spr then
  local pf=s.pose.riding and facing or (s.phase=='dismount' and 'down' or Player.facing or 'down')
  local frame,mirror=Sprites.pose(spr,pf,0,false,{fieldMove=not s.pose.riding and (Player.fieldMoveAnim or 0)>0})
  local mesh=Scene.cardMesh(spr,frame,mirror)
  if mesh then
   local pp=s.pose.player
   local rideBob=(s.pose.riding and bob) or 0
   draw(mesh,spr.image,Mat.mul(Mat.translate(pp[1],pp[2]+rideBob,pp[3]),pose),playerPull)
  end
 end
end

local cloudImg
local function cloudImage()
 if cloudImg~=nil then return cloudImg or nil end
 cloudImg=false
 pcall(function()
  local puffs={{22,38,13},{38,34,15},{50,41,11},{32,44,16},{14,44,9},{44,46,12}}
  local d=love.image.newImageData(64,64)
  local function inside(cx,cy)
   for _,p in ipairs(puffs)do
    local dx,dy=cx-p[1],cy-p[2]
    if dx*dx+dy*dy<=p[3]*p[3] then return true end
   end
  end
  d:mapPixel(function(x,y)
   local cx,cy=math.floor(x/4)*4+2,math.floor(y/4)*4+2
   if not inside(cx,cy) then return 0,0,0,0 end
   local depth=0
   while depth<5 and inside(cx,cy-4*(depth+1)) do depth=depth+1 end
   local t=depth/5
   return 1-.14*t,1-.10*t,1-.04*t,1
  end)
  local img=love.graphics.newImage(d);img:setFilter('nearest','nearest');cloudImg=img
 end)
 return cloudImg or nil
end
function M.overlay(canvas,w,h,rw,rh)
 local s=S;if not (s and canvas and s.view) then return end
 local vw=s.view.w or 0
 local white=0
 if s.phase=='fly' then
  white=whiteAt(s)
 end
 if vw<=0 and white<=0 then return end
 local g=love.graphics
 g.push('all')
 g.setCanvas(canvas);g.origin();g.setShader();g.setBlendMode('alpha')
 local sx,sy=w/(rw or w),h/(rh or h)
 local img=cloudImage()
 if img and vw>0 then
  local eye,up=s.view.eye,s.view.up
  local list={}
  for _,c in ipairs(s.clouds)do
   local x,y,z=c[1]-s.shift[1],c[2],c[3]-s.shift[2]
   local px,py,_,depth=R.project(x,y,z)
   local half=32*c[4]
   local qx,qy=R.project(x+up[1]*half,y+up[2]*half,z+up[3]*half)
   if px and qx then
    local dx,dy,dz=x-eye[1],y-eye[2],z-eye[3]
    local d=math.sqrt(dx*dx+dy*dy+dz*dz)
    local a=.9*vw*Path.smooth((d-60)/160)
    local r=math.sqrt((qx-px)^2+(qy-py)^2)
    if a>0 and r>1 then list[#list+1]={px,py,r,depth or 0,a}end
   end
  end
  table.sort(list,function(p,q)return p[4]>q[4]end)
  for _,c in ipairs(list)do
   local k=2*c[3]*sy/64
   g.setColor(1,1,1,c[5]);g.draw(img,c[1]*sx,c[2]*sy,0,k,k,32,32)
  end
 end
 if white>0 then g.setColor(.96,.97,1,white);g.rectangle('fill',0,0,w,h)end
 g.pop()
end

function M.warm(s)
 local t0=now()
 local Scene=V.require('Gen3Scene');local Sprites=eng('src.core.game3.ow_sprites')
 local function cards(spr)
  if not (spr and spr.quads) then return end
  for frame in pairs(spr.quads)do for _,mirror in ipairs(spr.groundPadding==0 and {false} or {false,true})do pcall(Scene.cardMesh,spr,frame,mirror)end end
 end
 cards(s.mount and s.mount.spr)
 local gid=Sprites.playerGraphicsId(s.game)
 cards(gid and Sprites.getDraw(gid))
 if s.ground then Ground.warm() else sea() end
 shadow();cloudImage()
 note('warmed in %.0f ms',(now()-t0)*1000)
end

M.PREWARM_MS=.004 -- s per step spent laying the ground on the town map
function M.prewarm(game)
 pre=nil
 if S or not (game and integ and integ.level~=0 and integ.active) then return end
 if not (R.available and R.available()) then return end
 local Map=eng('src.core.game3.map');local Player=eng('src.core.game3.player')
 if not supported(game,Map.current) then return end
 local world,hub,st=worldFrom(game,Map.current,Map.current);if not world then return end
 if not Ground.begin(game,groundMaps(game,hub)) then return end
 pre={hx=st.ox*16+(Player.px or 0),hz=st.oy*16+(Player.py or 0),t0=now()}
 note('town map open: laying the world')
end
function M.prewarmStep()
 local p=pre;if not p then return end
 if S then pre=nil;return end
 local ok,err=pcall(function()
  local Stream=eng('src.core.game3.asset_stream');Stream.frameComplete();Stream.update()
  p.steps=(p.steps or 0)+1
  Ground.step(p.hx,p.hz,M.PREWARM_MS)
  if Ground.done() then pre=nil;Ground.pause();note('world laid on the town map in %.1f s',now()-p.t0)end
 end)
 if not ok then pre=nil;note('town map prewarm failed: %s',tostring(err))end
end

function M.install(Integration)
 local Field=eng('src.core.game3.field')
 local Fx=eng('src.core.game3.field_effects')
 local Fade=eng('src.ui.game3.fade')
 integ=Integration
 local flyTo,startOut,startIn,begin=Field.flyTo,Fx.startFlyOut,Fx.startFlyIn,Fade.begin
 local okRm,Rm=pcall(eng,'src.ui.game3.rse.region_map')
 local rmShow,rmFrame
 if okRm and type(Rm)=='table' and Rm.show and Rm.frame then
  rmShow,rmFrame=Rm.show,Rm.frame
  Rm.show=function(opts)
   if type(opts)=='table' and opts.mode=='fly' then
    pcall(M.prewarm,Field._game)
    local o={};for k,v in pairs(opts)do o[k]=v end
    local close=opts.onClose
    o.onClose=function(...)
     pre=nil;Ground.pause()
     if close then return close(...)end
    end
    opts=o
   else pre=nil end
   return rmShow(opts)
  end
  Rm.frame=function(...)
   if pre then M.prewarmStep()end
   return rmFrame(...)
  end
 end
 local okPop,Pop=pcall(eng,'src.ui.game3.map_name_popup');if not okPop then Pop=nil end
 local popShow=Pop and Pop.show
 popOriginal=popShow
 if popShow then
  Pop.show=function(def,opts)
   if S and S.swapping then S.popup={def,opts};return end
   return popShow(def,opts)
  end
 end
 Field.flyTo=function(section,mon,info)
  armed=nil
  local ok,plan=pcall(M.plan,Field._game,section,mon,info)
  if ok then armed=plan else note('plan failed: %s',tostring(plan))end
  return flyTo(section,mon,info)
 end
 Fx.startFlyOut=function(onFlownOff)
  local plan=armed;armed=nil
  if plan and not S then
   local ok,why=pcall(M.eligible,plan,Integration)
   if ok and why==true then
    local started,err=pcall(M.start,plan,onFlownOff)
    if started then return {kind='fly_out',flyover=true}end
    S=nil;restorePlayer();note('start failed, original Fly: %s',tostring(err))
   else note('original Fly: %s',tostring(ok and why or why))end
  end
  return startOut(onFlownOff)
 end
 Fx.startFlyIn=function(onDone)
  if S and (S.swapped or S.swapping) and not S.onDone then S.onDone=onDone;return {kind='fly_in',flyover=true}end
  return startIn(onDone)
 end
 Fade.begin=function(mode,speed,done)
  if S and S.swapping then
   Fade.active=false
   if done then done()end
   return
  end
  return begin(mode,speed,done)
 end
 return function()
  M.abort('unload')
  for _,mesh in ipairs({seaMesh or false,shadowMesh or false})do if mesh then mesh:release()end end
  seaMesh,shadowMesh,shadowImages,cloudImg=nil,nil,nil,nil
  Field.flyTo,Fx.startFlyOut,Fx.startFlyIn,Fade.begin=flyTo,startOut,startIn,begin
  if rmShow then Rm.show,Rm.frame=rmShow,rmFrame end
  pre,integ=nil,nil
  if popShow then Pop.show=popShow end
  popOriginal=nil
 end
end
function M.plan(game,section,mon,info)
 local Field=eng('src.core.game3.field')
 local dest=info and info.dest or Field.flyDestination(section)
 if not (dest and dest.map and tonumber(dest.x) and tonumber(dest.y)) then return nil end
 return {game=game or Field._game,dest={map=dest.map,x=tonumber(dest.x),y=tonumber(dest.y)},mon=mon,section=section}
end
function M.eligible(plan,Integration)
 local game=plan.game
 if not (Integration and Integration.level~=0 and Integration.active) then return '3D field not showing' end
 if not (R.available and R.available()) then return 'no 3D renderer' end
 if not (game and game.data and game.data.maps) then return 'no map data' end
 local Map=eng('src.core.game3.map')
 if not supported(game,Map.current) then return 'start is not an outdoor 3D map: '..tostring(Map.current) end
 if not supported(game,plan.dest.map) then return 'destination is not an outdoor 3D map: '..tostring(plan.dest.map) end
 return true
end
return M
