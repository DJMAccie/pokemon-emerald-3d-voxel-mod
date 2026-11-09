-- Physical support from native stair topology and reviewed source surfaces
local V=...
local Levels=V.require('TerrainLevels')
local Pairs=V.require('Gen3Tilesets')
local cache=setmetatable({},{__mode='k'})
local M={}
local okP,PinData=pcall(V.require,'Gen3PinData')
if not okP then PinData=nil end
M.PINS_ON=true
M.pinZones={}
M.CONNECTOR_MAX=12
M.BLOCKED_MARK_REACH=8
M.TREE_SETTLE={EM_ROUTE120={{35,38,85,86,0},{34,34,85,86,1}},EM_ROUTE111={{12,12,131,131,1}}}
M.BLOCKED_WATER=true
M.WATER_LEGS={fortree={[0x0F5]=true,[0x0F8]=true,[0x0F9]=true,[0x0FA]=true,[0x0FC]=true}}
M.WATER_DECKS={fortree={[0x0ED]=true,[0x0F0]=true,[0x0F1]=true,[0x0F2]=true,[0x0FB]=true,[0x0E8]=true,[0x0EC]=true,[0x0F3]=true,[0x0F4]=true,[0x0F7]=true,[0x0FD]=true}}
M.PIN_PX=16
M.PIN_SKIP={}
M.BLOCKS_ON=true
M.BLOCKS_SLACK=2
M.SLOPE_DEG=45
M.PLAIN_GRASS_MIDS={[0x001]=true,[0x002]=true}
M.ORPHAN_MAX=24
M.STAIR_EXT=true -- the foot extension of steep flights
M.STAIR_PROFILE=true -- stair profile pass (R-34)
M.LEDGES=true;M.LEDGE_MIN=8;M.LEDGE_MAX=3 -- hidden ledges (R-35): rock wedge on the lower cell of an unbanded plateau edge
M.LEDGE_SKIP={EM_FORTREE_CITY=true}
M.BAND_LEVEL='lower'
M.POCKET_MAX=12
M.BLOCKS_RMAX=12
M.classes={} -- mapId -> class counts of the last classify (gate)
M.MAX_FLIGHT=4
M.COURSE=16
M.MAX_STEP=3
M.COURSE_BY_MAP={EM_FORTREE_CITY=32,EM_ROUTE110=48}
M.ELEV_REMAP={EM_FORTREE_CITY={[15]=4},EM_ROUTE110={[15]=4},EM_ROUTE109={[4]=3},
 EM_ROUTE119={[15]=4}}
M.STEP_MIDS={EM_ROUTE110={[0x2D4]=true}}
M.PAIR_STEP_MIDS={general__cave={[0x204]=true}} -- the cave's stair metatile (Victory Road, ...): a run of steps between two floors, whatever the map
for id,d in pairs(V.require('Gen3Decks').MAPS)do M.STEP_MIDS[id]=d.steps end
local FLIGHT_TREADS={general__mauville={[0x2D4]=8},general__mossdeep={[0xAF]=2,[0xCF]=2},general__lilycove={[0xAF]=2,[0xCF]=2},general__sootopolis={[0x244]=2,[0x245]=2}}
M.DAIS={EM_LILYCOVE_CITY_CONTEST_HALL={h=10,rects={{18,7,32,16},{6,19,20,28},{30,19,44,28}},
 steps={[0x283]=true,[0x284]=true,[0x285]=true,[0x293]=true,[0x294]=true,[0x295]=true,[0x2B3]=true,[0x2B4]=true,[0x2B5]=true},
 furniture={[0x26F]=true,[0x277]=true,[0x268]=true,[0x269]=true,[0x26A]=true,[0x270]=true,[0x272]=true,[0x278]=true,[0x279]=true,[0x27A]=true}}}
M.DAIS.EM_BATTLE_FRONTIER_BATTLE_ARENA_LOBBY={h=8,rects={{0,3,15,7}},steps={},
 mids={[0x201]=true,[0x21F]=true,[0x223]=true,[0x224]=true,[0x225]=true,[0x226]=true,[0x215]=true,[0x216]=true}}
do
 local hall={h=48,anySteps=true,steps={[0x2E1]=true,[0x2E2]=true,[0x2D9]=true,[0x2DA]=true},low={[0x2E7]=true}}
 for n=1,5 do local d={};for k,v in pairs(hall)do d[k]=v end;d.rects={{0,3,10,4}};M.DAIS['EM_EVER_GRANDE_CITY_HALL'..n]=d end
end
local function daisAt(d,x,y,mid)
 if d.mids and mid and not d.mids[mid] then return false end
 for _,r in ipairs(d.rects)do if x>=r[1] and x<=r[3] and y>=r[2] and y<=r[4] then return true end end
end
function M.daisPrepare(cells,def)
 local d=def and M.DAIS[def.id];if not d then return end
 for _,c in pairs(cells)do
  if daisAt(d,c.cx,c.cy,c.mid) then
   c.shape=d.steps[c.mid] and {kind='steps',height=6} or {kind='flat',reviewedSurface=true}
   if not (d.furniture and d.furniture[c.mid]) then c.noFurniture=true end
  elseif d.anySteps and d.steps[c.mid] then
   c.shape={kind='steps',height=6};c.noFurniture=true
  end
 end
end
function M.daisSettle(cells,def)
 local d=def and M.DAIS[def.id];if not d then return end
 if d.low then for _,c in pairs(cells)do if d.low[c.mid] then c.base=0 end end end
 if d.furniture then
  for _,c in pairs(cells)do
   if d.furniture[c.mid] and daisAt(d,c.cx,c.cy,c.mid) then
    c.base=d.h
    if c.prop then c.prop.groundHeight=d.h end
   end
  end
 end
end
M.RAISED={EM_ROUTE110_TRICK_HOUSE_ENTRANCE={y0=0,y1=6,h=8},
 EM_ROUTE111_OLD_LADYS_REST_STOP={y0=0,y1=6,h=8}} -- same tatami step
M.SINK_MAPS={EM_MOSSDEEP_CITY=16}
M.MARKER_CELLS=4
local blocked={{[0x30]=true,[0x34]=true,[0x36]=true},{[0x31]=true,[0x35]=true,[0x37]=true},
 {[0x33]=true,[0x36]=true,[0x37]=true},{[0x32]=true,[0x34]=true,[0x35]=true}}
local opposite={2,1,4,3}
function M.field(def)
 local l=def and def.midLayout;if not l then return end
 local keys={};for k in pairs(l.overrides or {})do keys[#keys+1]=k end;table.sort(keys)
 local edits={tostring(l.cells),tostring(l.width),tostring(l.height),tostring(l.pair),tostring(def.id)};for _,k in ipairs(keys)do local c=l.overrides[k];edits[#edits+1]=table.concat({k,c.mid or 0,c.coll or 255,c.elev or 0},',')end
 local signature=table.concat(edits,';');local old=cache[l]
 if old and old.signature==signature then return old end
 local behaviors=require('src.core.game3.scripting.interaction_scripts').behaviors[l.pair]or{}
 local spec=Pairs.resolve(l.pair,require('src.import.gba.versions').TILESET_PAIRS)
 local shapes=V.require('Gen3TileShape')
 local drawn=M.PINS_ON and not M.PIN_SKIP[def.id] and PinData and PinData.MAPS[def.id]
 if drawn and drawn.cells then
  assert(l.width>=drawn.w and l.width<=drawn.w+1 and l.height>=drawn.h and l.height<=drawn.h+1,'Height-map dimensions disagree with '..def.id)
  local f={width=l.width,height=l.height,cells={},groups={},flights={},conflicts={},classes={},signature=signature}
  local dirs={N={0,-1},S={0,1},E={1,0},W={-1,0}}
  local byMap=V.require('Gen3ShapesByMap').shapes[def.id]
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y);local k=math.min(x,drawn.w-1)..':'..math.min(y,drawn.h-1)
   local zi,a,fall=drawn.cells[k],drawn.arrows[k],drawn.waterfalls[k]
   local h=zi and drawn[zi][3]*M.PIN_PX or a and (a.lo+a.hi)*M.PIN_PX/2 or 0
   local shape=shapes.of(spec.primary,spec.secondary,raw.mid,behaviors[raw.mid],raw.coll)
   local cls=a and 'FACE' or shape.kind=='water' and 'WATER' or raw.elev==15 and 'DECK' or shape.kind=='cliff' and 'MASS' or 'PLATEAU'
   if not (zi or a) then cls='OTHER' end
   local c={x=x,y=y,height=h,pin=h,anchor=true,kind=shape.kind,layer=raw.elev,behavior=behaviors[raw.mid],
    floor=zi~=nil and raw.coll~=7,lathe=type(byMap)=='table' and type(byMap[raw.mid])=='table' and byMap[raw.mid].kind=='lathe',cls=cls,waterfall=fall~=nil,object=drawn.objects[k],zone=zi,step=a and a.stairs or false}
   if c.step then c.low=a.lo*M.PIN_PX;c.high=a.hi*M.PIN_PX;c.height=c.low;c.stairUp=dirs[a.dir];c.treads=4 end
   f.cells[Levels.key(x,y)]=c;f.classes[cls]=(f.classes[cls] or 0)+1
  end end
  -- an object pin whose object is gone (plain walkable ground) or a lathe (draws itself whole) takes the ground around it
  local seen={}
  for _,c0 in pairs(f.cells)do if c0.object and not seen[c0] then
   local group,stack,gone,ground={},{c0},true,nil;seen[c0]=true
   while #stack>0 do local c=table.remove(stack);group[#group+1]=c
    if not (c.lathe or (c.floor and c.kind=='flat')) then gone=false end
    for _,d in pairs(dirs)do local n=f.cells[Levels.key(c.x+d[1],c.y+d[2])]
     if n and n.object and n.height==c.height then if not seen[n] then seen[n]=true;stack[#stack+1]=n end
     elseif n and n.cls=='PLATEAU' and not n.object then ground=math.min(ground or n.height,n.height) end
    end
   end
   if gone and ground and ground<c0.height then for _,c in ipairs(group)do c.height,c.pin,c.object=ground,ground,nil end;M.goneObjects=(M.goneObjects or 0)+#group end
  end end
  M.classes[def.id]=f.classes;cache[l]=f;return f
 end
 local drop={[0x38]={1,0},[0x39]={-1,0},[0x3A]={0,-1},[0x3B]={0,1}}
 local pins
 local StairT=V.data('gen3_stair_terraces')
 local gen=StairT[def.id]
 local stairCells={}
 local zoneOf={}
 local keepRated=false
 if gen then
  for _,c in ipairs(gen.stairs)do stairCells[c[1]..':'..c[2]]=true end
  local function floodPin(zi,row,h)
   local a0=l:cellAt(row[1],row[2])
   local zone=row[4]=='zone';local box=zone and row[5]
   local function inZone(n,nx,ny)
    if not zone then return true end
    if box and (nx<box[1] or ny<box[2] or nx>box[3] or ny>box[4]) then return false end
    local beh=behaviors[n.mid]
    if beh and ((beh>=0x38 and beh<=0x3F) or beh==0x2A or beh==0x1D0) then return false end
    return shapes.of(spec.primary,spec.secondary,n.mid,beh,n.coll).kind~='water'
   end
   local stack,seen={{row[1],row[2]}},{[row[1]..':'..row[2]]=true}
   while #stack>0 do local q=table.remove(stack);pins[q[1]..':'..q[2]]=h
    if zone then zoneOf[q[1]..':'..q[2]]=zi end
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local nx,ny=q[1]+d[1],q[2]+d[2];local k=nx..':'..ny
     local n=not seen[k] and nx>=0 and ny>=0 and nx<l.width and ny<l.height and l:cellAt(nx,ny)
     if n and n.coll~=7 and n.elev==a0.elev and not stairCells[k] and n.mid~=0xAF and n.mid~=0xCF and n.mid~=0xE8 and inZone(n,nx,ny) then seen[k]=true;stack[#stack+1]={nx,ny} end
    end
   end
  end

  if gen.on then
   pins=pins or {};keepRated=true
   for zi,row in ipairs(gen.pins)do floodPin(zi,row,row[3]*(gen.rise or 16)) end
   for _,c in ipairs(gen.cells or {})do
    local x0,y0,x1,y1,lv=c[1],c[2],c[1],c[2],c[3]
    if c[5] then x1,y1,lv=c[3],c[4],c[5] end
    for y=y0,y1 do for x=x0,x1 do pins[x..':'..y]=lv*(gen.rise or 16) end end
   end
  else
   for zi,row in ipairs(gen.pins)do pins=pins or {}
    local h=row[3]*(gen.rise or StairT.rise)
    if row[4]=='zone' then floodPin(zi,row,h) else pins[row[1]..':'..row[2]]=h end
   end
   for _,c in ipairs(gen.cells or {})do
    local x0,y0,x1,y1,lv=c[1],c[2],c[1],c[2],c[3]
    if c[5] then x1,y1,lv=c[3],c[4],c[5] end
    for y=y0,y1 do for x=x0,x1 do pins[x..':'..y]=lv*(gen.rise or StairT.rise) end end
   end
  end
 end
 local dais=M.DAIS[def.id]
 if dais then
  pins=pins or {}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if daisAt(dais,x,y,raw and raw.mid) then
    if not dais.steps[raw.mid] then pins[x..':'..y]=dais.h;stairCells[x..':'..y]=nil end
   elseif raw and raw.coll~=7 then pins[x..':'..y]=0 end
  end end
 end
 local decks=V.require('Gen3Decks').MAPS[def.id]
 if decks then
  pins=pins or {}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   local h=x<(decks.w or 1e9) and y<(decks.h or 1e9) and ((decks.pinAt and decks.pinAt(x,y)) or decks.wall(x,y) or decks.level(x,y))
   if h and raw and not (decks.steps[raw.mid] and raw.coll==0) then pins[x..':'..y]=h end
  end end
 end
 local raised=M.RAISED[def.id]
 if not raised and tostring(l.pair):find('generic_building') then
  for y=0,l.height-1 do
   local n=0
   for x=0,l.width-1 do local r=l:cellAt(x,y);if r and r.mid==0x318 then n=n+1 end end
   if n>=4 then raised={y0=0,y1=y,h=8};break end
  end
 end
 if raised then
  pins=pins or {}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if raw and raw.coll~=7 then pins[x..':'..y]=(y>=raised.y0 and y<=raised.y1) and raised.h or 0 end
  end end
 end
 local flatIn={}
 if tonumber(def.mapType)==8 then
  local seen={}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if raw and raw.coll==0 and raw.elev>=4 and raw.elev~=15 and not seen[x..':'..y] then
    local list,stack={}, {{x,y}};seen[x..':'..y]=true
    while #stack>0 do local p=table.remove(stack);list[#list+1]=p
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local nx,ny=p[1]+d[1],p[2]+d[2];local n=l:cellAt(nx,ny)
      if n and n.coll==0 and n.elev==raw.elev and not seen[nx..':'..ny] then seen[nx..':'..ny]=true;stack[#stack+1]={nx,ny} end
     end
    end
    if #list<=M.MARKER_CELLS then for _,p in ipairs(list)do flatIn[p[1]..':'..p[2]]=3 end end
   end
  end end
 end
 local function elevAt(x,y,n)return flatIn[x..':'..y] or n.elev end
 local climb={}
 -- Elevation-0 plain grass between floors is a walk-through, not a stair.
 local sparse=V.sparseHeightmaps
 local userPins=sparse and sparse.marks[def.id]
 local plainGrass=userPins and M.PLAIN_GRASS_MIDS or {}
 do
  local decks={{1,0},{-1,0},{0,1},{0,-1}}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if raw and raw.coll==0 and raw.elev==0 then
    local lo,hi
    for _,d in ipairs(decks)do
     local n=l:cellAt(x+d[1],y+d[2])
     if n and n.coll==0 and n.elev>=3 then local e=elevAt(x+d[1],y+d[2],n);lo=math.min(lo or e,e);hi=math.max(hi or e,e) end
    end
    if (lo and hi and hi>lo and not plainGrass[raw.mid]) or stairCells[x..':'..y] then climb[x..':'..y]=true end
   end
  end end
  local function flat(x,y)local r=l:cellAt(x,y);return r and r.coll==0 and r.elev==0 end
  local function floorAt(x,y)local r=l:cellAt(x,y);return r and r.coll==0 and r.elev>=3 and elevAt(x,y,r) or nil end
  for _,d in ipairs({{0,1},{1,0}})do
   for y=0,l.height-1 do for x=0,l.width-1 do
    if flat(x,y) and not flat(x-d[1],y-d[2]) then
     local n,ex,ey=0,x,y
     while flat(ex,ey) and n<=M.MAX_FLIGHT do n=n+1;ex,ey=ex+d[1],ey+d[2] end
     local a,b=floorAt(x-d[1],y-d[2]),floorAt(ex,ey)
     if a and b and a~=b and n<=M.MAX_FLIGHT and n>=2 then
      for k=0,n-1 do local q=l:cellAt(x+d[1]*k,y+d[2]*k);if not plainGrass[q.mid] then climb[(x+d[1]*k)..':'..(y+d[2]*k)]=true end end
     end
    end
   end end
  end
 end
 local relevel={}
 do
  local seen={}
  local dirs={{1,0},{-1,0},{0,1},{0,-1}}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if raw and raw.coll==0 and raw.elev==15 and not seen[x..':'..y] then
    local list,stack={}, {{x,y}};seen[x..':'..y]=true
    local votes={}
    while #stack>0 do
     local p=table.remove(stack);list[#list+1]=p
     for _,d in ipairs(dirs)do
      local nx,ny=p[1]+d[1],p[2]+d[2];local n=l:cellAt(nx,ny)
      if n and n.coll==0 and n.elev==15 and not seen[nx..':'..ny] then seen[nx..':'..ny]=true;stack[#stack+1]={nx,ny}
      elseif n and n.coll==0 and n.elev>=3 and n.elev~=15 then votes[n.elev]=(votes[n.elev] or 0)+1
      elseif not (n and n.coll==0 and n.elev==15) then votes.open=true end -- cliff, water, edge: a real deck
     end
    end
    local levels=0;local best
    for e in pairs(votes)do if e~='open' then levels=levels+1;best=e end end
    if #list<=M.MARKER_CELLS and not votes.open and levels==1 then
     for _,p in ipairs(list)do relevel[p[1]..':'..p[2]]=best end
    end
   end
  end end
 end
 local bridgeElev={}
 do
  local seen={}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if raw and raw.coll~=7 and raw.elev==15 and not seen[x..':'..y] then
    local list,stack,top={}, {{x,y}},nil;seen[x..':'..y]=true
    while #stack>0 do local p=table.remove(stack);list[#list+1]=p
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local nx,ny=p[1]+d[1],p[2]+d[2];local n=l:cellAt(nx,ny)
      if n and n.coll~=7 then
       if n.elev==15 then if not seen[nx..':'..ny] then seen[nx..':'..ny]=true;stack[#stack+1]={nx,ny} end
       elseif n.elev>=3 then top=math.max(top or 0,n.elev) end
      end
     end
    end
    if top then for _,p in ipairs(list)do bridgeElev[p[1]..':'..p[2]]=top end end
   end
  end end
 end
 if userPins then
  pins,zoneOf=sparse.prepare(M,def,l,userPins,behaviors,stairCells,climb,shapes,spec,elevAt,plainGrass)
  keepRated=true
 end
 local flightPair=def.midLayout and def.midLayout.pair
 Levels.mapId=def.id
 Levels.stretch=not(userPins and M.STAIR_PROFILE)
 local f=Levels.build(l.width,l.height,function(x,y)
  local raw=l:cellAt(x,y);local beh=behaviors[raw.mid]
  if relevel[x..':'..y] then raw={mid=raw.mid,coll=raw.coll,elev=relevel[x..':'..y]} end
  if flatIn[x..':'..y] then raw={mid=raw.mid,coll=raw.coll,elev=3} end
  local remap=M.ELEV_REMAP[def.id]
  local hElev=(remap and remap[raw.elev]) or bridgeElev[x..':'..y] or raw.elev
  local dz=dais and daisAt(dais,x,y,raw.mid)
  local step=((dz or (dais and dais.anySteps)) and dais.steps[raw.mid]) or beh==0x2A or beh==0x1D0 or climb[x..':'..y]==true or stairCells[x..':'..y]==true or (M.STEP_MIDS[def.id] and M.STEP_MIDS[def.id][raw.mid] and raw.coll==0) or (userPins and (M.PAIR_STEP_MIDS[l.pair] or {})[raw.mid] and raw.coll==0) or false;local jump=beh and beh>=0x38 and beh<=0x3F -- 0x1D0: Emerald MUDDY_SLOPE
  local shape=shapes.of(spec.primary,spec.secondary,raw.mid,beh,raw.coll)
  local pinned=raw.coll~=7 and not step and not jump and raw.elev>=3 and shape.kind~='water'
  return {floor=(dz and not step) or (raw.coll~=7 and not step and not jump),step=step,drop=drop[beh],layer=raw.elev,behavior=beh,
   treads=step and ((FLIGHT_TREADS[flightPair] or {})[raw.mid] or 4) or nil,
   waterfall=beh==0x13 or beh==0x113,
   kind=shape.kind,seed=0,anchor=(pins and pins[x..':'..y]~=nil) or nil,zone=zoneOf[x..':'..y],
   pin=(pins and pins[x..':'..y]) or ((not pins or keepRated) and raw.coll~=7 and raw.elev==1 and shape.kind~='water' and 0) or ((not pins or keepRated) and pinned and math.min(hElev-3,M.MAX_STEP)*(M.COURSE_BY_MAP[def.id] or M.COURSE) or nil)}
 end,function(a,b,d)
  local layer=a.layer==b.layer and a.zone==b.zone
  return layer and (a.kind=='water')==(b.kind=='water') and not blocked[d][a.behavior] and not blocked[opposite[d]][b.behavior]
 end,6,V.require('BuildBudget').tick)
 if pins then
  local seen={}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local c=f.cells[Levels.key(x,y)]
   if c and c.layer==15 and not seen[c] then
    local run,stack,top={},{{x,y}},nil;seen[c]=true
    while #stack>0 do
     local p=table.remove(stack);run[#run+1]=f.cells[Levels.key(p[1],p[2])]
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local nx,ny=p[1]+d[1],p[2]+d[2]
      local n=nx>=0 and ny>=0 and nx<l.width and ny<l.height and f.cells[Levels.key(nx,ny)]
      if n then
       if n.layer==15 then if not seen[n] then seen[n]=true;stack[#stack+1]={nx,ny} end
       elseif n.floor and n.kind~='water' and n.height and not n.step then top=math.max(top or n.height,n.height) end
      end
     end
    end
    if top then for _,q in ipairs(run)do if (q.height or 0)<top then q.height=top;q.high=nil;q.low=nil end end end
   end
  end end
 end
 if userPins then sparse.settle(M,def,l,f,Levels,behaviors,stairCells) end
 if gen and gen.ramps then
  local function edgeHeight(x0,x1,y0,y1)
   local hs={}
   for y=y0,y1 do for x=x0,x1 do local c=f.cells[Levels.key(x,y)]
    if c and c.floor and c.height and not c.step and c.kind~='water' then hs[#hs+1]=c.height end
   end end
   table.sort(hs);return hs[math.ceil(#hs/2)]
  end
  for _,r in ipairs(gen.ramps)do
   local ew=r.ax=='x'
   local hn,hs
   if ew then hn,hs=edgeHeight(r[1]-1,r[1]-1,r[2],r[4]),edgeHeight(r[3]+1,r[3]+1,r[2],r[4])
   else hn,hs=edgeHeight(r[1],r[3],r[2]-1,r[2]-1),edgeHeight(r[1],r[3],r[4]+1,r[4]+1)end
   if hn and hs then
    local lines={}
    if ew then for y=r[2],r[4]do local L={};for x=r[1],r[3]do L[#L+1]={x,y} end;lines[#lines+1]=L end
    else for x=r[1],r[3]do local L={};for y=r[2],r[4]do L[#L+1]={x,y} end;lines[#lines+1]=L end end
    local function markAt(q)return q and userPins and pins[q[1]..':'..q[2]] or nil end
    for _,L in ipairs(lines)do
     local i=1
     while i<=#L do
      if markAt(L[i])~=nil then i=i+1
      else
       local j=i;while j<#L and markAt(L[j+1])==nil do j=j+1 end
       local a=markAt(L[i-1]) or hn;local b=markAt(L[j+1]) or hs
       local span=j-i+2
       for t=i,j do local x,y=L[t][1],L[t][2];local c=f.cells[Levels.key(x,y)]
        if c and (c.floor or (r.smooth and c.step)) and (r.smooth or not c.step) and c.kind~='water' then
         c.height=a+(b-a)*(t-i+1)/span;c.high=nil;c.low=nil
         if r.smooth then c.relief=true;c.connector=true;c.step=false;c.floor=true end
        end
       end
       i=j+1
      end
     end
    end
   end
  end
 end
 local sink=not userPins and M.SINK_MAPS[def.id]
 if sink then
  for _,c in pairs(f.cells)do
   for _,k in ipairs({'height','high','low','ledgeLow'})do
    if c[k]~=nil then c[k]=math.max(0,c[k]-sink) end
   end
  end
 end
 if userPins then sparse.finish(M,def,l,userPins,f,Levels,shapes,spec,behaviors,pins) end
 f.signature=signature
 cache[l]=f;return f
end
function M.cell(def,x,y)
 local f=M.field(def);return f and f.cells[Levels.key(x,y)]
end
function M.at(def,x,z)return Levels.at(M.field(def),x,z)end
function M.supportFill(cells,regions)
 local changed,limit=true,512
 local function walkable(c)
  return c and c.floor and c.floor.height and c.floor.kind~='water' and (c.collision or 0)==0
 end
 local fill={}
 for _,c in pairs(cells)do if c.boundary then fill[#fill+1]=c end end
 table.sort(fill,function(a,b)if a.cy~=b.cy then return a.cy<b.cy end return a.cx<b.cx end)
 while changed and limit>0 do
  changed=false;limit=limit-1
  for _,c in ipairs(fill)do
   if (c.base or 0)>0 then
    local support
    for _,d in ipairs(Levels.directions)do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n then
      local h
      if n.boundary then h=(n.base or 0)+M.COURSE
      elseif walkable(n) then h=n.floor.height+M.COURSE end
      if h and (not support or h<support) then support=h end
     end
    end
    if support==nil then
     for _,r in ipairs(regions)do
      local x=math.max(0,math.min(r.w-1,c.cx-r.x));local y=math.max(0,math.min(r.h-1,c.cy-r.y))
      local q=r.floorField and r.floorField.cells[Levels.key(x,y)]
      if q and q.floor and q.height and q.kind~='water' then
       local h=q.height+(r.floorOffset or 0);if not support or h<support then support=h end
      end
     end
    end
    if support==nil then support=0 end
    if (c.base or 0)>support then c.base=support;c.floorHigh=nil;changed=true end
   end
  end
 end
end
M.STOOP=12
M.BOULDER_MAX=14
M.PROP_STEP=16
function M.bind(cells,regions)
 local bx0,by0,bx1,by1=1e9,1e9,-1e9,-1e9
 for _,c in pairs(cells)do
  if c.cx<bx0 then bx0=c.cx end;if c.cx>bx1 then bx1=c.cx end
  if c.cy<by0 then by0=c.cy end;if c.cy>by1 then by1=c.cy end
 end
 for i,region in ipairs(regions)do
  local reach=i==1 or (region.x<=bx1+1 and region.x+region.w>=bx0-1 and region.y<=by1+1 and region.y+region.h>=by0-1)
  region.floorField=reach and M.field(region.def) or nil
 end
 Levels.align(regions)
 for _,c in pairs(cells)do
  for _,r in ipairs(regions)do local x,y=c.cx-r.x,c.cy-r.y
   if x>=0 and y>=0 and x<r.w and y<r.h then
    local floor=r.floorField and r.floorField.cells[Levels.key(x,y)]
    c.floor=floor;c.base=(floor and floor.height or 0)+r.floorOffset
    c.floorHigh=floor and floor.high and floor.high+r.floorOffset;break
   end
  end
  if c.base==nil then
   local distance,donor
   for _,r in ipairs(regions)do
    local x=math.max(0,math.min(r.w-1,c.cx-r.x));local y=math.max(0,math.min(r.h-1,c.cy-r.y))
    local d=(c.cx-r.x-x)^2+(c.cy-r.y-y)^2
    if not distance or d<distance then
     local q=r.floorField and r.floorField.cells[Levels.key(x,y)]
     if q and q.cls and r.floorField.classes and c.boundary then
      local want=(c.boundary=='mountain') and 'rock' or (c.boundary=='water') and 'water' or 'floor'
      local function fam(cell)
       if not cell then return nil end
       if cell.cls=='MASS' or cell.cls=='FACE' then return 'rock' end
       if cell.cls=='WATER' then return 'water' end
       if cell.cls=='PLATEAU' or cell.cls=='DECK' then return 'floor' end
       return nil
      end
      if want=='water' then q={height=0}
      elseif fam(q)~=want then
       local best
       for dd=1,8 do
        for _,sgn in ipairs({-1,1})do
         local qx,qy=x,y
         if c.cx-r.x~=x then qy=y+sgn*dd else qx=x+sgn*dd end
         local cand=qx>=0 and qy>=0 and qx<r.w and qy<r.h and r.floorField.cells[Levels.key(qx,qy)]
         if cand and fam(cand)==want then best=cand;break end
        end
        if best then break end
       end
       if best then q=best elseif want=='floor' and fam(q)=='rock' then
        q={height=q.srcMax or q.height}
       end
      end
     end
     distance,donor=d,(q and q.height or 0)+r.floorOffset
    end
   end
   c.base=donor or 0
  end
 end
 M.supportFill(cells,regions)
 -- Iterate in map order: pairs() order varies per run (Route 110 gatehouse stood at 0 or 4).
 local bound={}
 for _,c in pairs(cells)do bound[c]=c.base end
 for _,c in pairs(cells)do
  local g=c.column and c.column.group or c.civic or c.prop
  if g then
   if g.groundHeight==nil then
    local x=g.cx or c.cx;local y=g.cy or c.cy
    if g.front then x=math.floor((g.left+g.right)/32);y=math.floor(g.front/16)
    else x=x+math.floor((g.width or (g.w or 16)/16)/2);y=y+(g.depth or (g.d or 16)/16)end
    local below=cells[x..':'..y]or c;g.groundHeight=bound[below] or 0
    if below~=c and below.shape and below.shape.kind=='steps' and not (below.floor and below.floor.step) then
     g.groundHeight=g.groundHeight+M.STOOP end
   end
   c.base=g.groundHeight
  end
 end
 local function owner(c)return c.column and c.column.group or c.civic or c.prop end
 local grew=true
 while grew do
  grew=false
  for _,c in pairs(cells)do
   local g=owner(c)
   if g and c.collision==0 and not c.boundary and bound[c]~=c.base then
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and (owner(n)~=g or n.base==bound[n]) and n.collision==0 and not n.boundary and n.base==bound[c] then c.base=bound[c];grew=true;break end
    end
   end
  end
 end
 local function tree(c)return c.shape and c.shape.kind=='tree' and not c.shape.canopy end
 local function leftHalf(mid)
  if mid>=0x26B and mid<=0x276 then return mid%2==1 end
  return mid%2==0
 end
 for _,c in pairs(cells)do
  if tree(c) and leftHalf(c.mid) then
   local r=cells[(c.cx+1)..':'..c.cy]
   if r and tree(r) and r.mid==c.mid+1 and c.base~=r.base and math.abs(c.base-r.base)<=M.PROP_STEP and not c.boundary and not r.boundary then
    local h=math.max(c.base,r.base);c.base=h;r.base=h
   end
  end
 end
 local seen={}
 local function inMap(c)
  for _,r in ipairs(regions)do if c.cx>=r.x and c.cy>=r.y and c.cx<r.x+r.w and c.cy<r.y+r.h then return true end end
  return false
 end
 for _,c0 in pairs(cells)do
  if c0.shape and c0.shape.kind=='cliff' and not c0.boundary and not seen[c0] and inMap(c0) then
   local group,stack,small={c0},{c0},true
   seen[c0]=true
   while #stack>0 do
    local c=table.remove(stack)
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.shape and (n.shape.kind=='caveWall' or n.boundary) then small=false
     elseif n and n.shape and n.shape.kind=='cliff' and not seen[n] then seen[n]=true;group[#group+1]=n;stack[#stack+1]=n end
    end
    if #group>2 then small=false end
   end
   if small then
    local low
    for _,c in ipairs(group)do for dx=-1,1 do for dy=-1,1 do
     local n=cells[(c.cx+dx)..':'..(c.cy+dy)]
     if n and n.shape and n.shape.kind~='water' and n.shape.kind~='cliff' and n.shape.kind~='caveWall' then low=math.min(low or n.base,n.base) end
    end end end
    for _,c in ipairs(group)do
     if low and low<c.base then c.base=math.max(low,c.base-M.PROP_STEP) end
     if c.shape.height and c.shape.height>M.BOULDER_MAX then c.shape=setmetatable({height=M.BOULDER_MAX},{__index=c.shape}) end
    end
   end
  end
 end
 for _,c in pairs(cells)do
  if c.shape and c.shape.crownFloor then
   local n=cells[c.cx..':'..(c.cy-1)]
   if n and (n.collision or 0)==0 and not n.boundary then c.base=n.base;c.floorHigh=nil end
  end
 end
end
function M.lift(vertices,start,height,back)
 if height==0 then return end
 for i=(start or 0)+1,#vertices do local v=vertices[i];v[2]=v[2]+height
  if v[9] and v[9]~=0 then v[9]=v[9]+height end
  if back then v[3]=v[3]+height end
 end
end
function M.invalidate()cache=setmetatable({},{__mode='k'})end
return M
