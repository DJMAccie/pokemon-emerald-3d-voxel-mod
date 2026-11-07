-- QA driver: census of overworld wild Pokemon per map (emerald_3d_voxel_mod).
--   EM_MAPS="EM_ROUTE101 EM_ROUTE102" EM_DRIVER=<this file> tools/qa_tryp.sh "-" <abs out> "-" 4 0 200
-- Per map: the encounter table (land/water species), then, at 3 spread-out walkable cells, the spawns after
-- ~4 s: species, terrain, behavior, visible, ambient. Prints [census] lines; one shot per map at the first cell.
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
 local S=ex.wilds
 if C then C.setLevel(4,game) end
 local maps={}
 for m in (os.getenv('EM_MAPS') or 'EM_ROUTE101'):gmatch('%S+') do maps[#maps+1]=m end
 local function name(s)return Pk.name(s) or tostring(s) end
 local function tbl(t,key)
  local a=t and t[key];local slots=a and (a.slots or a.mons or a);local out={}
  for _,e in ipairs(slots or {}) do out[#out+1]=name(tonumber(e.species or e[1])) end
  return table.concat(out,',')
 end
 for _,id in ipairs(maps) do
  if not Map.load(nil,game,id,{x=1,y=1,facing='down'}) then print('[census]',id,'LOAD FAILED')
  else
   U.wait(30)
   Enc.ensureLoaded();local t=Enc.tableFor(id)
   print('[census]',id,'table land=['..tbl(t,'land')..'] grass=['..tbl(t,'grass')..'] water=['..tbl(t,'water')..']')
   local def=Map.currentDef();local w=def and (def.midLayout and def.midLayout.width or def.width) or 0;local h=def and (def.midLayout and def.midLayout.height or def.height) or 0
   local cells={}
   for y=0,h-1 do for x=0,w-1 do
    if Col.isWalkable(x,y) and not Col.warpAt(x,y) then cells[#cells+1]={x,y} end
   end end
   print('[census]',id,'size',w,h,'land cells',#cells)
   local picks={}
   if #cells>0 then picks={cells[math.max(1,math.floor(#cells*.2))],cells[math.max(1,math.floor(#cells*.5))],cells[math.max(1,math.floor(#cells*.8))]} end
   local totalVisible,seen=0,{}
   for i,c in ipairs(picks) do
    pcall(Player.reset,c[1],c[2],'down');U.wait(120)
    local list={}
    for _,r in pairs(S.spawns) do list[#list+1]=('%s/%s/%s%s%s'):format(name(r.species),r.terrain or '?',r.behavior or '?',r.visible and '' or '/HIDDEN',r.ambient and '/ambient' or '') ; if r.visible then totalVisible=totalVisible+1 end seen[name(r.species)..'/'..tostring(r.terrain)]=true end
    table.sort(list)
    print('[census]',id,'at',c[1],c[2],'spawns',#list,table.concat(list,' '))
    local near,n10=999,0
    for _,r in pairs(S.spawns) do local d=math.abs(r.cellX-c[1])+math.abs(r.cellY-c[2]);near=math.min(near,d);if math.abs(r.cellX-c[1])<=10 and math.abs(r.cellY-c[2])<=8 then n10=n10+1 end end
    print('[census]',id,'  nearest spawn',near,'within window',n10)
   end
   -- shot beside one calm visible spawn (3rd person), so the frame shows what a player sees
   local pick
   for _,r in pairs(S.spawns) do if r.visible and (os.getenv('EM_AMBIENT') or not r.ambient) and r.behavior~='aggressive' and r.behavior~='hidden' then pick=r;break end end
   if pick then
    pcall(Player.reset,pick.cellX+3,pick.cellY,'left');U.wait(40)
    U.shot(game,dir..'/'..id..'_'..name(pick.species)..'.png')
    print('[census]',id,'shot at',name(pick.species),pick.terrain,pick.cellX,pick.cellY,'phase',game.phase)
   else print('[census]',id,'no calm visible spawn to shoot') end
   local k={} for s in pairs(seen) do k[#k+1]=s end table.sort(k)
   print('[census]',id,'SEEN',table.concat(k,' '))
  end
 end
 print('[EM QA] done')
 love.event.quit()
end
