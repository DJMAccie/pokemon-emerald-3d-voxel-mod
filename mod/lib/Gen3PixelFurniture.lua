-- Pixel-voxel furniture
local V=...
local M={}

M.recipes={}
local function add(name,secondary,rows,parts,ground,shadow,h,wall,opts)
 M.recipes[#M.recipes+1]={name=name,primary='building',secondary=secondary,rows=rows,
  kind='pixel',parts=parts,pixelGround=ground,shadow=shadow or {},h=h or 0,wall=wall,
  ground=ground[1]} -- the floor drawn under the object
 for k,v in pairs(opts or {})do M.recipes[#M.recipes][k]=v end
end
-- Brendan's / May's house 1F: the dining table on the rug and its four chairs
add('em_house_table','brendans_mays_house',{{0x21A,0x21B},{0x222,0x223}},
 {{2,30,23,8}},{0x220},{{12,29}},8)
for _,mid in ipairs({0x219,0x221})do -- backrest on the west
 add('em_house_chair_w_'..mid,'brendans_mays_house',{{mid}},
  {{1,5,6,9,true},{5,15,10,5}},{0x220},{{7,15}},5)
end
for _,mid in ipairs({0x21C,0x224})do -- backrest on the east
 add('em_house_chair_e_'..mid,'brendans_mays_house',{{mid}},
  {{11,15,6,9,true},{1,11,10,5}},{0x220},{{8,15}},5)
end

add('em_player_bed','brendans_mays_house',{{0x27B,0x27C,0x27D},{0x283,0x284,0x285},{0x28B,0x28C,0x28D}},
 {{13,36,17,12,true,14},{12,36,38,6,false,23}},{0x201},nil,6)
add('em_player_shelf','brendans_mays_house',{{0x252},{0x25A},{0x262}},{{1,15,10,36,true,9,32}},{0x201},nil,36,9)

local house='generic_building'
add('em_generic_table',house,{{0x248,0x249},{0x250,0x251}},{{2,30,22,9}},{0x23E,0x223},nil,9)
for _,mid in ipairs({0x2E2,0x22C})do
 add('em_generic_chair_e_'..mid,house,{{mid}},{{10,15,7,8,true},{1,10,10,5}},{0x23E,0x223},nil,5,nil,{floorFrom='neighbour'})
end
add('em_generic_chair_w_22B',house,{{0x22B}},{{2,6,7,8,true},{5,15,10,5}},{0x223,0x23E},nil,5,nil,{floorFrom='neighbour'})
add('em_generic_wardrobe',house,{{0x24C,0x24D},{0x254,0x255}},{{1,31,1,30,true}},{0x223},nil,30)
add('em_generic_kitchen',house,{{0x286,0x287},{0x28E,0x28F},{0x296,0x297}},{{0,32,18,20,true,12}},{0x224},nil,20,32)
add('em_generic_bookshelf',house,{{0x279,0x27A},{0x281,0x282},{0x289,0x28A}},{{2,23,16,22,true,12}},{0x224},nil,22,32)
add('em_generic_drawers',house,{{0x268,0x269},{0x270,0x271}},{{0,32,1,22,true,0,16}},{0x224,0x223},nil,22)
add('em_generic_tea_table',house,{{0x24E,0x24F},{0x256,0x257}},{{2,30,23,7}},{0x229,0x223},{{0,24},{31,17}},7)
add('em_generic_square_table',house,{{0x24A,0x24B},{0x252,0x253}},{{2,30,22,8}},{0x223},nil,8)
add('em_soot_table',house,{{0x3F3,0x3F4},{0x3FB,0x3FC}},{{2,30,22,9}},{0x3FE},{{8,27}},9)
add('em_soot_chair_w',house,{{0x2DD}},{{2,6,7,8,true},{5,15,10,5}},{0x3FE},{{0,8}},5)
add('em_soot_chair_e',house,{{0x2DE}},{{10,14,7,8,true},{1,10,10,5}},{0x3FE},{{15,8}},5)
add('em_pacif_table',house,{{0x3AA,0x3AB},{0x3B2,0x3B3}},{{1,31,23,8}},{0x39D},nil,8)
add('em_pacif_chair_w',house,{{0x3AE}},{{1,5,7,8,true},{5,15,10,5}},{0x39D},nil,5)
add('em_pacif_chair_e',house,{{0x3AF}},{{11,15,7,8,true},{1,11,10,5}},{0x39D},nil,5)
-- the Rustboro flats' two table drawings (floor 0x32C)
add('em_flat_table_a',house,{{0x368,0x369},{0x370,0x371}},{{2,30,22,8}},{0x32C},{{1,24}},8)
add('em_flat_table_b',house,{{0x36A,0x36B},{0x372,0x373}},{{1,31,23,7}},{0x32C},{{1,26}},7)
add('em_flat_partition',house,{{0x2D7},{0x300},{0x300},{0x300},{0x300},{0x300},{0x2DF},{0x2E7}},
 {{2,14,98,27,true,0,nil,nil,true,nil,nil,nil,true}},{0x32B,0x32C},nil,27,nil,{maxH=32})
add('em_hall_partition_ns',house,{{0x2F8},{0x300},{0x300},{0x300},{0x300},{0x308},{0x310}},
 {{2,14,85,24,true,0,nil,nil,true,nil,nil,nil,true}},{0x223,0x239},nil,24,nil,{maxH=32})
-- the same partition one row shorter (Verdanturf, Wanda's house)
add('em_hall_partition_ns6',house,{{0x2F8},{0x300},{0x300},{0x300},{0x308},{0x310}},
 {{2,14,69,24,true,0,nil,nil,true,nil,nil,nil,true}},{0x223,0x239},nil,24,nil,{maxH=32})
add('em_hall_partition_ew',house,{{0x2FA,0x2FB,0x2FB,0x2FB},{0x302,0x303,0x303,0x303},{0x30A}},
 {{2,64,22,23,true,12,nil,nil,true,nil,nil,nil,true}},{0x223,0x239},nil,23,nil,{maxH=32})
add('em_mauville_bikes','mauville',{{0x298,0x299,0x29A}},
 {{1,22,0,13,true,0,10,'card'},{25,46,0,13,true,0,10,'card'}},{0x001},nil,13,nil,{primary='general',maxH=13})
local SC={primary='general',lift=0}
for _,mid in ipairs({0x361})do
 add('em_sc_stool_'..mid,'facility',{{mid}},{{2,14,9,5,true,1,nil,true}},{0x2F0,0x2F1},nil,5,nil,SC)
end
add('em_sc_plot_table','facility',{{0x368,0x369},{0x370,0x371}},
 {{0,6,22,8},{26,32,22,8},{6,26,22,3,true,1,nil,nil,nil,nil,5}},{0x2F0},nil,8,nil,SC)
for _,left in ipairs({{0x363,0x36B},{0x362,0x36A}})do
 add('em_sc_desk_'..left[1],'facility',{{left[1],0x364},{left[2],0x36C}},
  {{0,6,24,6},{26,32,24,6},{6,26,24,3,true,12,nil,nil,nil,nil,3},
   {3,15,10,6,true,9,nil,nil,nil,nil,6},{16,29,16,8,true,12,nil,nil,nil,nil,6}},{0x2F0},nil,6,nil,SC)
end
for _,mid in ipairs({0x373,0x356,0x374})do
 add('em_sc_rail_'..mid,'facility',{{mid}},{{0,16,0,12,true,0,11,'card',true}},{0x2F0,0x366},nil,12,nil,{primary='general'})
end
add('em_tree_cabinet',house,{{0x3E0},{0x3E8}},{{1,15,8,14,true,2,nil,nil,true}},{0x3D9},nil,14,2)
add('em_fanclub_partition_w',house,{{0x309,0x2FB,0x2FC},{0x303,0x303,0x304}},
 {{0,47,22,9,true,11,nil,nil,true,nil,nil,{10,14}}},{0x223},nil,9)
add('em_fanclub_partition_e',house,{{0x2FA,0x2FB,0x2FB},{0x302,0x303,0x303}},
 {{1,48,22,9,true,11,nil,nil,true,nil,nil,{20,14}}},{0x223},nil,9)
for _,mid in ipairs({0x2EE,0x326})do
 add('em_pyre_grave_'..string.format('%X',mid),'facility',{{mid}},{{1,15,4,11,true,0,nil,true,true}},{0x2E6,0x2E7},nil,11,nil,{primary='general',lift=4})
end
local PY={primary='general'}
for _,mid in ipairs({0x324,0x325})do
 add('em_pyre_grave_out_'..string.format('%X',mid),'facility',{{mid}},
  {{0,16,8,7,true,7},{2,14,2,4,true,0,nil,nil,nil,nil,7}},{0x001},nil,7,nil,PY)
end
for _,mid in ipairs({0x32A,0x32B})do
 add('em_pyre_stone_'..string.format('%X',mid),'facility',{{mid}},{{0,16,5,10,true,0,nil,true}},{0x001},nil,10,nil,PY)
end
add('em_pyre_altar','facility',{{0x32C,0x32D,0x32E}},
 {{6,12,2,12,true,0},{36,42,2,12,true,0},{12,36,7,5,true,3,nil,nil,nil,nil,5}},{0x001},nil,12,nil,PY)
add('em_mauville_lightning','mauville_gym',{{0x220,0x221},{0x228,0x229}},
 {{0,32,9,5,true,10,14,'card',nil,nil,6},{0,32,14,4,true,15,18,'card',nil,nil,6},
  {0,32,18,5,true,19,23,'card',nil,nil,6}},{0x20A,0x232,0x233},nil,5,nil,{lift=0,maxH=5})
add('em_generic_bed',house,{{0x25A,0x25B},{0x262,0x263}},
 {{4,28,4,12,true,0},{4,28,24,6,false,11}},{0x223},nil,6)

for _,mid in ipairs({0x226,0x234})do
 add('em_center_stool_'..mid,'pokemon_center',{{mid}},{{1,15,9,5,true}},{0x202},{{1,11}},5)
end
add('em_center_glass_table','pokemon_center',{{0x23D,0x23E},{0x245,0x246}},{{1,31,25,5}},{0x202},{{1,10}},5)

-- The second author's recipes are add() argument lists in data/; prepare() applies
-- the plant lift, back-wall flag and facility clone.
local BACK_YES={'crate','box','load','bucket','bin','seat','chair','stool','sofa','bench','cushion','cot','bed',
 'stand','pedestal','planter','plant','pot','potbush','basket','statue','bust','grave','table','tablet','stump','log','trunk',
 'pillar','post','pole','cube','capsule','cooler','pylon','backrest','bush','beacon','benche','wide'}
local BACK_NO={'cabinet','counter','desk','pc','tv','shelf','machine','console','kiosk','fridge','sink','board',
 'display','screen','monitor','register','rack','wardrobe','drawer','server','engine','generator','vending','slot',
 'roulette','gate','partition','fence','rail','railflag','flag','umbrella','kitchen','stove','laptop','appliance','case','showcase'}
local WALL_PIECE={'cabinet','counter','shelf','fridge','sink','kitchen','stove','drawer','wardrobe','rack','appliance','showcase','desk'}
local function prepare(a)
 if a[1]:find('plant') and not a[1]:find('planter') then
  a[9]=a[9] or {};a[9].lift=0
  local pot,leaves
  for _,pt in ipairs(a[4])do if pt[11] then leaves=pt else pot=pt end end
  if pot and leaves then
   local L0,L1=leaves[6],leaves[3]+leaves[4]
   local n=math.floor((L1-L0+1)/2) -- half the rows deep, half tall
   local c=(pot[6]+pot[3])/2+pot[4] -- the pot's middle (depth)
   local F=math.floor(c+.5)
   if a[9].crownCentre then F=math.floor(c+n/2+.5) end
   leaves[3]=L0+n-1;leaves[4]=L1-leaves[3];leaves[11]=math.max(pot[4]+1,F-1-L1)
   local cx=math.floor((pot[1]+pot[2])/2)
   a[4][#a[4]+1]={cx-2,cx+2,L1,leaves[11]-pot[4],true,L1-3,nil,'disc',nil,nil,pot[4]}
  end
 end
 local back=a[9] and a[9].back
 do -- pieces that stand against a wall (not TVs/PCs: their depth comes from the tube rule)
  local wall,free=false,false
  for tok in a[1]:gsub('^em_gate_','em_'):gmatch('[^_]+')do
   tok=tok:gsub('%d+$',''):gsub('s$','')
   for _,w in ipairs(WALL_PIECE)do if tok:sub(-#w)==w then wall=true end end
   for _,w in ipairs(BACK_YES)do if tok:sub(-#w)==w then free=true end end
   if tok=='tv' or tok=='pc' or tok:find('top$') then free=true end
  end
  if wall and not free then a[9]=a[9] or {};a[9].wallPiece=true end
 end
 if back==nil then
  local yes,no=false,false
  for tok in a[1]:gsub('^em_gate_','em_'):gmatch('[^_]+')do -- em_gate_*: the Reception Gate's pieces, not gates
   tok=tok:gsub('%d+$',''):gsub('s$','')
   for _,w in ipairs(BACK_NO)do if tok:sub(-#w)==w then no=true end end
   for _,w in ipairs(BACK_YES)do if tok:sub(-#w)==w then yes=true end end
  end
  back=yes and not no
 end
 if back then for _,pt in ipairs(a[4])do
  if pt[5]==true and (not pt[8] or pt[8]==true) and pt[14]==nil then -- plain and round=true parts (not disc/card/ball)
   pt[14]=true
  end
 end end
 if a[2]~='facility' then return a end
 local b={};for i=1,9 do b[i]=a[i] end
 local o={};for k,v in pairs(a[9] or {})do o[k]=v end;o.primary='general';b[1]=a[1]..'_g';b[9]=o
 return a,b
end
do
 local rows=V and V.data and V.data('gen3_pixel_furniture_b')
 if type(rows)=='table' then for _,a in ipairs(rows)do
  local main,clone=prepare(a)
  add(main[1],main[2],main[3],main[4],main[5],main[6],main[7],main[8],main[9])
  if clone then add(clone[1],clone[2],clone[3],clone[4],clone[5],clone[6],clone[7],clone[8],clone[9]) end
 end end
end

M.LIFT=.6
function M.lift(h,r)
 if not h or h<=0 then return 0 end
 local L=math.max(0,math.min(math.floor(h*M.LIFT+.5),10,38-h))
 if r and r.lift then L=math.min(L,r.lift) end
 if r and r.maxH then L=math.max(0,math.min(L,r.maxH-h)) end
 return L
end

function M.append(p,x,z,pixel,colours,source,box,sample)
 local r=p.recipe
 local W,D=p.w,p.d
 local floor={}
 local function key(cr,cg,cb)return math.floor(cr*255+.5)*65536+math.floor(cg*255+.5)*256+math.floor(cb*255+.5)end
 for _,mid in ipairs(r.pixelGround or {})do for _,c in ipairs(colours(mid))do floor[key(c[1],c[2],c[3])]=true end end
 for _,s in ipairs(r.shadow or {})do local cr,cg,cb=pixel(s[1],s[2]);floor[key(cr,cg,cb)]=true end
 local obj,objK={},{}
 local keepMode=false
 local function is(px,py)
  if px<0 or px>=W or py<-32 or py>=D+32 then return false end
  local k=py*W+px
  local t=keepMode and objK or obj
  if t[k]==nil then
   local cr,cg,cb,ca=pixel(px,py)
   t[k]=ca>.5 and (keepMode or not floor[key(cr,cg,cb)])
  end
  return t[k]
 end
 local function runs(py,x0,x1,f)
  local s
  for px=x0,x1 do
   local on=px<x1 and is(px,py)
   if on and not s then s=px elseif not on and s then f(s,px);s=nil end
  end
 end
 for _,part in ipairs(r.parts)do
  local x0,x1,front,h,solid=part[1],part[2],part[3],part[4],part[5]
  keepMode=part[9] and true or false
  local B=part[11] or 0
  local source,box=source,box
  if B~=0 then
   local s0,b0=source,box
   local function up(q)return {q[1],q[2]+B,q[3]+B}end
   source=function(sx,sy,sw,sh,a,b,c,d)return s0(sx,sy,sw,sh,up(a),up(b),up(c),up(d))end
   box=function(xa,ya,za,xb,yb,zb,m)return b0(xa,ya+B,za+B,xb,yb+B,zb+B,m)end
  end
  if part[8]=='ball' then
   local r0=part[6] or 0
   local R=math.min(x1-x0,front+1-r0)/2
   local cxp,cyp=(x0+x1)/2,(r0+front+1)/2
   local zc=z+cyp
   for py=r0,front do for px=x0,x1-1 do
    local dx,dy=px+.5-cxp,py+.5-cyp
    local q=R*R-dx*dx-dy*dy
    if q>0 then
     local dz=math.max(.5,math.sqrt(q))
     local y1=R-dy+.5;local y0=y1-1
     local X0,X1=x+px,x+px+1
     box(X0,y0,zc-dz,X1,y1,zc+dz,sample(px,py))
     source(px,py,1,1,{X0,y1,zc+dz+.02},{X1,y1,zc+dz+.02},{X1,y0,zc+dz+.02},{X0,y0,zc+dz+.02})
    end
   end end
   goto nextpart
  end
  local first
  for py=part[6] or 0,front do for px=x0,x1-1 do if not first and is(px,py)then first=py end end end
  first=first or front
  local zb,zf=z+first+h,z+front+1+h
  local L=M.lift(h,r);local H=h+L
  local disc=part[8]=='disc'
  local ecx,erx=(x0+x1)/2,(x1-x0)/2
  local ecz,erz=(first+front+1)/2,(front-first+1)/2
  local function edge(px)
   local t=((px+.5-ecx)/erx)^2;if t>1 then return nil end
   return math.min(front,math.floor(ecz+erz*math.sqrt(1-t)-.5))
  end
  local function inside(px,py)
   if not disc then return true end
   local e=edge(px);if not e then return false end
   return py>=math.ceil(ecz-erz*math.sqrt(1-((px+.5-ecx)/erx)^2)-.5) and py<=e
  end
  local base=runs
  local function runs(py,a0,a1,f,face)
   if not disc then return base(py,a0,a1,f) end
   base(py,a0,a1,function(a,b)
    local s
    for px=a,b do
     local on=px<b and (face and edge(px) or (not face and inside(px,py)))
     if on and not s then s=px elseif not on and s then f(s,px);s=nil end
    end
   end)
  end
  if not(part[6] and part[6]>front) then
  for py=first,front do runs(py,x0,x1,function(a,b)
   local zz=z+py+h
   source(a,py,b-a,1,{x+a,H+.02,zz},{x+b,H+.02,zz},{x+b,H+.02,zz+1},{x+a,H+.02,zz+1})
  end)end
  end
  local apronEnd=front
  for py=front+1,front+h do
   local wide=false
   runs(py,x0,x1,function(a,b)if b-a>(x1-x0)*.5 then wide=true end end)
   if wide and apronEnd==py-1 then apronEnd=py else break end
  end
  local fill=part[10] or (solid and front+math.ceil(h/2) or math.min(apronEnd+1,front+h))
  local rows={}
  for py=front+1,front+h do
   rows[#rows+1]=py
   if py==fill then for _=1,L do rows[#rows+1]=py end end
  end
  for k,py in ipairs(rows)do
   local y1=H-k+1
   if disc then
    runs(py,x0,x1,function(a,b)
     for px=a,b-1 do
      local zc=z+edge(px)+1+h+.02
      source(px,py,1,1,{x+px,y1,zc},{x+px+1,y1,zc},{x+px+1,y1-1,zc},{x+px,y1-1,zc})
     end
    end,true)
   else
   runs(py,x0,x1,function(a,b)
    source(a,py,b-a,1,{x+a,y1,zf+.02},{x+b,y1,zf+.02},{x+b,y1-1,zf+.02},{x+a,y1-1,zf+.02})
   end)
   end
  end
  local function material(ra,rb,fx,fy)
   if part[12] then return sample(part[12][1],part[12][2]) end
   local count,best,bx,by={},0,fx,fy
   for py=math.max(ra,1),math.min(rb,D-2) do for px=math.max(x0,1),math.min(x1-1,W-2) do
    if is(px,py) and is(px-1,py) and is(px+1,py) and is(px,py-1) and is(px,py+1) then
     local cr,cg,cb=pixel(px,py);local k=key(cr,cg,cb)
     count[k]=(count[k] or 0)+1
     if count[k]>best then best,bx,by=count[k],px,py end
    end
   end end
   return sample(bx,by)
  end
  if solid and part[8]=='card' then
   local zback=part[7] and z+part[7] or zb
   for k,py in ipairs(rows)do
    local y1=H-k+1
    runs(py,x0,x1,function(a,b)
     source(a,py,b-a,1,{x+b,y1,zback},{x+a,y1,zback},{x+a,y1-1,zback},{x+b,y1-1,zback})
     source(a,py,1,1,{x+a,y1,zback},{x+a,y1,zf},{x+a,y1-1,zf},{x+a,y1-1,zback})
     source(b-1,py,1,1,{x+b,y1,zf},{x+b,y1,zback},{x+b,y1-1,zback},{x+b,y1-1,zf})
     source(a,py,b-a,1,{x+a,y1,zback},{x+b,y1,zback},{x+b,y1,zf},{x+a,y1,zf})
     source(a,py,b-a,1,{x+a,y1-1,zf},{x+b,y1-1,zf},{x+b,y1-1,zback},{x+a,y1-1,zback})
    end)
   end
  elseif solid and part[8] then
   local mat=material(front+1,front+h,math.floor((x0+x1)/2),math.min(front+1,D-1))
   for py=first,front do runs(py,x0,x1,function(a,b)
    box(x+a+.03,0,z+py+h+.03,x+b-.03,H,z+py+h+.97,mat)
   end)end
   if part[14] and not disc then
    local back={}
    for py=first,front do runs(py,x0,x1,function(a,b)
     for px=a,b-1 do if not back[px] then back[px]=z+py+h+.01 end end
    end)end
    for px,zz in pairs(back)do for k,fr in ipairs(rows)do
     if is(px,fr)then local y1=H-k+1
      source(px,fr,1,1,{x+px+1,y1,zz},{x+px,y1,zz},{x+px,y1-1,zz},{x+px+1,y1-1,zz})
     end
    end end
   end
   if disc then
    local mid=math.floor(ecx)
    local dark={}
    local function darkest(fr)
     if dark[fr]==nil then
      local best,bk=nil,false
      for c=x0,x1-1 do if is(c,fr)then
       local r,g,b=pixel(c,fr);local l=r*.3+g*.59+b*.11
       if not best or l<best then best,bk=l,key(r,g,b)end
      end end
      dark[fr]=bk
     end
     return dark[fr]
    end
    local function bark(col,fr)
     local step=col<=mid and 1 or -1
     local c,first=col,nil
     local dk=darkest(fr)
     while c>=x0 and c<x1 do
      if is(c,fr)then
       first=first or c
       local r,g,b=pixel(c,fr)
       if key(r,g,b)~=dk then return c end
      end
      if c==mid then break end
      c=c+step
     end
     return first
    end
    local back={}
    for py=first,front do runs(py,x0,x1,function(a,b)
     local zz=z+py+h
     for k,fr in ipairs(rows)do
      local y1=H-k+1
      local ca,cb=bark(a,fr),bark(b-1,fr)
      if ca then source(ca,fr,1,1,{x+a,y1,zz},{x+a,y1,zz+1},{x+a,y1-1,zz+1},{x+a,y1-1,zz})end
      if cb then source(cb,fr,1,1,{x+b,y1,zz+1},{x+b,y1,zz},{x+b,y1-1,zz},{x+b,y1-1,zz+1})end
     end
     for px=a,b-1 do if not back[px] then back[px]=zz end end
    end)end
    for px,zz in pairs(back)do for k,fr in ipairs(rows)do
     local y1=H-k+1
     local c=bark(px,fr)
     if c then source(c,fr,1,1,{x+px+1,y1,zz},{x+px,y1,zz},{x+px,y1-1,zz},{x+px+1,y1-1,zz})end
    end end
   end
  elseif solid then
   local mat=material(front+1,front+h,math.floor((x0+x1)/2),math.min(front+1,D-1))
   local zback=part[7] and z+part[7] or zb
   if r.wallPiece and p.wallZ and not part[7] and zb-p.wallZ>.5 and zb-p.wallZ<=16 then zback=p.wallZ end -- seated against its wall, not floating in front of it
   box(x+x0,0,zback,x+x1,H,zf,mat)
   if part[14] then
    for k,fr in ipairs(rows)do local y1=H-k+1
     for px=x0,x1-1 do if is(px,fr)then
      source(px,fr,1,1,{x+px+1,y1,zback-.02},{x+px,y1,zback-.02},{x+px,y1-1,zback-.02},{x+px+1,y1-1,zback-.02})
     end end
    end
   end
   if part[13] then
    local function edgeCol(col,step,fr)
     local c=col
     while c>=x0 and c<x1 do if is(c,fr)then return c end;c=c+step end
    end
    for k,fr in ipairs(rows)do
     local y1=H-k+1
     local ca,cb=edgeCol(x0,1,fr),edgeCol(x1-1,-1,fr)
     for zz=zback,zf-1 do
      if ca then source(ca,fr,1,1,{x+x0-.02,y1,zz},{x+x0-.02,y1,zz+1},{x+x0-.02,y1-1,zz+1},{x+x0-.02,y1-1,zz})end
      if cb then source(cb,fr,1,1,{x+x1+.02,y1,zz+1},{x+x1+.02,y1,zz},{x+x1+.02,y1-1,zz},{x+x1+.02,y1-1,zz+1})end
     end
    end
   end
   if not part[13] and part[7]~=0 then
    local function casing(col,step,fr)
     local dk,dl=nil,1e9
     for c=x0,x1-1 do if is(c,fr)then local r,g,b=pixel(c,fr);local l=r*.3+g*.59+b*.11;if l<dl then dl,dk=l,key(r,g,b)end end end
     local c,firstc=col,nil
     for _=1,3 do
      if c<x0 or c>=x1 then break end
      if is(c,fr)then firstc=firstc or c;local r,g,b=pixel(c,fr);if key(r,g,b)~=dk then return c end end
      c=c+step
     end
     return firstc
    end
    for k,fr in ipairs(rows)do
     local y1=H-k+1
     local ca,cb=casing(x0,1,fr),casing(x1-1,-1,fr)
     if ca then source(ca,fr,1,1,{x+x0-.02,y1,zback},{x+x0-.02,y1,zf},{x+x0-.02,y1-1,zf},{x+x0-.02,y1-1,zback})end
     if cb then source(cb,fr,1,1,{x+x1+.02,y1,zf},{x+x1+.02,y1,zback},{x+x1+.02,y1-1,zback},{x+x1+.02,y1-1,zf})end
     if not part[14] and ca then
      local xm=math.floor((x0+x1)/2)
      source(ca,fr,1,1,{x+xm,y1,zback-.02},{x+x0,y1,zback-.02},{x+x0,y1-1,zback-.02},{x+xm,y1-1,zback-.02})
      source(cb or ca,fr,1,1,{x+x1,y1,zback-.02},{x+xm,y1,zback-.02},{x+xm,y1-1,zback-.02},{x+x1,y1-1,zback-.02})
     end
    end
   end
  else
   local edge=material(front+1,math.max(front+1,apronEnd),math.floor((x0+x1)/2),math.min(apronEnd,D-1))
   local yb=H-math.max(1,apronEnd-front)
   for py=first,front do runs(py,x0,x1,function(a,b)
    box(x+a,H-1,z+py+h,x+b,H,z+py+h+1,edge)
   end)end
   if apronEnd>front then
    box(x+x0,yb,zb,x+x0+1,H-1,zf,edge);box(x+x1-1,yb,zb,x+x1,H-1,zf,edge)
    box(x+x0,yb,zb,x+x1,H-1,zb+1,edge)
   end
   runs(front+h,x0,x1,function(a,b)
    if b-a<=(x1-x0)*.4 then
     local mat=sample(math.floor((a+b)/2),front+h)
     local dz=b-a
     box(x+a,0,zf-dz,x+b,yb,zf,mat)
     box(x+a,0,zb,x+b,yb,zb+dz,mat)
    end
   end)
  end
  ::nextpart::
 end
 if r.wall then
  local zw=z+r.wall-.05
  for py=0,r.wall-1 do
   local y1=r.wall-py
   source(0,py,W,1,{x,y1,zw},{x+W,y1,zw},{x+W,y1-1,zw},{x,y1-1,zw})
  end
 end
end
for _,r in ipairs(M.recipes)do
 local n=r.name or ''
 if n=='em_generic_wardrobe' or n=='em_generic_kitchen' or n=='em_generic_bookshelf' or n=='em_generic_drawers' then r.wallPiece=true end
 if n:find('^em_pacif_chair') or n:find('^em_house_chair') or n:find('^em_generic_chair_e') or n:find('^em_soot_chair')
   or n=='em_player_bed' or n=='em_generic_bed' or n:find('^em_sc_stool') or n:find('^em_pyre_grave') or n:find('^em_pyre_stone') then
  for _,pt in ipairs(r.parts or {})do
   if pt[5]==true and pt[8]~='card' and pt[8]~='ball' and pt[14]==nil then pt[14]=true end
  end
 end
end
return M
