-- Classic Emerald healthboxes, nudged to sit right under the 3D battle models;
-- the battle textbox loses its panel and keeps only white text
local M={drawing=false}
local OFFSET_FOE={x=-11,y=-13}
local OFFSET_PLAYER={x=10,y=2}
function M.install(stage)
 local Health=require('src.core.game3.battle.healthbox')
 local Battle=require('src.core.game3.battle')
 local original=Health.draw
 local Chrome=require('src.ui.game3.battle_chrome')
 local Font=require('src.ui.game3.frlg_font')
 local panel,text=Chrome.drawPanel,Font.draw
 local function active()
  if not (M.drawing and stage.active) then return false end
  for _,name in ipairs({'bag_menu','party_menu','summary_menu','help_system','pokedex'})do
   local menu=package.loaded['src.ui.game3.'..name]
   if menu and menu.isOpen and menu.isOpen()then return false end
  end
  return true
 end
 Chrome.drawPanel=function(mode,...)
  if not active()then return panel(mode,...)end
 end
 Font.draw=function(value,x,y,opts,...)
  if active()and y and y>=112 then
   local copy={};for key,v in pairs(opts or {})do copy[key]=v end
   copy.colors=Font.COLOR.WHITE
   return text(value,x,y,copy,...)
  end
  return text(value,x,y,opts,...)
 end
 Health.draw=function(side,battler,opts)
  local st=Battle._st
  if not (stage.active and st and not st.double and not st.safari) then return original(side,battler,opts)end
  local o={}
  for k,v in pairs(opts or {})do o[k]=v end
  local d=(side=='player' or side==0) and OFFSET_PLAYER or OFFSET_FOE
  o.ox=(o.ox or 0)+d.x;o.oy=(o.oy or 0)+d.y
  return original(side,battler,o)
 end
 return function()Health.draw=original;Chrome.drawPanel=panel;Font.draw=text;M.drawing=false end
end
return M
