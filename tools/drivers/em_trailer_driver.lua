-- Trailer capture: records each shot of a shot list as a 60 fps ProRes clip, one game step per video frame.
--   EM_SHOTS=<shots.lua> EM_DRIVER=<this file> tools/qa_tryp.sh "" <abs out> "-" 7 0 0   (or tools/trailer.sh)
-- shots.lua returns {party={nat,...}, player='MAY', gender=1, opts={...}, <shot>, <shot>, ...}; a shot:
--   name, map, x, y, facing, frames (recorded), warm (frames before recording), hour (number or {from,to}),
--   level (game camera 4/6/7) + look={from={yaw,pitch},to={...}} for level 6/7,
--   or cam={from={yaw,pitch,dist,h,fov,ox,oz},to={...}} (free camera orbiting the player; pitch = elevation),
--   walk={{'up',48},{'wait',20},...} (world directions), fly='MAPSEC_...', battle={foe=nat,level=n,taps={f,...}},
--   stills={.5,...} (PNG at those fractions of the shot), stillOnly (no clip), prewalk (steps before recording;
--   the follower appears once the player walks). x/y left out = the map's centre; keep = same map, no reload. list.flags = flag ids set at boot.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 local FF=os.getenv('EM_FFMPEG') or '/opt/homebrew/bin/ffmpeg'
 local list=dofile(assert(os.getenv('EM_SHOTS'),'EM_SHOTS not set'))
 local only=os.getenv('EM_ONLY');if only=='' then only=nil end
 love.window.setMode(tonumber(os.getenv('EM_W') or 1920),tonumber(os.getenv('EM_H') or 1080),{resizable=false})
 local W,H=love.graphics.getPixelDimensions()
 print('[trailer] window',love.window.getMode(),'pixels',W,H,'dpi',love.window.getDPIScale())

 -- the mod's wall-clock effects (breeze, mist) follow game frames, not the slow capture loop
 local realGet=love.timer.getTime
 local vt=realGet()
 love.timer.getTime=function()
  local i=debug.getinfo(2,'S');local s=i and i.short_src or ''
  if s:find('Voxel3D',1,true) or s:find('TowerGraveMist',1,true) then return vt end
  return realGet()
 end

 local first=list[1]
 game:_handleBootAction({action='new_game',name=list.player or 'MAY',gender=list.gender or 1,start={map=first.map,x=first.x,y=first.y,facing=first.facing or 'down'}})
 U.wait(90)
 local export=game.mods.exports.emerald_3d_voxel_mod
 local lib=export.lib
 local C=export.gen3.camera
 local Scene=lib.require('Gen3Scene')
 local V3=lib.require('Voxel3D')
 local DN=lib.require('DayNight')
 local Fly=lib.require('Gen3FlyOver')
 local Options=lib.require('Gen3SceneOptions')
 if os.getenv('EM_WALLS') then -- one line per map: shell back (cells) vs the front of the room-wall columns
  local ID=lib.require('InteriorDiorama');local p0=ID.profile
  local pend,seen='',{}
  ID.profile=function(def,...) local r=p0(def,...)
   if r and r.bounds and not seen[def.id or ''] then seen[def.id or '']=true
    print(string.format('[walls] %s shellBack=%.2f %s',tostring(def.id),r.bounds[2]/16,pend)) end
   return r end
  local F=lib.require('Gen3Furniture');local ex0=F.extract
  F.extract=function(cells)
   local TS=lib.require('Gen3TileShape');local fronts,top={},99
   for _,c in pairs(cells) do if c.shape and c.shape.kind=='roomWall' then top=math.min(top,c.cy) end end
   for k,c in pairs(cells) do if c.shape and c.shape.kind=='roomWall' and c.cy==top then
    local col=TS.column(cells,k);if col then fronts[col.front/16]=(fronts[col.front/16] or 0)+1 end end end
   local t={};for f,n in pairs(fronts) do t[#t+1]=string.format('%g:%d',f,n) end;table.sort(t)
   pend=string.format('top=%d fronts=%s',top,table.concat(t,','))
   return ex0(cells)
  end
 end
 if os.getenv('EM_PROBE') then -- print every furniture recipe match and the building cells no recipe took
  local F=lib.require('Gen3Furniture');local ex0=F.extract
  F.extract=function(cells)
   local out=ex0(cells)
   if os.getenv('EM_DUMP') then -- EM_DUMP="520,524;528,532": write those tiles of the map's tileset as dump.png (x4)
    local ts;for _,c in pairs(cells) do if c.ts then ts=c.ts break end end
    local rows={};for rw in os.getenv('EM_DUMP'):gmatch('[^;]+') do local r={};for m in rw:gmatch('%d+') do r[#r+1]=tonumber(m) end rows[#rows+1]=r end
    local img=love.image.newImageData(#rows[1]*16,#rows*16)
    for ry,r in ipairs(rows) do for rx,mid in ipairs(r) do local slot=ts.midToSlot[mid]
     if slot then for py=0,15 do for px=0,15 do
      local ax,ay=slot%ts.cols*16+px,math.floor(slot/ts.cols)*16+py
      local a,b,c,d=ts.imageData:getPixel(ax,ay)
      if ts.overImageData then local a2,b2,c2,d2=ts.overImageData:getPixel(ax,ay);if d2>0 then a,b,c,d=a2*d2+a*(1-d2),b2*d2+b*(1-d2),c2*d2+c*(1-d2),math.max(d,d2) end end
      img:setPixel((rx-1)*16+px,(ry-1)*16+py,a,b,c,1) end end end end end
    local fh=io.open(dir..'/dump.png','wb');fh:write(img:encode('png'):getString());fh:close()
   end
   for _,p in ipairs(out) do print(string.format('[probe] prop %s at %d,%d (%dx%d px)',p.recipe.name,p.cx,p.cy,p.w,p.d)) end
   local miss={}
   for _,c in pairs(cells) do if (c.primary=='building' or c.primary=='general') and not c.prop and not c.stairs then miss[#miss+1]=string.format('%d,%d mid=%s k=%s col=%s',c.cx,c.cy,tostring(c.mid),tostring(c.shape and c.shape.kind),tostring(c.collision)) end end
   table.sort(miss);print('[probe] unmatched building cells: '..table.concat(miss,' | '))
   return out
  end
 end
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local Party=require('src.core.game3.party');local Pokemon=require('src.core.game3.pokemon')
 local Field=require('src.core.game3.field')
 print('[trailer] Voxel3D chunk',debug.getinfo(V3.viewProjection,'S').short_src)

 -- settings: the player's defaults, plus what a trailer wants
 local function setOpt(k,v)
  local o=(game.save and game.save.options) or game.options
  if o then o.modOptions=o.modOptions or {};o.modOptions['emerald_3d_voxel_mod']=o.modOptions['emerald_3d_voxel_mod'] or {};o.modOptions['emerald_3d_voxel_mod'][k]=v end
  game.mods.modOptions=game.mods.modOptions or {};game.mods.modOptions['emerald_3d_voxel_mod']=game.mods.modOptions['emerald_3d_voxel_mod'] or {};game.mods.modOptions['emerald_3d_voxel_mod'][k]=v
 end
 setOpt('catch_hud_size',0)
 local opts=list.opts or {}
 if opts.distance then lib.require('RenderDistance').setting:setIndex(opts.distance,game);Scene.invalidate() end
 if opts.water then lib.require('Water').setting:setIndex(opts.water,game);Scene.invalidate() end
 if opts.battleCamera then lib.require('BattleShots').setting:setIndex(opts.battleCamera,game) end
 if opts.tour then Options.tour:setIndex(2,game);lib.require('TourMode').overlay=function() end end -- tour builds whole neighbours and lights the windows; its debug label stays off
 for k,v in pairs(opts.raw or {}) do setOpt(k,v) end

 for _,id in ipairs(list.flags or {}) do require('src.core.game3.mystery_gift').setFlag(game.session,id,true) end
 pcall(function() local P=require('src.ui.game3.map_name_popup');P.show=function() return false end;P.dismiss() end)
 local mon
 for _,nat in ipairs(list.party or {}) do
  local code,m=Party.giveMonToPlayer(game.session,Pokemon.speciesFromNational(nat) or nat,list.partyLevel or 40)
  mon=mon or m
  print('[trailer] party',nat,code)
 end

 if os.getenv('EM_GLASSLOG') then lib.require('GlassMask').log=true end
 local hour=12
 DN.hours=function() return hour end

 -- free camera: replaces the level-7 orbit eye right before the projection is built
 local cine
 local origVP=V3.viewProjection
 V3.viewProjection=function(...)
  if cine and V3.camera and not Fly.active() then V3.camera=cine() end
  return origVP(...)
 end

 local function ease(u) return u*u*(3-2*u) end
 local function lerp(a,b,u) return a+(b-a)*u end
 local function mix(from,to,u,key,def)
  local a=from[key];if a==nil then a=def end
  local b=to[key];if b==nil then b=a end
  return lerp(a,b,u)
 end

 local pipe
 local function record(name)
  pipe=io.popen(string.format("'%s' -loglevel error -y -f rawvideo -pix_fmt rgba -s %dx%d -r 60 -i - -c:v prores_ks -profile:v 3 -vendor apl0 -pix_fmt yuv422p10le '%s/%s.mov' 2>>'%s/ffmpeg.log'",FF,W,H,dir,name,dir),'w')
 end
 local function grab(still)
  local p=pipe
  love.graphics.captureScreenshot(function(img)
   if p then p:write(img:getString()) end
   if still then local f=io.open(still,'wb');if f then f:write(img:encode('png'):getString());f:close() end end
  end)
 end
 local function stop()
  U.wait(3)
  if pipe then pipe:close();pipe=nil end
 end

 local dirs={'up','right','down','left'}
 local function keyFor(world)
  if (C.level or 0)<6 then return world end
  for _,d in ipairs(dirs) do if C.worldDirection(d,C.yaw)==world then return d end end
  return world
 end
 local held
 local function hold(key)
  if held and held~=key then game.input.state[held]=false end
  held=key
  if key then table.insert(game.input.pressQueue,key);game.input.state[key]=true end
 end

 local function step()
  Options.update(1/60)
  if Fly.active() then
   local ok,err=pcall(Fly.update,1/60,game)
   if not ok then Fly.abort(err) end
  end
  vt=vt+1/60
  U.wait(1)
 end

 for n,shot in ipairs(list) do
  if not only or only:find(shot.name,1,true) then
   local t0=realGet()
   cine=nil;hour=type(shot.hour)=='table' and shot.hour[1] or shot.hour or 12
   local ok,err=true,nil
   if not shot.keep then ok,err=pcall(function() assert(Map.load(nil,game,shot.map,{x=shot.x or 1,y=shot.y or 1,facing=shot.facing or 'down'})) end) end
   local L=Map.currentDef() and Map.currentDef().midLayout or {}
   local x,y=shot.x or math.floor((L.width or 2)/2),shot.y or math.floor((L.height or 2)/2)
   print('[trailer] load',shot.map,ok,err or '','size',L.width,L.height,'at',x,y)
   pcall(Player.reset,x,y,shot.facing or 'down')
   C.setLevel(shot.level or 7,game)
   C.yaw=(shot.look and shot.look.from.yaw) or (shot.cam and shot.cam.from.yaw) or shot.yaw or 0
   C.pitch=(shot.look and shot.look.from.pitch) or shot.pitch or .16
   local frames=shot.frames or 300
   local u=0
   if shot.cam then
    local f,t=shot.cam.from,shot.cam.to or shot.cam.from
    cine=function()
     local e=shot.cam.linear and u or ease(u)
     local yaw,pitch=mix(f,t,e,'yaw',0),mix(f,t,e,'pitch',.35)
     local dist,h,fov=mix(f,t,e,'dist',120),mix(f,t,e,'h',24),mix(f,t,e,'fov',50)
     local cx=(Player.px or 0)+8+mix(f,t,e,'ox',0)
     local cz=(Player.py or 0)+8+mix(f,t,e,'oz',0)
     local g=Scene.groundAt(cx,cz+8-.001,Player.elevation) or 0
     local dx,dz=math.sin(yaw),-math.cos(yaw)
     local r=dist*math.cos(pitch)
     C.yaw=yaw%(math.pi*2);C.pitch=math.max(-.6,math.min(.65,pitch))
     return {eye={cx-dx*r,g+h+dist*math.sin(pitch),cz-dz*r},focus={cx,g+h,cz},fov=math.rad(fov)}
    end
   end
   if shot.battle then
    for i=1,240 do
     U.wait(30)
     local st=export.status and export.status()
     if st and (st.state=='ready' or st.state=='failed') then print('[trailer] importer',st.state,'after',i*.5,'s') break end
    end
    local Bridge=require('src.core.game3.battle_bridge')
    local ok,err=pcall(Bridge.startWild,game.mods,game,{species=Pokemon.speciesFromNational(shot.battle.foe) or shot.battle.foe,level=shot.battle.level or 30},{})
    print('[trailer] startWild',shot.battle.foe,ok,err or '')
   else
    for _=1,30 do step() end
    for _=1,900 do if C.active and (not Scene.readyFor or Scene.readyFor(Map.current)) then break end;step() end
   end
   for _,w in ipairs(shot.prewalk or {}) do
    for _=1,w[2] do hold(w[1]~='wait' and keyFor(w[1]) or nil);step() end
   end
   hold(nil)
   for _=1,shot.warm or 90 do step() end
   print('[trailer] shot',shot.name,'map',shot.map,'active',tostring(C.active),'level',C.level,'warm',string.format('%.1fs',realGet()-t0))

   if shot.fly then
    local dest=assert(Field.flyDestination(shot.fly),'no fly destination '..shot.fly)
    Field.flyTo(shot.fly,mon,{dest=dest})
   end
   if not shot.stillOnly then record(shot.name) end
   local walk,wi,wleft=shot.walk or {},1,nil
   local stills={}
   for _,s in ipairs(shot.stills or {.5}) do stills[math.max(1,math.floor(s*frames))]=true end
   local taps={}
   for _,f in ipairs(shot.battle and shot.battle.taps or {}) do taps[f]=true end
   local tr=realGet()
   local flyDone,flyStarted
   for i=1,frames do
    u=(i-1)/math.max(1,frames-1)
    if type(shot.hour)=='table' then hour=lerp(shot.hour[1],shot.hour[2],shot.hourLinear and u or ease(u)) end
    if shot.look and not shot.cam then
     local e=ease(u);local f,t=shot.look.from,shot.look.to or shot.look.from
     C.yaw=mix(f,t,e,'yaw',0)%(math.pi*2);C.pitch=mix(f,t,e,'pitch',.16)
    end
    if walk[wi] then
     wleft=wleft or walk[wi][2]
     hold(walk[wi][1]~='wait' and keyFor(walk[wi][1]) or nil)
     wleft=wleft-1
     if wleft<=0 then wi=wi+1;wleft=nil end
    else hold(nil) end
    if taps[i] then table.insert(game.input.pressQueue,'a');game.input.state.a=true end
    if stills[i] then print(string.format('[trailer] still %s frame %d hour %.2f glassNight %.2f yaw %.2f pitch %.2f firstArea %s',shot.name,i,hour,V3.glassNight or -1,C.yaw,C.pitch,tostring(Scene.firstArea and Scene.firstArea()))) end
    grab(stills[i] and string.format('%s/%s_%03d.png',dir,shot.name,i) or nil)
    step()
    game.input.state.a=false
    if shot.fly and Fly.active() then flyStarted=true end
    if shot.fly and flyStarted and not Fly.active() and not flyDone then flyDone=i;print('[trailer] fly ended at frame',i) end
    if flyDone and i>flyDone+(shot.flyTail or 120) then break end
   end
   hold(nil)
   stop()
   print(string.format('[trailer] recorded %s: %d frames in %.1f s, map %s, cell %s,%s',shot.name,frames,realGet()-tr,tostring(Map.current),tostring(Player.cellX),tostring(Player.cellY)))
   cine=nil
  end
 end
 print('[EM QA] done')
 love.event.quit()
end
