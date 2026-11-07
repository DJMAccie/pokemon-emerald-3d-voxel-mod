-- QA driver: ambient flyers (wilds/lib/gen3/flyers.lua).
--   EM_MAPS="EM_ROUTE104 EM_SLATEPORT_CITY" EM_HOUR=12 EM_DRIVER=<this file> tools/qa_tryp.sh "wilds/lib/gen3/init.lua wilds/lib/gen3/flyers.lua wilds/options.lua" <abs out> "-" 4 0 200
-- Per map: the player stands on a walkable cell near the middle; the flyers are logged six times 1 s apart
-- (species, offset from the player in cells, altitude, facing, flap, visible); then shot (3rd person) whenever a flyer is
-- within 7 x 4 cells of the player, at most 3 times per map (polled every 20 frames for ~14 s).
-- EM_HOUR sets the clock (12 = day, 23 = night: no flyers expected). EM_FLYSTUB=1: per map, Gen3FlyOver.active is
-- forced true for 30 frames (the Fly ride): the flyers must be gone, then come back from the edge.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local ex=game.mods.exports.emerald_3d_voxel_mod
 local C=ex.gen3 and ex.gen3.camera
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local Pk=require('src.core.game3.pokemon');local Col=require('src.core.game3.collision')
 local DN=ex.lib.require('DayNight')
 local hour=tonumber(os.getenv('EM_HOUR')) or 12
 DN.hours=function() return hour end
 if C then C.setLevel(4,game) end
 local F=ex.gen3Flyers
 local maps={}
 for m in (os.getenv('EM_MAPS') or 'EM_ROUTE104'):gmatch('%S+') do maps[#maps+1]=m end
 for _,id in ipairs(maps) do
  if not Map.load(nil,game,id,{x=1,y=1,facing='down'}) then print('[fly]',id,'LOAD FAILED')
  else
   U.wait(30)
   local def=Map.currentDef();local w=def and (def.midLayout and def.midLayout.width or def.width) or 0;local h=def and (def.midLayout and def.midLayout.height or def.height) or 0
   local best,bd
   for y=0,h-1 do for x=0,w-1 do
    if Col.isWalkable(x,y) and not Col.warpAt(x,y) then
     local d=math.abs(x-w/2)+math.abs(y-h/2);if not bd or d<bd then best,bd={x,y},d end
    end end
   end
   if best then pcall(Player.reset,best[1],best[2],'down') end
   U.wait(40)
   local pool={}
   for _,e in ipairs(F.pool or {}) do pool[#pool+1]=(Pk.name(Pk.speciesFromNational(e.nat)) or e.nat)..':'..e.w end
   print('[fly]',id,'size',w,h,'player',Player.cellX,Player.cellY,'pool',table.concat(pool,','),'hour',hour)
   for k=1,6 do
    local list={}
    for _,f in ipairs(F.list) do
     local r=f.row
     list[#list+1]=('%s@%+d,%+d alt%d %s%s%s'):format(Pk.name(Pk.speciesFromNational(f.nat)) or f.nat,r.cellX-Player.cellX,r.cellY-Player.cellY,-(r.raiseY or 0),r.facing,r.moving and ' flap' or ' glide',r.visible and '' or ' HIDDEN')
    end
    print('[fly]',id,'t'..k,'flyers',#F.list,table.concat(list,' | '))
    U.wait(60)
   end
   if os.getenv('EM_FLYSTUB') then
    local Fly=ex.lib.require('Gen3FlyOver');local real=Fly.active
    Fly.active=function() return true end;U.wait(30)
    print('[fly]',id,'ride stub: flyers',#F.list)
    Fly.active=real;U.wait(10)
    print('[fly]',id,'ride over: flyers',#F.list)
   end
   local shots=0
   for _=1,40 do
    local near
    for _,f in ipairs(F.list) do if math.abs(f.row.cellX-Player.cellX)<=7 and math.abs(f.row.cellY-Player.cellY)<=4 then near=f end end
    if near and shots<3 then
     shots=shots+1;U.shot(game,dir..'/'..id..'_near'..shots..'.png')
     print('[fly]',id,'shot',shots,Pk.name(Pk.speciesFromNational(near.nat)) or near.nat,near.row.cellX-Player.cellX,near.row.cellY-Player.cellY)
     U.wait(100)
    else U.wait(20) end
   end
  end
 end
 print('[EM QA] done')
 love.event.quit()
end
