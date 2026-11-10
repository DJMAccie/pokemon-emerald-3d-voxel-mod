-- Emerald metatile recipes for the Gen 3 scene
local V=...
local M={}

local B={
 TALL_GRASS=0x02,LONG_GRASS=0x103,SHORT_GRASS=0x107,ASHGRASS=0x124,
 JUMP_EAST=0x38,JUMP_WEST=0x39,JUMP_NORTH=0x3A,JUMP_SOUTH=0x3B,
 JUMP_SOUTHEAST=0x13E,JUMP_SOUTHWEST=0x13F,
 MOUNTAIN_TOP=0x0C,CAVE=0x08,LADDER=0x61,WARP_DOOR=0x69,CAVE_DOOR=0x60,
 HORIZONTAL_RAIL=0x1D6,VERTICAL_RAIL=0x1D5,
 ISOLATED_HORIZONTAL_RAIL=0x1D4,ISOLATED_VERTICAL_RAIL=0x1D3,
 INTERIOR_DEEP_WATER=0x111,SOOTOPOLIS_DEEP_WATER=0x114,
 SEAWEED=0x22,SEAWEED_NO_SURFACING=0x12A,WATERFALL=0x13,PUDDLE=0x16,
 BERRY_TREE_SOIL=0x1A0,MUDDY_SLOPE=0x1D0,BUMPY_SLOPE=0x1D1,
}
M.behaviors=B
local BLOCKED=7

local function set(list)local t={};for _,id in ipairs(list)do t[id]=true end;return t end
local function span(t,from,to)for id=from,to do t[id]=true end;return t end

-- Reviewed loose stones. Each entry selects the floor tile and foreground silhouette.
local silhouettes={
 {0x03C0,0x07F0,0x0FFC,0x1FFE,0x3FFE,0x3FFE,0x3FFE,0x3FFF,0x3FFF,0x7FFE,0x7FFC,0x7FFE,0x7FFF,0x7EFF,0x3C7E,0x003C},
 {0x0070,0x1CF8,0x3EF8,0x7FFC,0xFFFE,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0x7FFE,0x3FFE,0x7FFE,0x7FFE,0x7FFC,0x3E38,0x1C00},
 {0x0FC0,0x1FE0,0x3FF8,0x7FFC,0xFFFE,0xFFFE,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0x7FFE,0x7FF8,0x1FC0},
 {0x0000,0x07C0,0x0FE0,0x1FF0,0x3FF8,0x7FFC,0x7FFE,0x7FFF,0x7FFF,0x7FFF,0x7FFF,0x7FFF,0x3FFF,0x0FFE,0x0FFC,0x07F8},
 {0x01F0,0x03F0,0x0FF8,0x1FF8,0x3FF8,0x7FFC,0x7FFC,0x7FFC,0x7FF8,0x3FFC,0x7FFE,0x7BFE,0x39FE,0x01FC,0x00F8,0x0000},
 {0x0F00,0x1FC0,0x3FE0,0x3FF8,0x7FFE,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0x7FFE,0x7FFE,0x3FFC,0x0FF0},
 {0x0000,0x0070,0x38F8,0x7DFC,0x7DFC,0xFFFE,0xFFFE,0xFFFE,0x7FFF,0x7FFF,0x7FFE,0xFFFE,0xFFFE,0x7FFE,0x7F7C,0x0000},
 {0x3000,0x7B80,0xFFCC,0xFFFE,0xFFFF,0xFFFF,0x7FFF,0x3FFE,0x3FFC,0x3FFC,0x7FFC,0x7FFE,0xFFFE,0xFFFF,0x7F3C,0x3E00},
 {0x03C0,0x07F0,0x0FF8,0x1FFC,0x3FFE,0x3FFE,0x3FFE,0x3FFF,0x3FFF,0x3FFF,0x1FFE,0x3FFC,0x7FFE,0xFFFE,0x7E3C,0x3C00},
 {0x0780,0x0FCC,0x1FDE,0x3FFF,0x7FFF,0x7FFF,0x7FFF,0x7FFE,0x7FFC,0x7FFE,0xFFFE,0xFFFF,0xFFFF,0x7E7E,0x3C3C,0x0000},
 {0x03C0,0x07E0,0x0FF0,0x1FF8,0x3FFC,0x3FFE,0x3FFE,0x7FFF,0xFFFF,0xFFFF,0xFFFF,0xFFFE,0xFFFE,0x7FFE,0x3E3C,0x1800},
 {0x0038,0x387C,0x7CFE,0xFFFF,0xFFFF,0xFFFF,0x7FFF,0x7FFF,0x7FFE,0xFFF8,0xFFF8,0xFFFC,0xFFFC,0x7FFC,0x3DFC,0x00F8},
}
local stones={
 cave={[0x202]={0x201,1},[0x203]={0x201,2},[0x250]={0x201,1},[0x262]={0x209,1},
  [0x266]={0x211,1},[0x2D5]={0x2DD,1},[0x2D6]={0x2DD,2},[0x2ED]={0x2F5,1},
  [0x2EE]={0x2F5,2},[0x330]={0x31B,1},[0x331]={0x31B,2},[0x37D]={0x38D,1},
  [0x37E]={0x38D,2}},
 facility={[0x3B0]={0x2E6,3},[0x3B1]={0x2E7,3}},
 fallarbor={[0x217]={0x218,3},[0x219]={0x218,4},[0x21A]={0x218,5},[0x223]={0x279,4},
  [0x22B]={0x279,5},[0x255]={0x241,3},[0x26F]={0x001,3},[0x2AF]={0x314,4},
  [0x2B7]={0x314,5},[0x2BF]={0x314,4},[0x2C7]={0x314,5}},
 general={[0x0C5]={0x0C0,6},[0x0CD]={0x0C8,6},[0x0E0]={0x001,3},[0x0E1]={0x071,3},
  [0x0E2]={0x11C,3},[0x18C]={0x170,6},[0x194]={0x157,6}},
 lavaridge={[0x30D]={0x308,3}},
 lilycove={[0x288]={0x1AE,6},[0x31A]={0x002,3}},
 mauville={[0x3B1]={0x113,3}},
 meteor_falls={[0x20E]={0x201,7},[0x20F]={0x201,8},[0x217]={0x224,7},[0x21F]={0x224,8},
  [0x28C]={0x201,8}},
 mirage_tower={[0x202]={0x201,1},[0x203]={0x201,2},[0x250]={0x201,1},[0x262]={0x209,1},
  [0x266]={0x211,1},[0x2D5]={0x2DD,1},[0x2D6]={0x2DD,2},[0x2ED]={0x2F5,1},
  [0x2EE]={0x2F5,2},[0x330]={0x31B,1},[0x331]={0x31B,2}},
 mossdeep={[0x300]={0x001,3}},
 navel_rock={[0x202]={0x201,1},[0x203]={0x201,2},[0x250]={0x201,1},[0x262]={0x209,1},
  [0x266]={0x211,1},[0x2D5]={0x201,1},[0x2D6]={0x201,2},[0x2ED]={0x2F5,1},
  [0x2EE]={0x2F5,2},[0x330]={0x31B,1},[0x331]={0x31B,2},[0x33D]={0x27F,1},
  [0x33E]={0x27F,2},[0x356]={0x201,1}},
 pacifidlog={[0x207]={0x235,1},[0x20F]={0x234,1},[0x217]={0x235,2},[0x21F]={0x234,2},
  [0x273]={0x27E,2},[0x274]={0x27E,1},[0x27B]={0x279,2},[0x27C]={0x279,1},
  [0x2AD]={0x264,1},[0x2AE]={0x264,2},[0x2BC]={0x2BA,3}},
 rusturf_tunnel={[0x203]={0x202,9},[0x204]={0x202,10},[0x205]={0x230,11},[0x206]={0x230,12}},
 underwater={[0x2B8]={0x253,3}},
}

local G={}
G.grass=0x001
G.sand=0x11C

G.cliff={}
span(G.cliff,0x068,0x06D);span(G.cliff,0x070,0x07D)
span(G.cliff,0x080,0x084);span(G.cliff,0x088,0x08C)
span(G.cliff,0x090,0x094);span(G.cliff,0x09B,0x09E)
G.cliff[0x0A0]=true;span(G.cliff,0x0A2,0x0A4);span(G.cliff,0x0A8,0x0AC)
span(G.cliff,0x0B4,0x0B7);G.cliff[0x0BD]=true;G.cliff[0x0BE]=true
span(G.cliff,0x0E0,0x0E2);G.cliff[0x0E4]=true;G.cliff[0x0E7]=true;G.cliff[0x0EE]=true;G.cliff[0x0EF]=true
span(G.cliff,0x160,0x16F);span(G.cliff,0x175,0x17F);G.cliff[0x158]=true;G.cliff[0x15C]=true
G.cliff[0x150]=true;G.cliff[0x151]=true;G.cliff[0x159]=true
G.seaRock=set({0x150,0x151,0x158,0x159,0x15C,0x175,0x176,0x177,0x178,0x179,0x17A,0x17B,0x17C,0x17D,0x17E,0x17F})
span(G.cliff,0x182,0x184);G.cliff[0x187]=true
G.cliff[0x1EE]=true;G.cliff[0x1EF]=true;G.cliff[0x1F0]=true;G.cliff[0x1F1]=true
G.cliffCap=0x0DC -- cap texture for the raised top
G.cliffSide=0x0E1 -- face texture for the vertical drop

G.ledgeLeft=set({0x06E})
G.ledgeRight=set({0x06F})

local roof,wall={},{}
local function building(roofIds,wallIds)
 for _,id in ipairs(roofIds)do roof[id]=true end
 for _,id in ipairs(wallIds)do wall[id]=true end
end
building({0x008,0x009,0x00A,0x010,0x011,0x012},
 {0x018,0x019,0x01A,0x020,0x021,0x022,0x00B,0x00C,0x013,0x014})
building({0x028,0x029,0x02A,0x02B,0x030,0x031,0x032,0x033},
 {0x038,0x039,0x03A,0x03B,0x040,0x041,0x042,0x043})
building({0x048,0x049,0x04A,0x04B,0x050,0x051,0x052,0x053},
 {0x058,0x059,0x05A,0x05B,0x060,0x061,0x062,0x063})
building({0x130,0x132},
 {0x1C0,0x1C1,0x1C2,0x1C3,0x1C4,0x1C5,0x1C8,0x1C9,0x1CA,0x1CB,0x1CC,0x1CD})
building({0x1AA,0x1AB,0x1AC,0x1B2,0x1B3,0x1B4},{0x1B8,0x1B9,0x1BA,0x1BB,0x1BC})
G.roof,G.wall=roof,wall

G.treeTop=set({0x1D4,0x1D5,0x1D6,0x1D7})
G.treeRootLeft=set({0x1DC,0x1E4,0x1E6})
G.treeRootRight=set({0x1DD,0x1E5,0x1E7})
G.treeOverhang=set({0x1CE,0x1CF}) -- grass under a canopy edge
G.treeOverhangGrass=set({0x1C6,0x1C7}) -- tall grass under a canopy edge
G.treeArt={{0x1CE,0x1CF},{0x1D4,0x1D5},{0x1DC,0x1DD}}

G.canopyTree=set({0x0C6,0x0C7,0x0CE})
G.narrowTreeTop={[0x00E]=0x016,[0x00F]=0x017}
G.narrowTreeRoot={[0x016]=0x00E,[0x017]=0x00F}
-- Every flower metatile, by tileset: all of them become 3D tufts (kind 'flowers', Gen3Outdoor.plant)
local FLOWERS={
 general={0x004},
 mauville={0x205,0x207,0x208,0x209,0x20A,0x20B,0x20C,0x20D,0x20E,0x20F,0x210,0x211,0x212,0x213,0x214,0x215,0x216,0x217},
 ever_grande={0x290,0x291,0x292,0x293,0x294,0x295,0x296,0x297},
 dewford={0x2C8},
 lavaridge={0x21E,0x21F},
}
G.flowers=set(FLOWERS.general)
G.shrub=set({0x193})
G.sign=set({0x003,0x01B,0x131})
G.rockInWater=set({0x0CD,0x18C,0x194})
-- Short-grass paths and their edges: reviewed flat ground.
G.surface={}
span(G.surface,0x1D0,0x1D2);span(G.surface,0x1D8,0x1DA);span(G.surface,0x1E0,0x1E2)
span(G.surface,0x100,0x102);span(G.surface,0x108,0x10A);span(G.surface,0x110,0x112)
G.surface[0x001]=true;G.surface[0x11C]=true

local S={}
local function secondary(name,t)
 t.ground=t.ground or G.grass
 for _,k in ipairs({'roof','wall','treeTop','treeRootLeft','treeRootRight','hedge','shrub','surface'})do t[k]=t[k] or {} end
 t.flowers=set(FLOWERS[name] or {})
 S[name]=t
end
-- Long grass shares its palette with the crowns. Mask trees against bare ground.
secondary('fortree',{ground=G.grass})
secondary('petalburg',{
 roof=set({0x208,0x20A,0x218,0x219,0x21A,0x282,0x283}), -- the rest comes from gen3_emerald_auto
 roofTypes=(function()
  local t={}
  for _,mid in ipairs({0x208,0x209,0x20A,0x210,0x211,0x212,0x218,0x219,0x21A})do t[mid]='twoTier' end
  for _,mid in ipairs({0x20C,0x20D,0x20E,0x214,0x215,0x216,0x242,0x243,0x24A,0x24B})do t[mid]='lowRidge' end
  return t
 end)(),
 treeRootLeft=set({0x285}), -- trunk half overlapping a Mart roof corner
 shrub=set({0x202,0x28A,0x28B}),
 hedge=set({0x23C,0x23D,0x23E,0x244,0x245,0x246,0x24C,0x24D,0x254,0x255,0x256,0x264,0x265,0x266}),
 surface=set({0x201,0x206,0x207,0x270,0x271,0x272,0x278,0x279,0x27A,0x288,0x289,0x28C}),
})
secondary('sootopolis',{roofType='flat',roof=set({0x201,0x202,0x209,0x20A,0x20B,0x218})})
secondary('pacifidlog',{roofType='flat',roof=set({0x209,0x20A,0x20B,0x211,0x212,0x213})})
secondary('rustboro',{})
secondary('lilycove',{})
secondary('fallarbor',{wall=set({0x2FF}),cliff=set({0x223})})
M.secondary=S
M.treeArt=G.treeArt

-- data/gen3_emerald_auto.lua is generated by tools/tilerules/emerald_tables.py.
local auto
do
 local ok,mod=pcall(function()return V.data('gen3_emerald_auto')end)
 if not (ok and mod) then ok,mod=pcall(dofile,(os.getenv('DS_MOD_PATH') or '.')..'/data/gen3_emerald_auto.lua') end
 auto=ok and mod or {outdoor={},general={},interiors={}}
end
local HAND_KINDS={'roof','wall','treeTop','treeRootLeft','treeRootRight','hedge','shrub','surface','rock','cliff','caveWall'}
local function claimed(t,mid)
 for _,k in ipairs(HAND_KINDS)do if t[k] and t[k][mid] then return true end end
 return false
end
local AUTO_KINDS={'roof','wall','cliff','caveWall'}
for name,gen in pairs(auto.outdoor or {})do
 local t=S[name]
 if not t then secondary(name,{ground=gen.floor});t=S[name];t.auto=true elseif gen.floor and not t.ground then t.ground=gen.floor end
 for _,k in ipairs(AUTO_KINDS)do
  t[k]=t[k] or {}
  for _,mid in ipairs(gen[k] or {})do if not claimed(t,mid) then t[k][mid]=true end end
 end
end
G.rock=G.rock or {}
for _,k in ipairs({'roof','wall','cliff'})do
 for _,mid in ipairs((auto.general or {})[k] or {})do
  if not (G.roof[mid] or G.wall[mid] or G.cliff[mid] or G.treeTop[mid] or G.treeRootLeft[mid] or G.treeRootRight[mid]
   or G.treeOverhang[mid] or G.treeOverhangGrass[mid] or G.flowers[mid] or G.shrub[mid] or G.sign[mid] or G.surface[mid]) then
   G[k][mid]=true
  end
 end
end
M.auto=auto

local function isSurfable(behavior)
 local ok,Collision=pcall(require,'src.core.game3.collision')
 if ok and Collision and Collision.isSurfable and Collision.isSurfable(behavior) then return true end
 return behavior==B.INTERIOR_DEEP_WATER or behavior==B.SOOTOPOLIS_DEEP_WATER
  or behavior==B.SEAWEED or behavior==B.SEAWEED_NO_SURFACING or behavior==B.WATERFALL
end

local function jumpSouth(b)return b==B.JUMP_SOUTH or b==B.JUMP_SOUTHEAST or b==B.JUMP_SOUTHWEST end

local function tree(t,mid,ground)
 if t.treeRootLeft[mid] then return {kind='tree',root=true,ground=ground,anchorX=16,anchorZ=12,art=G.treeArt,artTipRows=1} end
 if t.treeRootRight[mid] then return {kind='tree',root=false,ground=ground} end
 if t.treeTop[mid] then return {kind='tree',root=false,ground=ground} end
end

local ROCKY={dewford=true,ever_grande=true,fallarbor=true,fortree=true,lavaridge=true,lilycove=true,pacifidlog=true,sootopolis=true}
local PINS={slateport={}}
local STAKE_FENCE={[0x149]=true,[0x148]=true,[0x13A]=true,[0x138]=true,[0x14A]=true,[0x142]=true,[0x140]=true,[0x139]=true}
for _,mid in ipairs({517,525,526,527,551,565,559,760,761,762})do PINS.slateport[mid]='awning' end
PINS.slateport[0x243]='shrub'
PINS.sootopolis={[0x244]='steps',[0x245]='steps'}
PINS.lilycove={}
for _,mid in ipairs({0x258,0x25A})do PINS.lilycove[mid]='fenceline' end
PINS.lilycove[0x2A2]='flatart'
for _,mid in ipairs({0x250,0x251,0x252})do PINS.lilycove[mid]='fence' end
PINS.mauville=PINS.mauville or {}
for _,mid in ipairs({0x04E,0x04D,0x03E,0x045,0x047})do PINS.mauville[mid]='fence' end
for _,mid in ipairs({0x149,0x148,0x13A,0x138,0x14A,0x142,0x140,0x139})do PINS.mauville[mid]='fence' end
for _,mid in ipairs({0x291,0x292,0x288,0x28A,0x273,0x282,0x2B2,0x290})do PINS.mauville[mid]='stakes' end
PINS.fortree={[0x233]='flat'}
PINS.facility={}
for _,mid in ipairs({0x332,0x338,0x339,0x33B,0x33C,0x33D})do PINS.facility[mid]='flat' end
for _,mid in ipairs({0x32F,0x340,0x33E,0x337,0x33F})do PINS.facility[mid]='flat' end
for _,mid in ipairs({0x330,0x331})do PINS.facility[mid]='steps' end
PINS.slateport=PINS.slateport or {}
for _,m in ipairs({0x338,0x339,0x33A,0x340,0x341,0x342,0x348,0x349,0x34A,0x346,0x347,0x368,0x34E,0x34F,0x370,0x356,0x357,0x378,0x35E,0x35F,0x380})do PINS.slateport[m]='boat' end
PINS.fortree=PINS.fortree or {}
for _,m in ipairs({0x206,0x20F})do PINS.fortree[m]='river' end
PINS.rustboro={[0x205]='flatart'}
local RUSTBORO_RAIL={[0x2FC]=0x2BB,[0x2A7]=0x2BB,[0x2BE]=0x2BB,[0x2BF]=0x2BB,[0x31A]=0x2BB,[0x2B7]=0x001,
 [0x2DE]=0x001,[0x2DF]=0x001,[0x2EC]=0x2BB,[0x318]=0x318,[0x319]=0x319,
 [0x315]=0x2BB,[0x320]=0x2BB,[0x31D]=0x2BB,[0x2C6]=0x2BB,[0x2C7]=0x2BB,[0x2D5]=0x2BB,[0x321]=0x001,[0x33F]=0x001,[0x2D7]=0x001,
 [0x31B]=0x001,[0x32D]=0x32D,[0x2E9]=0x2BB,[0x2E7]=0x001,[0x2E6]=0x001,[0x32C]=0x32C,[0x352]=0x2BB,[0x2DC]=0x2BB,[0x2CD]=0x2BB,
 [0x337]=0x001,[0x33E]=0x001}
for m in pairs(RUSTBORO_RAIL)do PINS.rustboro[m]='fence' end
PINS.rustboro[0x21A]='lamp'
PINS.rustboro[0x212]='lamptop'
PINS.rustboro[0x213]='lamptop'
PINS.lavaridge={}
for _,mid in ipairs({0x254,0x255,0x25C,0x25D,0x264,0x265})do PINS.lavaridge[mid]='poleFoot' end -- cable-car pylon column: plain ground, Gen3CableCar stands the pole upright
for _,mid in ipairs({0x299,0x29A,0x29B,0x29D,0x2A1,0x2A5,0x2A9,0x2AD,0x2B1,0x2B2,0x2B3,0x2B4,0x2B5})do PINS.lavaridge[mid]='rim' end
for _,mid in ipairs({0x2C5,0x2C6,0x2C7,0x2CC,0x2CD})do PINS.lavaridge[mid]='ashtree' end
PINS.lavaridge[0x2C4]='ashtop'
for _,mid in ipairs({0x296,0x293,0x287,0x285,0x294,0x28E,0x28F})do PINS.lavaridge[mid]='fence' end
PINS.fallarbor={}
local FALLARBOR_TREES={
 green={art={{0x206,0x207},{0x20E,0x20F}},roots={0x20F,0x26B,0x274},parts={0x206,0x207,0x20E,0x26C,0x273,0x214,0x215}},
 ash={art={{0x204,0x205},{0x20C,0x20D}},roots={0x20D,0x26D,0x276},parts={0x204,0x205,0x20C,0x26E,0x275}},
}
for fam,t in pairs(FALLARBOR_TREES)do
 for _,m in ipairs(t.roots)do PINS.fallarbor[m]='ftree:'..fam..':root' end
 for _,m in ipairs(t.parts)do PINS.fallarbor[m]='ftree:'..fam..':part' end
end
PINS.ever_grande={}
for mid=0x248,0x25F do PINS.ever_grande[mid]='leagueGate' end
for _,mid in ipairs({0x260,0x264,0x26C})do PINS.ever_grande[mid]='leagueGate' end

function M.floor(secondary)
 local t=S[secondary]
 return t and t.ground or nil
end
local FORTREE_CANOPY={[0x22A]=true,[0x243]=true,[0x244]=true,[0x246]=true,[0x247]=true,
 [0x248]=true,[0x249]=true,[0x24A]=true,[0x250]=true,[0x251]=true,[0x252]=true,
 [0x25C]=true,[0x273]=true,[0x241]=true}
local FORTREE_PALM_CROWN={[0x250]=true,[0x251]=true,[0x252]=true}
local FORTREE_PALM_FLAT={[0x248]=true,[0x249]=true,[0x24A]=true,[0x250]=true,[0x251]=true,[0x252]=true,
 [0x25C]=true,[0x273]=true,[0x241]=true}
local stamps,stampsTried
function M.of(primary,secondary,mid,behavior,collision)
 if type(mid)~='number' then return nil end
 if primary~='general' then return nil end
 if secondary=='inside_ship' then return nil end
 local stoneSet=stones[mid<0x200 and primary or secondary]
 local stone=stoneSet and stoneSet[mid]
 if stone then
  return {kind='rock',ground=stone[1],stoneMask=silhouettes[stone[2]],height=16,noFurniture=true,reviewedSurface=true}
 end
 local sec=S[secondary]
 local ground=(sec and sec.ground) or G.grass
 local pin=PINS[secondary] and PINS[secondary][mid]
 if stampsTried==nil then
  local ok,m=pcall(function()return V and V.require and V.require('Gen3TreeStamps')end)
  stampsTried=true;stamps=ok and m or nil
 end
 if stamps then
  local stamp=stamps.of(secondary,mid,collision,behavior,ground,behavior and isSurfable(behavior))
  if stamp then return stamp end
 end
 local stake=not pin and STAKE_FENCE[mid]
 if stake then pin='fence' end
 if secondary=='fortree' and FORTREE_CANOPY[mid] and (collision==BLOCKED or mid==0x241) then
  return {kind='tree',root=true,canopy=true,fortree=true,ground=ground,anchorX=8,anchorZ=8,art={{mid}},
   topMid=FORTREE_PALM_FLAT[mid] and 0x0C7 or nil,palmCrown=FORTREE_PALM_CROWN[mid] or nil}
 end
 if secondary=='mauville' then
  local ok,R=pcall(function()return V and V.require and V.require('Gen3CyclingRoad')end)
  if ok and type(R)=='table' then
   if R.DECK[mid] then return {kind='flat',reviewedSurface=true,cyclingRoad='deck'} end
   if R.SEA[mid] then return {kind='water',reviewedSurface=true,behavior=behavior,cyclingRoad='sea'} end
   if R.LAND[mid] then return {kind='flat',reviewedSurface=true,cyclingRoad='land',ground=G.grass} end
   if R.TREE[mid] then return {kind='tree',root=true,canopy=true,ground=ground,anchorX=8,anchorZ=8,art={{mid}},topMid=0x0C7,roadTree=true} end
  end
 end
 if pin=='fenceline' then return {kind='flat',ground=ground,fenceLine=true} end
 if pin=='ashtree' then return {kind='flat',ground=0x271,ashPine=true,reviewedSurface=true} end
 if type(pin)=='string' and pin:sub(1,6)=='ftree:' then
  local fam,role=pin:match('ftree:(%a+):(%a+)')
  local t=FALLARBOR_TREES[fam]
  if role=='root' then
   return {kind='tree',root=true,ground=0x279,planeOwn=true,anchorX=0,anchorZ=10,art=t.art,artTipRows=1,reviewedSurface=true}
  end
  return {kind='tree',root=false,ground=0x279,planeOwn=true,reviewedSurface=true}
 end
 if pin=='fence' then
  local g=({lavaridge=0x271,lilycove=0x001,mauville=0x001})[secondary] or ground
  if secondary=='rustboro' then g=RUSTBORO_RAIL[mid] or g end
  if stake then g=0x001 end
  return {kind='fence',ground=g,reviewedSurface=true}
 end
 if pin=='river' then return {kind='water',reviewedSurface=true,river=true} end
 if pin=='stakes' then
  if collision~=BLOCKED then return nil end
  return {kind='posts',h=9,ground=0x001,reviewedSurface=true}
 end
 if pin=='flatart' then return {kind='flat',reviewedSurface=true} end
 if pin=='boat' then return {kind='boat',reviewedSurface=true} end
 if pin=='ashtop' then return {kind='flat',groundMid=0x271,ashTop=true,reviewedSurface=true} end
 if pin=='lamp' then return {kind='flat',ground=0x2BB,lamp=true,reviewedSurface=true} end
 if pin=='lamptop' then return {kind='flat',lampTop=true,reviewedSurface=true} end
 if pin=='leagueGate' then return {kind='flat',reviewedSurface=true,leagueGate=true} end
 if pin=='poleFoot' then return {kind='flat',reviewedSurface=true,groundMid=0x271} end
 if pin=='rim' then return {kind='rock',ground={0x2A8,0x2A3,0x2BC,0x274,0x272,0x001},height=8} end
 if pin=='awning' then return {kind='awning',ground=ground,height=28} end
 if pin=='shrub' then return {kind='shrub',ground=ground,height=10} end
 if pin=='steps' then return {kind='steps',height=6} end
 if pin=='flat' then return {kind='flat',reviewedSurface=true} end
 local mountain=false
 if behavior then
  if behavior==B.MUDDY_SLOPE then return {kind='steps',height=6} end
  if isSurfable(behavior) then return {kind='water',reviewedSurface=true,behavior=behavior} end
  if jumpSouth(behavior) then
   return {kind='ledge',ground=ground,left=behavior==B.JUMP_SOUTHWEST or nil,right=behavior==B.JUMP_SOUTHEAST or nil}
  end
  if behavior==B.JUMP_EAST or behavior==B.JUMP_WEST then return {kind='ledge',side=true,ground=ground} end
  if behavior==B.JUMP_NORTH then
   return {kind='flat',reviewedSurface=true}
  end
  if behavior==B.HORIZONTAL_RAIL or behavior==B.ISOLATED_HORIZONTAL_RAIL
   or behavior==B.VERTICAL_RAIL or behavior==B.ISOLATED_VERTICAL_RAIL then
   return {kind='flat',reviewedSurface=true}
  end
  if behavior==B.TALL_GRASS or behavior==B.LONG_GRASS or behavior==B.ASHGRASS then
   return {kind='grass',ground=ground,height=behavior==B.LONG_GRASS and 8 or 4,ownGround=behavior==B.ASHGRASS or nil}
  end
  if behavior==B.MOUNTAIN_TOP and collision==BLOCKED then
   mountain=true
  elseif behavior==B.MOUNTAIN_TOP or behavior==B.BERRY_TREE_SOIL or behavior==B.MUDDY_SLOPE
   or behavior==B.BUMPY_SLOPE or behavior==B.PUDDLE or behavior==B.SHORT_GRASS then
   return {kind='flat',reviewedSurface=true}
  end
 end
 if primary=='general' then
  if G.cliff[mid] then
   if collision==BLOCKED then
    if G.seaRock[mid] then return {kind='flat',seaRock=true,ground=ground} end
    return {kind='cliff',height=32,ground=ground,cap=G.cliffCap,side=G.cliffSide}
   end
   return {kind='flat',reviewedSurface=true}
  end
  if G.ledgeLeft[mid] then return {kind='ledge',ground=ground,left=true} end
  if G.ledgeRight[mid] then return {kind='ledge',ground=ground,right=true} end
  if G.roof[mid] then return {kind='roof',ground=ground,roofType='front'} end
  if G.wall[mid] then return {kind='wall',ground=ground} end
  local t=tree(G,mid,ground);if t then return t end
  if G.canopyTree[mid] then
   if collision==BLOCKED then return {kind='tree',root=true,canopy=true,ground=ground,anchorX=8,anchorZ=8,art={{mid}}} end
   return {kind='flat',reviewedSurface=true}
  end
  if G.narrowTreeRoot[mid] then return {kind='tree',root=true,ground=ground,anchorX=8,anchorZ=12,art={{G.narrowTreeRoot[mid]},{mid}}} end
  if G.narrowTreeTop[mid] then return {kind='tree',root=false,ground=ground} end
  if G.treeOverhang[mid] then return {kind='flat',reviewedSurface=true,groundMid=G.grass} end
  if G.treeOverhangGrass[mid] then return {kind='grass',ground=ground,groundMid=G.grass,height=4} end
  if G.flowers[mid] then return {kind='flowers',ground=G.grass,height=6} end
  if G.shrub[mid] then return {kind='shrub',ground=G.grass,height=10} end
  if G.sign[mid] then return {kind='sign',height=12,ground=ground} end
  if G.rockInWater[mid] or G.surface[mid] then return {kind='flat',reviewedSurface=true} end
  if G.rock[mid] then
   if collision==BLOCKED then return {kind='rock',ground=ground,height=8} end
   return {kind='flat',reviewedSurface=true}
  end
 end
 if sec then
  if sec.roof[mid] then return {kind='roof',ground=sec.ground,roofType=(sec.roofTypes and sec.roofTypes[mid]) or sec.roofType or 'front'} end
  if sec.wall[mid] then return {kind='wall',ground=sec.ground} end
  local t=tree(sec,mid,ground);if t then return t end
  if sec.flowers[mid] then return {kind='flowers',ground=ground,height=6} end
  if sec.hedge[mid] then return {kind='shrub',ground=ground,height=8,hedge=true} end
  if sec.shrub[mid] then
   if collision==BLOCKED then return {kind='shrub',ground=ground,height=10} end
   return {kind='flat',reviewedSurface=true}
  end
  if sec.surface[mid] then return {kind='flat',reviewedSurface=true} end
  if sec.cliff and sec.cliff[mid] and ROCKY[secondary] then
   if collision==BLOCKED then return {kind='cliff',height=32,ground=ground,cap=mid,side=mid} end
   return {kind='flat',reviewedSurface=true}
  end
  if sec.caveWall and sec.caveWall[mid] then
   if collision==BLOCKED then return {kind='caveWall',height=28,ground=ground,cap=mid,side=mid} end
   return {kind='flat',reviewedSurface=true}
  end
  if sec.rock and sec.rock[mid] then
   if collision==BLOCKED then return {kind='rock',ground=ground,height=8} end
   return {kind='flat',reviewedSurface=true}
  end
 end
 if mountain then return {kind='cliff',height=32,ground=ground,cap=mid,side=mid,mountain=true} end
 return nil
end

return M
