-- QA driver: which national species 1-386 have a 3D battle model in this install (task 32, 'beyond the overworld').
--   EM_FROM=1 EM_TO=130 EM_DEXNAMES=<abs mod/data/battle_species_dex_386.lua> EM_DRIVER=<this file> tools/qa_tryp.sh "-" <abs out> "-" 4 0 200
-- Per species: models.newInstance(n,'normal') (the path a battle takes: pack read + parse + renderer), the dex name the
-- battle code uses (battle_species_dex_386) vs the engine's key name. Prints [mod] lines, then [mod] SUMMARY / MISSING.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local ex=game.mods.exports.emerald_3d_voxel_mod
 local Pk=require('src.core.game3.pokemon')
 local models=ex.models
 local from,to=tonumber(os.getenv('EM_FROM')) or 1,tonumber(os.getenv('EM_TO')) or 386
 local names=dofile(assert(os.getenv('EM_DEXNAMES')))
 -- the importer extracts the Stadium 2 cache from the ROM on a fresh identity: wait for it (status() = {state=...})
 for i=1,240 do
  local st=ex.status and ex.status()
  if st and (st.state=='ready' or st.state=='failed') then print('[mod] importer',st.state,'after',i*0.5,'s') break end
  U.wait(30)
 end
 print('[mod] status',tostring(ex.status and ex.status() and ex.status().state),'available',tostring(ex.available and ex.available()),'speciesMax',tostring(ex.speciesMax and ex.speciesMax()),'battleEnabled',tostring(ex.battleEnabled and ex.battleEnabled()))
 local ok251,miss={},{}
 local nameBad={}
 for n=from,to do
  local sp=Pk.speciesFromNational(n)
  local key=sp and Pk.keyName(sp)
  if not sp then nameBad[#nameBad+1]=n..':no-internal-id'
  elseif names[n]~=key then nameBad[#nameBad+1]=n..':'..tostring(names[n])..'~='..tostring(key) end
  local t0=love.timer.getTime()
  local pok,inst,err=pcall(models.newInstance,n,'normal')
  local ms=math.floor((love.timer.getTime()-t0)*1000)
  if pok and inst then
   local m=inst.metrics and inst:metrics() or nil
   local h=m and (m.height or m.h) or nil
   print('[mod]',n,tostring(key),'OK',ms..'ms','height',tostring(h))
   ok251[#ok251+1]=n
   pcall(function()inst:release()end)
  else
   miss[#miss+1]=n
   print('[mod]',n,tostring(key),'MISSING',tostring(pok and err or inst))
  end
 end
 print('[mod] SUMMARY range',from,to,'ok',#ok251,'missing',#miss)
 print('[mod] MISSING',table.concat(miss,','))
 print('[mod] NAMEMISMATCH',#nameBad,table.concat(nameBad,' '))
 print('[EM QA] done')
 love.event.quit()
end
