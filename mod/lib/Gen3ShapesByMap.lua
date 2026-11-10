-- Every per-map metatile recipe: what a map's own tiles are built as.
-- (Gen3Scene's SHAPE_BY_MAP block, moved out unchanged: R-43.)
local V=...
local shapes={}
do
 local R={}
 for _,m in ipairs({0x24E,0x24F,0x235,0x256,0x257,0x23D,0x27A,0x25E,0x25F,0x245,0x254})do R[m]={kind='roomWall',ground=0x24A} end
 for _,m in ipairs({0x263,0x246,0x247})do R[m]={kind='hang',rail=true,edge=8,ground=0x25B} end
 for _,m in ipairs({0x2E4,0x2E5,0x2E6,0x2EC,0x2ED,0x2EE,0x2F0,0x2F1,0x2F8,0x2F9})do R[m]={kind='hang',edge=8} end
 shapes.EM_LILYCOVE_CITY_DEPARTMENT_STORE_ROOFTOP=R
end
do
 local R={}
 for _,m in ipairs({0x20A,0x209,0x210,0x211,0x220})do R[m]={kind='partition',ground=0x228} end
 for _,m in ipairs({0x2E0,0x221,0x2C3,0x2C4,0x2C5,0x2CB,0x2CC,0x2CD,0x2B3,0x2B4,0x2B5,0x2BB,0x2BC,0x2BD,0x2D4,0x2D5,0x223,0x224})do
  R[m]={kind='roomWall',ground=0x228} end
 for _,id in ipairs({'EM_AQUA_HIDEOUT_1F','EM_AQUA_HIDEOUT_B1F','EM_AQUA_HIDEOUT_B2F'})do shapes[id]=R end
end
do
 local W,E={},{}
 local function curb(t,ids,g)for _,m in ipairs(ids)do t[m]={kind='extrude',h=5,light=.7,ground=g} end end
 local function box(t,ids,g)for _,m in ipairs(ids)do t[m]={kind='extrude',h=8,ground=g} end end
 curb(W,{0x05D,0x05F,0x045,0x056,0x066,0x065,0x057,0x067,0x04D,0x04E,0x047,0x055,0x257,0x25F,0x3F5,0x3FD,0x3CD},0x05E)
 box(W,{0x208,0x209,0x20A,0x210,0x211,0x212,0x218,0x219,0x21A},0x05E)
 curb(E,{0x3CA,0x3C8,0x3C1,0x066,0x3D1,0x04E,0x047,0x3B7,0x3F9,0x3BF,0x3CB,0x3FD,0x3CC,0x3C7,0x3CF,0x05D,0x05F,0x3BB,0x3D0,0x04F,0x065,0x3C3,0x3C0,0x3C2,0x3C9,0x3D2,0x3F5,0x3A1,0x3AF,0x3BC},0x05E)
 box(E,{0x2CB,0x2CC,0x2CD,0x2C8,0x2C9,0x2D0,0x2F7,0x2FF,0x307},0x05E)
 for _,m in ipairs({0x2D8,0x2E0,0x2E8})do E[m]={kind='extrude',h=12,ground=0x10A} end
 for _,m in ipairs({0x2E1,0x2E2,0x2E9,0x2EA})do E[m]={kind='extrude',h=6,ground=0x10A} end
 for _,m in ipairs({0x149,0x148,0x13A,0x142,0x140})do W[m]={kind='fence',ground=0x001,reviewedSurface=true} end
 shapes.EM_BATTLE_FRONTIER_OUTSIDE_WEST=W
 shapes.EM_BATTLE_FRONTIER_OUTSIDE_EAST=E
 local SL={}
 curb(SL,{0x245,0x23C,0x2B9,0x24D,0x2FF,0x23F,0x255,0x264,0x27E,0x2B8,0x2BA,0x2BB,0x04E},0x001)
 for _,m in ipairs({0x142,0x149,0x148,0x14A,0x141,0x13A,0x133})do SL[m]={kind='fence',ground=0x001,reviewedSurface=true} end
 local LH={x0=32,y0=51,x1=33,y1=54,ground={0x001,0x34C},tower={cx=16,base=14,sections={
  {r=14,h=34,rows=function(y)return y<6 and 49-y or (y>=31 and 43-(y-31) or 52) end}, -- drum: the door, plain wall, its top rows
  {disc=14,row=40}, -- gallery ledge
  {r=11,h=11,rows=function(y)return 31-y end}, -- lantern room with its window band
  {disc=13,row=22},{r=13,h=2,rows=function()return 22 end},{disc=13,row=21}, -- roof skirt
  {r=9,h=5,rows=function(y)return 19-y end}, -- upper lantern
  {disc=11,row=13},{r=11,h=1,rows=function()return 13 end},{r=10,h=1,rows=function()return 12 end},
  {r=9,h=1,rows=function()return 11 end},{r=7,h=1,rows=function()return 10 end},{r=5,h=1,rows=function()return 9 end},
  {r=2,h=1,rows=function()return 8 end},{disc=2,row=8}}}}
 for _,m in ipairs({0x246,0x247,0x24E,0x24F,0x256,0x257,0x25E,0x25F})do SL[m]={kind='lathe',lathe=LH,ground=0x001,reviewedSurface=true} end
 for _,m in ipairs({0x220,0x221,0x222,0x228,0x229,0x22A})do SL[m]={kind='extrude',h=9,ground=0x001,sidePx={0x229,8,8},reviewedSurface=true,dock=true} end
 SL.at=V.require('Gen3Market').shape
 shapes.EM_SLATEPORT_CITY=SL
 local R117={}
 for _,m in ipairs({0x149,0x148,0x13A,0x138,0x14A,0x142,0x140})do R117[m]={kind='fence',ground=0x001,reviewedSurface=true} end
 shapes.EM_ROUTE117=R117
end
do
 local R={}
 for _,m in ipairs({0x338,0x339,0x33A,0x340,0x341,0x342,0x348,0x349,0x34A})do R[m]={kind='extrude',h=10,ground=0x2BB,cool=true,reviewedSurface=true} end
 for _,m in ipairs({0x17A})do R[m]={kind='rock',ground=0x170,height=8} end
 shapes.EM_RUSTBORO_CITY=R
end
do
 local R={}
 for _,m in ipairs({0x17A,0x17C,0x17D,0x17E,0x182,0x184,0x0F5,0x0F8,0x0F9,0x0FA,0x0FC,0x2C3})do R[m]={kind='flat',reviewedSurface=true,river=true} end
 for _,m in ipairs({0x210,0x218,0x213,0x21B})do R[m]={kind='flat',reviewedSurface=true,underWater=0x206} end
 for _,m in ipairs({0x0ED,0x0F0,0x0F1,0x0F2,0x0FB,0x0E8,0x0EC,0x0F3,0x0F4,0x0F7,0x0FD})do R[m]={kind='flat',reviewedSurface=true,underWater=0x206,planks=.7} end
 -- The bridge spans both banks as well as the river. These tile variants cover land.
 for _,mid in ipairs({0x211,0x214,0x215,0x219,0x21C,0x21D})do
  R[mid]={kind='flat',reviewedSurface=true,underGrass=true}
 end
 R[0x015]={kind='grass',ground=0x001,height=8}
 -- The two boulders just upstream of the waterfall sit on the four-course riverbed.
 R.at=function(x,y)
  if (x>=22 and x<=23 and y>=74 and y<=75) or (x>=21 and x<=22 and y>=76 and y<=77) then
   return {kind='water',reef=true,level=64}
  end
 end
 shapes.EM_ROUTE119=R
end
do
 local R={[0x0AF]={kind='steps',down=true,reviewedSurface=true},[0x0CF]={kind='steps',down=true,reviewedSurface=true}}
 for _,m in ipairs({0x280,0x281,0x283,0x284})do R[m]={kind='rock',ground=0x001,height=8} end
 R.at=function(cx,cy,mid)if cx==15 and cy==51 and mid==0x001 then return {kind='flat',reviewedSurface=true,level=16} end end
 for _,m in ipairs({0x33D,0x26E})do R[m]={kind='pier',h=16,reviewedSurface=true} end
 for _,m in ipairs({0x345,0x26D})do R[m]={kind='pier',h=16,post={0x276,10,2},posts={2,10},reviewedSurface=true} end
 for _,m in ipairs({0x32E,0x336})do R[m]={kind='pier',h=16,land=true,reviewedSurface=true} end
 shapes.EM_ROUTE104=R
end
do
 local R={[0x2BD]={kind='flat',reviewedSurface=true}}
 shapes.EM_MT_CHIMNEY=R
end
do
 local R={}
 for _,m in ipairs({0x220,0x221,0x222,0x223,0x224,0x225,0x228,0x229,0x22A,0x22B,0x21D,0x231})do R[m]={kind='obwall',ground=0x201} end
 shapes.EM_RUSTBORO_CITY_GYM=R
end
do
 local R={[0x260]={kind='roomWall',ground=0x225}}
 for _,m in ipairs({0x20C,0x20D,0x20E,0x224,0x226,0x214,0x216,0x21C,0x21D,0x21E,0x219})do R[m]={kind='extrude',h=4,ground=0x225} end
 for _,id in ipairs({'EM_CONTEST_HALL','EM_CONTEST_HALL_BEAUTY','EM_CONTEST_HALL_TOUGH','EM_CONTEST_HALL_COOL','EM_CONTEST_HALL_SMART','EM_CONTEST_HALL_CUTE'})do shapes[id]=R end
end
do
 local FLOOR={{140,222,173},{173,247,197},{255,239,148}}
 local F={}
 local fs={auto=7,hBy={[0x230]=4,[0x232]=4,[0x221]=4},floor=FLOOR,perCell=true,
  palette={mid=0x22B,mids={0x22B,0x22C,0x224,0x2CB,0x2C4,0x2CC,0x263,0x264}}}
 fs.bodyBy={}
 for _,m in ipairs(fs.palette.mids)do fs.bodyBy[m]={0x22B,12,4} end
 for _,m in ipairs({0x22B,0x22C,0x230,0x232,0x221,0x224,0x2CB,0x2C4,0x2CC,0x263,0x264})do F[m]={kind='obwall',ground=0x23B,ob=fs} end
 for _,id in ipairs({'EM_TRAINER_HILL_1F','EM_TRAINER_HILL_2F','EM_TRAINER_HILL_3F','EM_TRAINER_HILL_4F'})do shapes[id]=F end
 local E={}
 local es={auto=9,floor=FLOOR,patch={{15*16+5,8*16,15*16+10,7*16+51}},posts={{x=15*16+5,w=6,top=7*16+19,foot=7*16+51}}}
 for _,m in ipairs({0x305,0x306,0x34A,0x34B,0x315,0x352,0x318,0x319,0x312,0x313,0x314,0x31A,0x31B,0x31C,0x348,0x349,0x30F,0x317,0x31F,0x334,
  0x308,0x303,0x304,0x30B,0x30C})do E[m]={kind='obwall',ground=0x330,ob=es} end
 for _,m in ipairs({0x31E,0x302})do E[m]={kind='roomWall',ground=0x330} end
 E[0x321]={kind='roomWall',ground=0x330,fullHeight=0x329}
 shapes.EM_TRAINER_HILL_ENTRANCE=E
 shapes.EM_INSIDE_OF_TRUCK={[0x220]={kind='flat',groundMid=0x210,reviewedSurface=true}}
end
do
 local R={}
 for _,m in ipairs({0x3A5,0x3AD,0x215,0x21D,0x20C,0x214,0x205,0x206,0x207,0x20D,0x20E,0x20F})do R[m]={kind='roomWall',ground=0x3A1} end
 for _,m in ipairs({0x21F,0x3C1,0x3C5,0x22A,0x22B,0x22E})do R[m]={kind='fence',ground=0x3A0,reviewedSurface=true} end
 for _,m in ipairs({0x3C2,0x3C3})do R[m]={kind='fence',ground=0x170,waterGround=true,reviewedSurface=true} end
 shapes.EM_BIRTH_ISLAND_HARBOR=R;shapes.EM_NAVEL_ROCK_HARBOR=R
end
do
 local R={}
 for m=0x241,0x25F do if m%8>=1 then R[m]={kind='roomWall',ground=0x340,tall=true} end end
 shapes.EM_BATTLE_FRONTIER_BATTLE_DOME_CORRIDOR=R
 local B={}
 local st={board=3,riser=4,h0=16,ground=0x309}
 for m=0x2D0,0x2DA do B[m]={kind='stand',stand=st,ground=0x309} end
 shapes.EM_BATTLE_FRONTIER_BATTLE_DOME_BATTLE_ROOM=B
end
do
 local R={}
 local ob={auto=48,floor={}}
 for _,m in ipairs({0x256,0x257,0x25E,0x25F,0x266,0x267,0x26B,0x273,0x27B})do
  R[m]=function(cx,cy)
   if cy>=8 then return {kind='obwall',ground=0x201,ob=ob} end
   return {kind='roomWall',ground=0x201,tall=true}
  end
 end
 shapes.EM_BATTLE_FRONTIER_BATTLE_ARENA_CORRIDOR=R
end
do
 local function room(ground,flat)
  return {at=function(cx,cy,mid)
   if cy<=1 then return {kind='roomWall',ground=ground} end
   if flat and mid>=0x290 and mid<=0x294 then return {kind='flat',noFurniture=true} end
  end}
 end
 shapes.EM_FALLARBOR_TOWN_BATTLE_TENT_BATTLE_ROOM=room(0x210,true)
 shapes.EM_SLATEPORT_CITY_BATTLE_TENT_BATTLE_ROOM=room(0x210,true)
 shapes.EM_VERDANTURF_TOWN_BATTLE_TENT_BATTLE_ROOM=room(0x001)
end
do
 local T={x0=18,y0=53,x1=20,y1=58,axis=true,ground={0x251,0x259,0x25A,0x121}}
 local M={}
 for m=0x3D8,0x3F2 do if (m%8<=2 and m>=0x3D8) or (m>=0x3DB and m<=0x3DD) or (m>=0x3E3 and m<=0x3E5) then M[m]={kind='lathe',lathe=T,ground=0x251,reviewedSurface=true,noFurniture=true} end end
 shapes.EM_ROUTE111=M
end
do
 local top={kind='rail',top=true,noFurniture=true}
 local foot={kind='rail',noFurniture=true}
 shapes.EM_SAFARI_ZONE_SOUTH={[0x313]=top,[0x31D]=top,[0x316]=top,[0x31E]=top,[0x321]=foot,[0x315]=foot}
end
do
 local AWNING_UP=24
 local ob={auto=7,over=true,noGap=true,floor={},floorMids={0x001},hBy={[0x263]=16+AWNING_UP-8,[0x264]=16+AWNING_UP-8},
  overOnly={},liftBy={},liftUp={}}
 local cloth={kind='obwall',ground=0x001,ob=ob,walkOk=true,overArt=true}
 local pole={kind='obwall',ground=0x001,ob=ob}
 local S=shapes.EM_SLATEPORT_CITY or {};shapes.EM_SLATEPORT_CITY=S
 for _,m in ipairs({0x270,0x271,0x272,0x278,0x279,0x27A,0x216,0x21E})do S[m]=cloth;ob.overOnly[m]=true;ob.liftBy[m]=16+AWNING_UP-14;ob.liftUp[m]=AWNING_UP end
 S[0x263]=pole;S[0x264]=pole
end
do
 local ob={auto=8,noGap=true,backToTop=true,floor={},floorMids={0x203,0x201}}
 local foot={kind='obwall',ground=0x203,ob=ob,walkOk=true}
 shapes.EM_BATTLE_FRONTIER_BATTLE_PALACE_LOBBY={[0x29B]=foot,[0x29C]=foot,[0x29D]=foot}
end
do
 local far={kind='roomWall',ground=0x202,tall=true}
 local H={at=function(cx,cy)if cy<=3 then return far end end}
 shapes.EM_LILYCOVE_CITY_HARBOR=H;shapes.EM_SLATEPORT_CITY_HARBOR=H
 local back={kind='roomWall',ground=0x28A}
 shapes.EM_BATTLE_FRONTIER_BATTLE_FACTORY_BATTLE_ROOM={at=function(cx,cy)if cy<=1 then return back end end}
end
do
 local ob={auto=24,over=true,floor={},floorMids={0x209,0x210},body={0x224,8,2},wallArt=true,
  solid={[0x21C]=true,[0x21D]=true,[0x21E]=true,[0x224]=true,[0x225]=true,[0x226]=true}}
 local D={}
 for _,m in ipairs({0x204,0x207,0x208,0x20C,0x20E,0x20F,0x214,0x217,0x21C,0x21D,0x21E,0x224,0x225,0x226,0x221,0x229})do
  D[m]={kind='obwall',ground=0x209,ob=ob} end
 for _,m in ipairs({0x205,0x222,0x212,0x21A,0x215,0x216,0x218,0x21B,0x211,0x213,0x20D,0x223})do
  D[m]={kind='obwall',ground=0x209,ob=ob,walkOk=true} end
 shapes.EM_DEWFORD_TOWN_GYM=D
end
do
 local ob={auto=32,over=true,noGap=true,wallArt=true,body={0x340,8,4},
  floor={{66,74,107},{140,140,140},{181,181,165},{214,214,181},{222,214,82},{247,247,165}},
  solid={[0x338]=true,[0x340]=true,[0x29E]=true,[0x29F]=true,[0x2DF]=true,[0x2E7]=true,[0x300]=true,[0x2D7]=true}}
 local wall={kind='obwall',ground=0x32C,ob=ob}
 local top={kind='obwall',ground=0x32C,ob=ob,walkOk=true}
 local F={[0x2D7]=wall,[0x300]=wall,[0x2DF]=wall,[0x2E7]=wall,[0x29E]=wall,[0x29F]=wall,[0x31E]=top,[0x29D]=top,
  [0x338]=function(cx,cy)if cy>=5 then return wall end end,[0x340]=function(cx,cy)if cy>=5 then return wall end end}
 for _,n in ipairs({'1F','2F','3F'})do shapes['EM_RUSTBORO_CITY_FLAT2_'..n]=F end
end
do
 local FLOOR={{132,173,74},{140,140,140},{165,206,107},{197,255,173},{107,140,49}}
 local function maze(h,body,blocked,walk)
  local ob={auto=h,over=true,noGap=true,floor=FLOOR,body=body,wallArt=true}
  local N={}
  for _,m in ipairs(blocked)do N[m]={kind='obwall',ground=0x208,ob=ob} end
  for _,m in ipairs(walk)do N[m]={kind='obwall',ground=0x208,ob=ob,walkOk=true} end
  return N
 end
 shapes.EM_ROUTE110_TRICK_HOUSE_PUZZLE1=maze(14,{0x224,8,9},
  {0x223,0x224,0x225,0x22B,0x221,0x222,0x22A,0x22C,0x228,0x230},{0x25A,0x21A,0x21B,0x21C,0x21D})
 shapes.EM_ROUTE110_TRICK_HOUSE_PUZZLE3=maze(22,{0x235,8,4},
  {0x226,0x22D,0x21E,0x235,0x24D,0x23A,0x242,0x22E,0x22F,0x236,0x237,0x240,0x241,0x222},
  {0x271,0x255,0x238,0x239,0x218,0x219})
end
shapes.EM_ROUTE110_TRICK_HOUSE_PUZZLE5={[0x268]={kind='flat',noFurniture=true}}
shapes.EM_TRAINER_HILL_ROOF={[0x3C5]={kind='flat'},[0x3C6]={kind='flat'}}
do
 local ob={auto=23,through=true,over=true,noGap=true,voidGround=0x208,body={0x227,8,3},floor={{132,148,140},{173,189,173},{206,206,206},{214,222,214},{0,0,0}}}
 local N={}
 local black={0x21F,0x25C,0x25D,0x260,0x261,0x268,0x26A,0x270,0x272,0x278,0x27A,0x280,0x282,0x288,0x289,0x28A,0x28B,0x28C,
  0x299,0x29A,0x29F,0x2A7,0x2A8,0x2B6,0x2B7}
 local plain={0x227,0x277,0x290,0x291,0x293,0x294,0x295,0x296,0x298,0x2A0,0x2A5,0x2A6,0x2B1,0x2B4,0x2BE,0x2BF,0x2CE,0x2CF}
 ob.solid={}
 for _,m in ipairs(black)do N[m]={kind='obwall',ground=0x208,ob=ob};ob.solid[m]=true end
 for _,m in ipairs(plain)do N[m]={kind='obwall',ground=0x210,ob=ob};ob.solid[m]=true end
 ob.solid[0x2CE],ob.solid[0x2CF]=nil,nil -- (floor shows over these two)
 for _,m in ipairs({0x237,0x279,0x28D,0x28E,0x29D,0x29E,0x287,0x297,0x292,0x26F})do N[m]={kind='obwall',ground=0x210,ob=ob,walkOk=true} end
 N[0x2C6]={kind='flat',noFurniture=true};N[0x2C7]=N[0x2C6]
 shapes.EM_NEW_MAUVILLE_INSIDE=N
end
do
 local w={kind='roomWall',ground=0x265,tall=true,trimTop=8}
 shapes.EM_BATTLE_FRONTIER_BATTLE_TOWER_ELEVATOR={at=function(cx,cy)if cy<=2 then return w end end}
end
do
 local wall={kind='roomWall',ground=0x201,tall=true,sideArt=true}
 shapes.EM_BATTLE_FRONTIER_BATTLE_FACTORY_PRE_BATTLE_ROOM={at=function(cx,cy)
  if cy<=5 and (cx%4==0 or (cx>=5 and cx<=11)) then return wall end
  if cy<=3 then return wall end
 end}
 shapes.EM_BATTLE_FRONTIER_BATTLE_DOME_PRE_BATTLE_ROOM={at=function(cx,cy,mid)
  if cy==0 and cx>=7 then return {kind='roomWall',ground=0x346,fullHeight=0x358} end
  if cy<=1 and cx>=2 and cx<=6 and mid~=0x202 and mid~=0x20A then return {kind='roomWall',ground=0x346} end
 end}
end
do
 local R={}
 local ob={auto=32,floor={},floorFromWalkable=true,body={0x22B,5,5}}
 for _,m in ipairs({0x230,0x231,0x232,0x225,0x223,0x224,0x222,0x226,0x22D,0x22B,0x27B,0x22A,0x2FB,0x22C,0x22E,0x233})do R[m]={kind='obwall',ground=0x2BA,ob=ob} end
 for _,m in ipairs({0x2AE,0x2B6})do R[m]={kind='obwall',ground=0x2BA,ob=ob,walkOk=true} end
 for _,id in ipairs({'EM_SS_TIDAL_CORRIDOR','EM_ABANDONED_SHIP_CORRIDORS_1F','EM_ABANDONED_SHIP_CORRIDORS_B1F','EM_ABANDONED_SHIP_HIDDEN_FLOOR_CORRIDORS'})do shapes[id]=R end
end
-- Frontier rooms whose drawn back band is also the room's shell: InteriorDiorama
-- reads the depth in cells as BACK_BY_MAP and the shell height in pixels as
-- HEIGHT_BY_MAP, so both halves of a room are written next to its tiles.
-- (The Dome pre-battle room has no diorama entry; its shape alone frames it.)
local M={shapes=shapes,rooms={
 EM_BATTLE_FRONTIER_BATTLE_FACTORY_BATTLE_ROOM={back=2},
 EM_BATTLE_FRONTIER_BATTLE_TOWER_ELEVATOR={back=3,height=44},
 EM_BATTLE_FRONTIER_BATTLE_FACTORY_PRE_BATTLE_ROOM={back=4,height=100},
}}
return M
