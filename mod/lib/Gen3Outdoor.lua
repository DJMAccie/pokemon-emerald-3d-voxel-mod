-- Reviewed General outdoor metatiles
local V=...
local M={}
M.LONG_H=14 -- long grass blade height (px)
M.SOLID_PLANTS=false
local Mask=V and V.require("SceneryMask") or assert(loadfile("lib/SceneryMask.lua"))()
local plants={[4]=1,[5]=1,[0xD]=1,[0x160]=1,[0x168]=1,[0x304]=0x2E5,[0x30C]=0x2E9}
local registered={}
local images={}
function M.registerPlant(pair,mid,ground)
 local t=registered[pair];if not t then t={};registered[pair]=t end
 if t[mid]~=ground then
  t[mid]=ground
  local old=images[pair];if old then old.image:release();images[pair]=nil end
 end
end
local tuftInfo,tufts
local function sub(uv,l,t,r,b)
 local function p(x,y)return {uv[1][1]+(uv[2][1]-uv[1][1])*x/16,uv[1][2]+(uv[3][2]-uv[1][2])*y/16}end
 return {p(l,t),p(r,t),p(r,b),p(l,b)}
end
local function pixel(ts,x,y)
 local r,g,b,a=ts.imageData:getPixel(x,y)
 if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(x,y)
  r,g,b,a=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa),aa+a*(1-aa)
 end
 return r,g,b,a
end
local function colorKey(r,g,b)return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)end
function M.mask(ts,mid,ground)
 local floor={}
 local any=false
 for _,g in ipairs(type(ground)=='table' and ground or {ground})do
  local slot=ts.midToSlot[g]
  if slot then
   any=true
   for y=0,15 do for x=0,15 do
    floor[colorKey(pixel(ts,slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y))]=true
   end end
  end
 end
 if not any then return end
 local at=ts.midToSlot[mid];if not at then return end
 return Mask.mask(16,function(x,y)
  local r,g,b,a=pixel(ts,at%ts.cols*16+x,math.floor(at/ts.cols)*16+y)
  return a==0 or floor[colorKey(r,g,b)]
 end)
end
M.HEDGE_HULL_MIN=100
M.HEDGE_JOIN=6 -- widest gap of ground, in pixels, that is filled between two hedges in one tile
local function solidPlant(c,emit,uv,anchor)
 local ts=c.ts
 local at=ts.midToSlot[c.mid];if not at then return 0 end
 local mask=M.mask(ts,c.mid,c.shape.ground)
 local ox,oy=at%ts.cols*16,math.floor(at/ts.cols)*16
 local tuft=c.shape.kind=='grass'
 local r0min=tuft and 4 or 0
 local g={}
 for r=0,15 do g[r]={};for px=0,15 do
  local _,_,_,a=pixel(ts,ox+px,oy+r)
  g[r][px]=(r>=r0min and a>.5 and (not mask or mask[r*16+px])) and true or false
 end end
 local function on(px,r)
  return px>=0 and px<=15 and r>=r0min and r<=15 and g[r][px]
 end
 local runs,active={},{}
 for px=0,15 do
  local segs,r={},r0min
  while r<=15 do
   if g[r][px] then
    local r1=r
    while r1+1<=15 and g[r1+1][px] do r1=r1+1 end
    segs[#segs+1]={r0=r,r1=r1};r=r1+1
   else r=r+1 end
  end
  local nxt={}
  for _,s in ipairs(segs)do
   local key=s.r0..':'..s.r1
   local run=active[key]
   if run and run.px1==px then run.px1=px+1 else run={px0=px,px1=px+1,r0=s.r0,r1=s.r1};runs[#runs+1]=run end
   nxt[key]=run
  end
  active=nxt
 end
 local x,zc=c.cx*16,c.cy*16+8
 local z0,z1=zc-2,zc+2
 local n=0
 local function quad(p,t,shade)n=n+1;emit(p,t,shade,anchor)end
 for _,run in ipairs(runs)do
  local a,b,t,u=run.px0,run.px1,run.r0,run.r1+1
  local x0,x1=x+a,x+b
  local y0,y1=15-run.r1,16-run.r0
  quad({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},sub(uv,a,t,b,u),1) -- front
  quad({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},sub(uv,b,t,a,u),.72) -- back, mirrored
  quad({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},sub(uv,a+.25,t,a+.75,u),.78) -- left side
  quad({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},sub(uv,b-.75,t,b-.25,u),.9) -- right side
  local px=a
  while px<b do
   if on(px,t-1) then px=px+1 else
    local e=px
    while e<b and not on(e,t-1) do e=e+1 end
    quad({{x+px,y1,z0},{x+e,y1,z0},{x+e,y1,z1},{x+px,y1,z1}},sub(uv,px,t+.25,e,t+.75),1)
    px=e
   end
  end
 end
 return n
end
function M.plant(c,emit,uv,uvFor,cells)
 local x,z=c.cx*16,c.cy*16
 if c.shape.kind=='shrub' and V.require('TreePresentation').props:get()=='modeled' then
  local mask=M.mask(c.ts,c.mid,c.shape.ground);local slot=c.ts.midToSlot[c.mid]
  if mask and c.shape.hedge then
   local floor,slotG={},c.ts.midToSlot[c.shape.ground]
   local img=c.ts.imageData
   if slotG then for y=0,15 do for x=0,15 do
    local r,g,b=img:getPixel(slotG%c.ts.cols*16+x,math.floor(slotG/c.ts.cols)*16+y);floor[colorKey(r,g,b)]=true
   end end end
   local n,at=0,c.ts.midToSlot[c.mid]
   if at then for y=0,15 do for x=0,15 do
    local r,g,b,a=img:getPixel(at%c.ts.cols*16+x,math.floor(at/c.ts.cols)*16+y)
    if a>.5 and not floor[colorKey(r,g,b)] then n=n+1 end
   end end end
   if n<M.HEDGE_HULL_MIN and V.require('Gen3Canopy').applies(c) then return true end
  end
  if mask and slot then
   local hedge=c.shape.hedge
   local join={}
   if hedge and cells then -- a narrow strip of ground between two hedges (also across a tile edge) is filled: one wall
    local function edgeRun(m,py,fromRight)
     local n=0
     for q=0,15 do
      local px=fromRight and 15-q or q
      if m[py*16+px] then return n end
      n=n+1
     end
     return 16
    end
    for _,side in ipairs({{-1,false},{1,true}})do
     local n=cells[(c.cx+side[1])..':'..c.cy]
     local nm=n and n.pair==c.pair and n.shape and n.shape.hedge and M.mask(n.ts,n.mid,n.shape.ground)
     if nm then for py=0,15 do
      local own,theirs=edgeRun(mask,py,side[2]),edgeRun(nm,py,not side[2])
      if own<16 and theirs<16 and own+theirs<=M.HEDGE_JOIN then
       local dir,first=side[2] and -1 or 1,side[2] and 15-own or own
       local best,lum=first,-1
       for k=0,8 do -- the leaf green of the hedge (the brightest pixel), not the pale rim of the art
        local sx=first+dir*k
        if sx>=0 and sx<=15 and mask[py*16+sx] then
         local r,g,b=pixel(c.ts,slot%c.ts.cols*16+sx,math.floor(slot/c.ts.cols)*16+py)
         if r+g+b>lum then lum,best=r+g+b,sx end
        end
       end
       for q=0,math.min(15,own+3) do local px=side[2] and 15-q or q;join[py*16+px]=best end -- the ground and the pale rim pixel at the edge
      end
     end end
    end
   end
   local faces=V.require('VoxelHull').build(16,16,function(px,py)
    local src=join[py*16+px] or px
    local r,g,b,a=pixel(c.ts,slot%c.ts.cols*16+src,math.floor(slot/c.ts.cols)*16+py)
    local t=sub(uv,src+.5,py+.5,src+.5,py+.5)[1]
    return r,g,b,(mask[py*16+px] or join[py*16+px]) and a or 0,t[1],t[2]
   end,1,0,hedge and 10 or nil,(not hedge) and 'bush' or nil,nil,nil,nil,hedge)
   for _,q in ipairs(faces)do
    local p={};for _,v in ipairs(q)do p[#p+1]={x+8+v[1],v[2],z+8+v[3]}end
    local t={q.u,q.v};emit(p,{t,t,t,t},q.shade)
   end
   return true
  end
 end
 if c.shape.kind=='grass' and (c.shape.height or 4)>=8 then
  emit({{x,.025,z},{x+16,.025,z},{x+16,.025,z+16},{x,.025,z+16}},uv,1)
  local L,T,R,B=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
  for k,zz in ipairs({3,7,11,15})do
   for px=0,15 do
    local hash=(c.cx*73+c.cy*151+px*37+k*19)%7
    local h=M.LONG_H-4+hash*.9-(k==1 and 0 or 0)
    local r0=math.max(0,16-h)
    local u0,u1=L+(R-L)*px/16,L+(R-L)*(px+1)/16
    local v0,v1=T+(B-T)*r0/16,B
    local xa=x+px+(k%2)*.5
    emit({{xa,h,z+zz},{xa+1,h,z+zz},{xa+1,0,z+zz},{xa,0,z+zz}},{{u0,v0},{u1,v0},{u1,v1},{u0,v1}},.78+.06*k)
   end
  end
  return true
 end
 M.registerPlant(c.ts.pair,c.mid,c.shape.ground)
 local h=c.shape.kind=='grass' and (c.shape.height or 4)*1.5 or 16
 local groundUv=((c.shape.ownGround or c.shape.kind=='grass') and uv) or (c.shape.groundMid and uvFor(c.ts,c.shape.groundMid)) or uvFor(c.ts,c.shape.ground) or uv
 local bladeUv=(not c.shape.ownGround and c.shape.groundMid and uvFor(c.ts,0x00D)) or uv
 if M.TUFTS and (c.shape.kind=='flowers' or c.shape.kind=='grass') and c.ts.midToSlot[c.mid] and c.ts.imageData then
  local info=tuftInfo(c.ts,c.mid,c.shape.ground)
  if info and tufts(c,emit,uv,groundUv,info) then return true end
 end
 if M.SOLID_PLANTS and (c.shape.kind=='flowers' or c.shape.kind=='grass') and c.ts.midToSlot[c.mid] then
  if c.shape.kind=='grass' then emit({{x,.025,z},{x+16,.025,z},{x+16,.025,z+16},{x,.025,z+16}},groundUv,1) end
  solidPlant(c,emit,uv,{x+8,z+8,.001})
  return true
 end
 if c.shape.kind=='grass' then
  emit({{x,.025,z},{x+16,.025,z},{x+16,.025,z+16},{x,.025,z+16}},groundUv,1)
  emit({{x+8,h,z},{x+8,h,z+16},{x+8,.001,z+16},{x+8,.001,z}},bladeUv,.92,{x+8,z+8,.001})
 end
 emit({{x,h,z+8},{x+16,h,z+8},{x+16,.001,z+8},{x,.001,z+8}},bladeUv,1,{x+8,z+8,.001})
 return true
end
local STANDS={sign=true,awning=true}
local function groupAwnings(cells)
 local seen={}
 for _,c in pairs(cells)do
  if c.shape and c.shape.kind=='awning' and not seen[c] then
   local members,stack={}, {c};seen[c]=true
   while #stack>0 do
    local p=table.remove(stack);members[#members+1]=p
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(p.cx+d[1])..':'..(p.cy+d[2])]
     if n and not seen[n] and n.pair==c.pair and n.shape and n.shape.kind=='awning' then seen[n]=true;stack[#stack+1]=n end
    end
   end
   local x0,y0,x1,y1=c.cx,c.cy,c.cx,c.cy
   for _,m in ipairs(members)do x0=math.min(x0,m.cx);y0=math.min(y0,m.cy);x1=math.max(x1,m.cx);y1=math.max(y1,m.cy) end
   local set={}
   for _,m in ipairs(members)do set[m.cx..':'..m.cy]=true end
   local comp={x0=x0*16,z0=y0*16,x1=(x1+1)*16,z1=(y1+1)*16,set=set}
   for _,m in ipairs(members)do m.awn=comp end
  end
 end
end
M.SIGN_POST_REPEAT=3
M.RISE=.5 -- height gained per unit of run toward the ridge
function M.groundProps(cells)
 groupAwnings(cells)
 local function vote(c,pass)
  local votes,best,top={},nil,0
  for dy=-1,1 do for dx=-1,1 do
   local n=(dx~=0 or dy~=0) and cells[(c.cx+dx)..':'..(c.cy+dy)]
   if n and n.pair==c.pair and n.shape and c.ts.midToSlot[n.mid] then
    local mid
    if pass==1 then
     if n.shape.kind=='flat' and n.collision==0 and not n.boundary then mid=n.mid end
    elseif n.shape.grounded then mid=n.shape.ground end
    if mid and c.ts.midToSlot[mid] then
     local v=(votes[mid] or 0)+((dx==0 or dy==0) and 2 or 1)
     votes[mid]=v
     if v>top then top,best=v,mid end
    end
   end
  end end
  return best
 end
 local pending={}
 for _,c in pairs(cells)do
  if c.shape and STANDS[c.shape.kind] and c.ts then
   local best=vote(c,1)
   if best then c.shape.ground=best;c.shape.grounded=true else pending[#pending+1]=c end
  end
 end
 for _=1,3 do
  local rest={}
  for _,c in ipairs(pending)do
   local best=vote(c,2)
   if best then c.shape.ground=best;c.shape.grounded=true else rest[#rest+1]=c end
  end
  pending=rest
 end
end
M.LEDGE_EXTRA=3
M.LEDGE_H=10 -- R-40: a level ledge rises this many px to the lip.
M.FACE_MAX=9
M.RUN_F=9
local ledgeSplit=setmetatable({},{__mode='k'})
local function isGreen(ts,ox,oy,x,y)
 local r,g,b,a=pixel(ts,ox+x,oy+y)
 return a<=.5 or (g>r*1.1 and g>b*1.05)
end
local function profile(ts,mid)
 local cache=ledgeSplit[ts];if not cache then cache={};ledgeSplit[ts]=cache end
 if cache[mid]~=nil then return cache[mid] or nil end
 local slot=ts.midToSlot[mid];if not slot then cache[mid]=false;return end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local cols,faceCols={}, 0
 for x=0,15 do
  local l=15
  while l>=0 and isGreen(ts,ox,oy,x,l) do l=l-1 end
  if l<0 then cols[x]={none=true}
  else
   local f=l
   while f-1>=0 and not isGreen(ts,ox,oy,x,f-1) and (l-f+1)<M.FACE_MAX do f=f-1 end
   cols[x]={f=f,l=l};faceCols=faceCols+1
  end
 end
 local function mode(key)
  local count,best,bn={},nil,0
  for x=0,15 do local v=cols[x][key];if v then count[v]=(count[v] or 0)+1;if count[v]>bn then best,bn=v,count[v] end end end
  return best
 end
 local mf,ml=mode('f'),mode('l')
 for x=0,15 do local c=cols[x]
  if c.f then
   if mf and math.abs(c.f-mf)<=1 then c.f=mf end
   if ml and math.abs(c.l-ml)<=1 then c.l=ml end
  end
 end
 for x=0,15 do local c=cols[x]
  if c.f and c.l>=14 and c.f>=5 and c.f<=9 then c.tf=c.f;c.f=M.RUN_F;c.l=15 end
 end
 if faceCols<5 then cache[mid]=false;return end
 for x=0,15 do local c=cols[x];if c.f and (c.l-c.f+1)<2 then c.f=nil;c.none=true end end
 cache[mid]=cols;return cols
end
M.SIDE_H=8
local sideBand=setmetatable({},{__mode='k'})
local function sideProfile(ts,mid)
 local cache=sideBand[ts];if not cache then cache={};sideBand[ts]=cache end
 if cache[mid]~=nil then return cache[mid] or nil end
 local slot=ts.midToSlot[mid];if not slot then cache[mid]=false;return end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local x0,x1
 for x=0,15 do
  local n=0
  for y=0,15 do if not isGreen(ts,ox,oy,x,y) then n=n+1 end end
  if n>=12 then x0=x0 or x;x1=x+1 elseif n>4 and x0 and not x1 then cache[mid]=false;return end
 end
 if not x0 or x1-x0>12 or x1-x0<2 then cache[mid]=false;return end
 local clean,rowMap,least,leastN={}, {},nil,99
 for y=0,15 do
  local n=0;for x=x0,x1-1 do if isGreen(ts,ox,oy,x,y) then n=n+1 end end
  clean[y]=n==0
  if n<leastN then least,leastN=y,n end
 end
 for y=0,15 do
  local best;for d=0,15 do if clean[y-d] then best=y-d;break elseif clean[y+d] then best=y+d;break end end
  rowMap[y]=best or least
 end
 cache[mid]={x0=x0,x1=x1,rowMap=rowMap};return cache[mid]
end
local function sideLedge(c,emit,uv)
 local east=c.behavior==0x38
 if not (east or c.behavior==0x39) then return false end
 local b=sideProfile(c.ts,c.mid);if not b then return false end
 local x,z=c.cx*16,c.cy*16
 local drop=c.floor and c.floor.ledgeLow and c.base and c.base-c.floor.ledgeLow
 local top=(drop and drop>.5) and 0 or M.SIDE_H
 local foot=(drop and drop>.5) and -drop or 0
 local a,e=x+b.x0,x+b.x1
 if top>0 then
  -- R-40: turf ramps up to the lip; the face drops on the jump side.
  local from,lip=east and x or x+16,east and e or a
  if east then
   if b.x1<16 then emit({{e,.01,z},{x+16,.01,z},{x+16,.01,z+16},{e,.01,z+16}},sub(uv,b.x1,0,16,16),1) end
   emit({{from,.01,z},{lip,top,z},{lip,top,z+16},{from,.01,z+16}},sub(uv,0,0,b.x1,16),1)
  else
   if b.x0>0 then emit({{x,.01,z},{a,.01,z},{a,.01,z+16},{x,.01,z+16}},sub(uv,0,0,b.x0,16),1) end
   emit({{lip,top,z},{from,.01,z},{from,.01,z+16},{lip,top,z+16}},sub(uv,b.x0,0,16,16),1)
  end
  local function face(xx,y0,y1,shade,westward)
   for r=0,15 do
    local cs=sub(uv,b.x0,b.rowMap[r],b.x1,b.rowMap[r]+1)
    local q={{cs[1][1],cs[1][2]},{cs[1][1],cs[4][2]},{cs[2][1],cs[3][2]},{cs[2][1],cs[2][2]}}
    local zs,ze=z+r,z+r+1
    if westward then emit({{xx,y1,zs},{xx,y1,ze},{xx,y0,ze},{xx,y0,zs}},{q[1],q[2],q[3],q[4]},shade)
    else emit({{xx,y1,ze},{xx,y1,zs},{xx,y0,zs},{xx,y0,ze}},{q[2],q[1],q[4],q[3]},shade) end
   end
  end
  face(lip,0,top,east and .74 or .7,not east)
  local band=sub(uv,b.x0,0,b.x1,1)
  if east then
   emit({{from,.01,z+16},{lip,top,z+16},{lip,0,z+16},{from,0,z+16}},band,.84)
   emit({{lip,top,z},{from,.01,z},{from,0,z},{lip,0,z}},band,.62)
  else
   emit({{lip,top,z+16},{from,.01,z+16},{from,0,z+16},{lip,0,z+16}},band,.84)
   emit({{from,.01,z},{lip,top,z},{lip,0,z},{from,0,z}},band,.62)
  end
  return true
 end
 if b.x0>0 then emit({{x,.01+(east and 0 or foot),z},{a,.01+(east and 0 or foot),z},{a,.01+(east and 0 or foot),z+16},{x,.01+(east and 0 or foot),z+16}},sub(uv,0,0,b.x0,16),1) end
 if b.x1<16 then emit({{e,.01+(east and foot or 0),z},{x+16,.01+(east and foot or 0),z},{x+16,.01+(east and foot or 0),z+16},{e,.01+(east and foot or 0),z+16}},sub(uv,b.x1,0,16,16),1) end
 emit({{a,top,z},{e,top,z},{e,top,z+16},{a,top,z+16}},sub(uv,b.x0,0,b.x1,16),1)
 local function face(xx,y0,y1,shade,westward)
  if y1-y0<.01 then return end
  for r=0,15 do
   local cs=sub(uv,b.x0,b.rowMap[r],b.x1,b.rowMap[r]+1)
   local q={{cs[1][1],cs[1][2]},{cs[1][1],cs[4][2]},{cs[2][1],cs[3][2]},{cs[2][1],cs[2][2]}}
   local zs,ze=z+r,z+r+1
   if westward then emit({{xx,y1,zs},{xx,y1,ze},{xx,y0,ze},{xx,y0,zs}},{q[1],q[2],q[3],q[4]},shade)
   else emit({{xx,y1,ze},{xx,y1,zs},{xx,y0,zs},{xx,y0,ze}},{q[2],q[1],q[4],q[3]},shade) end
  end
 end
 if east then face(e,foot,top,.74,false);face(a,0,top,.7,true)
 else face(a,foot,top,.7,true);face(e,0,top,.74,false) end
 local band=sub(uv,b.x0,0,b.x1,1)
 emit({{a,top,z+16},{e,top,z+16},{e,math.min(0,foot),z+16},{a,math.min(0,foot),z+16}},band,.84)
 emit({{e,top,z},{a,top,z},{a,math.min(0,foot),z},{e,math.min(0,foot),z}},band,.62)
 return true
end
function M.ownsFaces(c)
 local drop=c.floor and c.floor.ledgeLow and c.base and c.base-c.floor.ledgeLow
 if not (drop and drop>.5) or c.stageHidden then return false end
 if c.shape and c.shape.side then
  return (c.behavior==0x38 or c.behavior==0x39) and sideProfile(c.ts,c.mid) and true or false
 end
 return profile(c.ts,c.mid) and true or false
end
function M.ledgeFloor(c,emit,ground)
 local drop=c.floor and c.floor.ledgeLow and c.base and c.base-c.floor.ledgeLow
 if not (drop and drop>.5) or c.stageHidden then return false end
 if c.shape and c.shape.side then
  return (c.behavior==0x38 or c.behavior==0x39) and sideProfile(c.ts,c.mid) and true or false
 end
 local cols=profile(c.ts,c.mid);if not cols then return false end
 local x,z=c.cx*16,c.cy*16
 local x0,d0
 for cx=0,16 do
  local p=cols[cx]
  local d=p and not p.none and p.l+1-math.max(p.f,1) or 0
  if d~=d0 then
   if d0 and d0>0 then emit({{x+x0,0,z},{x+cx,0,z},{x+cx,0,z+d0},{x+x0,0,z+d0}},sub(ground,x0,0,cx,d0),1) end
   x0,d0=cx,d
  end
 end
 return true
end
function M.ledge(c,emit,uv)
 if c.shape and c.shape.side then
  if not sideLedge(c,emit,uv) then local x,z=c.cx*16,c.cy*16;emit({{x,.01,z},{x+16,.01,z},{x+16,.01,z+16},{x,.01,z+16}},uv,1) end
  return true
 end
 local cols=profile(c.ts,c.mid);if not cols then return false end
 local x,z=c.cx*16,c.cy*16
 local E=M.LEDGE_EXTRA
 local strips={}
 for cx=0,15 do
  local p=cols[cx]
  local key=p.none and 'none' or (p.f..':'..p.l..':'..(p.tf or p.f))
  local last=strips[#strips]
  if last and last.key==key then last.x1=cx+1 else strips[#strips+1]={key=key,x0=cx,x1=cx+1,p=p} end
 end
 local function band(x0,x1,zz,y0,y1,r0,r1,shade,flip)
  local q=sub(uv,x0,r0,x1,r1)
  if flip then emit({{x+x1,y1,zz},{x+x0,y1,zz},{x+x0,y0,zz},{x+x1,y0,zz}},q,shade)
  else emit({{x+x0,y1,zz},{x+x1,y1,zz},{x+x1,y0,zz},{x+x0,y0,zz}},q,shade) end
 end
 for _,st in ipairs(strips)do
  local p=st.p
  if p.none then
   emit({{x+st.x0,.01,z},{x+st.x1,.01,z},{x+st.x1,.01,z+16},{x+st.x0,.01,z+16}},sub(uv,st.x0,0,st.x1,16),1)
  else
   local rows=p.l-p.f+1
   local H=rows+E
   local zf=z+p.l+1 -- front of the wall
   local zb=zf-math.max(p.f,1) -- back of the top
   local dropF=c.floor and c.floor.ledgeLow and c.base and c.base-c.floor.ledgeLow
   local gy=(dropF and dropF>.5) and .01-dropF or .01
   if p.l<15 then emit({{x+st.x0,gy,zf},{x+st.x1,gy,zf},{x+st.x1,gy,z+16},{x+st.x0,gy,z+16}},sub(uv,st.x0,p.l+1,st.x1,16),1) end
   local rep=p.f+1
   if rep>p.l then rep=p.l end
   local drop=c.floor and c.floor.ledgeLow and c.base and c.base-c.floor.ledgeLow
   local r0=math.min(p.f+2,p.l)
   local wedge
   if drop and drop>.5 then
    H=0
    local lip=r0-p.f
    if drop>=lip+3 and p.l-r0>=2 then
     band(st.x0,st.x1,zf,-lip,0,math.min(r0+1,p.l-lip+1),math.min(r0+1,p.l-lip+1)+lip,1,false)
     band(st.x0,st.x1,zf,-drop,-drop+1,p.l,p.l+1,.9,false)
     local y=-lip
     while y>-drop+1.01 do
      local h=math.min(p.l-r0,y-(-drop+1))
      band(st.x0,st.x1,zf,y-h,y,r0,r0+h,1,false)
      y=y-h
     end
    else
     band(st.x0,st.x1,zf,-drop,0,r0,p.l+1,1,false)
    end
   else
   -- R-40: one gentle slope to the lip, a short steep face on the jump side.
   wedge=math.max(1.5,M.LEDGE_H*(p.l+1)/16)
   band(st.x0,st.x1,zf,0,wedge,p.f,p.l+1,1,false)
   end
   local tx0,tx1=st.x0,st.x1
   if c.shape and c.shape.right and tx1>8 then tx0,tx1=0,math.min(8,tx1-st.x0)
   elseif c.shape and c.shape.left and tx0<8 then tx0,tx1=math.max(8,16-(tx1-st.x0)),16 end
   if wedge then
    emit({{x+st.x0,.01,z},{x+st.x1,.01,z},{x+st.x1,wedge,zf},{x+st.x0,wedge,zf}},sub(uv,tx0,0,tx1,math.min(p.tf or p.f,6)),1)
   elseif p.f>0 then emit({{x+st.x0,H,zb},{x+st.x1,H,zb},{x+st.x1,H,zf},{x+st.x0,H,zf}},sub(uv,tx0,0,tx1,math.min(p.tf or p.f,6)),1) end
   local cap=sub(uv,st.x0,p.f,st.x0+1,p.f+1)
   if wedge then
    emit({{x+st.x0,.01,z},{x+st.x0,wedge,zf},{x+st.x0,0,zf},{x+st.x0,0,z}},cap,.8)
    emit({{x+st.x1,wedge,zf},{x+st.x1,.01,z},{x+st.x1,0,z},{x+st.x1,0,zf}},cap,.9)
   else
    local yb=-drop
    local sideTex=sub(uv,0,r0,16,p.l+1)
    emit({{x+st.x0,H,z},{x+st.x0,H,zf},{x+st.x0,yb,zf},{x+st.x0,yb,z}},sideTex,.8)
    emit({{x+st.x1,H,zf},{x+st.x1,H,z},{x+st.x1,yb,z},{x+st.x1,yb,zf}},sideTex,.9)
   end
  end
 end
 return true
end
M.TUFTS=true
M.TUFT_H=2
local tuftCache=setmetatable({},{__mode='k'})
local function hsh(a,b,c)local n=math.sin(a*12.9898+b*78.233+c*37.719)*43758.5453;return n-math.floor(n)end
function tuftInfo(ts,mid,ground)
 local cache=tuftCache[ts];if not cache then cache={};tuftCache[ts]=cache end
 local k=mid..':'..tostring(ground)
 if cache[k]~=nil then return cache[k] end
 local mask=M.mask(ts,mid,ground)
 local at=ts.midToSlot[mid]
 if not mask or not at then cache[k]=false;return false end
 local ox,oy=at%ts.cols*16,math.floor(at/ts.cols)*16
 local px,green={}, {}
 for y=0,15 do for x=0,15 do
  if mask[y*16+x] then
   local r,g,b=pixel(ts,ox+x,oy+y)
   px[y*16+x]={r,g,b,.3*r+.59*g+.11*b}
   green[y*16+x]=g>r*1.05 and g>b*1.05 and g-math.min(r,b)>.22 and .3*r+.59*g+.11*b<.66
  end
 end end
 local best,bd
 for y=0,14 do for x=0,15 do
  local a,b=px[y*16+x],px[(y+1)*16+x]
  local steady=x>0 and x<15 and green[y*16+x-1] and green[y*16+x+1] and green[(y+1)*16+x-1] and green[(y+1)*16+x+1]
  if a and b and green[y*16+x] and green[(y+1)*16+x] and a[4]-b[4]>.04 and (steady or not bd or bd<0) then
   if steady then a={a[1],a[2],a[3],a[4]+1} end
   local d=a[4]-b[4];if not bd or d>bd then best,bd={x,y},d end
  end
 end end
 local any
 if not best then for y=0,15 do for x=0,15 do if green[y*16+x] and not any then any={x,y} end end end end
 local seen,flowers={}, {}
 for y=0,15 do for x=0,15 do
  local i=y*16+x
  if px[i] and not green[i] and not seen[i] then
   local stack,n,x0,y0,x1,y1={i},0,x,y,x,y;seen[i]=true
   while #stack>0 do
    local q=table.remove(stack);n=n+1
    local qx,qy=q%16,math.floor(q/16)
    x0,y0,x1,y1=math.min(x0,qx),math.min(y0,qy),math.max(x1,qx),math.max(y1,qy)
    for dy=-1,1 do for dx=-1,1 do
     local nx,ny=qx+dx,qy+dy;local j=ny*16+nx
     if nx>=0 and ny>=0 and nx<16 and ny<16 and px[j] and not green[j] and not seen[j] then seen[j]=true;stack[#stack+1]=j end
    end end
   end
   if n>=6 and x1-x0<10 and y1-y0<10 then flowers[#flowers+1]={math.max(0,x0-1),y0,math.min(16,x1+2),y1+1} end
  end
 end end
 local info={blade=best,plain=any,flowers=flowers}
 if not (best or any) then info=false end
 cache[k]=info;return info
end
local function blades(emit,uv,info,bx,bz,n,H,W,seed)
 local t
 if info.blade then t=sub(uv,info.blade[1]+.2,info.blade[2]+.1,info.blade[1]+.8,info.blade[2]+1.9)
 else t=sub(uv,info.plain[1]+.2,info.plain[2]+.2,info.plain[1]+.8,info.plain[2]+.8) end
 for i=1,n do
  local a=(i+hsh(seed,i,1))*2*math.pi/n
  local dx,dz=math.cos(a),math.sin(a)
  local lean=(i==1 and .4 or 1.4+2.2*hsh(seed,i,2))*H/8
  local h=H*(i==1 and 1.15 or .65+.45*hsh(seed,i,3))
  local w=W*(.8+.4*hsh(seed,i,4))
  local fx,fz=bx+dx*.6,bz+dz*.6
  local tx,tz=fx+dx*lean,fz+dz*lean
  emit({{tx+dz*.25,h,tz-dx*.25},{tx-dz*.25,h,tz+dx*.25},{fx-dz*w/2,.03,fz+dx*w/2},{fx+dz*w/2,.03,fz-dx*w/2}},t,.82+.18*hsh(seed,i,5),{bx,bz,.001})
 end
end
function tufts(c,emit,uv,groundUv,info)
 local x,z=c.cx*16,c.cy*16
 if c.shape.kind=='grass' then
  if (c.shape.height or 4)>=8 then return false end
  emit({{x,.025,z},{x+16,.025,z},{x+16,.025,z+16},{x,.025,z+16}},groundUv,1)
  local H=(c.shape.height or 4)*M.TUFT_H
  for k,p in ipairs({{3,3},{11,4},{7,8.5},{3,13},{12,12.5}})do
   local seed=c.cx*73+c.cy*139+k*17
   blades(emit,uv,info,x+p[1]+3*hsh(seed,1,9)-1.5,z+p[2]+3*hsh(seed,2,9)-1.5,5,H,2.6,seed)
  end
  return true
 end
 if #info.flowers==0 then return false end
 for k,p in ipairs({{4,5},{12,6},{8,12}})do
  blades(emit,uv,info,x+p[1],z+p[2],4,4.5,3.2,c.cx*31+c.cy*57+k*13)
 end
 local stem=info.blade and sub(uv,info.blade[1]+.3,info.blade[2]+1.2,info.blade[1]+.7,info.blade[2]+1.8) or sub(uv,info.plain[1]+.3,info.plain[2]+.3,info.plain[1]+.7,info.plain[2]+.7)
 for k,f in ipairs(info.flowers)do
  local w,d=f[3]-f[1],f[4]-f[2]
  local xc,zc=x+(f[1]+f[3])/2,z+(f[2]+f[4])/2
  local hs=5+2.5*hsh(c.cx,c.cy,k)
  local t=sub(uv,f[1],f[2],f[3],f[4])
  local an={xc,zc,.001}
  emit({{xc-.5,hs,zc},{xc+.5,hs,zc},{xc+.5,.03,zc},{xc-.5,.03,zc}},stem,.8,an)
  emit({{xc,hs,zc-.5},{xc,hs,zc+.5},{xc,.03,zc+.5},{xc,.03,zc-.5}},stem,.7,an)
  emit({{xc-w/2,hs+1.5,zc-d/2},{xc+w/2,hs+1.5,zc-d/2},{xc+w/2,hs-.5,zc+d/2},{xc-w/2,hs-.5,zc+d/2}},t,1,an)
  emit({{xc-w/2,hs+d/2,zc},{xc+w/2,hs+d/2,zc},{xc+w/2,hs-d/2,zc},{xc-w/2,hs-d/2,zc}},t,.95,an)
  emit({{xc,hs+d/2,zc-w/2},{xc,hs+d/2,zc+w/2},{xc,hs-d/2,zc+w/2},{xc,hs-d/2,zc-w/2}},t,.88,an)
 end
 return true
end
function M.append(c,emit,uvFor,cells)
 local s,x,z=c.shape,c.cx*16,c.cy*16
 local uv=assert(uvFor(c.ts,c.mid))
 local function box(x0,y0,z0,x1,y1,z1,tex,frontTex)
  emit({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},tex,1)
  emit({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},frontTex or tex,frontTex and 1 or .85)
  emit({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},tex,.72)
  emit({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},tex,.78)
  emit({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},tex,.9)
 end
 if s.kind=='sign' then
  local function R(l,t,r,b)return sub(uv,l,t,r,b)end
  local function sbox(x0,y0,z0,x1,y1,z1,front,back,side,top)
   emit({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},front,1) -- south: the drawing
   emit({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},back or front,.72) -- north: same art
   emit({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},side,.78)
   emit({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},side,.9)
   if top then emit({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},top,1) end
  end
  local function stack(x0,x1,z0,z1,y,l,t,r,b,times,side,top)
   for i=0,times-1 do
    local y0=y+i*(b-t+1);local y1=y0+(b-t+1)
    sbox(x0,y0,z0,x1,y1,z1,R(l,t,r,b+1),nil,side,i==times-1 and top or nil)
   end
   return y+times*(b-t+1)
  end
  local mid=c.mid
  local n=M.SIGN_POST_REPEAT
  if mid==0x01B then
   local y=stack(x+3,x+12,z+5.5,z+10.5,0,3,13,12,15,1,R(4,14,5,15))
   y=stack(x+6,x+9,z+6.5,z+9.5,y,6,11,9,12,n,R(6,11,7,12))
   sbox(x+0,y,z+6,x+15,y+10,z+10,R(0,1,15,11),nil,R(0,5,1,6),R(2,2,3,3))
  elseif mid==0x131 then
   local y=stack(x+3,x+14,z+5.5,z+10.5,0,3,12,14,15,1,R(5,13,6,14))
   y=stack(x+5,x+12,z+6,z+10,y,5,11,12,11,n*2,R(6,11,7,12))
   sbox(x+1,y,z+6,x+16,y+11,z+10,R(1,0,16,11),nil,R(1,4,2,5),R(3,0,4,1))
  else
   sbox(x+0,0,z+6,x+16,15,z+10,R(0,0,16,15),nil,R(15,6,16,7),R(1,1,2,2))
  end
 elseif s.kind=='fence' then
  local vertical=s.axis and not s.turn
  local post=uvFor(c.ts,s.material or (s.wood and 0xE6 or 0xE7)) or uv
  local face,cap=sub(post,3,6,6,14),sub(post,3,3,6,6)
  local rail=sub(post,3,9,5,11)
  local function stake(px,pz)
   box(px-1.4,0,pz-1.4,px+1.4,10,pz+1.4,face)
   box(px-1.5,10,pz-1.5,px+1.5,10.6,pz+1.5,cap)
  end
  if vertical then
   for _,dz in ipairs(s.stop and {8} or {4,12})do stake(x+s.axis,z+dz)end
   for _,h in ipairs({3,7})do box(x+s.axis-.6,h,z,x+s.axis+.6,h+1,z+(s.stop and 8 or 16),rail)end
  else
   for _,dx in ipairs({4,12})do stake(x+dx,z+8)end
   for _,h in ipairs({3,7})do
    box(x,h,z+7.4,x+16,h+1,z+8.6,rail)
    if s.turn then box(x+s.axis-.6,h,z+(s.turn=='north' and 0 or 8),x+s.axis+.6,h+1,z+(s.turn=='north' and 8 or 16),rail)end
   end
  end
 elseif s.kind=='ledge' then
  if not M.ledge(c,emit,uv) then
  emit({{x,.01,z},{x+16,.01,z},{x+16,.01,z+6},{x,.01,z+6}},sub(uv,0,0,16,4),1)
  local RIDGE=5
  local function height(u,v)
   local endScale=(s.left and math.min(1,u/5) or s.right and math.min(1,(16-u)/5) or 1)
   return RIDGE*math.sin(math.min(1,math.max(0,(v-6)/10))*math.pi*.5)*endScale
  end
  for ix=0,3 do for iz=0,3 do
   local a,b=ix*4,(ix+1)*4;local p,q=6+iz*2.5,6+(iz+1)*2.5
   emit({{x+a,height(a,p),z+p},{x+b,height(b,p),z+p},{x+b,height(b,q),z+q},{x+a,height(a,q),z+q}},sub(uv,a,4+(p-6)*.6,b,4+(q-6)*.6),1)
  end end
  for ix=0,3 do local a,b=ix*4,(ix+1)*4
   emit({{x+a,height(a,16),z+16},{x+b,height(b,16),z+16},{x+b,0,z+16},{x+a,0,z+16}},sub(uv,a,10,b,16),.85)
  end
  for _,u in ipairs({0,16})do
   emit({{x+u,0,z+6},{x+u,height(u,16),z+16},{x+u,0,z+16},{x+u,0,z+6}},sub(uv,2,10,5,16),.8)
  end
  end
 elseif s.kind=='awning' then
  local h=s.height or 12
  local a=c.awn
  if a then
   local cap=math.min(M.RISE*math.min(a.x1-a.x0,a.z1-a.z0)/2,2.5)
   local function H(px,pz)
    local run=math.min(px-a.x0,a.x1-px,pz-a.z0,a.z1-pz)
    return h+math.min(cap,M.RISE*run)
   end
   for iz=0,3 do for ix=0,3 do
    local l,t=ix*4,iz*4;local r,b=l+4,t+4
    local h1,h2,h3,h4=H(x+l,z+t),H(x+r,z+t),H(x+r,z+b),H(x+l,z+b)
    emit({{x+l,h1,z+t},{x+r,h2,z+t},{x+r,h3,z+b},{x+l,h4,z+b}},sub(uv,l,t,r,b),1)
   end end
   local south=not a.set[c.cx..':'..(c.cy+1)]
   local north=not a.set[c.cx..':'..(c.cy-1)]
   if south then emit({{x,h,z+16},{x+16,h,z+16},{x+16,h-3,z+16},{x,h-3,z+16}},sub(uv,0,13,16,16),.82) end
   if north then emit({{x+16,h,z},{x,h,z},{x,h-3,z},{x+16,h-3,z}},sub(uv,0,0,16,3),.7) end
   if c.cx*16==a.x0 and c.cy*16==a.z0 then
    local f=sub(uv,1,1,2,2)
    local t={f[1],f[1],f[1],f[1]}
    local function post(px,pz)
     local e=2
     emit({{px,h-1,pz},{px+e,h-1,pz},{px+e,h-1,pz+e},{px,h-1,pz+e}},t,1)
     emit({{px,0,pz+e},{px+e,0,pz+e},{px+e,h-1,pz+e},{px,h-1,pz+e}},t,.88)
     emit({{px+e,0,pz},{px,0,pz},{px,h-1,pz},{px+e,h-1,pz}},t,.66)
     emit({{px+e,0,pz+e},{px+e,0,pz},{px+e,h-1,pz},{px+e,h-1,pz+e}},t,.8)
     emit({{px,0,pz},{px,0,pz+e},{px,h-1,pz+e},{px,h-1,pz}},t,.74)
    end
    post(a.x0+2,a.z0+2);post(a.x1-4,a.z0+2)
    post(a.x0+2,a.z1-4);post(a.x1-4,a.z1-4)
   end
  else
   emit({{x,h,z},{x+16,h,z},{x+16,h,z+16},{x,h,z+16}},uv,1)
   emit({{x,h,z+16},{x+16,h,z+16},{x+16,h-3,z+16},{x,h-3,z+16}},sub(uv,0,13,16,16),.82)
   emit({{x+16,h,z},{x,h,z},{x,h-3,z},{x+16,h-3,z}},sub(uv,0,0,16,3),.7)
  end
 elseif s.kind=='flowers' or s.kind=='grass' or s.kind=='shrub' then
  M.plant(c,emit,uv,uvFor,cells)
 end
end
-- Never ship or read private imported pixels.
function M.image(ts,frame)
 local old=images[ts.pair];if old and old.ts==ts and old.frame==frame then return old.image end
 if not ts.imageData then return end
 local data=ts.imageData:clone()
 local masks={}
 for k,v in pairs(plants)do masks[k]=v end
 for mid,ground in pairs(registered[ts.pair] or {})do masks[mid]=ground end
 for mid,ground in pairs(masks)do
  local mask=M.mask(ts,mid,ground)
  local at=ts.midToSlot[mid]
  if mask and at then for y=0,15 do for x=0,15 do
   local px,py=at%ts.cols*16+x,math.floor(at/ts.cols)*16+y
   local r,g,b,a=pixel(ts,px,py)
   if not mask[y*16+x]then a=0 end
   data:setPixel(px,py,r,g,b,a)
  end end end
 end
 local img=love.graphics.newImage(data);img:setFilter('nearest','nearest');data:release()
 if old then old.image:release()end;images[ts.pair]={ts=ts,image=img,frame=frame};return img
end
function M.release()
 for _,p in pairs(images)do p.image:release()end;images={}
end
return M
