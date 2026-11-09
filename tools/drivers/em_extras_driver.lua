-- QA driver: the every-species pool (wilds/data/wild_extras.lua, option all_species), task 32.
--   EM_MAPS="EM_ROUTE101 EM_ROUTE110 EM_ROUTE119 EM_VICTORY_ROAD_1F EM_SKY_PILLAR_5F" EM_TRIALS=25
--   EM_EXTRAS_FILE=<abs path of mod/wilds/data/wild_extras.lua> EM_DRIVER=<this file>
--   tools/qa_tryp.sh "wilds/lib/gen3/init.lua wilds/options.lua wilds/data/wild_extras.lua" <abs out> "-" 4 0 200
-- A) every national 1-386 resolves a sprite on land and on water (S.spawn nil = 'no species sprite'), shot of the
--    species without HGSS art; B) per map: re-seed the spawns EM_TRIALS times, tally table vs extra species, check
--    every extra's level against its rows; C) a unique (Rayquaza, Sky Pillar 5F) is one at a time and gone once caught;
--    D) option all_species off = table species only; E) the classic step hook (encounter.species) swaps in extras.
-- Prints [ext] lines; [ext] FAIL lines are defects.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local ex=game.mods.exports.emerald_3d_voxel_mod
 local C=(function()local n=ex and (ex.gen3 or ex.firered);return n and n.camera end)()
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local Enc=require('src.core.game3.encounters');local Pk=require('src.core.game3.pokemon');local Col=require('src.core.game3.collision')
 local Dex=require('src.core.game3.dex');local Runtime=require('src.mods.Runtime')
 local S=ex.wilds
 if C then C.setLevel(4,game) end
 local fails=0
 local function fail(...)fails=fails+1;print('[ext] FAIL',...)end
 local function name(s)return Pk.name(s) or tostring(s) end
 local function nat(s)return Pk.national and Pk.national(s) or s end
 local Extras=assert(dofile(assert(os.getenv('EM_EXTRAS_FILE'),'EM_EXTRAS_FILE')))
 local MODID='emerald_3d_voxel_mod'
 local function setOpt(k,v)game.mods.modOptions[MODID]=game.mods.modOptions[MODID]or{};game.mods.modOptions[MODID][k]=v end
 print('[ext] extras file: maps',(function()local n=0;for _ in pairs(Extras.maps)do n=n+1 end;return n end)(),'uniques',(function()local n=0;for _ in pairs(Extras.unique)do n=n+1 end;return n end)())

 -- A) sprites for all 386, land and water ---------------------------------------------------------------
 local noArt={112,118,144,145,146,151,201,202,208,243,244,245,249,250,251,321,348,377,378,379,380,381,382,383,384,385,386}
 local bad={land={},water={}}
 for n=1,386 do
  local sp=Pk.speciesFromNational(n)
  if not sp then fail('national',n,'has no internal species id') else
   for _,terrain in ipairs({'land','water'}) do
    local row,err=S.spawn(sp,5,Player.cellX,Player.cellY,terrain,{behavior='idle'})
    if row then S.remove(row) else bad[terrain][#bad[terrain]+1]=n..'='..name(sp)..'('..tostring(err)..')' end
   end
  end
 end
 print('[ext] sprite land missing',#bad.land,table.concat(bad.land,' '))
 print('[ext] sprite water missing',#bad.water,table.concat(bad.water,' '))
 if #bad.land>0 or #bad.water>0 then fail('species without a sprite') end
 -- shot of the species without HGSS art (they fall back to Actors.front), 3 rows of 9, on Route 101 (towns hide wilds)
 do
  local id='EM_ROUTE101'
  if Map.load(nil,game,id,{x=1,y=1,facing='down'}) then
   U.wait(30)
   local def=Map.currentDef();local w=def and (def.midLayout and def.midLayout.width or def.width) or 0;local h=def and (def.midLayout and def.midLayout.height or def.height) or 0
   local cells={}
   for y=0,h-1 do for x=0,w-1 do if Col.isWalkable(x,y) and not Col.warpAt(x,y) then cells[#cells+1]={x,y} end end end
   local c,best=nil,1e9
   for _,cell in ipairs(cells) do local d=(cell[1]-w/2)^2+(cell[2]-h/2)^2;if d<best then best=d;c=cell end end -- the cell nearest the map centre (the 9x3 grid must fit inside the map)
   if c then
    pcall(Player.reset,c[1],c[2]+1,'up');U.wait(10)
    for _,r in pairs(S.spawns)do S.remove(r)end
    for i,n in ipairs(noArt) do
     local sp=Pk.speciesFromNational(n)
     local r=math.floor((i-1)/9);local cc=(i-1)%9
     if sp then S.spawn(sp,5,c[1]-4+cc,c[2]-1-r*2,'land',{behavior='idle'}) end
    end
    U.wait(20)
    do local n,vis,placed=0,0,{} for _,r in pairs(S.spawns)do n=n+1;if r.visible then vis=vis+1 end;placed[#placed+1]=name(r.species)..'@'..r.cellX..','..r.cellY..(r.visible and '' or '/HIDDEN') end
     table.sort(placed);print('[ext] noart rows',n,'visible',vis,table.concat(placed,' ')) end
    U.shot(game,dir..'/noart_front_sprites.png')
    print('[ext] shot noart_front_sprites phase',game.phase,'player',c[1],c[2])
    for _,r in pairs(S.spawns)do S.remove(r)end
   end
  end
 end

 -- contact sheet of the same 27 exactly as Actors.front draws them (battle front pic squeezed to 24x24), x4, 9 per row
 do
  local cv=love.graphics.newCanvas(9*104,3*104)
  love.graphics.push('all');love.graphics.setCanvas(cv);love.graphics.clear(.36,.55,.33,1);love.graphics.setColor(1,1,1,1)
  local missing={}
  for i,n in ipairs(noArt) do
   local pic=Pk.frontPic(Pk.speciesFromNational(n))
   local c,r=(i-1)%9,math.floor((i-1)/9)
   if pic then
    local cvs=love.graphics.newCanvas(24,24);love.graphics.setCanvas(cvs);love.graphics.clear(0,0,0,0)
    love.graphics.draw(pic.image,0,0,0,24/pic.w,24/pic.h);love.graphics.setCanvas(cv);cvs:setFilter('nearest','nearest')
    love.graphics.draw(cvs,c*104+4,r*104+4,0,4,4)
   else missing[#missing+1]=n end
  end
  love.graphics.pop()
  local fd=cv:newImageData():encode('png');local f=io.open(dir..'/noart_sheet.png','wb')
  if f then f:write(fd:getString());f:close() end
  print('[ext] noart_sheet written; no front pic for',#missing,table.concat(missing,','))
  if #missing>0 then fail('species with neither HGSS art nor a front pic',table.concat(missing,',')) end
 end

 -- B) per map census -----------------------------------------------------------------------------------
 local maps={}
 for m in (os.getenv('EM_MAPS') or 'EM_ROUTE101'):gmatch('%S+') do maps[#maps+1]=m end
 local trials=tonumber(os.getenv('EM_TRIALS')) or 25
 local function tableSet(id)
  Enc.ensureLoaded();local t=Enc.tableFor(id);local out={}
  for _,key in ipairs({'land','water'}) do
   local a=t and t[key];local slots=a and (a.slots or a.mons or a)
   for _,e in ipairs(slots or {}) do local s=tonumber(e.species or e[1]);if s then out[s]=true end end
  end
  return out
 end
 local function fitsRows(id,terrain,n,level)
  local m=Extras.maps[id];local rows=m and m[terrain=='water' and 'water' or 'land']
  for _,r in ipairs(rows or {}) do if r[1]==n and level>=r[2] and level<=r[3] then return true end end
  return false
 end
 local function census(id,quiet)
  if not Map.load(nil,game,id,{x=1,y=1,facing='down'}) then fail(id,'LOAD FAILED');return nil end
  U.wait(30)
  local def=Map.currentDef();local w=def and (def.midLayout and def.midLayout.width or def.width) or 0;local h=def and (def.midLayout and def.midLayout.height or def.height) or 0
  local cells={}
  for y=0,h-1 do for x=0,w-1 do if Col.isWalkable(x,y) and not Col.warpAt(x,y) then cells[#cells+1]={x,y} end end end
  if #cells==0 then fail(id,'no walkable cell');return nil end
  local picks={cells[math.max(1,math.floor(#cells*.2))],cells[math.max(1,math.floor(#cells*.5))],cells[math.max(1,math.floor(#cells*.8))]}
  local tab=tableSet(id);local stat={trials=trials,total=0,tableN=0,extraN=0,byExtra={},byTable={},maxSame={},levelBad=0,rows=0}
  for t=1,trials do
   local c=picks[(t-1)%#picks+1]
   pcall(Player.reset,c[1],c[2],'down');S.map=nil;U.wait(4)
   local cnt={}
   for _,r in pairs(S.spawns) do
    if not r.ambient then
     stat.total=stat.total+1
     local n=nat(r.species)
     if tab[r.species] then stat.tableN=stat.tableN+1;stat.byTable[name(r.species)]=(stat.byTable[name(r.species)] or 0)+1
     else stat.extraN=stat.extraN+1;stat.byExtra[name(r.species)]=(stat.byExtra[name(r.species)] or 0)+1
      if not fitsRows(id,r.terrain,n,r.level) then stat.levelBad=stat.levelBad+1 end end
     cnt[n]=(cnt[n] or 0)+1;stat.maxSame[n]=math.max(stat.maxSame[n] or 0,cnt[n])
    end
   end
  end
  local function keys(t)local o={};for k,v in pairs(t)do o[#o+1]=k..'x'..v end;table.sort(o);return table.concat(o,' ')end
  local de=0;for _ in pairs(stat.byExtra)do de=de+1 end
  if not quiet then
   print('[ext]',id,'size',w,h,'trials',trials,'spawns',stat.total,'table',stat.tableN,'extra',stat.extraN,'distinct extras',de,'level-misfit',stat.levelBad)
   print('[ext]',id,'TABLE',keys(stat.byTable))
   print('[ext]',id,'EXTRA',keys(stat.byExtra))
  end
  return stat,picks
 end
 local firstMap
 for _,id in ipairs(maps) do
  local st=census(id)
  if st then
   firstMap=firstMap or id
   if st.levelBad>0 then fail(id,'extras outside their rows level range',st.levelBad) end
   local haveRows=Extras.maps[id]
   if haveRows and st.total>0 and st.extraN==0 then fail(id,'has extra rows but no extra species spawned in',trials,'trials') end
  end
 end

 -- C) a unique: one at a time, gone once caught (Rayquaza, EM_SKY_PILLAR_5F) -------------------------------
 local uid,usp='EM_SKY_PILLAR_5F',Pk.speciesFromNational(384)
 do
  local st=census(uid,true)
  local seen,maxSame=0,st and st.maxSame[384] or 0
  -- census(quiet) tallied by species name: pull the count from byExtra
  seen=st and st.byExtra[name(usp)] or 0
  print('[ext] unique',name(usp),'on',uid,'appearances in',trials,'trials:',seen,'max at once',maxSame)
  if seen==0 then fail('unique',name(usp),'never spawned on',uid) end
  if maxSame>1 then fail('unique',name(usp),'more than one at a time:',maxSame) end
  local d=game.session and game.session.dex
  if d then
   Dex.setCaught(d,usp);print('[ext] unique caught flag',tostring(Dex.isCaught(d,usp)))
   local st2=census(uid,true);local after=st2 and st2.byExtra[name(usp)] or 0
   print('[ext] unique',name(usp),'after Dex caught: appearances',after)
   if after>0 then fail('unique',name(usp),'spawned',after,'times after it was caught') end
  else fail('no game.session.dex to mark caught') end
 end

 -- D) option off = Emerald's table only ----------------------------------------------------------------
 local offMap=firstMap or 'EM_ROUTE101'
 setOpt('all_species',false)
 local so=census(offMap,true)
 print('[ext] all_species=false',offMap,'spawns',so and so.total or 'nil','extra',so and so.extraN or 'nil')
 if so and so.extraN>0 then fail('all_species=false still spawned',so.extraN,'extras on',offMap) end

 -- E) classic step hook (encounter.species), option on and off -----------------------------------------
 local function hookRun(id,terrain,n)
  local base=Pk.speciesFromNational(263) or 1 -- any table species as the engine's roll
  local swapped,distinct,lvBad={}, {},0
  local cnt=0
  local tab=tableSet(id)
  for _=1,n do
   local enc={species=Pk.keyName(base),speciesId=base,level=3}
   local out=Runtime.call('encounter.species',function(e)return e end,enc,{mapId=id,terrain=terrain,rng=love.math.random,opts={}})
   if out and out.speciesId and out.speciesId~=base then
    cnt=cnt+1;local nn=nat(out.speciesId);distinct[nn]=true
    if not fitsRows(id,terrain=='water' and 'water' or 'land',nn,out.level or 0) then lvBad=lvBad+1 end
    if tab[out.speciesId] and false then end
   end
  end
  local d=0;for _ in pairs(distinct)do d=d+1 end
  return cnt,d,lvBad
 end
 local m1=firstMap or 'EM_ROUTE101'
 setOpt('all_species',true)
 local rows=Extras.maps[m1] and Extras.maps[m1].land
 local expectW=0;for _,r in ipairs(rows or {})do expectW=expectW+r[4] end
 local cnt,dist,lvBad=hookRun(m1,'grass',600)
 print('[ext] classic step hook',m1,'grass: of 600 rolls',cnt,'swapped to an extra, distinct',dist,'level-misfit',lvBad,'expected about',math.floor(600*expectW/(100+expectW)))
 if rows and cnt==0 then fail('encounter.species wrap never returned an extra on',m1) end
 if lvBad>0 then fail('encounter.species extras outside rows level range',lvBad) end
 setOpt('all_species',false)
 local cnt0=hookRun(m1,'grass',600)
 print('[ext] classic step hook with all_species=false:',cnt0,'swapped (expect 0)')
 if cnt0>0 then fail('encounter.species swapped with the option off') end
 setOpt('all_species',true)
 local wmap='EM_ROUTE119'
 if Extras.maps[wmap] and Extras.maps[wmap].water then
  local cw,dw,lw=hookRun(wmap,'water',600)
  print('[ext] classic step hook',wmap,'water: of 600 rolls',cw,'swapped, distinct',dw,'level-misfit',lw)
  if cw==0 then fail('encounter.species wrap never returned a water extra on',wmap) end
 end
 print('[ext] FAILS',fails)
 print('[EM QA] done')
 love.event.quit()
end
