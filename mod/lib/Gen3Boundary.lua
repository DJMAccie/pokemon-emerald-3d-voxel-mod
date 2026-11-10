-- Render the native Emerald perimeter in map-local coordinates.
local V=...
local Select=V.require('BoundaryScenery')
local Shapes=V.require('Gen3TileShape')
local Pairs=V.require('Gen3Tilesets')
local Versions=require('src.import.gba.versions')
local Collision=require('src.core.game3.collision')
local M={}
local key,regions
local function treeArt(shape)
 if shape.art then return shape.art end
 local v=V.require('Generation').version()
 if v=='emerald' or v=='ruby' or v=='sapphire' then return V.require('Gen3EmeraldShapes').treeArt end
end
function M.regions(def,world)
 local parts={tostring(def),tostring(def.midLayout)}
 for _,e in ipairs(world or {})do parts[#parts+1]=table.concat({e.id or '',e.ox,e.oy,tostring(e.def.midLayout)},':')end
 local nextKey=table.concat(parts,';')
 if nextKey==key then return regions end
 key=nextKey;regions={}
 local function add(d,x,y)
  local L=d.midLayout
  if L then regions[#regions+1]={def=d,x=x,y=y,w=L.width,h=L.height}end
 end
 add(def,0,0)
 for _,e in ipairs(world or {})do add(e.def,e.ox,e.oy)end
 return regions
end
local function sample(r,x,y)
 local L=r.def.midLayout;local mid=L:midAt(x,y);local pair=L.pair
 local spec=Pairs.resolve(pair,Versions.TILESET_PAIRS)
 if not spec then return end
 local shape=Shapes.of(spec.primary,spec.secondary,mid)
 local kind=shape.kind
 local biome=kind=='tree' and 'forest' or kind=='cliff' and 'mountain'
 if Collision.isSurfable(Collision.behaviorOn(r.def,x,y))then biome='water'end
 return {mid=mid,pair=pair,biome=biome,primary=spec.primary,secondary=spec.secondary,shape=shape}
end
local ground,atlas,origins
function M.setWorld(maps)
 if maps and V.require('Generation').version()=='emerald' then
  ground=V.require('Gen3FlyGround')
  atlas=ground.fill()
  origins=ground.origins(maps)
 end
end
local dewfordTrees={0x1D4,0x1D5,0x1DC,0x1DD}
-- A crown tile is not solid on the map (the trunk tile below owns the tree): as a root of its own it drew a second crown above the tree
local function crownTile(secondary,mid)
 local g=V.require('Gen3TreeStamps').GENERAL[secondary]
 if g then for _,o in ipairs(g.over)do if o==mid then return true end end end
end
M.SKY={EM_SKY_PILLAR_TOP=true}
M.SEA={EM_SOOTOPOLIS_CITY=0x279}
function M.resolve(rs,x,y)
 local owner,_,_,inside=Select.owner(rs,x,y)
 if not owner or inside then return end
 local id=owner.def.id
 if M.SKY[id] then return end
 local L=owner.def.midLayout
 local version=V.require('Generation').version()
 if version=='emerald' and L.borderMids and (L.borderWidth or 0)>0 and (L.borderHeight or 0)>0 then
  local lx,ly=x-owner.x,y-owner.y
  local mid=L.borderMids[(ly%L.borderHeight)*L.borderWidth+lx%L.borderWidth+1]
  if id=='EM_DEWFORD_TOWN' then
   mid=dewfordTrees[(ly%2)*2+lx%2+1]
  end
  local pair=L.pair
  local origin=origins and origins[id]
  if atlas and origin and not origin.overlay then
   local p,m=ground.fillAt(atlas,origin.ox+lx,origin.oy+ly)
   pair,mid=p or pair,m or ground.SEA_MID
  end
  mid=M.SEA[id] or mid
  if mid and mid~=0 then
   local spec=Pairs.resolve(pair,Versions.TILESET_PAIRS)
   local behavior=(require('src.core.game3.scripting.interaction_scripts').behaviors[pair] or {})[mid]
   local shape=Shapes.of(spec.primary,spec.secondary,mid,behavior,crownTile(spec.secondary,mid) and 0 or 7)
   local biome=shape.kind=='tree' and 'forest' or shape.kind=='cliff' and 'mountain'
    or shape.kind=='water' and 'water' or 'ground'
   if M.SEA[id] then return mid,L.pair,{kind='water',reviewedSurface=true},'water' end
   return mid,pair,shape,biome
  end
 end
 local donor,real=Select.resolve(rs,x,y,sample)
 if real or not donor or donor.primary~='general' then return end
 do local o=Select.owner(rs,x,y);if o and o.def and M.SKY[o.def.id or ''] then return end
  local sea=o and o.def and M.SEA[o.def.id or ''];local L=o and o.def and o.def.midLayout
  if sea and L then return sea,L.pair,{kind='water',reviewedSurface=true},'water' end end
 if donor.biome=='forest' then
  local source=donor.shape;local spacing=source.spacing or 2
  return donor.mid,donor.pair,{kind='tree',ground=source.ground or 1,root=x%spacing==0 and y%spacing==0,
   spacing=source.spacing,anchorX=source.anchorX or 16,anchorZ=source.anchorZ or 12,art=treeArt(source),artTipRows=source.artTipRows or (not source.art and treeArt(source) and 1 or nil)},'forest'
 elseif donor.biome=='mountain' then
  return 113,donor.pair,{kind='cliff',height=32,ground=1},'mountain'
 elseif donor.biome=='water' then
  local shore=V.data('gen3_water_edge')[donor.pair] -- (tools/tilerules/water_edge.py)
  return shore and shore[donor.mid] or donor.mid,donor.pair,{kind='water',reviewedSurface=true},'water'
 end
 local r=Select.owner(rs,x,y)
 local L=r and r.def and r.def.midLayout
 if L and L.borderMids then
  local spec=Pairs.resolve(L.pair,Versions.TILESET_PAIRS)
  if spec and spec.primary=='general' then
   local tree,cliff
   for _,mid in ipairs(L.borderMids)do
    local shape=Shapes.of(spec.primary,spec.secondary,mid)
    if shape.kind=='tree' then if not tree or shape.root then tree={mid=mid,shape=shape} end
    elseif shape.kind=='cliff' then cliff=true end
   end
   if tree then
    local source=tree.shape;local spacing=source.spacing or 2
    return tree.mid,L.pair,{kind='tree',ground=source.ground or 1,root=x%spacing==0 and y%spacing==0,
     spacing=source.spacing,anchorX=source.anchorX or 16,anchorZ=source.anchorZ or 12,art=treeArt(source),artTipRows=source.artTipRows or (not source.art and treeArt(source) and 1 or nil)},'forest'
   elseif cliff then
    return 113,L.pair,{kind='cliff',height=32,ground=1},'mountain'
   end
  end
 end
 -- Never copy a facade, decoration or door into the void: use the donor's own ground.
 local floor
 if donor.primary=='general' then
  local gen=V.require('Generation').version()
  if gen=='emerald' or gen=='ruby' or gen=='sapphire' then floor=V.require('Gen3EmeraldShapes').floor(donor.secondary) end
 end
 if donor.secondary=='facility' then floor=0x001 end
 if floor then return floor,donor.pair,{kind='flat',reviewedSurface=true},'ground' end
 return 1,donor.pair,{kind='flat',reviewedSurface=true},'ground'
end
function M.clear()key,regions=nil,nil end
return M
