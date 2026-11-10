-- The Mt
local M={}

local function set(t)local s={};for _,v in ipairs(t)do s[v]=true end;return s end
M.CABLE=set({0x250,0x251,0x252,0x253,0x254,0x255,0x259,0x25A,0x25B,0x25C,0x261})
-- cells whose under layer is the pole's foot: drawn with plain ground instead
M.FOOT={[0x264]=0x271}
M.POLE_MID=0x264
M.FOOT_ROWS=16

M.MAPS={
 EM_MT_CHIMNEY={
  pylons={{28,35,33,9}},
  -- station east wall (x 320) -> pylon 28 head -> off the south-east edge
  line={{320,540.5,1},{456,540.5,1},{640,628,1},{960,781,1}},
  beyond='level'},
 EM_ROUTE112={
  pylons={{24,26,24,9},{12,21,19,1},{4,17,15,9}},
  -- station west wall (x 432) -> pylon 24 -> pylon 12 -> off the north-west edge
  line={{432,396.5,1},{392,396.5,1},{200,307.5,2},{0,214.8,2},{-320,66.5,2}},
  beyond='climb'},
}

local function sub(uv,x0,y0,x1,y1)
 local l,t,r,b=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
 local u0,u1=l+(r-l)*x0/16,l+(r-l)*x1/16
 local v0,v1=t+(b-t)*y0/16,t+(b-t)*y1/16
 return {{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
end

function M.skipsOver(c)
 return c.secondary=='lavaridge' and M.CABLE[c.mid] and true or false
end

local function owned(mapId,c)
 local m=M.MAPS[mapId];if not m then return end
 for i,p in ipairs(m.pylons)do
  if p[1]==c.cx and p[2]==c.cy then return m,p,i==1 end
 end
end
function M.owns(mapId,c)return owned(mapId,c)~=nil end

function M.append(mapId,c,quad,uvFor)
 local m,p,cable=owned(mapId,c);if not m then return end
 local uv=uvFor(c.ts,M.POLE_MID);if not uv then return end
 local function box(x0,y0,z0,x1,y1,z1,t)
  quad({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},t,1)
  quad({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},t,.86)
  quad({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},t,.7)
  quad({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},t,.76)
  quad({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},t,.8)
 end
 local function pylon(q)
  local x0=q[1]*16
  local zb=q[2]*16+M.FOOT_ROWS-1 -- depth of the foot
  local top=zb-(q[3]*16+q[4]) -- height of the head's top row
  local pole=sub(uv,4,5,12,6) -- the pole's own row, repeated up it
  box(x0+4,0,zb-8,x0+12,top-7,zb,pole)
  box(x0,top-7,zb-7,x0+16,top,zb,sub(uv,5,2,11,3))
  box(x0+3,0,zb-10,x0+13,2,zb,sub(uv,4,14,12,15)) -- the foot
 end
 pylon(p)
 if not cable then return end
 local depthOf={}
 for i,q in ipairs(m.pylons)do depthOf[i]=q[2]*16+M.FOOT_ROWS-1 end
 local pts={}
 for i,s in ipairs(m.line)do
  pts[i]={s[1],s[2],depthOf[s[3]]}
 end
 local last=m.pylons[#m.pylons]
 local lastX=last[1]*16+8
 local hLevel
 for i,pt in ipairs(pts)do
  local h=pt[3]-pt[2]
  local beyond=(m.beyond=='level' and pt[1]>lastX+1) or false
  if beyond then
   hLevel=hLevel or (pts[i-1][3]-pts[i-1][2])
   h=hLevel;pt[3]=pt[2]+h
  end
  pt[4]=h
 end
 local strand=sub(uv,4,14,5,15) -- the grey cable
 local edge=sub(uv,4,1,5,2) -- its dark outline
 local function ribbon(a,b,dy,t)
  local ax,ay,az=a[1],a[4]+dy,a[3]
  local bx,by,bz=b[1],b[4]+dy,b[3]
  quad({{ax,ay+1,az-.5},{bx,by+1,bz-.5},{bx,by+1,bz+.5},{ax,ay+1,az+.5}},t,1)
  quad({{ax,ay,az+.5},{bx,by,bz+.5},{bx,by,bz-.5},{ax,ay,az-.5}},t,.6)
  quad({{ax,ay,az+.5},{ax,ay+1,az+.5},{bx,by+1,bz+.5},{bx,by,bz+.5}},t,.85)
  quad({{bx,by,bz-.5},{bx,by+1,bz-.5},{ax,ay+1,az-.5},{ax,ay,az-.5}},t,.75)
 end
 for i=1,#pts-1 do
  ribbon(pts[i],pts[i+1],0,strand)
  ribbon(pts[i],pts[i+1],-2,edge)
 end
end
return M
