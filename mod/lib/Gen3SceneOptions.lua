-- Shared presentation consumers for Game3
local V=...
local M={}
local Day=V.require('DayNight')
local Sky=V.require('Sky')
local R=V.require('Voxel3D')
local Underlay=V.require('WorldUnderlay')
local TiltShift=V.require('TiltShift')
M.invert=V.require('CameraSettings').invertY
local Tour=V.require('TourMode')
local DebugWalk=V.require('DebugWalk')
M.tour=V.require('ModSetting').new('tour','TOUR',{false,true},{'OFF','ON'},1)
-- Battles: draw the 3D scene (models and arena) at a lower resolution and blow it up with hard pixels,
-- so the smooth Stadium models sit in the pixel-art world (Petya 2026-11-19). GAME = the game's own pixel size.
M.battlePixels=V.require('ModSetting').new('battlePixels','BATTLE PIXELS',{'off','game','2','3'},{'OFF','GAME PIXELS','2X','3X'},2)
function M.battlePixelScale()
 local v=M.battlePixels:get()
 if v=='off' then return 1 end
 if v=='game' then
  local ok,Renderer=pcall(require,'src.render.Renderer')
  local k=ok and Renderer.fitScale and Renderer:fitScale() or 3
  return math.max(1,math.floor(k or 3))
 end
 return tonumber(v) or 1
end
M.settings={M.invert,
 V.require('Water').setting,M.tour,M.battlePixels}

M.log=false
local focusAt,focusNow,focusSet,focusUnder,focusPrint,focusShown=nil,.5,false,nil,0,nil
local function focusTarget()
 local Voxel3D=V.require('Voxel3D')
 local G=V.require('Gen3Scene')
 local battle=false
 local wx,wz
 if battle and focusUnder then wx,wz=focusUnder[1],focusUnder[2]
 else
  local Player=require('src.core.game3.player')
  wx,wz=(Player.px or 0)+8,(Player.py or 0)+8
 end
 local wy=G.groundAt(wx,wz+8-.001)
 local _,y=Voxel3D.project(wx,wy,wz)
 local _,h=Voxel3D.size()
 if not (y and h and h>0) then return nil,battle end
 return y/h,battle
end
local function focusTrack()
 local y,battle=focusTarget()
 local onScreen=y and y>=0 and y<=1
 local target=onScreen and math.max(.2,math.min(.8,y)) or TiltShift.FOCUS_Y
 local t=love.timer.getTime()
 local dt=focusAt and math.min(math.max(t-focusAt,0),.1) or 0
 focusAt=t
 if focusSet then focusNow=focusNow+(target-focusNow)*(1-math.exp(-dt/.15))
 else focusNow,focusSet=target,true end
 TiltShift.setFocus(focusNow)
 if M.log and (t-focusPrint>=1 or math.abs(target-(focusShown or -1))>.02) then
  focusPrint,focusShown=t,target
  print(string.format('[tiltshift] focus %.3f target %.3f raw %.3f battle %s',focusNow,target,y or -1,tostring(battle)))
 end
end

function M.update(dt)
 V.require("ForestAtmos").update(dt)
 Tour.update(DebugWalk.on())
end

function M.environment(indoor,background)
 Day.applyRig(not indoor)
 R.tint=Day.tint(not indoor)
 if indoor then return background end
 return Sky.dress({background[1],background[2],background[3],background[4] or 1})
end

function M.underlay(indoor,cx,cz,background)
 focusUnder={cx,cz}
 if indoor then return false end
 return Underlay.draw(cx,cz,background)
end

function M.finish(canvas,w,h)
 Tour.update(DebugWalk.on())
 TiltShift.setLevel(V.require('Gen3Integration').level==6 and 0 or 2)
 focusTrack()
 canvas=TiltShift.apply(canvas)
 Tour.overlay(canvas,w,h)
 return canvas
end
function M.release()
 TiltShift.invalidate()
 R.tint={1,1,1};R.fog=nil
end
return M
