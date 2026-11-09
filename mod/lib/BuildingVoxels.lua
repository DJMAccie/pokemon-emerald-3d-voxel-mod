-- BuildingVoxels
local V=...
local Budget=V.require('BuildBudget')
local FlatMesh=V.require('FlatMesh')
local Dome=V.require('BuildingDome')
local M={}
M.REPAINT_GROUND=8
M.REPAINT_SHARE=.05

M.MODELS={'frontier_gate','ferry_birth_island','ferry_navel_rock','trainer_hill_penthouse','abandoned_ship_wreck','littleroot_house_brendan','littleroot_house_may','birch_lab','devon_corp','lilycove_museum','weather_institute','fortree_treehouse','sootopolis_cone','sootopolis_box','sootopolis_box2','pacifidlog_hut','pokemon_center','poke_mart'}
M.FAMILY={pokemon_center=true,poke_mart=true,fortree_treehouse=true,sootopolis_cone=true,sootopolis_box=true,sootopolis_box2=true,pacifidlog_hut=true}
-- Door and window variants of a house share its roof row: match that row only, and take the facade art from the map cells.
M.LOOSE={sootopolis_cone=true,sootopolis_box=true,sootopolis_box2=true}
do
 local ok,idx=pcall(V.data,'buildings/index')
 if ok and type(idx)=='table' then for _,n in ipairs(idx)do M.MODELS[#M.MODELS+1]=n end end
end
-- The export only holds the facade rows; the roof rows above it stay map tiles lying on the ground.
-- rows = extra tile rows above the model (their art becomes the roof on top of the box, no stretch),
-- n = copies of the side walls behind the front slice (back wall ends at the top row), top = height of the roof plane;
-- the roof art repeats over the whole top.
M.DEEPEN={b055_lilycovecity_harbor={rows=3,n=5,top=32}}
-- Taller than the export: repeat the wall band hB..hA n more times and lift everything above it (gym roofs).
local GYM_RAISE={hB=27,hA=29,n=1}
M.RAISE={b003_petalburgcity_gym=GYM_RAISE,b017_mauvillecity_gym=GYM_RAISE,b024_rustborocity_gym=GYM_RAISE,
 b037_fortreecity_gym=GYM_RAISE,b057_mossdeepcity_gym=GYM_RAISE,b068_sootopoliscity_gym=GYM_RAISE,
 b089_dewfordtown_gym={hB=21,hA=23,n=1},b093_lavaridgetown_gym=GYM_RAISE}
local SHADE={0.90,0.68,1.00,0.84,0.72} -- south, north, top, east, west

local unpack=unpack or table.unpack
local function raise(q,r)
 local out,P,n={},r.hA-r.hB,0
 local function put(i,a,b)
  for j=0,9 do out[n+1+j]=q[i+j] end
  out[n+4]=a;out[n+5]=b;n=n+10
 end
 for i=1,#q,10 do
  local h0,h1=q[i+3],q[i+4]
  if q[i]==3 then put(i,h0>=r.hA and h0+r.n*P or h0,h1>=r.hA and h1+r.n*P or h1)
  elseif h0>=r.hA then put(i,h0+r.n*P,h1+r.n*P)
  elseif h1<=r.hB then put(i,h0,h1)
  else
   if h0<r.hB then put(i,h0,r.hB) end
   local a,b=math.max(h0,r.hB),math.min(h1,r.hA)
   if a<b then for k=0,r.n do put(i,a+k*P,b+k*P) end end
   if h1>r.hA then put(i,r.hA+r.n*P,h1+r.n*P) end
  end
 end
 return out
end

local function deepen(m,d)
 local out,sh,q={},d.rows*16,m.quads
 local wpx=(m.x1-m.x0+1)*16
 local function put(f,xa,xb,h0,h1,za,zb,px,py,shade)
  local n=#out
  out[n+1],out[n+2],out[n+3],out[n+4],out[n+5],out[n+6],out[n+7],out[n+8],out[n+9],out[n+10]=f,xa,xb,h0,h1,za,zb,px,py,shade
 end
 local back0=0
 for i=1,#q,10 do if q[i]==2 then back0=math.min(back0,q[i+5]) end end
 for i=1,#q,10 do
  local f,xa,xb,h0,h1,za,zb,px,py,shade=unpack(q,i,i+9)
  if h0<d.top then
   py=py+sh
   if f==2 then put(f,xa,xb,h0,h1,za-d.n*(-back0),zb-d.n*(-back0),px,py,shade)
   elseif f==1 then put(f,xa,xb,h0,h1,za,zb,px,py,shade)
   elseif f>=4 then
    put(f,xa,xb,h0,h1,za,zb,px,py,shade)
    if za<0 then for r=1,d.n do put(f,xa,xb,h0,h1,za+r*back0,zb+r*back0,px,py,shade) end end
   end
  end
 end
 local zr=back0*(d.n+1)
 for z=zr,-1 do for x=0,wpx-1 do put(3,x,x+1,d.top,d.top,z,z+1,x,(z-zr)%sh,0) end end
 return out
end

local loaded={}
-- Vertex lists are a pool: a build that yields mid-mesh never shares one.
local pool={}
local function model(name)
 if loaded[name]==nil then
  local ok,m=pcall(V.data,'buildings/'..name)
  loaded[name]=ok and type(m)=='table' and m or false
  local d=loaded[name] and M.DEEPEN[name]
  if d then m.quads=deepen(m,d);m.y0=m.y0-d.rows end
  if loaded[name] then m.quads=V.require('BuildingRoof').build(m) end
 end
 return loaded[name] or nil
end

function M.prepare(cells,def,claim)
 local out={}
 local mapId=def and def.id
 local indoorMap=def and tonumber(def.mapType)==8
 for _,name in ipairs(M.MODELS)do
  local m=model(name)
  if indoorMap and not (m and m.indoor and m.map==mapId) then m=nil end
  local anchor=m and m.anchor or {}
  if m and M.FAMILY[name] then
   if M.LOOSE[name] then
    local top=math.huge
    for _,a in ipairs(anchor)do top=math.min(top,a[2])end
    local row={}
    for _,a in ipairs(anchor)do if a[2]==top then row[#row+1]=a end end
    anchor=row
   else
    local lo,hi=math.huge,-math.huge
    for _,a in ipairs(anchor)do lo=math.min(lo,a[1]);hi=math.max(hi,a[1])end
    local inner={}
    for _,a in ipairs(anchor)do if a[1]>lo and a[1]<hi then inner[#inner+1]=a end end
    if #inner>=2 then anchor=inner end
   end
  end
  local function matches(dx,dy)
   for _,a in ipairs(anchor)do
    local c=cells[(a[1]+dx)..':'..(a[2]+dy)]
    if not (c and c.mid==a[3] and not c.bldModel) then return false end
    local pair=c.pair or (c.ts and c.ts.pair) or ''
    if M.FAMILY[name] then
     if pair:sub(1,9)~='general__' then return false end
     if a[3]>=0x200 and m.pair and pair~=m.pair then return false end
    elseif m.pair and pair~=m.pair then return false end
   end
   return true
  end
  local function place(dx,dy)
   local same=true
   if M.LOOSE[name] then
    for _,a in ipairs(m.anchor)do
     local c=cells[(a[1]+dx)..':'..(a[2]+dy)]
     if not (c and c.mid==a[3]) then same=false;break end
    end
   end
   local bld=claim(cells,{cx=m.x0+dx,cy=m.y0+dy,width=m.x1-m.x0+1,depth=m.y1-m.y0+1,name=name,voxels=m,
    tiles=same and m.tiles or nil})
   if bld then
    local kept={}
    local from=bld.cy+(m.claimFrom or 0)
    for _,c in ipairs(bld.claimed)do
     -- Art above the footprint is already on the model; restore its actual floor.
     if c.cy<from and c.mid>=0x200 and c.shape and c.shape.kind=='flat' then
      local best,dist
      for dy=-8,8 do for dx=-8,8 do
       local n=cells[(c.cx+dx)..':'..(c.cy+dy)]
       local k=n and n.shape and n.shape.kind
       local d=dx*dx+dy*dy
       if n and n.mid<0x200 and n.base==c.base and (k=='water' or k=='flat') and (not dist or d<dist) then best,dist=n,d end
      end end
      if best then c.mid,c.shape=best.mid,best.shape end
     end
     if (c.shape and c.shape.kind=='tree' and not m.keepTrees) or c.cy<from or (m.claimBlocked and (c.collision or 0)~=7) then c.bldModel=nil;c.civic=nil else kept[#kept+1]=c end
    end
    bld.claimed=kept
    if m.flatten then -- tiles of the model's own walls that read as rock bands stay flat floor under it
     local flat
     for _,c in ipairs(kept)do if c.shape and c.shape.kind=='flat' then flat=c.shape;break end end
     if flat then for _,c in ipairs(kept)do if c.shape and c.shape.kind=='cliff' then c.shape=flat end end end
    end
    local votes,best,bn,tpl={},nil,0,{}
    for x=bld.cx-1,bld.cx+bld.width do for y=bld.cy,bld.cy+bld.depth do
     local n=cells[x..':'..y]
     if n and not n.bldModel and (n.collision or 0)==0 and n.shape and n.shape.kind=='flat' then
      votes[n.mid]=(votes[n.mid] or 0)+1;tpl[n.mid]=n
      if votes[n.mid]>bn then best,bn=n.mid,votes[n.mid] end
     end
    end end
    bld.groundMid=best
    for _,r in ipairs(m.groundRows or {})do -- ledge rows below the model: plain ground instead of a flat yellow plate
     for x=bld.cx,bld.cx+bld.width-1 do
      local c,t=cells[x..':'..(bld.cy+r)],tpl[best]
      if c and t and not c.bldModel then c.mid,c.shape=t.mid,t.shape end
     end
    end
    out[#out+1]=bld
   end
  end
  local foreign = m and not M.FAMILY[name] and m.map ~= mapId
  if (m and M.FAMILY[name] or foreign) and anchor[1] then
   local a=anchor[1]
   for _,c in pairs(cells)do
    if c.mid==a[3] and not c.bldModel then
     local dx,dy=c.cx-a[1],c.cy-a[2]
     if matches(dx,dy) then place(dx,dy) end
    end
   end
  elseif m and m.map==mapId and matches(0,0) then
   place(0,0)
  end
 end
 return out
end

function M.mesh(bld,data,img)
 local m=bld.voxels
 local iw,ih=data:getDimensions()
 local ox=bld.cx*16
 local oy=bld.groundHeight or 0
 local oz=(bld.cy+bld.depth)*16
 local q=m.quads
 local rs=M.RAISE[m.name]
 if rs then m.tall=m.tall or raise(q,rs);q=m.tall end
 local rp=Dome.MODELS[m.name]
 if rp then m.dome=m.dome or Dome.build(q,rp);q=m.dome end
 local repaint={}
 do
  local ts=bld.ts
  local ground,any={},false
  local function key(r,g,b)return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)end
  for _,gm in ipairs({bld.groundMid or false,0x001})do
   local slot=gm and ts and ts.imageData and ts.midToSlot[gm]
   if slot then any=true
    local gx,gy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
    for y=0,15 do for x=0,15 do local r,g,b=ts.imageData:getPixel(gx+x,gy+y);ground[key(r,g,b)]=true end end
   end
  end
  local function isGround(px,py)
   if px<0 or py<0 or px>=iw or py>=ih then return false end
   local r,g,b,a=data:getPixel(px,py);return a>.5 and ground[key(r,g,b)] or false
  end
  if any and M.REPAINT_GROUND then
   local walls,bad={},{}
   for i=1,#q,10 do local f=q[i]
    if f~=3 and q[i+4]>q[i+3] then
     if isGround(q[i+7],q[i+8]) then bad[#bad+1]=i else walls[#walls+1]=i end
    end
   end
   -- a ground colour that covers a real share of the walls is the building's own material (Rustboro brick = its paving)
   local area,total={},0
   local function size(i)local f=q[i];return ((f==1 or f==2) and q[i+2]-q[i+1] or math.abs(q[i+6]-q[i+5]))*(q[i+4]-q[i+3]) end
   for _,i in ipairs(walls)do total=total+size(i) end
   for _,i in ipairs(bad)do local k=q[i+7]*4096+q[i+8];area[k]=(area[k] or 0)+size(i);total=total+size(i) end
   local leak={}
   for _,i in ipairs(bad)do
    if area[q[i+7]*4096+q[i+8]]>M.REPAINT_SHARE*total then walls[#walls+1]=i else leak[#leak+1]=i end
   end
   bad=leak
   local bucket={}
   for _,j in ipairs(walls)do
    local fj=q[j];local sj=fj~=1 and fj~=2
    local pl=sj and q[j+1] or q[j+5]
    for h=q[j+3],q[j+4]-1 do
     local k=(fj*4096+pl+2048)*4096+h+2048
     local b=bucket[k];if not b then b={};bucket[k]=b end;b[#b+1]=j
    end
   end
   for _,i in ipairs(bad)do
    local f,best,bd=q[i],nil,nil
    local side=f~=1 and f~=2
    local pl=side and q[i+1] or q[i+5]
    for h=q[i+3],q[i+4]-1 do
     for _,j in ipairs(bucket[(f*4096+pl+2048)*4096+h+2048] or {})do
      local d=side and math.abs((q[j+5]+q[j+6])-(q[i+5]+q[i+6])) or math.abs((q[j+1]+q[j+2])-(q[i+1]+q[i+2]))
      if not bd or d<bd or (d==bd and j<best) then best,bd=j,d end
     end
    end
    if best and bd<=M.REPAINT_GROUND*2 then repaint[i]=best end
   end
  end
 end
 local F,nf=table.remove(pool) or {},0
 for i=1,#q,10 do
  local f,x0,x1,h0,h1,z0,z1,px,py=q[i],q[i+1],q[i+2],q[i+3],q[i+4],q[i+5],q[i+6],q[i+7],q[i+8]
  if repaint[i] then px,py=q[repaint[i]+7],q[repaint[i]+8] end
  local u,v=(px+.5)/iw,(py+.5)/ih
  local s=SHADE[f] or 1
  if (q[i+9] or 0)>0 then s=q[i+9]/100 end
  local X0,X1,H0,H1,Z0,Z1=ox+x0,ox+x1,oy+h0,oy+h1,oz+z0,oz+z1
  local n=nf
  if f==1 or f==2 then
   F[n+1],F[n+2],F[n+3],F[n+4],F[n+5],F[n+6]=X0,H0,Z0,u,v,s
   F[n+7],F[n+8],F[n+9],F[n+10],F[n+11],F[n+12]=X1,H0,Z0,u,v,s
   F[n+13],F[n+14],F[n+15],F[n+16],F[n+17],F[n+18]=X1,H1,Z0,u,v,s
   F[n+19],F[n+20],F[n+21],F[n+22],F[n+23],F[n+24]=X0,H1,Z0,u,v,s
  elseif f==3 then
   F[n+1],F[n+2],F[n+3],F[n+4],F[n+5],F[n+6]=X0,H0,Z1,u,v,s
   F[n+7],F[n+8],F[n+9],F[n+10],F[n+11],F[n+12]=X1,H0,Z1,u,v,s
   F[n+13],F[n+14],F[n+15],F[n+16],F[n+17],F[n+18]=X1,H0,Z0,u,v,s
   F[n+19],F[n+20],F[n+21],F[n+22],F[n+23],F[n+24]=X0,H0,Z0,u,v,s
  else
   F[n+1],F[n+2],F[n+3],F[n+4],F[n+5],F[n+6]=X0,H0,Z0,u,v,s
   F[n+7],F[n+8],F[n+9],F[n+10],F[n+11],F[n+12]=X0,H0,Z1,u,v,s
   F[n+13],F[n+14],F[n+15],F[n+16],F[n+17],F[n+18]=X0,H1,Z1,u,v,s
   F[n+19],F[n+20],F[n+21],F[n+22],F[n+23],F[n+24]=X0,H1,Z0,u,v,s
  end
  nf=n+24
  if i%600==1 then Budget.tick() end
 end
 local mesh=nf>0 and FlatMesh.mesh(F,nf) or nil
 pool[#pool+1]=F
 return mesh
end

return M
