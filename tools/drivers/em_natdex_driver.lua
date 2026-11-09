-- QA driver: option national_dex (with all_species) unlocks Emerald's National Dex at the first map load, task 32.
--   EM_DRIVER=<this file> tools/qa_tryp.sh "wilds/lib/gen3/init.lua wilds/options.lua" <abs out> "-" 4 0 90
-- A) fresh new game, default options: Dex.nationalEnabled true; the Pokedex view (Pokedex.newView + List.create) lists
--    caught Pikachu/Mew/Rayquaza in National mode; B) national_dex off, flag cleared, map change: stays off, view is
--    Hoenn-only (200 rows) and drops Mew; C) all_species off + national_dex on: stays off; D) both on again:
--    unlocks; E) national_dex turned off afterwards: the flag is not cleared. Prints [nd] lines; [nd] FAIL = defect.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local ex=game.mods.exports.emerald_3d_voxel_mod
 local S=ex.wilds
 local Dex=require('src.core.game3.dex');local Pk=require('src.core.game3.pokemon');local List=require('src.ui.game3.rse.pokedex_list')
 local MODID='emerald_3d_voxel_mod'
 local fails=0
 local function fail(...)fails=fails+1;print('[nd] FAIL',...)end
 local function setOpt(k,v)game.mods.modOptions[MODID]=game.mods.modOptions[MODID]or{};game.mods.modOptions[MODID][k]=v end
 local sess=game.session
 if not sess then fail('no game.session');print('[EM QA] done');love.event.quit();return end
 local function on()return Dex.nationalEnabled(sess)==true end
 -- what the Pokedex screen would list (its own view + list code)
 local function view(tag)
  local ok,P=pcall(require,'src.ui.game3.rse.pokedex')
  if not ok then print('[nd]',tag,'pokedex module unavailable',tostring(P));return nil end
  local okv,s=pcall(P.newView,{session=sess})
  if not okv then print('[nd]',tag,'newView failed',tostring(s));return nil end
  local okl,list=pcall(List.create,s.ctx,s.dexMode,s.dexOrder)
  if not okl then print('[nd]',tag,'List.create failed',tostring(list));return nil end
  local found={}
  for i=0,list.count-1 do local it=list.items[i];if it and it.owned then found[it.dexNum]=true end end
  print('[nd]',tag,'nationalEnabled',tostring(s.nationalEnabled),'mode',s.dexMode,'rows',list.count,'owned',s.ownCount,'seen',s.seenCount,
   'Pikachu25',tostring(found[25]==true),'Mew151',tostring(found[151]==true),'Rayquaza384',tostring(found[384]==true))
  return {nat=s.nationalEnabled,mode=s.dexMode,rows=list.count,found=found}
 end
 local function recheck()S.map=nil;U.wait(20) end
 local function lock()sess.dex.national=false;sess.dex.nationalMagic=nil end

 -- mark three Kanto/Johto/Hoenn-legend species caught
 for _,n in ipairs({25,151,384})do local sp=Pk.speciesFromNational(n);if sp then Dex.setCaught(sess.dex,sp) else fail('no species for',n) end end

 -- A) default options
 if not on() then fail('A) default new game: National Dex not enabled') end
 local a=view('A default')
 if a and not(a.nat and a.mode==List.DEX_MODE_NATIONAL)then fail('A) view not in National mode')end
 if a and not(a.found[25]and a.found[151]and a.found[384])then fail('A) caught Kanto/Johto/Hoenn species missing from the National list')end

 -- B) national_dex off
 lock();setOpt('national_dex',false);recheck()
 if on() then fail('B) national_dex=false still enabled it') end
 local b=view('B off')
 -- Pikachu (25) and Rayquaza (384) are in Emerald's Hoenn dex; Mew (151) is not
 if b and b.found[151]then fail('B) Hoenn-only view lists Mew') end
 if b and b.rows>=360 then fail('B) Hoenn-only view has National row count',b.rows) end

 -- C) all_species off, national_dex on
 setOpt('national_dex',true);setOpt('all_species',false);recheck()
 if on() then fail('C) all_species=false still enabled the National Dex') end

 -- D) both on again
 setOpt('all_species',true);recheck()
 if not on() then fail('D) both on: not enabled') end
 view('D back on')

 -- E) turning the option off later never clears the flag
 setOpt('national_dex',false);recheck()
 if not on() then fail('E) turning national_dex off cleared the flag') end

 print('[nd] done fails',fails)
 print('[EM QA] done')
 love.event.quit()
end
