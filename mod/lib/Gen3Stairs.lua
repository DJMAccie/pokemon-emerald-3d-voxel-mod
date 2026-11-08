-- Interior stairs: source-textured flights, back-wall doorways, steps and ladders
local V=...
local D=V.data('gen3_stairs')
local recipes=D.flights
local M={WALL=D.wall}
function M.prepare(cells)
 local count=0
 local ordered={}
 for _,c in pairs(cells)do ordered[#ordered+1]=c end
 table.sort(ordered,function(a,b)return a.cy==b.cy and a.cx<b.cx or a.cy<b.cy end)
 for _,c in ipairs(ordered)do
  if not c.stairs then for _,r in ipairs(recipes)do
   if c.pair==r.pair and c.mid==r.rows[1][1] then
    local width=#r.rows[1]
    local group={r=r,cx=c.cx,cy=c.cy,ts=c.ts,cells={},width=width}
    local match=true
    for z=0,#r.rows-1 do for x=0,width-1 do
     local q=cells[(c.cx+x)..':'..(c.cy+z)]
     if not q or q.pair~=c.pair or q.mid~=r.rows[z+1][x+1] or q.stairs or q.prop then match=false end
     group.cells[z*width+x+1]=q
    end end
    local landing=group.cells[r.landing[2]*width+r.landing[1]+1]
    if landing and landing.collision==7 then match=false end
    if match then
     group.landing=landing
     for _,q in ipairs(group.cells)do q.stairs=group end
     group.owner=c;count=count+1;break
    end
   end
  end end
 end
 return count
end
-- Brendan's/May's house 1F: the stair doorway sits in the wall's lowest row, but the wall itself stands one row back
-- (at the kitchen's wall face); the wall-base tiles beside the doorway would stand up as slabs or lie as pale mats, so they become floor
function M.flatten(cells)
 for _,s in pairs(cells)do
  if s.pair=='building__brendans_mays_house' and M.wallKind(s)=='up' then
   for dx=-2,2 do local n=cells[(s.cx+dx)..':'..s.cy]
    if n and n~=s and n.pair==s.pair and n.collision==7 and not n.prop and not M.wallKind(n) then
     n.shape={kind='flat',groundMid=0x201};n.column=nil
    end
   end
  end
 end
end
local function builder(c,emit,uvFor)
 local ox,oz=c.cx*16,c.cy*16
 local function tex(mid,x,y)
  local t=assert(uvFor(c.ts,mid))
  local u=t[1][1]+(t[2][1]-t[1][1])*math.max(.03,math.min(.97,x/16))
  local v=t[1][2]+(t[3][2]-t[1][2])*math.max(.03,math.min(.97,y/16))
  return {u,v}
 end
 local function face(points,uv,shade)emit(points,uv,shade)end
 local function solid(mid,x,y)
  local u=tex(mid,x,y);return {u,u,u,u}
 end
 local function box(x0,y0,z0,x1,y1,z1,uv)
  local a,b,c,d=ox+x0,ox+x1,oz+z0,oz+z1
  face({{a,y1,c},{b,y1,c},{b,y1,d},{a,y1,d}},uv,1)
  face({{a,y0,d},{b,y0,d},{b,y1,d},{a,y1,d}},uv,.85)
  face({{b,y0,c},{a,y0,c},{a,y1,c},{b,y1,c}},uv,.7)
  face({{a,y0,c},{a,y0,d},{a,y1,d},{a,y1,c}},uv,.72)
  face({{b,y0,d},{b,y0,c},{b,y1,c},{b,y1,d}},uv,.8)
  if y0>0 then face({{a,y0,d},{b,y0,d},{b,y0,c},{a,y0,c}},uv,.6)end
 end
 return tex,solid,box,face,ox,oz
end
function M.append(c,emit,uvFor)
 local tex,solid,box,face,ox,oz=builder(c,emit,uvFor)
 local g=c.stairs
 if g then
  if g.owner~=c then return end
  local r=g.r
  local depth=#r.rows*16
  local function source(x,y)
   local q=g.cells[math.floor(y/16)*2+math.floor(x/16)+1]
   return q.mid,x%16,y%16
  end
  local landing=g.landing.mid
  local floor=solid(landing,8,12)
  local x0=r.east and 8 or 0
  local x1=r.east and 32 or 24
  local function horizontal(a,b,z0,z1,h,uv)
   for x=a,b-1,8 do for z=z0,z1-1,8 do
    face({{ox+x,h,oz+z},{ox+math.min(b,x+8),h,oz+z},{ox+math.min(b,x+8),h,oz+math.min(z1,z+8)},{ox+x,h,oz+math.min(z1,z+8)}},uv,1)
   end end
  end
  horizontal(0,32,0,8,0,floor)
  horizontal(0,32,depth-8,depth,0,floor)
  if x0>0 then horizontal(0,x0,8,depth-8,0,floor)end
  if x1<32 then horizontal(x1,32,8,depth-8,0,floor)end
  for i=0,5 do
   local a=r.east and x0+i*4 or x1-(i+1)*4
   local h=(i+1)*20/6*(r.down and -1 or 1)
   local sx=r.east and 16+i*2.4 or 15-i*2.4
   local sy=r.down and 18+i*2 or 29-i*3
   local material=solid(source(sx,sy))
   if r.down then
    horizontal(a,a+4,8,depth-8,h,material)
    box(a,h,7,a+4,0,8,material);box(a,h,depth-8,a+4,0,depth-7,material)
    local edge=r.east and a or a+4
    face({{ox+edge,h,oz+8},{ox+edge,h,oz+depth-8},{ox+edge,h+20/6,oz+depth-8},{ox+edge,h+20/6,oz+8}},material,.8)
   else
    for z=8,depth-9,8 do box(a,0,z,a+4,h,z+8,material)end
   end
  end
  local rail=solid(source(r.east and 29 or 2,15))
  if not r.down then
   for i=0,5 do
    local a=r.east and x0+i*4 or x1-(i+1)*4;local h=(i+1)*20/6
    for _,z in ipairs({7,depth-8})do
     box(a,h,z,a+1,h+5,z+1,rail)
     box(a,h+4,z,a+4,h+5,z+1,rail)
    end
   end
  else
   local edge=r.east and x1 or x0
   face({{ox+edge,-20,oz+depth-8},{ox+edge,-20,oz+8},{ox+edge,0,oz+8},{ox+edge,0,oz+depth-8}},rail,.5)
  end
  return
 end
 local s=c.shape
 if s.kind=='steps' then
  for n=0,3 do
   local rise=c.floor and c.floor.high and (c.floor.high-c.floor.low)or 6
   local z=n*4;local h=rise*(1-n/4)
   local uv={tex(c.mid,0,z),tex(c.mid,16,z),tex(c.mid,16,z+4),tex(c.mid,0,z+4)}
   for x=0,15,8 do box(x,0,z,x+8,h,z+4,solid(c.mid,x+4,z+2))end
   face({{ox,h,oz+z},{ox+16,h,oz+z},{ox+16,h,oz+z+4},{ox,h,oz+z+4}},uv,1)
  end
 elseif s.kind=='ladder' then
  local down=s.down
  local y0,y1=down and -16 or 0,down and 2 or 19
  local rail=solid(c.mid,7,9);local shade=solid(c.mid,8,3)
  if down then
   box(1,-16,1,3,0,15,shade);box(13,-16,1,15,0,15,shade)
   box(3,-16,1,13,0,3,shade);box(3,-16,13,13,0,15,shade)
   box(3,-17,3,13,-16,13,shade)
  end
  for _,x in ipairs({4,11})do box(x,y0,5,x+1.5,y1,7,rail)end
  for y=y0+2,y1-1,4 do box(5.5,y,5,11,y+1,7,rail)end
 end
end
-- a stair doorway in the back wall: 'up', 'down' or nil
function M.wallKind(c)
 local t=M.WALL[c.pair or '']
 local k=t and t[c.mid]
 if k and (c.collision or 0)~=7 and (c.collision or 0)~=0xFF then return k end
end
local function swatch(uv,x,y)
 local u=uv[1][1]+(uv[2][1]-uv[1][1])*(x+.5)/16
 local v=uv[1][2]+(uv[3][2]-uv[1][2])*(y+.5)/16
 return {{u,v},{u,v},{u,v},{u,v}}
end
function M.appendWall(c,quad,uvFor,frameMid)
 local k=M.wallKind(c);if not k then return false end
 local uv=uvFor(c.ts,c.mid);if not uv then return false end
 local fuv=frameMid and uvFor(c.ts,frameMid) or uv
 local x,z=c.cx*16,c.cy*16
 local tread=swatch(uv,8,12) -- the light step colour in the doorway art
 local riser=swatch(uv,8,9)
 local cheek=swatch(c.pair=='building__brendans_mays_house' and uv or fuv,c.pair=='building__brendans_mays_house' and 2 or 1,8) -- the gold frame
 local dark=swatch(uv,8,2)
 local x0,x1=x+2,x+14
 local function box(a,y0,c0,b,y1,c1,t,shade,noFront)
  quad({{a,y1,c0},{b,y1,c0},{b,y1,c1},{a,y1,c1}},t,1)
  if not noFront then quad({{a,y1,c1},{b,y1,c1},{b,y0,c1},{a,y0,c1}},t,(shade or 1)*.85)end
  quad({{a,y1,c0},{a,y1,c1},{a,y0,c1},{a,y0,c0}},t,(shade or 1)*.72)
  quad({{b,y1,c1},{b,y1,c0},{b,y0,c0},{b,y0,c1}},t,(shade or 1)*.72)
 end
 -- Brendan's/May's house: the doorway is drawn in the wall, so it goes flat on the wall face
 -- (the cell's north edge for 'up', its south edge for 'down'), not as slabs standing in front of it
 local doorway=c.pair=='building__brendans_mays_house'
 local function frame(zw,hgt)
  local post=swatch(uv,2,8)
  local function front(a,b,y0,y1,t,sh)quad({{a,y1,zw},{b,y1,zw},{b,y0,zw},{a,y0,zw}},t,sh)end
  front(x0,x1,0,hgt,riser,.55)
  front(x,x0,0,hgt+4,post,.9);front(x1,x+16,0,hgt+4,post,.9);front(x0,x1,hgt,hgt+4,post,.9)
 end
 if doorway and k=='down' then return true end -- the wall art already shows this doorway
 if k=='up' then
  if doorway then frame(z+.03,30) end
  for i=0,3 do
   local h=(i+1)*4
   local zf=z+16-i*4
   box(x0,0,zf-4,x1,h,zf,tread,nil,true) -- no front face: the riser quad below is that face (two coplanar faces z-fought)
   quad({{x0,h,zf},{x1,h,zf},{x1,h-4,zf},{x0,h-4,zf}},riser,.8)
   if doorway then box(x0-1.5,0,zf-4,x0,h+2,zf,cheek,.9);box(x1,0,zf-4,x1+1.5,h+2,zf,cheek,.9) end
  end
  if not doorway then
   box(x,0,z,x0,18,z+16,cheek,.9)
   box(x1,0,z,x+16,18,z+16,cheek,.9)
  end
 else
  quad({{x0,-16,z},{x1,-16,z},{x1,-16,z+16},{x0,-16,z+16}},dark,.5)
  quad({{x0,0,z},{x0,0,z+16},{x0,-16,z+16},{x0,-16,z}},dark,.6)
  quad({{x1,0,z+16},{x1,0,z},{x1,-16,z},{x1,-16,z+16}},dark,.6)
  for i=0,3 do
   local h=-(i+1)*4
   local zf=z+16-i*4
   quad({{x0,h,zf-4},{x1,h,zf-4},{x1,h,zf},{x0,h,zf}},tread,.9-i*.08)
   quad({{x0,h+4,zf},{x1,h+4,zf},{x1,h,zf},{x0,h,zf}},riser,.7-i*.06)
  end
  quad({{x,0,z},{x0,0,z},{x0,0,z+16},{x,0,z+16}},cheek,1)
  quad({{x1,0,z},{x+16,0,z},{x+16,0,z+16},{x1,0,z+16}},cheek,1)
 end
 return true
end
return M
