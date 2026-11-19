-- Original, palette-baked game art on grounded cards
local V=...
local Budget=V.require('BuildBudget')
local M={}
local size,cell=2048,128
M.TREE_DEPTH=28
M.SPECK=8
local data,image,dirty
local entries,content,count={},{},0
local function background(w,h,pixel)
 local counts={};local best,n=nil,0
 for y=0,h-1 do for x=0,w-1 do
  local r,g,b=pixel(x,y)
  local k=math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)
  counts[k]=(counts[k] or 0)+1
  if counts[k]>n then best,n=k,counts[k]end
 end end
 return best and {[best]=true} or {}
end
local function key(r,g,b)return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)end
function M.image()
 if not data then data=love.image.newImageData(size,size) end
 if not image then image=love.graphics.newImage(data);image:setFilter('nearest','nearest');dirty=false
 elseif dirty then image:replacePixels(data);dirty=false end
 return image
end
local function card(id,w,h,pixel,ground,shadowRows,keep)
 if entries[id] then return entries[id]end
 if w>cell-2 or h>cell-2 then return end
 local bytes={}
 for y=0,h-1 do for x=0,w-1 do
  local r,g,b,a=pixel(x,y)
  bytes[#bytes+1]=string.char(math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5),math.floor(a*255+.5))
 end end
 local fingerprint=w..':'..h..':'..tostring(shadowRows)..':'..table.concat(bytes)
 for k in pairs(ground)do fingerprint=fingerprint..':'..k end
 if content[fingerprint] then entries[id]=content[fingerprint];return entries[id]end
 if count>=(size/cell)^2 then return end
 if not data then data=love.image.newImageData(size,size)end
 local mask=V.require('SceneryMask').mask(w,function(x,y)
  if keep and keep(x,y) then return false end
  local r,g,b,a=pixel(x,y);return a==0 or ground[key(r,g,b)] or (shadowRows and b>r*1.25 and g>b)
 end,h)
 do
  local seen={}
  for sy=0,h-1 do for sx=0,w-1 do
   local k0=sy*w+sx
   if mask[k0] and not seen[k0] then
    local list,stack={}, {k0};seen[k0]=true
    while #stack>0 do
     local k=table.remove(stack);list[#list+1]=k
     local x,y=k%w,math.floor(k/w)
     for dy=-1,1 do for dx=-1,1 do
      if dx~=0 or dy~=0 then
       local nx,ny=x+dx,y+dy
       if nx>=0 and ny>=0 and nx<w and ny<h then
        local nk=ny*w+nx
        if mask[nk] and not seen[nk] then seen[nk]=true;stack[#stack+1]=nk end
       end
      end
     end end
    end
    if #list<M.SPECK then for _,k in ipairs(list)do mask[k]=false end end
   end
  end end
 end
 local x0,y0=count%(size/cell)*cell+1,math.floor(count/(size/cell))*cell+1
 count=count+1
 local lastOpaque=-1
 for y=0,h-1 do for x=0,w-1 do
  local r,g,b,a=pixel(x,y)
  if shadowRows and shadowRows>=16 and y>=h-shadowRows and g>r*1.08 and g>b*1.08 then a=0 end
  a=mask[y*w+x] and a or 0
  if a>0 then lastOpaque=math.max(lastOpaque,y)end
  data:setPixel(x0+x,y0+y,r,g,b,a)
 end end
 local c={w=w,h=h,bottom=math.max(0,h-lastOpaque-1),u0=x0/size,u1=(x0+w)/size,v0=y0/size,v1=(y0+h)/size}
 entries[id]=c;content[fingerprint]=c;dirty=true;return c
end
function M.append(c,v,i,q,x,y,z)
 if not c then return q end
 local bottom=c.bottom or 0
 local base=#v
 for _,p in ipairs({{-1,0},{1,0},{1,1},{-1,1}})do
  local t=p[2]
  v[#v+1]={x+p[1]*c.w/2,y-bottom+c.h*t,z,
   p[1]<0 and c.u0 or c.u1,c.v1-(c.v1-c.v0)*t,1,x,z,y+.001}
 end
 for _,n in ipairs({1,2,3,1,3,4})do i[#i+1]=base+n end
 return q+1
end
local function variant(c,family)
 if not c then return end
 c.variants=c.variants or {}
 if not c.variants[family]then
  c.variants[family]={w=c.w,h=c.h,bottom=c.bottom,u0=c.u0,u1=c.u1,v0=c.v0,v1=c.v1}
 end
 return c.variants[family]
end
M.VARIANTS=4
function M.variantAt(x,z)
 local n=math.sin(math.floor(x/16)*12.9898+math.floor(z/16)*78.233)*43758.5453
 return math.floor((n-math.floor(n))*M.VARIANTS)
end
-- Sprite stacking: the same voxel tree drawn as a pile of flat, see-through slices, one image per
-- voxel layer (Petya 2026-11-19). M.STACK_SUB planes per layer close the gaps seen from a low camera.
M.STACK_SUB=2
M.STACK_SHADE=.12 -- the lowest slice is this much darker than the top one
local shelf -- {x0,y0 of the current atlas cell, cursor x, cursor y, row height}
local function slot(w,h)
 if w>cell-2 or h>cell-2 then return end
 if shelf and shelf.x+w>cell-1 then shelf.x,shelf.y,shelf.row=1,shelf.y+shelf.row+1,0 end
 if not shelf or shelf.y+h>cell-1 then
  if count>=(size/cell)^2 then return end
  shelf={x0=count%(size/cell)*cell,y0=math.floor(count/(size/cell))*cell,x=1,y=1,row=0}
  count=count+1
 end
 local px,py=shelf.x0+shelf.x,shelf.y0+shelf.y
 shelf.x=shelf.x+w+1;shelf.row=math.max(shelf.row,h)
 return px,py
end
M.STACK_AXES=3 -- 1: lying slices only; 3: also standing slices along x and z, so a low camera sees no gaps
M.STACK_STRIDE=2 -- standing slices every this many voxels (fewer = less overdraw in dense forest)
-- Where stack slices go: the tree atlas (shared with the tree cards) or an atlas of its own (M.newAtlas)
local treeAtlas={size=size,slot=function(w,h)return slot(w,h)end,
 set=function(x,y,r,g,b,a)if not data then data=love.image.newImageData(size,size)end;data:setPixel(x,y,r,g,b,a)end,
 touch=function()dirty=true end,image=function()return M.image()end}
M.treeAtlas=treeAtlas
function M.newAtlas(sz)
 sz=sz or size
 local A={size=sz};local adata,aimage,adirty,acount,ashelf=nil,nil,false,0,nil
 function A.slot(w,h)
  if w>cell-2 or h>cell-2 then return end
  if ashelf and ashelf.x+w>cell-1 then ashelf.x,ashelf.y,ashelf.row=1,ashelf.y+ashelf.row+1,0 end
  if not ashelf or ashelf.y+h>cell-1 then
   if acount>=(sz/cell)^2 then return end
   ashelf={x0=acount%(sz/cell)*cell,y0=math.floor(acount/(sz/cell))*cell,x=1,y=1,row=0};acount=acount+1
  end
  local px,py=ashelf.x0+ashelf.x,ashelf.y0+ashelf.y
  ashelf.x=ashelf.x+w+1;ashelf.row=math.max(ashelf.row,h)
  return px,py
 end
 function A.set(x,y,r,g,b,a)if not adata then adata=love.image.newImageData(sz,sz)end;adata:setPixel(x,y,r,g,b,a)end
 function A.touch()adirty=true end
 function A.image()
  if not adata then adata=love.image.newImageData(sz,sz)end
  if not aimage then aimage=love.graphics.newImage(adata);aimage:setFilter('nearest','nearest');adirty=false
  elseif adirty then aimage:replacePixels(adata);adirty=false end
  return aimage
 end
 function A.used()return acount,(sz/cell)^2 end
 return A
end
local function bake(cells,w,h,A)
 local px,py=A.slot(w,h)
 if not px then return end
 for ty=0,h-1 do for tx=0,w-1 do A.set(px+tx,py+ty,0,0,0,0)end end
 for _,c in ipairs(cells)do
  local k=c[3]
  A.set(px+c[1],py+c[2],math.floor(k/65536)/255,math.floor(k/256)%256/255,k%256/255,1)
 end
 return px/A.size,(px+w)/A.size,py/A.size,(py+h)/A.size
end
function M.stack(vol,A)
 if not (vol and vol.vox) then return end
 A=A or treeAtlas
 local nx,ny,nz,step,bottom=vol.nx,vol.ny,vol.nz,vol.step or 1,vol.bottom or 0
 local planes={{},{},{}} -- 1: by y (lying), 2: by x, 3: by z (standing)
 local function add(set,key,a,b,colour)
  local L=set[key];if not L then L={a0=a,a1=a,b0=b,b1=b,cells={}};set[key]=L end
  if a<L.a0 then L.a0=a end;if a>L.a1 then L.a1=a end
  if b<L.b0 then L.b0=b end;if b>L.b1 then L.b1=b end
  L.cells[#L.cells+1]={a,b,colour}
 end
 for k,colour in pairs(vol.vox)do
  local zz=k%nz;local r=(k-zz)/nz;local xx=r%nx;local yy=(r-xx)/nx
  if (yy+1)*step-bottom>0 then
   add(planes[1],yy,xx,zz,colour)
   if M.STACK_AXES>1 then add(planes[2],xx,zz,ny-1-yy,colour);add(planes[3],zz,xx,ny-1-yy,colour)end
  end
 end
 local X=function(a)return a*step-vol.w/2 end
 local Y=function(a)return math.max(0,a*step-bottom)end
 local Z=function(a)return a*step-nz*step/2 end
 local quads={}
 for yy=0,ny-1 do local L=planes[1][yy];if L then
  Budget.tick()
  for _,c in ipairs(L.cells)do c[1]=c[1]-L.a0;c[2]=c[2]-L.b0 end
  local u0,u1,v0,v1=bake(L.cells,L.a1-L.a0+1,L.b1-L.b0+1,A)
  if not u0 then return end
  local X0,X1,Z0,Z1=X(L.a0),X(L.a1+1),Z(L.b0),Z(L.b1+1)
  local shade=1-M.STACK_SHADE*(1-yy/math.max(1,ny-1))
  local sub=M.STACK_AXES>1 and 1 or M.STACK_SUB
  for j=1,sub do
   local y=(yy+j/sub)*step-bottom
   if y>0 then quads[#quads+1]={{X0,y,Z0,u0,v0},{X1,y,Z0,u1,v0},{X1,y,Z1,u1,v1},{X0,y,Z1,u0,v1},shade=shade}end
  end
 end end
 for axis=2,3 do
  local count=axis==2 and nx or nz
  for p=0,count-1 do local L=(p%M.STACK_STRIDE==math.floor(M.STACK_STRIDE/2)) and planes[axis][p];if L then
   Budget.tick()
   for _,c in ipairs(L.cells)do c[1]=c[1]-L.a0;c[2]=c[2]-L.b0 end
   local u0,u1,v0,v1=bake(L.cells,L.a1-L.a0+1,L.b1-L.b0+1,A)
   if not u0 then return end
   local Ytop,Ybot=Y(ny-L.b0),Y(ny-1-L.b1)
   if axis==2 then
    local x=X(p+.5);local Z0,Z1=Z(L.a0),Z(L.a1+1)
    quads[#quads+1]={{x,Ytop,Z0,u0,v0},{x,Ytop,Z1,u1,v0},{x,Ybot,Z1,u1,v1},{x,Ybot,Z0,u0,v1},shade=.9}
   else
    local z=Z(p+.5);local X0,X1=X(L.a0),X(L.a1+1)
    quads[#quads+1]={{X0,Ytop,z,u0,v0},{X1,Ytop,z,u1,v0},{X1,Ybot,z,u1,v1},{X0,Ybot,z,u0,v1},shade=.95}
   end
  end end
 end
 A.touch()
 return quads
end
-- Any small hull object (bush, hedge) as a stack: its pixels are copied into this atlas, so the slices
-- can live here too; the caller emits the quads into the leaf batch, which draws with M.image().
local stacks={}
function M.stackHull(w,h,pixel,...)return M.stackHullOn(treeAtlas,w,h,pixel,...)end
function M.stackHullOn(A,w,h,pixel,...)
 local bytes={}
 local grid={}
 for y=0,h-1 do for x=0,w-1 do
  local r,g,b,a=pixel(x,y)
  a=(a or 0)>.5 and 1 or 0
  grid[y*w+x]={r,g,b,a}
  bytes[#bytes+1]=string.char(math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5),a*255)
 end end
 local id=tostring(A)..':'..w..'x'..h..':'..table.concat(bytes)
 local extra={...};for k=1,select('#',...) do id=id..':'..tostring(extra[k]) end
 if stacks[id]~=nil then return stacks[id] or nil end
 local vol=V.require('VoxelHull').volume(w,h,function(x,y)
  local p=grid[y*w+x];return p[1],p[2],p[3],p[4],0,0
 end,...)
 stacks[id]=M.stack(vol,A) or false
 A.touch()
 return stacks[id] or nil
end
function M.appendStack(quads,v,i,q,x,y,z)
 for _,s in ipairs(quads)do
  Budget.tick()
  local base=#v
  for _,p in ipairs({s[1],s[2],s[3],s[4]})do v[#v+1]={x+p[1],y+p[2],z+p[3],p[4],p[5],s.shade,0,0,0} end
  for _,k in ipairs({1,2,3,1,3,4})do i[#i+1]=base+k end
 end
 return (q or 0)+#quads
end
function M.stacked()
 return V.require('TreePresentation').props:get()=='stacked'
end
function M.appendModel(c,v,i,q,x,y,z,variant)
 if not c then return q end
 local Hull=V.require('VoxelHull')
 c.models=c.models or {}
 variant=variant or M.variantAt(x,z)
 local x0,y0=c.u0*size,c.v0*size
 local flip=variant%2==1
 local function args()
  return c.w,c.h,function(px,py)
   if flip then px=c.w-1-px end
   local r,g,b,a=data:getPixel(x0+px,y0+py)
   return r,g,b,a,(x0+px+.5)/size,(y0+py+.5)/size
  end,1,c.bottom,c.treeDepth or M.TREE_DEPTH,nil,true,c.taper,variant+1
 end
 if M.stacked() then
  local name='stack'..variant
  if c.models[name]==nil then c.models[name]=M.stack(Hull.volume(args())) or false end
  if c.models[name] then return M.appendStack(c.models[name],v,i,q,x,y,z) end
  -- the atlas is full: this tree stays solid
 end
 local name='solid'..variant
 if not c.models[name] then c.models[name]=Hull.build(args()) end
 return Hull.append(c.models[name],v,i,q,x,y,z)
end
function M.addInstance(c,groups,x,y,z)
 local Instances=V.require('ModelInstances')
 if not c or not Instances.available()then return false end
 c.meshes=c.meshes or setmetatable({},{__mode='v'})
 local variant=M.variantAt(x,z)
 local mkey=(M.stacked() and 's' or 'm')..variant
 local mesh=c.meshes[mkey]
 if mesh==nil then
  local v,i={},{};M.appendModel(c,v,i,0,0,0,0,variant)
  mesh=V.require('Voxel3D').newMesh(v,i) or false;c.meshes[mkey]=mesh
 end
 if not mesh then return false end
 local group=groups[mesh]
 if not group then group={mesh=mesh,card=c,positions={}};groups[mesh]=group end
 group.positions[#group.positions+1]={x,y,z}
 return true
end
function M.buildInstances(groups,v,i,out,onBatch)
 out=out or {}
 for _,group in pairs(groups)do
  Budget.check()
  local batch=V.require('ModelInstances').new(group.mesh,group.positions)
  if batch then out[#out+1]=batch;if onBatch then onBatch(batch)end
  else for _,p in ipairs(group.positions)do M.appendModel(group.card,v,i,0,p[1],p[2],p[3])end end
 end
 return out
end
function M.cardFrom(id,w,h,pixel)
 return variant(card(id,w,h,pixel,{},0),'conifer')
end
function M.gen3(c)
 local ts=c.ts;local forest=c.shape.spacing==3
 local art=c.shape.art
 local tiles='' -- every tile of the art: trees that share a crown tile but not a trunk tile are different cards
 if art then local t={};for _,row in ipairs(art)do t[#t+1]=table.concat(row,',')end;tiles=table.concat(t,'/')end
 local id=tostring(ts.imageData)..':'..tostring(ts.overImageData)..':'..tostring(forest)..':'..(c.shape.ground or 1)
  ..':'..(art and (#art..'x'..tiles..'t'..(c.shape.artTipRows or 0)..'g') or '')
 if entries[id]then return variant(entries[id],forest and 'tiered' or 'conifer')end
 local rows=c.shape.art or (forest and {{1,641,1},{648,649,650},{656,657,658},{672,673,674},{675,676,677}}
   or {{14,15},{28,29},{36,37}})
 local function pixel(mid,x,y)
  local slot=ts.midToSlot[mid];if not slot then return 0,0,0,0 end
  local px,py=slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y
  local r,g,b,a=ts.imageData:getPixel(px,py)
  if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(px,py)
   r,g,b,a=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa),aa+a*(1-aa)
  end
  return r,g,b,a
 end
 local ground=background(16,16,function(x,y)return pixel(c.shape.ground or 1,x,y)end)
 if art then
  for gy=0,15 do for gx=0,15 do local r,g,b=pixel(c.shape.ground or 1,gx,gy);ground[key(r,g,b)]=true end end
 end
 local tipRows=art and c.shape.artTipRows or 0
 local groundColours
 local function tipPixel(mid,x,y)
  local slot=ts.midToSlot[mid];if not slot then return 0,0,0,0 end
  local px,py=slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y
  if ts.overImageData then
   local r,g,b,a=ts.overImageData:getPixel(px,py)
   if a>.5 then return r,g,b,a end
   return 0,0,0,0
  end
  if not groundColours then
   groundColours={}
   for gy=0,15 do for gx=0,15 do local r,g,b=pixel(c.shape.ground or 1,gx,gy);groundColours[key(r,g,b)]=true end end
  end
  local r,g,b,a=pixel(mid,x,y)
  if groundColours[key(r,g,b)] then return 0,0,0,0 end
  return r,g,b,a
 end
 local function overAlpha(mid,x,y)
  if not ts.overImageData then return 0 end
  local slot=ts.midToSlot[mid];if not slot then return 0 end
  local _,_,_,a=ts.overImageData:getPixel(slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y)
  return a
 end
 local footY
 if art then
  local H=#rows*16
  for y=H-1,H-16,-1 do
   for x=0,#rows[1]*16-1 do
    local r,g,b,a=pixel(rows[#rows][math.floor(x/16)+1],x%16,y%16)
    if a>.5 and not ground[key(r,g,b)] and not (g>r*1.12 and g>b*1.08) then footY=y;break end
   end
   if footY then break end
  end
  if footY and (footY>=H-1 or footY<H-6) then footY=nil end
 end
 local result=card(id..(footY and ':f'..footY or ''),#rows[1]*16,#rows*16,function(x,y)
  local row=math.floor(y/16)+1
  local mid=rows[row][math.floor(x/16)+1]
  if footY and y>footY then return 0,0,0,0 end
  if row<=tipRows then return tipPixel(mid,x%16,y%16) end
  return pixel(mid,x%16,y%16)
 end,ground,forest and 16 or 8,function(x,y)
  local row=math.floor(y/16)+1
  local mid=rows[row][math.floor(x/16)+1]
  return mid and overAlpha(mid,x%16,y%16)>.5
 end)
 return variant(result,forest and 'tiered' or 'conifer')
end
return M
