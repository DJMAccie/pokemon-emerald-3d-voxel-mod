-- Gen3Blocks
local V=...
local M={enabled=true,LEAN=.05,FILLET=4,FILLET_CUTS={.5,1,1.5,2,3,4},SEAM=.25}
M.UP_FACES=true
M.LID_REACH=3
M.TOP_LUM=.06
M.SHADE={[1]=.78,[2]=.78,[3]=.84,[4]=.72} -- east, west, south, north faces
M.RAMPS=true
M.STEPS=true -- an arrow tile is one step (wall art 1:1) instead of a 45-degree wedge (stretches the art 1.41x; Petya: no stretched tiles)
M.STAIR_SIDES=false
M.count=0
local okP,PinData=pcall(V.require,'Gen3PinData')
if not okP then PinData=nil end
local function key(x,y)return x..':'..y end
local DIRS={{1,0},{-1,0},{0,1},{0,-1}}
local RVS={{2,3},{4,1},{3,4},{1,2}}
local besideHeight

function M.pinned(def)
 local E=V.require('Gen3Elevation')
 return M.enabled and E.BLOCKS_ON and E.PINS_ON and def and def.id and not E.PIN_SKIP[def.id] and PinData and PinData.MAPS[def.id] and true or false
end

function M.prepare(cells,regions,def)
 M.count=0
 local on=M.pinned(def)
 for _,c in pairs(cells)do c.blocks=nil end
 if not on then return 0 end
 M.looseStones(cells)
 for _,c in pairs(cells)do
  local s=c.shape
  if s and (s.kind=='cliff' or s.kind=='caveWall' or s.kind=='rock') and (c.collision==nil or c.collision==7) and not s.stoneMask and not s.seaRock and not s.sea and not (c.floor and c.floor.object) and not c.bedPlanter and not c.looseStone and c.ts and c.ts.midToSlot[c.mid] then
   local mine=c.boundary and true or false
   if not mine then
    for _,r in ipairs(regions)do
     local lx,ly=c.cx-r.x,c.cy-r.y
     if lx>=0 and ly>=0 and lx<r.w and ly<r.h then mine=M.pinned(r.def);break end
    end
   end
   if mine then c.blocks=true;M.count=M.count+1 end
  end
 end
 for _,c in pairs(cells)do
  local mass=c.mass
  if mass and c.blocks and not mass.blocksMass then
   mass.blocksMass=true
   for _,m in ipairs(mass.members)do
    if not m.blocks then
     if m.shape and m.shape.kind=='cliff' and m.ts and m.ts.midToSlot[m.mid] and not m.bedPlanter then m.blocks=true;M.count=M.count+1
     else m.blocksSkip=true;local o=m.object or m.objectTop;if o then o.merged=nil end end
    end
   end
  end
 end
 M.liftSpots(cells)
 M.arrowRamps(cells,regions)
 if M.RAMPS then M.buildRamps(cells) end
 V.require('Gen3Parapet').shoulders(cells) -- the shoulders beside Sootopolis' stair flights slope down with them
 if M.SLOPES then M.buildSlopes(cells) end
 M.lowerArches(cells)
 return M.count
end
-- Loose stones (Petya 2026-11-03): a stone tile from M.STONES, in a group of at most 2x2 on level floor, is no block
-- but a round boulder (Gen3Mass domes). Tiles under 0x200 are listed under the primary tileset, the rest under the secondary.
M.LOOSE=true
local function set(t)local r={};for _,v in ipairs(t)do r[v]=true end;return r end
M.STONES={
 general=set({0x093,0x094,0x09B,0x09C,0x0DF,0x0E0,0x0E1,0x0E2}),
 fallarbor=set({0x219,0x21A,0x223,0x225}), -- ash stones (Route 113)
}
function M.isStone(c)
 local t=M.STONES[c.mid<0x200 and (c.primary or 'general') or (c.secondary or '')]
 return t and t[c.mid] or false
end
function M.looseStones(cells)
 if not M.LOOSE then return end
 local function stone(c)local s=c and c.shape
  return s and (s.kind=='cliff' or s.kind=='rock') and (c.collision==nil or c.collision==7) and not s.stoneMask and not s.seaRock and c.ts and c.ts.midToSlot[c.mid] and M.isStone(c) end
 local seen={}
 for _,c in pairs(cells)do if not seen[c] and stone(c) then
  local g,stack={},{c};seen[c]=true
  while #stack>0 do
   local q=table.remove(stack);g[#g+1]=q
   for _,d in ipairs(DIRS)do local n=cells[key(q.cx+d[1],q.cy+d[2])]
    if n and not seen[n] and stone(n) then seen[n]=true;stack[#stack+1]=n end end
  end
  local x0,y0,x1,y1=1e9,1e9,-1e9,-1e9
  for _,q in ipairs(g)do x0,y0,x1,y1=math.min(x0,q.cx),math.min(y0,q.cy),math.max(x1,q.cx),math.max(y1,q.cy) end
  local ok=x1-x0<=1 and y1-y0<=1
  local lo,hi
  if ok then
   local inside={}
   for _,q in ipairs(g)do inside[q]=true end
   for _,q in ipairs(g)do for _,d in ipairs(DIRS)do local n=cells[key(q.cx+d[1],q.cy+d[2])]
    if n and not inside[n] then
     if n.boundary then ok=false end
     local f=n.base or 0;lo=math.min(lo or f,f);hi=math.max(hi or f,f)
    end end end
   ok=ok and lo~=nil and hi-lo<.25 -- level floor all round (a stone beside a ledge stays a block for now)
  end
  if ok then for _,q in ipairs(g)do
   q.looseStone=true;q.base=lo;q.floorHigh=nil
   if q.shape.kind=='rock' then local s={};for k,v in pairs(q.shape)do s[k]=v end;s.kind='cliff';q.shape=s end
  end end
 end end
end
-- Drawn arrows (Gen3PinData height maps): each arrow tile is a 45-degree wedge rising toward the arrow; a diagonal is a corner cone.
local HIGH={N={1,2},S={3,4},E={2,3},W={1,4}}
local APEX={NW=1,NE=2,SE=3,SW=4}
-- The end of a rock row is round in the art: a straight ramp with low floor on one side and rock on the other
-- is a corner cone around its high corner on the rock side. Returns that corner or nil.
local SIDE={N={0,-1,{1,2}},S={0,1,{3,4}},E={1,0,{2,3}},W={-1,0,{1,4}}}
local PERP={N={'E','W'},S={'E','W'},E={'N','S'},W={'N','S'}}
local function roundEnd(p,lx,ly,a)
 local function at(s)
  local d=SIDE[s];local k=(lx+d[1])..':'..(ly+d[2])
  local b=p.arrows[k]
  if b then return (b.dir==a.dir and b.lo==a.lo and b.hi==a.hi) and 'rock' or nil end
  local z=p.cells[k];local h=z and p[z][3]
  if not h then return nil end
  if h<=a.lo then return 'low' end
  if h>=a.hi then return 'rock' end
 end
 local s1,s2=PERP[a.dir][1],PERP[a.dir][2]
 local t1,t2=at(s1),at(s2)
 local rock=(t1=='low' and t2=='rock') and s2 or (t2=='low' and t1=='rock') and s1
 if not rock then return nil end
 for _,i in ipairs(HIGH[a.dir])do for _,j in ipairs(SIDE[rock][3])do if i==j then return i end end end
end
function M.arrowRamps(cells,regions)
 local n,px=0,V.require('Gen3Elevation').PIN_PX
 for _,c in pairs(cells)do c.hmap=nil;if c.arrow then c.arrow=nil;c.ramp=nil end end
 for _,r in ipairs(regions)do
  local p=r.def and M.pinned(r.def) and PinData.MAPS[r.def.id]
  if p and p.arrows then
   local off=r.floorOffset or 0
   for ly=0,r.h-1 do for lx=0,r.w-1 do
    local c=cells[key(r.x+lx,r.y+ly)]
    if c then
     c.hmap=true
     c.heightmapBase=(c.floor and c.floor.height or 0)+off;c.heightmapHigh=c.floorHigh
     local a=p.arrows[math.min(lx,p.w-1)..':'..math.min(ly,p.h-1)]
     if a and c.shape and c.shape.stoneMask then
      local lo=a.lo*px+off;c.base=lo;c.heightmapBase=lo;c.floorHigh=nil;c.heightmapHigh=nil
     elseif a and c.blocks and c.layer~=15 then
      local lo,hi=a.lo*px+off,a.hi*px+off
      local q
      local ap=HIGH[a.dir] and roundEnd(p,lx,ly,a)
      if ap then q={lo,lo,lo,lo};q[ap]=hi;q.cone={apex=ap,D=hi-lo}
      elseif HIGH[a.dir] then q={lo,lo,lo,lo};for _,i in ipairs(HIGH[a.dir])do q[i]=hi end
      elseif a.inner then local o=(APEX[a.dir]+1)%4+1;q={hi,hi,hi,hi};q[o]=lo;q.cone={apex=o,D=hi-lo,inv=true}
      else local ap=APEX[a.dir];q={lo,lo,lo,lo};q[ap]=hi;q.cone={apex=ap,D=hi-lo} end
      if M.STEPS then c.base=hi;c.heightmapBase=hi;c.arrow=a else q.comp={c};c.ramp=q;c.arrow=a end
      n=n+1
     end
    end
   end end
  end
 end
 local seen={}
 for _,c in pairs(cells)do
  if c.hmap and c.shape and c.shape.stoneMask and not seen[c] then
   local g,stack={},{c};seen[c]=true
   while #stack>0 do
    local q=table.remove(stack);g[#g+1]=q
    for _,d in ipairs(DIRS)do
     local nb=cells[key(q.cx+d[1],q.cy+d[2])]
     if nb and not seen[nb] and nb.hmap and nb.shape and nb.shape.stoneMask then seen[nb]=true;stack[#stack+1]=nb end
    end
   end
   local clo,wlo
   for _,q in ipairs(g)do
    local hb=q.heightmapBase or q.base or 0
    clo=clo and math.min(clo,hb) or hb
    for _,d in ipairs(DIRS)do
     local nb=cells[key(q.cx+d[1],q.cy+d[2])]
     if nb and not (nb.shape and nb.shape.stoneMask) and ((nb.collision or 0)==0 or (nb.shape and nb.shape.kind=='water')) then
      local nh=nb.heightmapBase or nb.base or 0
      wlo=wlo and math.min(wlo,nh) or nh
     end
    end
   end
   local lo=(wlo and clo and math.min(clo,wlo)) or clo or 0
   for _,q in ipairs(g)do q.base=lo;q.heightmapBase=lo;q.floorHigh=nil;q.heightmapHigh=nil end
  end
 end
 M.arrowCells=n
end
function M.restoreHeights(cells)
 for _,c in pairs(cells)do if c.hmap then c.base=c.heightmapBase;c.floorHigh=c.heightmapHigh end end
end
-- Ramp levels come from what lies beside it, never from the field's lo/hi.
function M.buildRamps(cells)
 local comp={}
 local function higherRock(c)
  for _,d in ipairs(DIRS)do
   local o=cells[key(c.cx+d[1],c.cy+d[2])]
   if o and o.blocks and o.base and o.base>c.base+.25 and not (o.floor and o.floor.cls=='FACE') then return true end
  end
 end
 local function member(c)return c and c.blocks and not c.hmap and c.base and c.floor and c.floor.cls=='FACE' and c.floor.srcMax and c.floor.height and (c.floor.srcMax-c.floor.height>.25 or higherRock(c)) end
 local n=0
 for _,c in pairs(cells)do if not c.arrow then c.ramp=nil end end
 local function vk(x,y)return x..','..y end
 for _,c in pairs(cells)do
  if member(c) and not comp[c] then
   local list,stack={},{c};comp[c]=true
   while #stack>0 do
    local q=table.remove(stack);list[#list+1]=q
    for _,d in ipairs(DIRS)do
     local o=cells[key(q.cx+d[1],q.cy+d[2])]
     if o and not comp[o] and member(o) then comp[o]=true;stack[#stack+1]=o end
    end
   end
   local inC={};for _,q in ipairs(list)do inC[q]=true end
   local srcs,adj={},{}
   local function link(a,b)adj[a]=adj[a] or {};adj[b]=adj[b] or {};adj[a][#adj[a]+1]=b;adj[b][#adj[b]+1]=a end
   local levels={}
   for _,q in ipairs(list)do
    local x,y=q.cx,q.cy
    local E={{x+1,y,x+1,y+1},{x,y,x,y+1},{x,y+1,x+1,y+1},{x,y,x+1,y}}
    for i,d in ipairs(DIRS)do
     local e=E[i];local a,b=vk(e[1],e[2]),vk(e[3],e[4]);link(a,b)
     local o=cells[key(x+d[1],y+d[2])]
     if o and not inC[o] and not o.blocks then
      local h=besideHeight(o)
      if h then
       local lv=math.floor(h*4+.5)/4
       if not srcs[lv]then srcs[lv]={};levels[#levels+1]=lv end
       srcs[lv][a]=true;srcs[lv][b]=true
      end
     end
    end
   end
   table.sort(levels)
   local dist={}
   for _,lv in ipairs(levels)do
    local dd,head,queue={},1,{}
    for v in pairs(srcs[lv])do dd[v]=0;queue[#queue+1]=v end
    while queue[head]do local v=queue[head];head=head+1
     for _,w in ipairs(adj[v] or {})do if dd[w]==nil then dd[w]=dd[v]+1;queue[#queue+1]=w end end end
    dist[lv]=dd
   end
   local vh={}
   for v in pairs(adj)do
    local top,num,den
    for i=#levels,1,-1 do local lv=levels[i];local d=dist[lv][v]
     if d==0 then top=lv;break end
     if d then num=(num or 0)+lv/d;den=(den or 0)+1/d end
    end
    vh[v]=top or (den and num/den) or nil
   end
   do
    local topLv=levels[1];for _,lv in ipairs(levels)do if lv>topLv then topLv=lv end end
    if not topLv or topLv<list[1].base+.25 then
     local function walk(o)return o and not o.blocks and besideHeight(o) end
     local function high(o,q)return o and o.blocks and o.base and not (o.floor and o.floor.cls=='FACE') and o.base>q.base+.25 end
     local valid={}
     for i,d in ipairs(DIRS)do
      local ok=true
      for _,q in ipairs(list)do
       local far=cells[key(q.cx+d[1],q.cy+d[2])];local near=cells[key(q.cx-d[1],q.cy-d[2])]
       if not ((inC[far] or high(far,q)) and (inC[near] or walk(near))) then ok=false;break end
      end
      if ok then
       local cnt=0
       for _,q in ipairs(list)do if not inC[cells[key(q.cx+d[1],q.cy+d[2])]] then cnt=cnt+1 end end
       valid[#valid+1]={i,cnt}
      end
     end
     table.sort(valid,function(a,b)return a[2]>b[2] end)
     if #valid>=1 and (#valid==1 or valid[1][2]>valid[2][2]) then -- both axes tied = no decision
      local d=DIRS[valid[1][1]];local ax=d[1]~=0
      local runs={} -- one run per row (E-W climb) or column (N-S climb)
      for _,q in ipairs(list)do local k=ax and q.cy or q.cx;runs[k]=runs[k] or {};runs[k][#runs[k]+1]=q end
      for _,run in pairs(runs)do
       table.sort(run,function(a,b)if ax then return (a.cx-b.cx)*d[1]<0 else return (a.cy-b.cy)*d[2]<0 end end) -- near end first
       local q1,qn=run[1],run[#run]
       local near=cells[key(q1.cx-d[1],q1.cy-d[2])];local far=cells[key(qn.cx+d[1],qn.cy+d[2])]
       if walk(near) and high(far,qn) then
        local hL,hT=besideHeight(near),far.base;local n=#run
        for k,q in ipairs(run)do
         local h0=hL+(hT-hL)*(k-1)/n;local h1=hL+(hT-hL)*k/n
         local x,y=q.cx,q.cy
         if ax then
          local xn,xf=(d[1]>0) and x or x+1,(d[1]>0) and x+1 or x
          vh[vk(xn,y)]=h0;vh[vk(xn,y+1)]=h0;vh[vk(xf,y)]=h1;vh[vk(xf,y+1)]=h1
         else
          local yn,yf=(d[2]>0) and y or y+1,(d[2]>0) and y+1 or y
          vh[vk(x,yn)]=h0;vh[vk(x+1,yn)]=h0;vh[vk(x,yf)]=h1;vh[vk(x+1,yf)]=h1
         end
        end
       end
      end
     end
    end
   end
   local fallback=list[1].base
   for _,q in ipairs(list)do
    local x,y=q.cx,q.cy
    local f=(#levels==0) and q.base or nil
    q.ramp={vh[vk(x,y)] or f or fallback,vh[vk(x+1,y)] or f or fallback,vh[vk(x+1,y+1)] or f or fallback,vh[vk(x,y+1)] or f or fallback} -- NW NE SE SW
    q.ramp.comp=list
    n=n+1
   end
  end
 end
 M.rampCells=n
end

M.SPOT_MIDS={[0x33B]=true,[0x33C]=true}
function M.liftSpots(cells)
 for _,c in pairs(cells)do
  if c.blocks and c.base and M.SPOT_MIDS[c.mid] then
   local best,face=c.base,nil
   for _,d in ipairs(DIRS)do
    local o=cells[key(c.cx+d[1],c.cy+d[2])]
    if o and o.blocks and o.base then
     if o.floor and o.floor.cls=='FACE' then face=face or o
     elseif o.base>best then best=o.base end
    end
   end
   if best>c.base then c.base=best
   elseif face and c.floor and c.floor.cls~='FACE' then
    local f={};for k,v in pairs(face.floor)do f[k]=v end
    c.floor=f;c.base=face.base
   end
  end
 end
end

-- A cave door outdoors is two tiles (R-50): the threshold on the floor and the arch behind it, standing in the wall.
-- The arch tile sits at the threshold's floor so doorAt draws it once, one course high, rock above and dark inside.
M.DOOR_BEHAVIOR={[0x60]=true,[0x69]=true,[0x6E]=true,[0x6F]=true,[0x8D]=true}
function M.lowerArches(cells)
 for _,c in pairs(cells)do
  local s=c.blocks and c.base and cells[key(c.cx,c.cy+1)]
  if s and not s.blocks and s.base and M.DOOR_BEHAVIOR[s.behavior or -1] and c.base>s.base and not V.require('Gen3Parapet').keepsHeight(c) then c.base=s.base;if c.heightmapBase then c.heightmapBase=s.base end end
 end
end

M.SLOPES=true
M.SLOPE_RUN=1e9 -- px a wedge may drop in its own cell: 1e9 = whole drop in one cell, 16 = true 45 degrees.
function M.buildSlopes(cells)
 local n=0
 local function dropOf(c,d)
  local o=cells[key(c.cx+d[1],c.cy+d[2])]
  if not o or o.ramp and o.floor and o.floor.cls=='FACE' then return 0 end
  if o.stairs or (o.shape and o.shape.kind=='steps') or (o.floor and o.floor.step) then return 0 end
  local h=besideHeight(o)
  if not h then return 0 end
  local dd=c.base-h
  if dd<.25 then return 0 end
  return math.min(dd,M.SLOPE_RUN)
 end
 for _,c in pairs(cells)do
  if c.blocks and c.base and not c.ramp and not c.hmap then
   local dr={}
   for i,d in ipairs(DIRS)do dr[i]=dropOf(c,d) end
   if not (dr[1]>0 and dr[2]>0) and not (dr[3]>0 and dr[4]>0) and (dr[1]+dr[2]+dr[3]+dr[4])>0 then
    local r={c.base,c.base,c.base,c.base}
    for i=1,4 do if dr[i]>0 then for _,v in ipairs(RVS[i])do r[v]=math.min(r[v],c.base-dr[i]) end end end
    r.comp={c};r.slope=true
    for _,pr in ipairs({{1,3,1},{1,4,2},{2,3,4},{2,4,3}})do -- sides E+S -> apex NW(1), E+N -> SW(4)... see APEX
     local a,b=pr[1],pr[2]
     if dr[a]>0 and dr[b]>0 and math.abs(dr[a]-dr[b])<.25 then
      local ap={[ '13']=1,['14']=4,['23']=2,['24']=3}
      r.cone={apex=ap[a..b],D=dr[a]}
     end
    end
    c.ramp=r;n=n+1
   end
  end
 end
 for _,c in pairs(cells)do
  if c.blocks and c.base and not c.ramp and not c.hmap then
   for _,dg in ipairs({{1,1,3},{-1,1,4},{1,-1,2},{-1,-1,1}})do
    local X=cells[key(c.cx+dg[1],c.cy+dg[2])]
    local A=cells[key(c.cx+dg[1],c.cy)];local B=cells[key(c.cx,c.cy+dg[2])]
    local hx=X and besideHeight(X)
    if hx and A and B and A.blocks and B.blocks and A.base and B.base and math.abs(A.base-c.base)<.25 and math.abs(B.base-c.base)<.25 and c.base-hx>.25 then
     local D=math.min(c.base-hx,M.SLOPE_RUN)
     local r={c.base,c.base,c.base,c.base};r[dg[3]]=c.base-D
     r.comp={c};r.slope=true;r.cone={apex=dg[3],D=D,inv=true}
     c.ramp=r;n=n+1;break
    end
   end
  end
 end
 M.slopeCells=n
end

local function floorOf(n)return n.floorHigh or n.base or 0 end
function besideHeight(n)
 if not (n and n.shape) then return nil end
 if n.blocks then return n.base or 0 end
 local k=n.shape.kind
 if k=='water' then return n.base or 0 end
 if n.stairs or k=='steps' or (n.floor and n.floor.step) then return n.base or 0 end
 if (n.collision or 0)==0 then return floorOf(n) end
 return n.base or 0
end

local function lumOf(ts,mid)
 local Rock=V.require('Gen3Rock')
 ts.blocksLum=ts.blocksLum or {}
 local v=ts.blocksLum[mid]
 if v==nil then
  local t=Rock.tileArt(ts,mid);v=false
  if t and t.L then local sum=0;for k=0,255 do sum=sum+t.L[k] end;v=sum/256 end
  ts.blocksLum[mid]=v
 end
 return v or nil
end
local function massStats(mass)
 if mass.blocksStats then return mass.blocksStats end
 local Rock=V.require('Gen3Rock')
 local votes,ts={},nil
 for _,m in ipairs(mass.members)do
  if m.ts and m.mid and Rock.tileArt(m.ts,m.mid) then votes[m.mid]=(votes[m.mid] or 0)+1;ts=ts or m.ts end
 end
 local st={votes=votes,ts=ts}
 local bestTop,bn=nil,0
 for mid,n in pairs(votes)do
  local t=Rock.tileArt(ts,mid)
  if t and not t.face and not t.foliage and not t.lava and (n>bn or (n==bn and mid<bestTop)) then bestTop,bn=mid,n end
 end
 st.topLum=bestTop and lumOf(ts,bestTop) or nil
 mass.blocksStats=st
 return st
end
local function faceLike(ts,mid,st)
 local Rock=V.require('Gen3Rock')
 local t=Rock.tileArt(ts,mid)
 if not t or t.foliage or t.lava or t.void then return false end
 if t.face then return true end
 local l=st and st.topLum and lumOf(ts,mid)
 return l and l<=st.topLum-M.TOP_LUM or false
end
M.FACE_REACH=3
local function faceMid(c,cells)
 local Rock=V.require('Gen3Rock')
 local forced=Rock.FACE_TILE[Rock.mapId or '']
 if forced and c.ts.midToSlot[forced] then return forced end
 local mass=c.mass
 local st=mass and massStats(mass)
 if faceLike(c.ts,c.mid,st) then return c.mid end
 do
  local seen={[c]=true};local ring={c}
  for _=1,M.FACE_REACH do
   local nxt={};local votes,best,bn={},nil,0
   for _,q in ipairs(ring)do
    for _,d in ipairs(DIRS)do
     local n=cells[key(q.cx+d[1],q.cy+d[2])]
     if n and not seen[n] and n.blocks and n.ts==c.ts and (not mass or n.mass==mass) then
      seen[n]=true;nxt[#nxt+1]=n
      if faceLike(n.ts,n.mid,st) then votes[n.mid]=(votes[n.mid] or 0)+1;if votes[n.mid]>bn or (votes[n.mid]==bn and n.mid<best) then best,bn=n.mid,votes[n.mid] end end
     end
    end
   end
   if best then return best end
   ring=nxt;if #ring==0 then break end
  end
  if mass and mass.blocksFace==nil then
   local best,bn=nil,0
   for mid,n in pairs(st.votes)do if faceLike(st.ts,mid,st) and (n>bn or (n==bn and mid<best)) then best,bn=mid,n end end
   if best and bn<3 and bn*10<#mass.members then best=nil end -- one stray dark tile (a door, a shadow) is not the wall of a mass of hundreds (Sootopolis faces went navy)
   mass.blocksFace=best or false
  end
  if mass and mass.blocksFace then return mass.blocksFace end
 end
 return c.mid
end
-- A grass floor tile: most of its pixels are green. Its drop to lower ground is rock, never grass.
function M.grassTop(ts,mid)
 if not (ts and ts.imageData and ts.midToSlot and ts.midToSlot[mid]) then return false end
 ts.blocksGrass=ts.blocksGrass or {}
 local v=ts.blocksGrass[mid]
 if v==nil then
  local slot=ts.midToSlot[mid];local gx,gy,n=slot%ts.cols*16,math.floor(slot/ts.cols)*16,0
  for y=0,15 do for x=0,15 do local r,g,b=ts.imageData:getPixel(gx+x,gy+y);if g>r+.12 and g>b+.04 then n=n+1 end end end
  v=n>=192;ts.blocksGrass[mid]=v
 end
 return v
end
-- Terrain beside the rock belongs on the floor, not repeated down its wall.
M.BLUE_COL=.6
M.CROP_MAX=6
-- A face tile's art often carries a strip of what lies beside the rock (water, grass, sand) along an edge.
-- Edge columns and rows that are mostly not rock are cut off, so a wall shows rock only.
local function notRock(r,g,b)
 return (b>r+.15 and b>g-.05) or (g>r+.12 and g>b+.04) or (r>.78 and g>.68 and r-b>.2)
end
local function edgeCrop(ts,mid)
 ts.blocksCrop=ts.blocksCrop or {}
 local w=ts.blocksCrop[mid]
 if w then return w end
 w={0,0,0,0}
 local slot=ts.imageData and ts.midToSlot and ts.midToSlot[mid]
 if slot then
  local gx,gy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
  local col,row={},{}
  for i=0,15 do
   local nc,nr=0,0
   for j=0,15 do
    if notRock(ts.imageData:getPixel(gx+i,gy+j)) then nc=nc+1 end
    if notRock(ts.imageData:getPixel(gx+j,gy+i)) then nr=nr+1 end
   end
   col[i]=nc/16>=M.BLUE_COL;row[i]=nr/16>=M.BLUE_COL
  end
  local function ends(t,cap)
   local a,b=0,0
   while a<16 and t[a] do a=a+1 end
   while b<16-a and t[15-b] do b=b+1 end
   if a+b<=cap then return a,b end
   return 0,0
  end
  w[1],w[2]=ends(col,M.CROP_MAX);w[3],w[4]=ends(row,M.CROP_MAX)
 end
 ts.blocksCrop[mid]=w
 return w
end
-- Share of a face tile, inside its crop, that is still not rock (a corner tile with water drawn in its notch).
local function impure(ts,mid)
 ts.blocksImpure=ts.blocksImpure or {}
 local v=ts.blocksImpure[mid]
 if v then return v end
 v=0
 local slot=ts.imageData and ts.midToSlot and ts.midToSlot[mid]
 if slot then
  local gx,gy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
  local w=edgeCrop(ts,mid);local n,tot=0,0
  for y=w[3],15-w[4] do for x=w[1],15-w[2] do
   tot=tot+1;if notRock(ts.imageData:getPixel(gx+x,gy+y)) then n=n+1 end
  end end
  v=tot>0 and n/tot or 0
 end
 ts.blocksImpure[mid]=v
 return v
end
M.PURE=.03
local function grey(ts,mid) -- share of a tile that is not warm rock (the grey shadow drawn at a rock's foot)
 ts.blocksGrey=ts.blocksGrey or {}
 local v=ts.blocksGrey[mid]
 if v then return v end
 v=0
 local slot=ts.imageData and ts.midToSlot and ts.midToSlot[mid]
 if slot then
  local gx,gy=slot%ts.cols*16,math.floor(slot/ts.cols)*16;local n=0
  for y=0,15 do for x=0,15 do
   local r,g,b=ts.imageData:getPixel(gx+x,gy+y);if b>=r-.03 then n=n+1 end -- rock is warm (red over blue); the shadow is grey or bluish
  end end
  v=n/256
 end
 ts.blocksGrey[mid]=v
 return v
end
-- A rock top shows rock only: no grass strip, no foot shadow.
local function lidDirty(ts,mid)return impure(ts,mid)>M.PURE or grey(ts,mid)>.01 end
local function cropWater(ts,mid,uv)
 if not (uv and ts) then return uv end
 local w=edgeCrop(ts,mid)
 if w[1]+w[2]+w[3]+w[4]==0 then return uv end
 local function lerp(p,q,t)return {p[1]+(q[1]-p[1])*t,p[2]+(q[2]-p[2])*t} end
 local s0,s1,t0,t1=w[1]/16,1-w[2]/16,w[3]/16,1-w[4]/16
 local function at(s,t)return lerp(lerp(uv[1],uv[2],s),lerp(uv[4],uv[3],s),t) end
 return {at(s0,t0),at(s1,t0),at(s1,t1),at(s0,t1)}
end
M.LEDGE_REACH=12
M.LEDGE_VOTES=24
function M.ledgeFaceUV(c,cells,uvFor,lid)
 local slot=lid and 'lidCleanUV' or 'ledgeUV'
 if c[slot]~=nil then return c[slot] or nil end
 local seen={[c]=true};local ring={c};local votes,ts,nv={},nil,0
 for _=1,M.LEDGE_REACH do
  local nxt={}
  for _,q in ipairs(ring)do
   for _,d in ipairs(DIRS)do
    local n=cells[key(q.cx+d[1],q.cy+d[2])]
    if n and not seen[n] then
     seen[n]=true
     if n.blocks and n.ts and n.mid and not n.boundary and nv<M.LEDGE_VOTES then
      local fm=lid and n.mid or faceMid(n,cells);ts=ts or n.ts
      if n.ts==ts then votes[fm]=(votes[fm] or 0)+1;nv=nv+1 end
     end
     nxt[#nxt+1]=n
    end
   end
  end
  if nv>=M.LEDGE_VOTES or #nxt==0 then break end
  ring=nxt
 end
 local best,bn,bl
 for pass=1,2 do -- clean rock tiles first; any voted tile only when none is clean
  for mid,n in pairs(votes)do
   local l=lumOf(ts,mid) or 1
   if (pass==2 or (impure(ts,mid)<=M.PURE and not (lid and grey(ts,mid)>.01))) and (not best or n>bn or (n==bn and l<bl)) then best,bn,bl=mid,n,l end
  end
  if best then break end
 end
 local uv=best and cropWater(ts,best,uvFor(ts,best)) or nil
 c[slot]=uv or false
 return uv
end
local function topLike(c,st)
 local Rock=V.require('Gen3Rock')
 local t=Rock.tileArt(c.ts,c.mid)
 if t and t.foliage then return true end
 return not faceLike(c.ts,c.mid,st)
end
local function wet(ts,mid) -- share of a tile's pixels that are water-blue (a lid tile with a water notch)
 ts.blocksWet=ts.blocksWet or {}
 local v=ts.blocksWet[mid]
 if v then return v end
 v=0
 local slot=ts.imageData and ts.midToSlot and ts.midToSlot[mid]
 if slot then
  local gx,gy=slot%ts.cols*16,math.floor(slot/ts.cols)*16;local n=0
  for y=0,15 do for x=0,15 do
   local r,g,b=ts.imageData:getPixel(gx+x,gy+y);if b>r+.15 and b>g-.05 then n=n+1 end
  end end
  v=n/256
 end
 ts.blocksWet[mid]=v
 return v
end
local lidUV0
local function lidUV(c,cells,uvFor,st)
 local u=lidUV0(c,cells,uvFor,st,false)
 if c.ts and c.mid and wet(c.ts,c.mid)>.005 then u=lidUV0(c,cells,uvFor,st,true) or u end
 return u
end
function lidUV0(c,cells,uvFor,st,clean)
 if topLike(c,st) and not (clean and wet(c.ts,c.mid)>.005) then return uvFor(c.ts,c.mid) end
 local T=c.base or 0
 local seen={[c]=true};local ring={c}
 for _=1,M.LID_REACH do
  local nxt={}
  for _,q in ipairs(ring)do
   for _,d in ipairs({{0,-1},{-1,0},{1,0},{0,1}})do
    local n=cells[key(q.cx+d[1],q.cy+d[2])]
    if n and not seen[n] and n.shape then
     seen[n]=true
     if n.blocks then
      if math.abs((n.base or 0)-T)<=2 then
       if topLike(n,st) and not (clean and (wet(n.ts,n.mid)>.005 or impure(n.ts,n.mid)>M.PURE)) then local u=uvFor(n.ts,n.mid);if u then return u end end
       nxt[#nxt+1]=n
      end
     elseif not n.boundary and math.abs((n.floorHigh or n.base or 0)-T)<=2 and not (n.floor and n.floor.step) then
      local k=n.shape.kind
      local g=(k=='flat' or k=='grass') and (n.collision or 0)==0 and (n.shape.groundMid or n.mid) or (k=='tree' or k=='flat' or k=='grass') and n.shape.ground or nil
      if g and not clean then local u=uvFor(n.ts,g);if u then return u end end
     end
    end
   end
  end
  ring=nxt;if #ring==0 then break end
 end
 if clean then return M.ledgeFaceUV(c,cells,uvFor) or uvFor(c.ts,c.mid) end
 return uvFor(c.ts,c.mid)
end

local function insetAt(lo,hi,lean,R,y)
 if y<lo or y>hi then return 0 end
 local drop=hi-lo;if drop<=0 then return 0 end
 local o=lean*(y-lo)/drop
 if R>0 and y>hi-R then local t=(y-(hi-R))/R;o=o+R*(1-math.sqrt(math.max(0,1-t*t))) end
 return o
end
local function face(emit,uv,shade,ax,az,bx,bz,ix,iz,lo,hi,ends,plain)
 if not uv then return end
 local u1,u2,vt,vb=uv[1][1],uv[2][1],uv[1][2],uv[3][2]
 local drop=hi-lo
 local lean=plain and 0 or M.LEAN*drop
 local R=plain and 0 or math.min(M.FILLET,drop/2)
 local endA,endB=ends and ends[1],ends and ends[2]
 local ex,ez=bx-ax,bz-az;local el=math.sqrt(ex*ex+ez*ez);ex,ez=ex/el,ez/el
 local function off(y)return insetAt(lo,hi,lean,R,y) end
 -- a face reaches SEAM past its ends and under its foot, so neighbours overlap instead of leaving a hairline
 local S=plain and 0 or M.SEAM
 local function PA(y)local o,t=off(y),0;if endA then o,t=endA(y) end;return {ax+ex*(t-S)+ix*o,y<lo+1e-6 and y-S or y,az+ez*(t-S)+iz*o} end
 local function PB(y)local o,t=off(y),0;if endB then o,t=endB(y) end;return {bx-ex*(t-S)+ix*o,y<lo+1e-6 and y-S or y,bz-ez*(t-S)+iz*o} end
 local function strip(ya,yb)
  local ct=hi-math.floor((hi-ya)/16+1e-6)*16
  local va,vbv
  if ct-16<lo-1e-6 then va=vb-(vb-vt)*(ya-lo)/16;vbv=vb-(vb-vt)*(yb-lo)/16
  else va=vt+(vb-vt)*(ct-ya)/16;vbv=vt+(vb-vt)*(ct-yb)/16 end
  emit({PA(yb),PB(yb),PB(ya),PA(ya)},{{u1,vbv},{u2,vbv},{u2,va},{u1,va}},shade)
 end
 -- Faces that meet at an edge must cut it at the same heights, or the rounded tops leave hairline cracks:
 -- every face cuts its top at the same offsets below the top (FILLET_CUTS), then at its courses and breaks.
 local cuts={hi,lo}
 if not plain then for _,d in ipairs(M.FILLET_CUTS)do if hi-d>lo+1e-6 then cuts[#cuts+1]=hi-d end end end
 for y=hi-16,lo+1e-6,-16 do cuts[#cuts+1]=y end
 if ends and ends.breaks then for _,b in ipairs(ends.breaks)do if b>lo+1e-6 and b<hi-1e-6 then cuts[#cuts+1]=b end end end
 table.sort(cuts,function(p,q)return p>q end)
 local y1=hi
 for k=2,#cuts do if cuts[k]<y1-1e-4 then strip(y1,cuts[k]);y1=cuts[k] end end
end

local function rampWall(emit,uv,shade,ax,az,bx,bz,pA,pB,qA,qB,onlyOut)
 if not uv then return end
 local u1,u2,vt,vb=uv[1][1],uv[2][1],uv[1][2],uv[3][2]
 local function vOf(hh)return vb-(vb-vt)*math.min(1,math.max(0,hh)/16) end
 local function piece(x1,z1,x2,z2,p1,p2,q1,q2,out)
  if math.abs(p1-q1)<.25 and math.abs(p2-q2)<.25 then return end
  if onlyOut and not out then return end
  local lo1,lo2=math.min(p1,q1),math.min(p2,q2)
  local hi1,hi2=math.max(p1,q1),math.max(p2,q2)
  local v1,v2=vOf(hi1-lo1),vOf(hi2-lo2)
  if out then emit({{x1,lo1,z1},{x2,lo2,z2},{x2,hi2,z2},{x1,hi1,z1}},{{u1,vb},{u2,vb},{u2,v2},{u1,v1}},shade)
  else emit({{x2,lo2,z2},{x1,lo1,z1},{x1,hi1,z1},{x2,hi2,z2}},{{u2,vb},{u1,vb},{u1,v1},{u2,v2}},shade) end
 end
 local dA,dB=pA-qA,pB-qB
 if dA*dB>=0 then piece(ax,az,bx,bz,pA,pB,qA,qB,(dA+dB)>0)
 else
  local s=dA/(dA-dB);local mx,mz=ax+(bx-ax)*s,az+(bz-az)*s
  local mh=pA+(pB-pA)*s
  piece(ax,az,mx,mz,pA,mh,qA,mh,dA>0);piece(mx,mz,bx,bz,mh,pB,mh,qB,dB>0)
 end
end
local RV={{2,3},{4,1},{3,4},{1,2}}
local OPP={2,1,4,3}
local NV={{1,4},{3,2},{2,1},{4,3}}
M.STAIR_TREADS=4
local function stairFlight(n,cells)
 local f=n.floor
 if not (n.stairs or (n.shape and n.shape.kind=='steps') or (f and f.step)) or not n.base then return nil end
 for _,ax in ipairs({{{0,-1},{0,1}},{{-1,0},{1,0}}})do
  local a=cells[key(n.cx+ax[1][1],n.cy+ax[1][2])]
  local b=cells[key(n.cx+ax[2][1],n.cy+ax[2][2])]
  if a and b and a.base and b.base then
   local B=n.base
   local da,db=a.base-B,b.base-B
   local up,dhi,dlo
   if da>.5 and db<-.5 then up,dhi,dlo=ax[1],a,b elseif db>.5 and da<-.5 then up,dhi,dlo=ax[2],b,a end
   if up then
    local R=dhi.base-B
    if dlo.base<B-.5 and not (dlo.floor and dlo.floor.step) and not (dhi.floor and dhi.floor.step) then B=dlo.base;R=dhi.base-B end
    return {up=up,foot=B,rise=R}
   end
  end
 end
 return nil
end
local function stairSide(emit,uv,shade,n,fl,ax,az,bx,bz,pA,pB)
 local T=M.STAIR_TREADS
 local nx0,nz0=n.cx*16,n.cy*16
 local function tOf(x,z) -- depth from the flight's lower edge, 0..16
  if fl.up[1]~=0 then return fl.up[1]>0 and (x-nx0) or (nx0+16-x) end
  return fl.up[2]>0 and (z-nz0) or (nz0+16-z)
 end
 local ta,tb=tOf(ax,az),tOf(bx,bz)
 local function lerp(s)return ax+(bx-ax)*s,az+(bz-az)*s,pA+(pB-pA)*s end
 if math.abs(ta-tb)<.01 then
  local k=ta<8 and 0 or T-1
  local H=fl.foot+(k+1)*fl.rise/T
  rampWall(emit,uv,shade,ax,az,bx,bz,pA,pB,math.max(H,pA),math.max(H,pB),false)
  return
 end
 for k=0,T-1 do
  local s0,s1=(16*k/T-ta)/(tb-ta),(16*(k+1)/T-ta)/(tb-ta)
  if s0>s1 then s0,s1=s1,s0 end
  local x1,z1,p1=lerp(s0);local x2,z2,p2=lerp(s1)
  local H=fl.foot+(k+1)*fl.rise/T
  rampWall(emit,uv,shade,x1,z1,x2,z2,p1,p2,math.max(H,p1),math.max(H,p2),false)
 end
end
local function appendRamp(c,cells,emit,uvFor)
 local r=c.ramp;local x,z=c.cx*16,c.cy*16
 local lid=uvFor(c.ts,c.mid);local fm=faceMid(c,cells);local fuv=fm and cropWater(c.ts,fm,uvFor(c.ts,fm)) or lid
 if impure(c.ts,fm or c.mid)>M.PURE then fuv=M.ledgeFaceUV(c,cells,uvFor) or fuv end
 if r.slope and not M.SPOT_MIDS[c.mid] then lid=fuv
 elseif c.ts and c.mid and wet(c.ts,c.mid)>.005 then lid=lidUV0(c,cells,uvFor,c.mass and massStats(c.mass) or nil,true) or lid -- a water notch in the lid art
 elseif c.floor and c.floor.cls=='FACE' and c.ts and c.mid and lidDirty(c.ts,c.mid) then lid=M.ledgeFaceUV(c,cells,uvFor,true) or lid end
 local Parapet=V.require('Gen3Parapet');local par=Parapet.is(c)
 if par then lid,fuv=Parapet.lid(c,uvFor) or lid,Parapet.face(c,uvFor) or fuv end
 if r.cone then
  local ax,az=({x,x+16,x+16,x})[r.cone.apex],({z,z,z+16,z+16})[r.cone.apex]
  local D=r.cone.D;local k=D/16;local T=r[1]>r[2] and r[1] or r[2];T=math.max(r[1],r[2],r[3],r[4])
  local N=6
  local inv=r.cone.inv
  local function hAt(px,pz)local d=math.sqrt((px-ax)^2+(pz-az)^2);if inv then return T-D+math.min(D,k*d) end;return T-math.min(D,k*d) end
  local function uvAt(u,v)
   local function mix(i,j)return lid[i][j]*(1-u)*(1-v)+lid[2][j]*u*(1-v)+lid[3][j]*u*v+lid[4][j]*(1-u)*v end
   return {mix(1,1),mix(1,2)}
  end
  for i=0,N-1 do for j=0,N-1 do
   local u0,u1,v0,v1=i/N,(i+1)/N,j/N,(j+1)/N
   local P={{x+16*u0,z+16*v0},{x+16*u1,z+16*v0},{x+16*u1,z+16*v1},{x+16*u0,z+16*v1}}
   local Q={{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
   local vs,uvs={},{}
   for t=1,4 do vs[t]={P[t][1],hAt(P[t][1],P[t][2]),P[t][2]};uvs[t]=uvAt(Q[t][1],Q[t][2]) end
   emit(vs,uvs,1)
  end end
 else
 emit({{x,r[1],z},{x+16,r[2],z},{x+16,r[3],z+16},{x,r[4],z+16}},lid,1)
 end
 for i,d in ipairs(DIRS)do
  local n=cells[key(c.cx+d[1],c.cy+d[2])]
  if n and not (n.ramp and n.ramp.comp==r.comp) then
   local h=besideHeight(n)
   if h then
    local ax,az,bx,bz
    if i==1 then ax,az,bx,bz=x+16,z,x+16,z+16 elseif i==2 then ax,az,bx,bz=x,z+16,x,z elseif i==3 then ax,az,bx,bz=x+16,z+16,x,z+16 else ax,az,bx,bz=x,z,x+16,z end
    local qA,qB=h,h
    if n.ramp then qA,qB=n.ramp[NV[i][1]],n.ramp[NV[i][2]] end
    rampWall(emit,fuv,M.SHADE[i],ax,az,bx,bz,r[RV[i][1]],r[RV[i][2]],qA,qB,n.blocks and true or false)
    local fl=M.STAIR_SIDES and stairFlight(n,cells)
    if fl then stairSide(emit,fuv,M.SHADE[i],n,fl,ax,az,bx,bz,r[RV[i][1]],r[RV[i][2]]) end
   end
  end
 end
 if par then Parapet.append(c,cells,emit,uvFor,c.base or r[1]) end
 return true
end
-- A doorway tile has a dark opening at its foot; a rock tile with a grey foot shadow there is no door.
local function darkHole(ts,mid)
 ts.blocksHole=ts.blocksHole or {}
 local v=ts.blocksHole[mid]
 if v==nil then
  v=false
  local slot=ts.imageData and ts.midToSlot and ts.midToSlot[mid]
  if slot then
   local gx,gy,l=slot%ts.cols*16,math.floor(slot/ts.cols)*16,0
   for y=12,14 do for x=7,8 do local r,g,b=ts.imageData:getPixel(gx+x,gy+y);l=l+.3*r+.59*g+.11*b end end
   v=l/6<.25
  end
  ts.blocksHole[mid]=v
 end
 return v
end
function M.append(c,cells,emit,uvFor)
 if c.ramp then return appendRamp(c,cells,emit,uvFor) end
 local T=c.base or 0
 local x,z=c.cx*16,c.cy*16
 local fm=faceMid(c,cells)
 local E=V.require('Gen3Elevation')
 local lid=(E.BAND_LEVEL=='lower' and c.floor and c.floor.cls=='FACE') and uvFor(c.ts,c.mid) or lidUV(c,cells,uvFor,c.mass and massStats(c.mass) or nil)
 if c.ts and c.mid and wet(c.ts,c.mid)>.005 then lid=lidUV0(c,cells,uvFor,c.mass and massStats(c.mass) or nil,true) or lid
 elseif c.floor and c.floor.cls=='FACE' and c.ts and c.mid and lidDirty(c.ts,c.mid) then lid=M.ledgeFaceUV(c,cells,uvFor,true) or cropWater(c.ts,c.mid,lid) end
 local fuv=cropWater(c.ts,fm or c.mid,fm and uvFor(c.ts,fm) or uvFor(c.ts,c.mid))
 if impure(c.ts,fm or c.mid)>M.PURE then fuv=M.ledgeFaceUV(c,cells,uvFor) or fuv end -- a notched corner tile: the ridge's clean rock instead
 local Parapet=V.require('Gen3Parapet');local par=Parapet.is(c)
 if par then lid,fuv=Parapet.lid(c,uvFor) or lid,Parapet.face(c,uvFor) or fuv end -- a stone railing: plain floor under it, rock walls, the rail stands on top
 local drops={}
 local nb,top={},{}
 for i,d in ipairs(DIRS)do
  local n=cells[key(c.cx+d[1],c.cy+d[2])];nb[i]=n
  local h=besideHeight(n);top[i]=h
  if h and n.ramp then
   local qA,qB=n.ramp[NV[i][1]],n.ramp[NV[i][2]]
   top[i]=math.min(h,qA,qB)
   local H=math.min(T,math.max(qA,qB))
   if math.min(qA,qB)<H-.25 then
    local o=OPP[i];local X,Z=n.cx*16,n.cy*16;local ax,az,bx,bz
    if o==1 then ax,az,bx,bz=X+16,Z,X+16,Z+16 elseif o==2 then ax,az,bx,bz=X,Z+16,X,Z elseif o==3 then ax,az,bx,bz=X+16,Z+16,X,Z+16 else ax,az,bx,bz=X,Z,X+16,Z end
    rampWall(emit,fuv,M.SHADE[i],ax,az,bx,bz,math.min(n.ramp[RV[o][1]],H),math.min(n.ramp[RV[o][2]],H),H,H,false)
   end
   h=H
  end
  if h and h<T-.25 then drops[i]=h end
 end
 -- A doorway is two tiles: the arch (this face tile, at the foot of a higher wall) and the floor in front of it.
 -- The arch stands once in the wall, one course high; above it plain rock, the floor inside it dark.
 local function doorAt(q,qn)return faceMid(q,cells)==q.mid and darkHole(q.ts,q.mid) and qn[4] and qn[3] and not qn[3].blocks and (besideHeight(qn[4]) or (q.base or 0))>(q.base or 0)+15.75 end
 local door=doorAt(c,nb)
 if door then
  -- the floor inside the opening is the arch's own dark (a patch from the middle of its hole)
  local a=uvFor(c.ts,c.mid)
  local function at(u,v)local function m(j)return a[1][j]*(1-u)*(1-v)+a[2][j]*u*(1-v)+a[3][j]*u*v+a[4][j]*(1-u)*v end;return {m(1),m(2)} end
  lid={at(.45,.8),at(.55,.8),at(.55,.9),at(.45,.9)}
 end
 local lean,R=M.LEAN,M.FILLET
 local function insetOwn(i,y)local h=drops[i];if not h then return 0 end;local drop=T-h;return insetAt(h,T,lean*drop,math.min(R,drop/2),y) end
 local function rampAt(o,px,py)local r=o.ramp;local dx,dy=px-o.cx,py-o.cy
  return r[(dy==0) and (dx==0 and 1 or 2) or (dx==1 and 3 or 4)] end
 local function endAt(i,j)
  local n,q=nb[j],cells[key(c.cx+DIRS[i][1]+DIRS[j][1],c.cy+DIRS[i][2]+DIRS[j][2])]
  local px,py=c.cx+((i==1 or j==1) and 1 or 0),c.cy+((i==3 or j==3) and 1 or 0)
  local hn,hq,he=top[j],besideHeight(q),drops[i] or T
  if n and n.ramp then hn=rampAt(n,px,py) end
  if q and q.ramp then hq=rampAt(q,px,py) end
  return function(y)
   local nS=hn and hn>=y-.25
   local qS=hq and hq>=y-.25
   if nS and qS then return 0,0 end
   if nS then
    if n.blocks and not n.ramp then
     local lo=math.min(he,hq or he);local hi=math.min(hn,T);local d=hi-lo
     if d<=0 then return 0,0 end
     return insetAt(lo,hi,lean*d,math.abs(hn-T)<.25 and math.min(R,d/2) or 0,y),0
    end
    return 0,0
   end
   if qS then return 0,0 end
   return insetOwn(i,y),insetOwn(j,y)
  end
 end
 local function ins(i,j)if not drops[i] then return 0 end;local o=endAt(i,j)(T);return o-M.SEAM end
 emit({{x+ins(2,4),T,z+ins(4,2)},{x+16-ins(1,4),T,z+ins(4,1)},{x+16-ins(1,3),T,z+16-ins(3,1)},{x+ins(2,3),T,z+16-ins(3,2)}},lid,1)
 local function ends(i,ja,jb)
  local b={}
  for _,j in ipairs({ja,jb})do local h=top[j];if h and h>drops[i]+.25 and h<T-.25 then b[#b+1]=h end
   local q=cells[key(c.cx+DIRS[i][1]+DIRS[j][1],c.cy+DIRS[i][2]+DIRS[j][2])];local hq=besideHeight(q);if hq and hq>drops[i]+.25 and hq<T-.25 then b[#b+1]=hq end end
  return {endAt(i,ja),endAt(i,jb),breaks=b}
 end
 if drops[1] then face(emit,fuv,M.SHADE[1],x+16,z,x+16,z+16,-1,0,drops[1],T,ends(1,4,3)) end
 if drops[2] then face(emit,fuv,M.SHADE[2],x,z+16,x,z,1,0,drops[2],T,ends(2,3,4)) end
 local below=nb[3]
 if drops[3] and below and below.blocks and not below.ramp and math.abs(drops[3]-(below.base or 0))<.25 and T>drops[3]+16.25 then
  local bn={}
  for i,d in ipairs(DIRS)do bn[i]=cells[key(below.cx+d[1],below.cy+d[2])] end
  if doorAt(below,bn) then
   local e=ends(3,2,1)
   face(emit,uvFor(below.ts,below.mid),M.SHADE[3],x,z+16,x+16,z+16,0,-1,drops[3],drops[3]+16,e)
   face(emit,M.ledgeFaceUV(below,cells,uvFor) or fuv,M.SHADE[3],x,z+16,x+16,z+16,0,-1,drops[3]+16,T,e)
   drops[3]=nil
  end
 end
 if drops[3] then face(emit,fuv,M.SHADE[3],x,z+16,x+16,z+16,0,-1,drops[3],T,ends(3,2,1)) end
 if drops[4] then face(emit,fuv,M.SHADE[4],x+16,z,x,z,0,1,drops[4],T,ends(4,1,2)) end
 if M.UP_FACES then
  for i,d in ipairs(DIRS)do
   local n=nb[i]
   if n and not n.blocks then
    local h=besideHeight(n)
    if h and n.ramp then
     local qA,qB=n.ramp[NV[i][1]],n.ramp[NV[i][2]]
     if math.max(qA,qB)>T+.25 then
      local ax,az,bx,bz
      if i==1 then ax,az,bx,bz=x+16,z,x+16,z+16 elseif i==2 then ax,az,bx,bz=x,z+16,x,z elseif i==3 then ax,az,bx,bz=x+16,z+16,x,z+16 else ax,az,bx,bz=x,z,x+16,z end
      rampWall(emit,fuv,M.SHADE[i],ax,az,bx,bz,T,T,qA,qB,false)
     end
    elseif h and h>T+.25 then
     if i==1 then face(emit,fuv,M.SHADE[2],x+16,z+16,x+16,z,1,0,T,h,nil,true)
     elseif i==2 then face(emit,fuv,M.SHADE[1],x,z,x,z+16,-1,0,T,h,nil,true)
     elseif i==3 then face(emit,fuv,M.SHADE[4],x+16,z+16,x,z+16,0,1,T,h,nil,true)
     elseif door then
      face(emit,fuv,M.SHADE[3],x,z,x+16,z,0,-1,T,math.min(h,T+16),nil,true)
      if h>T+16.25 then face(emit,M.ledgeFaceUV(c,cells,uvFor) or fuv,M.SHADE[3],x,z,x+16,z,0,-1,T+16,h,nil,true) end
     else face(emit,fuv,M.SHADE[3],x,z,x+16,z,0,-1,T,h,nil,true) end
    end
   end
  end
 end
 if par then Parapet.append(c,cells,emit,uvFor,T) end
 return true
end
return M
