-- Ambient flyers: a few peaceful birds crossing the sky over routes and towns. Plain billboard rows (not in
-- S.spawns: nothing to talk to, no battle, never shared) lifted by row.raiseY; the card's cast shadow lands
-- on the ground like any other actor's. Slow wide arcs around the player, hidden at night and during the Fly ride.
return function(mod,Actors,Presentation,get)
 local Player=require('src.core.game3.player')
 local Map=require('src.core.game3.map')
 local Encounter=require('src.core.game3.encounters')
 local Pokemon=require('src.core.game3.pokemon')
 local F={list={},pool=nil,map=nil,clock=0,night=false,check=0,show=false}
 local BASE=500000
 local RX,RY=17*16,12*16 -- home box around the player (px); outside it a flyer turns back
 -- national dex numbers that fly: Taillow, Swellow, Wingull, Pelipper, Swablu, Altaria, Skarmory
 local FLYER={[276]=1,[277]=1,[278]=1,[279]=1,[333]=1,[334]=1,[227]=1}
 local GLIDER={[278]=1,[279]=1,[333]=1,[334]=1}
 local SEA={EM_DEWFORD_TOWN=1,EM_SLATEPORT_CITY=1,EM_LILYCOVE_CITY=1,EM_MOSSDEEP_CITY=1,EM_PACIFIDLOG_TOWN=1,EM_EVER_GRANDE_CITY=1}
 local LAND={EM_LITTLEROOT_TOWN=1,EM_OLDALE_TOWN=1,EM_PETALBURG_CITY=1,EM_RUSTBORO_CITY=1,EM_MAUVILLE_CITY=1,EM_VERDANTURF_TOWN=1,EM_FALLARBOR_TOWN=1}
 local HIGH={EM_FORTREE_CITY=1,EM_LAVARIDGE_TOWN=1}
 local W_LAND,W_WATER={20,20,10,10,10,10,5,5,4,4,1,1},{60,30,5,4,1}
 local COUNT={low=1,normal=3,high=4,very_high=6}
 local rnd=love.math.random
 local function poolFor(map)
  map=tostring(map);local acc={}
  local function add(nat,w)acc[nat]=(acc[nat]or 0)+w end
  if map:find('^EM_ROUTE%d+$')then
   Encounter.ensureLoaded();local t=Encounter.tableFor(map)
   for kind,weights in pairs({land=W_LAND,water=W_WATER})do
    local area=t and(t[kind]or kind=='land'and t.grass)
    for i,e in ipairs(area and(area.slots or area.mons or area)or{})do
     local sp=tonumber(e.species or e[1]);local nat=sp and Pokemon.national(sp)
     if nat and FLYER[nat]then add(nat,weights[i]or 1)end
    end
   end
   for nat in pairs(acc)do acc[nat]=math.max(acc[nat],5)end -- a 1% slot still shows up now and then
   if not next(acc)then -- no bird in the table: the sky still gets its common one (gulls over water routes)
    if t and t.water then add(278,3);add(279,1)else add(276,3);add(277,1)end
   end
  elseif SEA[map]then add(278,3);add(279,1)
  elseif LAND[map]then add(276,3);add(277,1)
  elseif HIGH[map]then add(333,2);add(276,1)end
  local pool,total={},0
  for nat,w in pairs(acc)do pool[#pool+1]={nat=nat,w=w};total=total+w end
  table.sort(pool,function(a,b)return a.nat<b.nat end)
  pool.total=total;return pool
 end
 local function pick()
  local pool=F.pool;if not pool or #pool==0 then return end
  local roll=rnd()*pool.total
  for _,e in ipairs(pool)do roll=roll-e.w;if roll<=0 then return e.nat end end
  return pool[#pool].nat
 end
 local function isNight()
  local ok,moon=pcall(function()
   local V=mod.exports.lib;local D=V and V.require('DayNight');if not D then return false end
   local _,_,m=D.bodyAt(D.time());return m
  end)
  return ok and moon==true
 end
 local function airborne()
  local ok,fly=pcall(function()return mod.exports.lib.require('Gen3FlyOver').active()end)
  if ok and fly then return true end
  local r=mod.find and mod.find('DRAMATIC_SKY_RIDE');local ex=r and r.exports
  return ex and ex.isFlying and ex.isFlying()or false
 end
 -- centred 2 cells south of the player: the lift of a bird pushes it up the screen, this keeps it in frame
 local function origin()return Player.px or Player.cellX*16,(Player.py or Player.cellY*16)+32 end
 -- Enter from a random edge of the home box, heading across the sky.
 local function edge(f)
  local cx,cy=origin()
  if rnd()<.65 then
   f.x=cx+(rnd()<.5 and-RX or RX);f.y=cy+rnd(-RY,RY)
  else
   f.y=cy+(rnd()<.5 and-RY or RY);f.x=cx+rnd(-RX,RX)
  end
  f.h=math.atan2(cy-f.y,cx-f.x)+(rnd()-.5)*1.4
 end
 local function add(seed)
  local nat=pick();local sp=nat and Pokemon.speciesFromNational(nat)
  local gid=sp and Presentation.sprite(sp,nil,false);if not gid then return end
  local slot=#F.list+1
  local f={row=Actors.add(BASE+slot,Map.current,0,0,gid),nat=nat,slot=slot,
   v=24+rnd()*16,w0=.25+rnd()*.25,wf=.15+rnd()*.2,wp=rnd()*6.28,alt=48+rnd()*28,bp=rnd()*6.28,
   flap=rnd()<.5,flapT=1+rnd()*2}
  if seed then
   local cx,cy=origin();f.x=cx+rnd(-14,14)*16;f.y=cy+rnd(-10,10)*16;f.h=rnd()*6.28
  else edge(f)end
  f.row.facing='right'
  F.list[slot]=f
 end
 function F.clear()
  for _,f in ipairs(F.list)do Actors.rows[f.row.id]=nil end
  F.list={}
 end
 function F.reset()F.list={};F.pool=nil;F.map=nil end
 local function wrap(a)return(a+math.pi)%(2*math.pi)-math.pi end
 local function offMap(x,y)
  local def=Map.currentDef();if not def then return false end
  local w=def.midLayout and def.midLayout.width or def.width;local h=def.midLayout and def.midLayout.height or def.height
  if not w or not h then return false end
  local cx,cy=math.floor((x+8)/16),math.floor((y+8)/16)
  return cx<0 or cy<0 or cx>=w or cy>=h
 end
 local function step(f,dt)
  local px,py=origin();local dx,dy=px-f.x,py-f.y
  if math.abs(dx)>RX*1.4 or math.abs(dy)>RY*1.4 then edge(f)end
  local homing=math.abs(dx)>RX or math.abs(dy)>RY or offMap(f.x,f.y)
  if homing then f.h=f.h+math.max(-1,math.min(1,wrap(math.atan2(dy,dx)-f.h)))*dt*1.2
  else f.h=f.h+f.w0*math.sin(F.clock*f.wf+f.wp)*dt end
  f.x=f.x+math.cos(f.h)*f.v*dt;f.y=f.y+math.sin(f.h)*f.v*dt
  f.flapT=f.flapT-dt
  if f.flapT<=0 then
   f.flap=not f.flap
   local glider=GLIDER[f.nat]
   f.flapT=f.flap and(glider and 1+rnd()*1.5 or 2+rnd()*2)or(glider and 2+rnd()*3 or 1+rnd()*1.5)
  end
 end
 local function pose(f,dt)
  local row=f.row
  local vx,vy=math.cos(f.h),math.sin(f.h);local ax,ay=math.abs(vx),math.abs(vy)
  local horiz=row.facing=='left'or row.facing=='right'
  if horiz and ay>ax*1.3 or not horiz and ax>ay*1.3 then horiz=not horiz end
  row.facing=horiz and(vx>0 and'right'or'left')or(vy>0 and'down'or'up')
  row.px,row.py=f.x,f.y;row.cellX,row.cellY=math.floor((f.x+8)/16),math.floor((f.y+8)/16)
  row.raiseY=-(f.alt+3*math.sin(F.clock*1.7+f.bp))
  row.moving=f.flap;if f.flap then row.animClock=(row.animClock or 0)+dt*60 end
  row.visible=true
 end
 function F.update(game,dt,blocked)
  F.clock=F.clock+dt
  if F.map~=Map.current then F.clear();F.map=Map.current;F.pool=poolFor(Map.current);F.fresh=true;F.night=isNight();F.check=1 end
  F.check=F.check-dt
  if F.check<=0 then F.check=1;F.night=isNight()end
  local on=get('ambient_flyers')~=false and F.pool and#F.pool>0 and not F.night and not airborne()
  if not on then if #F.list>0 then F.clear()end;F.fresh=false;return end
  local want=COUNT[get('spawn_density')]or 3
  while #F.list>want do local f=table.remove(F.list);Actors.rows[f.row.id]=nil end
  -- first fill of a map seeds around the player; later fills (daybreak, option on) enter from an edge
  while #F.list<want do local n=#F.list;add(F.fresh);if #F.list==n then break end end
  F.fresh=false
  for _,f in ipairs(F.list)do
   if not blocked then step(f,dt)end
   pose(f,dt)
  end
 end
 return F
end
