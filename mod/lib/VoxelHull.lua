-- Closed, greedy-meshed voxel volumes
local V=...
local Budget=V and V.require("BuildBudget") or {tick=function()end,check=function()end}
local M={}
M.BACK_RATIO=.9
M.INK=180
M.TIER=.3
M.LUMP=.8
M.LATHE=true
M.LATHE_SKEW=3 -- widest the row centres of a card may drift for it to be turned into a round tree
M.FOOT_R=4 -- trunk radius, in card pixels
M.BELLY=4 -- rows from the foot over which the underside of a trunkless crown rounds off
M.UNDER=12 -- rows over which a crown on a trunk rounds in to the trunk, so the trunk shows from above
M.LIFT=4 -- rows the trunk is lengthened by (its own lowest row repeated)
M.TOP=2 -- rows from the top over which the crown rounds off into a dome
M.BUMP=.04 -- how far the crown outline wobbles in and out (share of the radius), so it reads as leaf clumps
M.VIEW=.5 -- the art looks down on the crown: a pixel outward from the axis shows the art this many rows lower
M.SEAM=1 -- columns at the card edge left out of the wrap, so no outline stripe where front and back meet
M.TRUNK_ROWS=.3 -- share of the card height, from the foot, where a non-green pixel is trunk
local NEIGH={{-1,0},{1,0},{0,-1},{0,1}}
local function meshVox(vox,paints,nx,ny,nz,step,w,bottom)
 local out={}
 local lo,hi={nx,ny,nz},{-1,-1,-1}
 for k in pairs(vox)do
  local z=k%nz;local r=(k-z)/nz;local x=r%nx;local y=(r-x)/nx
  if x<lo[1] then lo[1]=x end;if x>hi[1] then hi[1]=x end
  if y<lo[2] then lo[2]=y end;if y>hi[2] then hi[2]=y end
  if z<lo[3] then lo[3]=z end;if z>hi[3] then hi[3]=z end
 end
 local strides={nz,nx*nz,1}
 for axis=1,3 do for _,sign in ipairs({-1,1})do
  local limits={nx,ny,nz};local uaxis=axis%3+1;local vaxis=(axis+1)%3+1
  local sa,su,sv=strides[axis],strides[uaxis],strides[vaxis]
  for plane=lo[axis],hi[axis] do
   Budget.check()
   local grid={};local nw,nh=limits[uaxis],limits[vaxis]
   local inside=plane+sign>=0 and plane+sign<limits[axis]
   local across=sign*sa
   for v=lo[vaxis],hi[vaxis] do local rowk=plane*sa+v*sv;for u=lo[uaxis],hi[uaxis] do
    local k=rowk+u*su
    local colour=vox[k]
    if colour and not (inside and vox[k+across]) then grid[v*nw+u]=colour end
   end end
   for v=lo[vaxis],hi[vaxis] do for u=lo[uaxis],hi[uaxis] do
    local colour=grid[v*nw+u]
    if colour then
     local ww,hh=1,1
     while u+ww<nw and grid[v*nw+u+ww]==colour do ww=ww+1 end
     while v+hh<nh do
      local whole=true
      for du=0,ww-1 do if grid[(v+hh)*nw+u+du]~=colour then whole=false;break end end
      if not whole then break end;hh=hh+1
     end
     for dv=0,hh-1 do for du=0,ww-1 do grid[(v+dv)*nw+u+du]=nil end end
     local q={u=paints[colour][1],v=paints[colour][2],shade=axis==2 and (sign>0 and 1 or .68) or axis==1 and .85 or .94}
     for _,uv in ipairs({{u,v},{u+ww,v},{u+ww,v+hh},{u,v+hh}})do
      local p={};p[axis]=(plane+(sign>0 and 1 or 0))*step;p[uaxis]=uv[1]*step;p[vaxis]=uv[2]*step
      p[1]=p[1]-w/2;p[2]=math.max(0,p[2]-bottom);p[3]=p[3]-nz*step/2
      q[#q+1]=p
     end
     if sign<0 then q[2],q[4]=q[4],q[2] end
     out[#out+1]=q
    end
   end end
  end
 end end
 return out
end
-- A tree as a body of revolution: each row is a disc as wide as the card row, painted with the card
-- as seen from each of the four sides, so every angle shows the art's leaf clumps
local function wobble(phi,y,a,b)return (math.sin(phi*3+y*.9+a)+math.sin(phi*5-y*.55+b))/2 end
local function lathe(w,h,sample)
 local nx,ny,nz=w,h,w
 local rows,paints,vox={}, {}, {}
 for y=0,ny-1 do
  local sy=h-1-y
  local row={};local L,R=nil,nil
  for x=0,nx-1 do
   local r,g,b,a,u,v=sample(x,sy)
   if a and a>.5 then
    local k=math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)
    paints[k]=paints[k] or {u,v};row[x]=k;L=L or x;R=x
   end
  end
  if L then
   local r={row=row,L=L,R=R,cx=(L+R+1)/2,rho=(R-L+1)/2}
   r.shape=r.rho
   if y<ny*M.TRUNK_ROWS then
    for x=L,R do local k=row[x];if k and not r.trunk then
     local rr,gg,bb=math.floor(k/65536),math.floor(k/256)%256,k%256
     if rr+gg+bb>=M.INK and rr>=gg then r.trunk=k end
    end end
   end
   rows[y]=r
  end
 end
 local lo,hi
 for _,r in pairs(rows)do lo=math.min(lo or r.cx,r.cx);hi=math.max(hi or r.cx,r.cx) end
 if lo and hi-lo>M.LATHE_SKEW then return nil end -- a leaning or lopsided tree (clumps on a bent trunk) is not round
 local ybot
 for y in pairs(rows)do if not ybot or y<ybot then ybot=y end end
 local yTrunk,bark
 for y,r in pairs(rows)do if r.trunk and (not yTrunk or y>yTrunk) then yTrunk,bark=y,r.trunk end end
 local base,under,least=ybot,M.BELLY,.5
 if yTrunk then
  local up={}
  for y,r in pairs(rows)do
   if y<=yTrunk then r.trunk=r.trunk or bark;r.shape=0 end
   up[y+M.LIFT]=r
  end
  for i=0,M.LIFT-1 do up[ybot+i]=rows[ybot] end
  rows=up;ny=ny+M.LIFT
  base,under,least=yTrunk+M.LIFT+1,M.UNDER,M.FOOT_R
 end
 for y,r in pairs(rows)do
  local d=y-base
  if d>=0 and d<under then r.shape=math.max(least,r.rho*math.sqrt(1-((under-d)/under)^2)) end
 end
 local top=0
 for y in pairs(rows)do if y>top then top=y end end
 for y,r in pairs(rows)do
  local e=top-y
  if e<M.TOP then r.shape=math.min(r.shape,math.max(.5,r.rho*math.sqrt(1-((M.TOP-e)/M.TOP)^2*.8))) end
 end
 local function key(x,y,z)return (y*nx+x)*nz+z end
 local solid={}
 for y,r in pairs(rows)do
  Budget.check()
  for x=0,nx-1 do for z=0,nz-1 do
   local dx,dz=x+.5-r.cx,z+.5-nz/2
   local lim=r.shape
   if y-ybot>=M.BELLY and lim>0 then lim=lim*(1+M.BUMP*wobble(math.atan2(dx,dz),y,0,1.7)) end
   if r.trunk and M.FOOT_R>lim then lim=M.FOOT_R end
   if dx*dx+dz*dz<=lim*lim then solid[key(x,y,z)]=true end
  end end
 end
 local hp=math.pi/2
 local topY=0
 for y in pairs(rows)do if y>topY then topY=y end end
 local yLow=topY
 for y,r in pairs(rows)do if not r.trunk and y<yLow then yLow=y end end
 for y,r in pairs(rows)do
  Budget.check()
  for x=0,nx-1 do for z=0,nz-1 do
   local k=key(x,y,z)
   if solid[k] then
    local dx0,dz0=x+.5-r.cx,z+.5-nz/2
    if r.trunk and dx0*dx0+dz0*dz0<=M.FOOT_R*M.FOOT_R and (dx0*dx0+dz0*dz0>r.shape*r.shape or y-ybot<M.BELLY) then vox[k]=r.trunk else
    local dx,dz=x+.5-r.cx,z+.5-nz/2
    local phi=math.atan2(dx,dz)
    local a=math.abs(phi);if a>hp then a=math.pi-a end
    local src,sx=r,nil
    if not r.trunk and y>yLow then
     -- the art is drawn from above: paint as seen from the nearest of the four sides, lower art rows further out
     local m,t
     if math.abs(dz)>=math.abs(dx) then m=math.abs(dz);t=dz>=0 and dx or -dx else m=math.abs(dx);t=dx>=0 and dz or -dz end
     local av=y-yLow
     src=rows[math.floor(y-av*(1-math.exp(-M.VIEW*m/av))+.5)] or r
     if src.trunk then src=r end
     sx=math.floor(src.cx+t)
    else
     local span=math.max(.5,src.rho-M.SEAM)
     sx=math.floor(src.cx+(phi<0 and -1 or 1)*span*math.sin(a))
    end
    sx=math.max(src.L,math.min(src.R,sx))
    local c=src.row[sx]
    if not c then
     for d=1,nx do c=src.row[sx-d] or src.row[sx+d];if c then break end end
    end
    vox[k]=c
    end
    Budget.tick()
   end
  end end
 end
 return vox,paints,nx,ny,nz
end
function M.build(w,h,sample,step,bottom,depthLimit,organic,inflate,taper,seed,flat)
 step=step or 1;bottom=bottom or 0
 if inflate and seed and M.LATHE and step==1 then
  local vox,paints,nx,ny,nz=lathe(w,h,sample)
  if vox then return meshVox(vox,paints,nx,ny,nz,1,w,bottom) end
 end
 local nx,ny=math.ceil(w/step),math.ceil(h/step)
 local depth=w
 local nz=math.ceil(depth/step)
 local vox,paints={},{}
 local foliage,all={},{}
 local function key(x,y,z)return (y*nx+x)*nz+z end
 local halfDepth,relief
 local zr0,zr1,rowK={}, {}, {}
 if inflate then
  local INF=1e9
  local dist={}
  for y=0,ny-1 do local sy=h-1-y*step;for x=0,nx-1 do
   local _,_,_,a=sample(math.min(w-1,x*step+math.floor(step/2)),sy)
   dist[y*nx+x]=(a and a>.5) and INF or 0
  end end
  local function at(x,y)
   if y<0 then return INF end
   if x<0 or x>=nx or y>=ny then return 0 end
   return dist[y*nx+x]
  end
  for y=0,ny-1 do for x=0,nx-1 do local k=y*nx+x
   if dist[k]>0 then dist[k]=math.min(dist[k],at(x-1,y)+3,at(x,y-1)+3,at(x-1,y-1)+4,at(x+1,y-1)+4) end
  end end
  for y=ny-1,0,-1 do for x=nx-1,0,-1 do local k=y*nx+x
   if dist[k]>0 then dist[k]=math.min(dist[k],at(x+1,y)+3,at(x,y+1)+3,at(x+1,y+1)+4,at(x-1,y+1)+4) end
  end end
  local top=0
  for k,d in pairs(dist)do if d<INF and d>top then top=d end end
  local R=math.min(top/3,(depthLimit or 24)/2/step)
  halfDepth=function(x,y)
   local d=math.min(R,math.max(0,dist[y*nx+x]/3-.5))
   return math.sqrt(math.max(0,R*R-(R-d)^2))
  end
  if seed then
   local lum,lo,hi={},1e9,-1e9
   for y=0,ny-1 do local sy=h-1-y*step;for x=0,nx-1 do
    local r,g,b,a=sample(math.min(w-1,x*step+math.floor(step/2)),sy)
    if a and a>.5 then local l=r+g+b;lum[y*nx+x]=l;if l*255>=M.INK then lo=math.min(lo,l);hi=math.max(hi,l) end end
   end end
   local function hash(a,b,c)local n=math.sin(a*12.9898+b*78.233+c*37.719+seed*4.137)*43758.5453;return n-math.floor(n)end
   local CELL=7
   local function noise(x,y,c)
    local gx,gy=x/CELL,y/CELL;local ix,iy=math.floor(gx),math.floor(gy);local fx,fy=gx-ix,gy-iy
    fx,fy=fx*fx*(3-2*fx),fy*fy*(3-2*fy)
    local p,q=hash(ix,iy,c)+(hash(ix+1,iy,c)-hash(ix,iy,c))*fx,hash(ix,iy+1,c)+(hash(ix+1,iy+1,c)-hash(ix,iy+1,c))*fx
    return (p+(q-p)*fy)*2-1
   end
   relief=function(x,y,depth)
    local sum,n=0,0
    for dy=-2,2 do for dx=-2,2 do
     local xx,yy=x+dx,y+dy
     local l=xx>=0 and xx<nx and yy>=0 and yy<ny and lum[yy*nx+xx]
     if l then sum=sum+math.max(lo,math.min(hi,l));n=n+1 end
    end end
    local t=(n>0 and hi>lo) and (sum/n-lo)/(hi-lo) or 1
    local edge=math.min(1,depth/5)
    return depth*(1-M.TIER*(1-t))+noise(x,y,1)*M.LUMP*edge,depth*M.BACK_RATIO+noise(x,y,2)*M.LUMP*edge
   end
  end
 end
 for y=0,ny-1 do
  Budget.check()
  local sy=math.min(h-1,h-1-y*step)
  local row,left,right={},nx,-1
  for x=0,nx-1 do
   local sx=math.min(w-1,x*step+math.floor(step/2))
   local r,g,b,a,u,v=sample(sx,sy)
   if a and a>.5 then
    local k=math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)
    paints[k]=paints[k]or{u,v};row[x]=k;left=math.min(left,x);right=math.max(right,x)
    if organic then
     all[#all+1]=k
     if sy<h*.76 and g>r*1.12 and g>b*1.08 then foliage[#foliage+1]=k end
    end
   end
  end
  local runL,runR={}, {}
  do local x=left
   while x<=right do
    if row[x] then
     local e=x;while row[e+1] do e=e+1 end
     for k=x,e do runL[k]=x;runR[k]=e end
     x=e+1
    else x=x+1 end
   end
  end
  for x=left,right do if row[x] and not organic then
   local center=(runL[x]+runR[x]+1)/2;local radius=(runR[x]-runL[x]+1)/2
   local dx=x+.5-center
   local depth=math.sqrt(math.max(0,radius*radius-dx*dx))*.88
   if flat and depthLimit then depth=depthLimit/(2*step) end -- hedges: the same depth right to the tile edge, so tiles join
   if inflate then depth=math.max(.5,halfDepth(x,y)*(taper and (1-(1-taper)*y/math.max(1,ny-1)) or 1)) elseif depthLimit then depth=math.min(depth,depthLimit/(2*step)) end
   local z0=math.max(0,math.floor(nx/2-depth*(inflate and M.BACK_RATIO or 1)));local z1=math.min(nx-1,math.ceil(nx/2+depth)-1)
   if relief then
    local front,back=relief(x,y,depth)
    z0=math.max(0,math.floor(nx/2-math.max(.5,back)));z1=math.min(nx-1,math.ceil(nx/2+math.max(.5,front))-1)
   end
   if depthLimit and not inflate then
    local cells=math.max(1,math.floor(depthLimit/step))
    local first=math.floor((nx-cells)/2)
    z0=math.max(z0,first);z1=math.min(z1,first+cells-1)
   end
   if inflate then zr0[y*nx+x]=z0;zr1[y*nx+x]=z1;rowK[y]=row
   else for z=z0,z1 do vox[key(x,y,z)]=row[x] end end
  end end
 end
 if inflate then
  local function dominant(row)
   local counts,bestK,bestN,anyK,anyN={}, nil,0,nil,0
   for x=0,nx-1 do local k=row[x];if k then
    counts[k]=(counts[k] or 0)+1
    local r,g,b=math.floor(k/65536),math.floor(k/256)%256,k%256
    if counts[k]>anyN then anyK,anyN=k,counts[k] end
    if r+g+b>=M.INK and counts[k]>bestN then bestK,bestN=k,counts[k] end
   end end
   return bestK or anyK
  end
  local function ink(k) return math.floor(k/65536)+math.floor(k/256)%256+k%256<M.INK end
  local function leaf(x,yy)
   local row=rowK[yy];if not row then return nil end
   for d=0,nx do
    local k=row[x-d];if k and not ink(k) then return k end
    k=row[x+d];if k and not ink(k) then return k end
   end
  end
  local topRow=0
  for y=0,ny-1 do if rowK[y] then topRow=y end end
  local wideRow,wide=0,0
  for y=0,ny-1 do local row=rowK[y];if row then
   local n=0;for x=0,nx-1 do if row[x] and not ink(row[x]) then n=n+1 end end
   if n>wide then wide,wideRow=n,y end
  end end
  local zBack=nx
  for _,z in pairs(zr0)do if z<zBack then zBack=z end end
  local trunk={}
  if seed then
   local zFront=0
   for _,z in pairs(zr1)do if z>zFront then zFront=z end end
   for y=0,math.floor(ny*M.TRUNK_ROWS) do local row=rowK[y];if row then for x=0,nx-1 do local k=row[x];if k and not ink(k) then
    if math.floor(k/65536)>=math.floor(k/256)%256 then trunk[y*nx+x]=true;zr1[y*nx+x]=zFront end
   end end end end
  end
  local function rim(row,x,y)
   local up,dn=rowK[y+1],rowK[y-1]
   return not (row[x-1] and row[x+1] and up and up[x] and (dn and dn[x] or y==0))
  end
  if seed then
   local wall={}
   for y=0,ny-1 do local row=rowK[y];if row then for x=0,nx-1 do local k=row[x];if k and ink(k) and rim(row,x,y) and not trunk[y*nx+x] then
    local a,b
    for _,d in ipairs(NEIGH)do
     local xx,yy=x+d[1],y+d[2]
     local nr=rowK[yy];local nk=nr and nr[xx]
     if nk and not (ink(nk) and rim(nr,xx,yy)) then
      local n0,n1=zr0[yy*nx+xx],zr1[yy*nx+xx]
      a=a and math.min(a,n0) or n0;b=b and math.max(b,n1) or n1
     end
    end
    if a then wall[y*nx+x]={a,b} end
   end end end end
   for k,s in pairs(wall)do zr0[k],zr1[k]=s[1],s[2] end
  end
  local bodies={}
  local function colourAt(x,y,z)
   local row=rowK[y]
   local z0,z1=zr0[y*nx+x],zr1[y*nx+x]
   if z==z1 or trunk[y*nx+x] then return row[x] end
   if seed and ink(row[x]) and rim(row,x,y) then return row[x] end
   local d=z>=math.floor(nx/2) and z1-z or z-z0
   local yy=y+d
   if yy>topRow then yy=math.max(0,2*topRow-yy-3) end
   local above=rowK[y+1]
   local covered=above and above[x] and zr0[(y+1)*nx+x]<=z and zr1[(y+1)*nx+x]>=z
   if not covered then yy=seed and math.max(0,math.min(topRow,wideRow+math.floor(nx/2)-z)) or math.max(0,topRow-2-(z-zBack)) end
   local body=bodies[y];if body==nil then body=dominant(row) or false;bodies[y]=body end
   return leaf(x,yy) or leaf(x,y) or body or nil
  end
  -- The game runs without the JIT: keep this loop cheap.
  local planes={{},{},{}}
  local limits={nx,ny,nz}
  local function covers(x,y,z)
   if x<0 or y<0 or x>=nx or y>=ny then return false end
   local k=y*nx+x;local a=zr0[k];return a~=nil and a<=z and zr1[k]>=z
  end
  local function put(axis,sign,plane,u,v,colour)
   local t=planes[axis][sign*(plane+1)];if not t then t={};planes[axis][sign*(plane+1)]=t end
   t[v*limits[axis%3+1]+u]=colour
  end
  local function span(x,y)
   if x<0 or y<0 or x>=nx or y>=ny then return nil end
   local k=y*nx+x;return zr0[k],zr1[k]
  end
  for y=0,ny-1 do local row=rowK[y];if row then for x=0,nx-1 do if row[x] then
   local z0,z1=zr0[y*nx+x],zr1[y*nx+x]
   local lo_,hi_=z0,z1
   for _,d in ipairs(NEIGH)do
    local a,b=span(x+d[1],y+d[2])
    if a==nil then lo_,hi_=z1+1,z0-1;break end
    if a>lo_ then lo_=a end;if b<hi_ then hi_=b end
   end
   local z=z0
   while z<=z1 do
    if z>z0 and z<z1 and z>=lo_ and z<=hi_ then z=math.min(hi_+1,z1) end
    local xm,xp,ym,yp=not covers(x-1,y,z),not covers(x+1,y,z),not covers(x,y-1,z),not covers(x,y+1,z)
    local zm,zp=z==z0,z==z1
    if xm or xp or ym or yp or zm or zp then
     local c=colourAt(x,y,z)
     if c then
      if xm then put(1,-1,x,y,z,c) end;if xp then put(1,1,x,y,z,c) end
      if ym then put(2,-1,y,z,x,c) end;if yp then put(2,1,y,z,x,c) end
      if zm then put(3,-1,z,x,y,c) end;if zp then put(3,1,z,x,y,c) end
     end
    end
    z=z+1
   end
   Budget.tick()
  end end end end
  local out={}
  for axis=1,3 do for _,sign in ipairs({-1,1})do
   local uaxis=axis%3+1;local vaxis=(axis+1)%3+1
   local nw,nh=limits[uaxis],limits[vaxis]
   local list={}
   for pk in pairs(planes[axis])do if (pk>0)==(sign>0) then list[#list+1]=sign*pk-1 end end
   table.sort(list)
   for _,plane in ipairs(list)do
    Budget.check()
    local grid=planes[axis][sign*(plane+1)]
    local keys={};for k in pairs(grid)do keys[#keys+1]=k end
    table.sort(keys)
    for _,k0 in ipairs(keys)do
     local colour=grid[k0]
     if colour then
      local u,v=k0%nw,math.floor(k0/nw)
      local ww,hh=1,1
      while u+ww<nw and grid[v*nw+u+ww]==colour do ww=ww+1 end
      while v+hh<nh do
       local whole=true
       for du=0,ww-1 do if grid[(v+hh)*nw+u+du]~=colour then whole=false;break end end
       if not whole then break end;hh=hh+1
      end
      for dv=0,hh-1 do for du=0,ww-1 do grid[(v+dv)*nw+u+du]=nil end end
      local q={u=paints[colour][1],v=paints[colour][2],shade=axis==2 and (sign>0 and 1 or .68) or axis==1 and .85 or .94}
      for _,uv in ipairs({{u,v},{u+ww,v},{u+ww,v+hh},{u,v+hh}})do
       local p={};p[axis]=(plane+(sign>0 and 1 or 0))*step;p[uaxis]=uv[1]*step;p[vaxis]=uv[2]*step
       p[1]=p[1]-w/2;p[2]=math.max(0,p[2]-bottom);p[3]=p[3]-nz*step/2
       q[#q+1]=p
      end
      if sign<0 then q[2],q[4]=q[4],q[2] end
      out[#out+1]=q
     end
    end
   end
  end end
  return out
 end
 if organic and #all>0 then
  if #foliage==0 then foliage=all end
  local height=h-bottom
  local function oval(x,y,z,cx,cy,cz,rx,ry,rz)
   return ((x-cx)/rx)^2+((y-cy)/ry)^2+((z-cz)/rz)^2<=1
  end
  for y=0,ny-1 do for x=0,nx-1 do Budget.tick();for z=0,nz-1 do
   local xx=(x+.5)*step/w-.5;local yy=((y+.5)*step-bottom)/height;local zz=(z+.5)*step/depth-.5
   local pool
   if yy>=0 then
    if organic=='bush' then
     if oval(xx,yy,zz,-.17,.24,.06,.32,.26,.39)
      or oval(xx,yy,zz,.12,.35,-.08,.36,.36,.34)
      or oval(xx,yy,zz,.2,.2,.18,.26,.24,.25)then pool=foliage end
    elseif organic=='rock' then
     if oval(xx,yy,zz,-.1,.34,.04,.38,.4,.39)
      or oval(xx,yy,zz,.12,.45,-.06,.34,.5,.32)
      or oval(xx,yy,zz,.22,.2,.18,.24,.27,.26)then pool=all end
    end
   end
   if pool then
    local a,b,c=math.floor(x/2),math.floor(y/2),math.floor(z/2)
    local n=math.sin(a*12.9898+b*78.233+c*37.719)*43758.5453
    vox[key(x,y,z)]=pool[math.floor((n-math.floor(n))*#pool)+1]
   end
  end end end
 end
 return meshVox(vox,paints,nx,ny,nz,step,w,bottom)
end
function M.card(w,h,sample,bottom,height)
 local out={};local scale=(height or h)/h
 for y=0,h-1 do for x=0,w-1 do
  local _,_,_,a,u,v=sample(x,y)
  if a and a>.5 then
   local top=(h-y-(bottom or 0))*scale;local low=top-scale
   out[#out+1]={{x-w/2,top,0},{x+1-w/2,top,0},{x+1-w/2,low,0},{x-w/2,low,0},u=u,v=v,shade=1,card=true}
  end
 end end
 return out
end
function M.append(quads,v,i,count,x,y,z)
 for _,q in ipairs(quads)do
  Budget.tick()
  local base=#v
  for _,p in ipairs(q)do v[#v+1]={x+p[1],y+p[2],z+p[3],q.u,q.v,q.shade,0,0,0} end
  for _,k in ipairs({1,2,3,1,3,4})do i[#i+1]=base+k end
 end
 return (count or 0)+#quads
end
return M
