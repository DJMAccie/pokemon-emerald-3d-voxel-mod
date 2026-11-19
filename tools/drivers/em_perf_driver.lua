-- QA driver: frame time of the tree styles (ROCKS & PLANTS option) in one process, vsync off.
--   EM_DRIVER=$PWD/tools/drivers/em_perf_driver.lua tools/qa_tryp.sh "<lib files>" <abs out> "{'EM_LITTLEROOT_TOWN',10,8}" 7
-- Per case and style: rebuild the scene, then 400 frames while the camera turns slowly; prints
-- [EM perf] <map> <style> level <n> mean <ms> median <ms> p95 <ms>, and per style a shot at yaw 0 and at 45 degrees (<map>-diag).
-- EM_PERF_STYLES=modeled,stacked (default) picks the option values; EM_PERF_FRAMES sets the count.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true,vsync=0})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local export=(game.mods and game.mods.exports or {}).emerald_3d_voxel_mod
 local ns=export and (export.gen3 or export.firered)
 local C=assert(ns and ns.camera,'no gen3 camera')
 local Trees=export.lib.require('TreePresentation')
 if os.getenv('EM_TOUR') then export.lib.require('Gen3SceneOptions').tour:setIndex(2,game) end
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local cases=os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or {{'EM_LITTLEROOT_TOWN',10,10}}
 local levels=os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or {7}
 local styles={}
 for s in (os.getenv('EM_PERF_STYLES') or 'modeled,stacked'):gmatch('[^,]+') do styles[#styles+1]=s end
 local frames=tonumber(os.getenv('EM_PERF_FRAMES')) or 400
 local function indexOf(v) for i,x in ipairs(Trees.props.values) do if x==v then return i end end end
 for _,case in ipairs(cases) do
  local ok,err=pcall(function() assert(Map.load(nil,game,case[1],{x=case[2],y=case[3],facing='down'})) end)
  print('[EM perf] load',case[1],ok,err or '')
  if ok then
   pcall(Player.reset,case[2],case[3],'down')
   for _,level in ipairs(levels) do
    for _,style in ipairs(styles) do
     Trees.props:setIndex(assert(indexOf(style),'no style '..style),game);Trees.changed(Trees.props.key)
     C.setLevel(level,game);C.yaw=0
     U.wait(60)
     for _=1,900 do if C.active then break end;U.wait(1) end;U.wait(240)
     U.shot(game,string.format('%s/%s_%d_%s.png',dir,case[1],level,style))
     C.yaw=math.pi/4;U.wait(30);U.shot(game,string.format('%s/%s_%d_%s.png',dir,case[1]..'-diag',level,style));C.yaw=0;U.wait(10)
     local t={}
     for i=1,frames do C.yaw=(i/frames)*math.pi*2;U.wait(1);t[#t+1]=love.timer.getDelta()*1000 end
     table.sort(t)
     local sum=0;for _,v in ipairs(t) do sum=sum+v end
     print(string.format('[EM perf] %s %s level %d mean %.2f median %.2f p95 %.2f',case[1],style,level,
      sum/#t,t[math.ceil(#t/2)],t[math.ceil(#t*.95)]))
    end
   end
  end
 end
 print('[EM QA] done')
 love.event.quit()
end
