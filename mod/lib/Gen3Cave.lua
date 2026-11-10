-- Cave masses and boulders use their native palette and silhouette
local V=...
local M={}
local function boulderMask(mask)
 local visited,best={},{}
 for start=0,255 do if mask[start] and not visited[start] then
  local component,queue={}, {start};visited[start]=true
  local at=1
  while queue[at] do
   local k=queue[at];at=at+1;component[#component+1]=k
   local x,y=k%16,math.floor(k/16)
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local nx,ny=x+d[1],y+d[2];local nextKey=ny*16+nx
    if nx>=0 and nx<16 and ny>=0 and ny<16 and mask[nextKey] and not visited[nextKey] then
     visited[nextKey]=true;queue[#queue+1]=nextKey
    end
   end
  end
  if #component>#best then best=component end
 end end
 local out={};for _,k in ipairs(best)do out[k]=true end
 return out
end
function M.wall(cells,c,emit,uvFor)
 return V.require('Gen3Terrain').append(cells,c,emit,uvFor)
end
function M.positionMask(ts,mid,floor)
 local a,b=ts.midToSlot[mid],ts.midToSlot[floor]
 if not (a and b and ts.imageData) then return end
 local function px(slot,x,y)
  local X,Y=slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y
  local r,g,bl,al=ts.imageData:getPixel(X,Y)
  if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(X,Y);r,g,bl,al=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+bl*(1-aa),aa+al*(1-aa) end
  return math.floor(r*255+.5),math.floor(g*255+.5),math.floor(bl*255+.5),al
 end
 local mask,n={},0
 for y=0,15 do for x=0,15 do
  local r,g,bl,al=px(a,x,y)
  local fr,fg,fb=px(b,x,y)
  if al>0 and (r~=fr or g~=fg or bl~=fb) then mask[y*16+x]=true;n=n+1 end
 end end
 if n>0 then return mask end
end
local rockMemo=setmetatable({},{__mode='k'})
-- A tile that draws several small stones (the Lavaridge onsen rim, shape.stones) is one little dome per stone, as in the art.
local STONE_LUM=.49 -- the stone tops (cream, grey) against their navy shade
local STONE_TONE=.38 -- darkest colour a dome is painted with
local STONE_MIN=6 -- fewest lit pixels that make a stone
local D4={{1,0},{-1,0},{0,1},{0,-1}}
local function stoneMasks(c)
 local ts=c.ts
 local slot=ts.midToSlot[c.mid];local px,py=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local lit,solid={}, {}
 for y=0,15 do for x=0,15 do
  local r,g,b,a=ts.imageData:getPixel(px+x,py+y)
  if (a or 1)>.5 and math.abs(g-r)<.1 and not (r>b+.2) then -- grey stone and its navy shade: not water, grass or sand ground
   solid[y*16+x]=true
   if .299*r+.587*g+.114*b>=STONE_LUM then lit[y*16+x]=true end
  end
 end end
 local seen,comps={}, {}
 for k0=0,255 do if lit[k0] and not seen[k0] then
  local comp,at={}, 1
  local queue={k0};seen[k0]=true
  while queue[at] do
   local k=queue[at];at=at+1;comp[#comp+1]=k
   local x,y=k%16,math.floor(k/16)
   for _,d in ipairs(D4)do
    local nx,ny=x+d[1],y+d[2];local nk=ny*16+nx
    if nx>=0 and nx<16 and ny>=0 and ny<16 and lit[nk] and not seen[nk] then seen[nk]=true;queue[#queue+1]=nk end
   end
  end
  if #comp>=STONE_MIN then comps[#comps+1]=comp end
 end end
 local claimed={}
 for _,comp in ipairs(comps)do for _,k in ipairs(comp)do claimed[k]=true end end
 local out={}
 for _,comp in ipairs(comps)do
  local own={}
  for _,k in ipairs(comp)do own[k]=true end
  for _,k in ipairs(comp)do -- one ring of shade round the lit top
   local x,y=k%16,math.floor(k/16)
   for _,d in ipairs(D4)do
    local nx,ny=x+d[1],y+d[2];local nk=ny*16+nx
    if nx>=0 and nx<16 and ny>=0 and ny<16 and solid[nk] and not claimed[nk] then claimed[nk]=true;own[nk]=true end
   end
  end
  out[#out+1]=own
 end
 return out
end
local function hullFor(c,uvFor,mask,stone)
 local uv=assert(uvFor(c.ts,c.mid))
 local function tex(x,y)
  return {uv[1][1]+(uv[2][1]-uv[1][1])*x/16,
   uv[1][2]+(uv[3][2]-uv[1][2])*y/16}
 end
 local slot=c.ts.midToSlot[c.mid]
 local px,py=slot%c.ts.cols*16,math.floor(slot/c.ts.cols)*16
 local minX,minY,maxX,maxY=16,16,-1,-1
 for y=0,15 do for x=0,15 do
  if mask[y*16+x]then
   if x<minX then minX=x end;if x+1>maxX then maxX=x+1 end
   if y<minY then minY=y end;if y+1>maxY then maxY=y+1 end
  end
 end end
 if maxX<minX or maxY<minY then return end
 local hw,hh=maxX-minX,maxY-minY
 local bottom=hh*.4 -- bury the lower 40% of the cropped stone
 local H=V.require('VoxelHull')
 local sample=function(x,y)
  local sx,sy=minX+x,minY+y
  local r,g,b,a=c.ts.imageData:getPixel(px+sx,py+sy)
  local uvx,uvy=unpack(tex(sx+.5,sy+.5))
  return r,g,b,mask[sy*16+sx]and a or 0,uvx,uvy
 end
 local card=V.require('TreePresentation').props:get()=='cards'
 local ox,oz=minX+hw/2,minY+hh/2
 if card then
  local hull=H.card(hw,hh,sample,bottom,c.shape.height or 16)
  return {hull=hull,ox=ox,oz=oz,card=true}
 end
 -- Build a 3D rounded voxel boulder with the lower 40% buried (60% above ground)
 -- and paint it with the stone's own non-outline palette tones.
 local samples={}
 local paints={}
 for sy=minY,maxY-1 do for sx=minX,maxX-1 do
  if mask[sy*16+sx] then
   local r,g,b,a=c.ts.imageData:getPixel(px+sx,py+sy)
   if (a or 1)>.5 then
    local k=math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)
    if not paints[k] then
     local uvx,uvy=unpack(tex(sx+.5,sy+.5))
     paints[k]={uvx,uvy}
    end
    local lum=.299*r+.587*g+.114*b
    if not stone or lum>=STONE_TONE then samples[#samples+1]={k=k,lum=lum} end
   end
  end
 end end
 if #samples==0 then return end
 table.sort(samples,function(a,b)return a.lum<b.lum end)
 local tones={}
 local startIdx=stone and 1 or math.max(1,math.floor(#samples*.35)+1)
 for i=startIdx,#samples do
  local k=samples[i].k
  if #tones==0 or tones[#tones]~=k then tones[#tones+1]=k end
 end
 if #tones==0 then tones[1]=samples[#samples].k end
 local rowL,rowR={},{}
 for z=0,hh-1 do
  local sy=minY+z
  local l,r=hw,-1
  for x=0,hw-1 do
   if mask[sy*16+(minX+x)] then
    if x<l then l=x end
    if x>r then r=x end
   end
  end
  rowL[z],rowR[z]=l,r
 end
 local ny=math.max(4,math.floor(hh*.6+.5))
 local rx,rz=math.max(1,hw/2),math.max(1,hh/2)
 local vox={}
 for y=0,ny-1 do
  local u=(y+.5)/ny
  local s=1.15*u-.15
  local scale=math.sqrt(math.max(0,1-s*s))
  for z=0,hh-1 do
   local l,r=rowL[z],rowR[z]
   if l<=r then
    local rcx,rrx=(l+r+1)/2,(r-l+1)/2
    local dz=(z+.5-hh/2)/rz
    for x=0,hw-1 do
     local dxRow=(x+.5-rcx)/math.max(1,rrx+.35)
     local dx=(x+.5-hw/2)/rx
     local rad2=math.max(dx*dx+dz*dz,dxRow*dxRow*.85+dz*dz*.85)
     if rad2<=scale*scale then
      local light=.52+.34*u-.26*dx-.18*dz
      local idx=math.max(1,math.min(#tones,math.floor(light*#tones)+1))
      vox[(y*hw+x)*hh+z]=tones[idx]
     end
    end
   end
  end
 end
 local hull={}
 local strides={hh,hw*hh,1}
 local limits={hw,ny,hh}
 for axis=1,3 do for _,sign in ipairs({-1,1})do
  local uaxis=axis%3+1;local vaxis=(axis+1)%3+1
  local sa,su,sv=strides[axis],strides[uaxis],strides[vaxis]
  local nw,nh=limits[uaxis],limits[vaxis]
  for plane=0,limits[axis]-1 do
   if not (axis==2 and sign<0 and plane==0) then
    local grid={}
    local inside=plane+sign>=0 and plane+sign<limits[axis]
    local across=sign*sa
    for v=0,nh-1 do local rowk=plane*sa+v*sv;for u=0,nw-1 do
     local k=rowk+u*su
     local col=vox[k]
     if col and not (inside and vox[k+across]) then grid[v*nw+u]=col end
    end end
    for v=0,nh-1 do for u=0,nw-1 do
     local col=grid[v*nw+u]
     if col then
      local ww,hh2=1,1
      while u+ww<nw and grid[v*nw+u+ww]==col do ww=ww+1 end
      while v+hh2<nh do
       local whole=true
       for du=0,ww-1 do if grid[(v+hh2)*nw+u+du]~=col then whole=false;break end end
       if not whole then break end;hh2=hh2+1
      end
      for dv=0,hh2-1 do for du=0,ww-1 do grid[(v+dv)*nw+u+du]=nil end end
      local q={u=paints[col][1],v=paints[col][2],shade=axis==2 and (sign>0 and 1 or .68) or axis==1 and .85 or .94}
      for _,uvc in ipairs({{u,v},{u+ww,v},{u+ww,v+hh2},{u,v+hh2}})do
       local p={}
       p[axis]=plane+(sign>0 and 1 or 0)
       p[uaxis]=uvc[1];p[vaxis]=uvc[2]
       p[1]=p[1]-hw/2;p[3]=p[3]-hh/2
       q[#q+1]=p
      end
      if sign<0 then q[2],q[4]=q[4],q[2] end
      hull[#hull+1]=q
     end
    end end
   end
  end
 end end
 return {hull=hull,ox=ox,oz=oz,card=false,scale=stone and 1 or nil}
end
local function rockHull(c,uvFor)
 local rows=c.shape.stoneMask
 local mask
 if rows then
  mask={}
  for y=0,15 do for x=0,15 do
   mask[y*16+x]=math.floor(rows[y+1]/2^x)%2==1
  end end
 else
  if c.shape.stones then
   local parts={}
   for _,m in ipairs(stoneMasks(c))do local p=hullFor(c,uvFor,m,true);if p then parts[#parts+1]=p end end
   if #parts>0 then return {parts=parts} end
  end
  mask=c.shape.floorTile and M.positionMask(c.ts,c.mid,c.shape.floorTile) or V.require('Gen3Outdoor').mask(c.ts,c.mid,c.shape.ground)
  if not mask then return end
  mask=boulderMask(mask)
 end
 return hullFor(c,uvFor,mask,false)
end
function M.rock(c,emit,uvFor)
 local card=V.require('TreePresentation').props:get()=='cards'
 local memo=rockMemo[c.ts];if not memo or memo.n>256 then memo={n=0};rockMemo[c.ts]=memo end
 local key=tostring(c.mid)..':'..tostring(c.shape.ground)..':'..tostring(c.shape.floorTile)..':'..tostring(card)..':'..tostring(c.shape.height)..':'..tostring(uvFor)
 local r=memo[key]
 if r==nil then r=rockHull(c,uvFor) or false;memo[key]=r;memo.n=memo.n+1 end
 if not r then return end
 for _,pr in ipairs(r.parts or {r})do
  local hull,ox,oz=pr.hull,pr.ox,pr.oz
  local scale=card and 1 or pr.scale or (c.shape.height or 16)/16
  for _,q in ipairs(hull)do
   local points={}
   for _,p in ipairs(q)do
    points[#points+1]={c.cx*16+ox+p[1],p[2]*scale,c.cy*16+oz+p[3]}
   end
   local uvs=q.uvs
   if not uvs then local t={q.u,q.v};uvs={t,t,t,t} end
   emit(points,uvs,q.shade,card and {c.cx*16+8,c.cy*16+8,.001} or nil)
  end
 end
end
M.UNDERWATER_FILL={[0x213]=true}
local function underwater(def)
 return tonumber(def and def.mapType)==5 and tostring(def.id or ''):find('^EM_UNDERWATER') and true or false
end
local lavaMemo=setmetatable({},{__mode='k'})
local function isLava(c)
 local ts=c.ts
 if not (ts and ts.imageData and ts.midToSlot and ts.midToSlot[c.mid]) then return false end
 local m=lavaMemo[ts];if not m then m={};lavaMemo[ts]=m end
 local v=m[c.mid]
 if v==nil then
  local slot=ts.midToSlot[c.mid]
  local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
  local rs,gs=0,0
  for y=0,15 do for x=0,15 do local r,g=ts.imageData:getPixel(ox+x,oy+y);rs=rs+r;gs=gs+g end end
  v=rs/256>.7 and gs/256<.32;m[c.mid]=v
 end
 return v
end
M.PIT={general__pacifidlog={[0x238]=1,[0x239]=1,[0x23A]=1,[0x240]=1,[0x241]=1,[0x242]=1,[0x248]=1,[0x249]=1,[0x24A]=1,[0x24B]=1,[0x24D]=1}}
M.BOULDER={general__pacifidlog={[0x207]=1,[0x20F]=1,[0x217]=1,[0x21F]=1}}
M.CAP={general__pacifidlog={[0x23C]=1}}
M.BOULDER_FLOOR={general__pacifidlog={[0x207]=0x235,[0x20F]=0x234,[0x217]=0x234,[0x21F]=0x234}}
M.UNDERWATER_MAXH=16
local baseMaxh
function M.settle(def,cells)
 local Rock=V.require('Gen3Rock')
 baseMaxh=baseMaxh or Rock.CAVE_MAXH
 Rock.CAVE_MAXH=underwater(def) and M.UNDERWATER_MAXH or baseMaxh
 for _,c in pairs(cells)do
  local k=c.shape and c.shape.kind
  if (k=='caveWall' or k=='cliff') and c.collision==7 and isLava(c) and not (c.prop or c.stairs or c.object or c.objectTop) then
   c.shape={kind='flat',ground=c.shape.ground,reviewedSurface=true};c.noFurniture=true;c.caveLava=true
  end
 end
 for _,c in pairs(cells)do
  local cap=M.CAP[c.pair]
  if cap and cap[c.mid] and c.shape and c.shape.kind=='caveWall' and c.collision==7 and not (c.prop or c.stairs or c.object or c.objectTop) then
   c.shape={kind='cliff',cap=c.mid,side=c.mid,ground=1,height=32}
  end
 end
 local done={}
 for _,c in pairs(cells)do
  if c.caveLava and not done[c] then
   local group,q={c},{c};done[c]=true
   local low=c.base or 0
   local i=1
   while q[i]do
    local a=q[i];i=i+1
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
     if n and n.caveLava and not done[n] then done[n]=true;group[#group+1]=n;q[#q+1]=n;low=math.min(low,n.base or 0) end
    end
   end
   for _,g in ipairs(group)do g.base=low end
  end
 end
 for _,c in pairs(cells)do
  local k=c.shape and c.shape.kind
  if (k=='caveWall' or k=='cliff' or k=='flat') and c.collision==7 and not (c.prop or c.stairs or c.object or c.objectTop) then
   local pit,boulder=M.PIT[c.pair],M.BOULDER[c.pair]
   if pit and pit[c.mid] then c.shape={kind='flat',ground=c.shape.ground,reviewedSurface=true};c.noFurniture=true
   elseif boulder and boulder[c.mid] then c.shape={kind='rock',ground=M.BOULDER_FLOOR[c.pair][c.mid],floorTile=M.BOULDER_FLOOR[c.pair][c.mid],height=14};c.noFurniture=true
    c.collision=43 end
  end
 end
 if underwater(def) then
  for _,c in pairs(cells)do
   local k=c.shape and c.shape.kind
   if k=='caveWall' and M.UNDERWATER_FILL[c.mid] and not (c.prop or c.stairs or c.object or c.objectTop) then
    c.shape={kind='flat',ground=c.shape.ground,reviewedSurface=true};c.noFurniture=true
   end
  end
 end
end
return M
