-- QA driver: per-frame animation state of the 3D battle models (why does an idle loop look wrong?).
--   EM_FOE_SPECIES=<national> EM_PLAYER_SPECIES=<national> EM_PROBE_FRAMES=<n> EM_DRIVER=<this file> tools/qa_tryp.sh "Gen3Scene.lua" <abs out> "-" 4 0 200
-- EM_PROBE_TAPS=<frame>: from then on tap A every 45 frames (menus, moves), as the trailer shot does.
-- Prints [ap] lines: frame, dt the model got, context, anim index, source frame, time, finished, loop, and the
-- clip table of the foe's model ([ap clips]: index, frames, loopStart, name) so a loop's seam can be read off.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_ROUTE101',x=8,y=10,facing='down'}})
 U.wait(90)
 local Party=require('src.core.game3.party');local Pokemon=require('src.core.game3.pokemon')
 local function internal(nat) return Pokemon.speciesFromNational(tonumber(nat)) or tonumber(nat) end
 Party.giveMonToPlayer(game.session,internal(os.getenv('EM_PLAYER_SPECIES') or 252),12)
 local ex=game.mods.exports.emerald_3d_voxel_mod
 for i=1,120 do U.wait(30);local st=ex and ex.status();if st and (st.state=='ready' or st.state=='failed') then print('[ap] importer',st.state,i*.5,'s') break end end
 local lib=ex.lib
 local SM=lib.require('StadiumModels')
 -- the module's local actor table, reached through the upvalue of update
 local actors
 for i=1,60 do local n,v=debug.getupvalue(SM.update,i);if not n then break end;if n=='actors' then actors=v break end end
 assert(actors,'no actors upvalue')
 local lastDt=0
 local update0=SM.update
 SM.update=function(battle,dt) lastDt=dt;return update0(battle,dt) end
 local ok,err=pcall(require('src.core.game3.battle_bridge').startWild,game.mods,game,{species=internal(os.getenv('EM_FOE_SPECIES') or 263),level=5},{})
 print('[ap] startWild',ok,err)
 local side=os.getenv('EM_PROBE_SIDE') or 'enemy'
 local n=tonumber(os.getenv('EM_PROBE_FRAMES') or 400)
 local printedClips
 for t=1,n do
  U.wait(1)
  local a=actors[side];local inst=a and a.instance;local r=inst and inst._renderer
  if r then
   if not printedClips then
    printedClips=true
    for i,an in ipairs(r.model.anims or {}) do print(string.format('[ap clips] %d frames %s loopStart %s name %s',i,tostring(an.frames),tostring(an.loopStart),tostring(an.name))) end
    local P=require('mods.emerald_3d_voxel_mod.models.lib.pack')
    for _,c in ipairs({'idle','entrance','attack','attack_default','hit','faint','sleep'}) do print('[ap ctx]',c,tostring(P.contextIndex(r.model,c))) end
    print('[ap] staticPose',tostring(r.model.staticPose),'anchorEnabled',tostring(r.anchorEnabled))
   end
   print(string.format('[ap] %d dt %.4f ctx %s anim %s frame %s time %.3f fin %s loop %s',t,lastDt,tostring(a.context),tostring(r.animIndex),tostring(r.frame),r.time or -1,tostring(r.finished),tostring(r.loop)))
  elseif t%60==1 then print('[ap]',t,'no instance yet') end
  if os.getenv('EM_PROBE_TAPS') and t>=tonumber(os.getenv('EM_PROBE_TAPS')) and t%45==0 then table.insert(game.input.pressQueue,'a');game.input.state.a=true end
  game.input.state.a=false
  if t==120 or t==240 or t==360 then U.shot(game,dir..'/ap_'..t..'.png') end
 end
 print('[EM QA] done')
 love.event.quit()
end
