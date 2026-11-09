-- Voxel world mode

local V = ...


local GlassMask = {}

GlassMask.GLASS_W = 6
GlassMask.SHINE = true -- a pane's drawn shine joins the pane (detect)
GlassMask.ROWS = { 4, 5 } -- door pane, building pane

local function isBlack(r, g, b)
  return r < 0.12 and g < 0.12 and b < 0.12
end

GlassMask._isBlack = isBlack -- named for the suite

local cache = {} -- image path -> { rects, texture (or false) }

local facadeSets = setmetatable({}, { __mode = "k" }) -- tileset -> { mids, n }
local MB = require("src.core.game3.mb")

function GlassMask.facade(ts, mid)
  if not (ts and mid) then return end
  local f = facadeSets[ts]
  if not f then f = { mids = {}, n = 0 }; facadeSets[ts] = f end
  if not f.mids[mid] then f.mids[mid] = true; f.n = f.n + 1 end
end

function GlassMask.door(ts, mid, behavior)
  if type(behavior) ~= "number" then return end
  local name = MB.nameOf(behavior)
  if name and name:find("DOOR") then GlassMask.facade(ts, mid) end
end

function GlassMask.isFacadeCell(c)
  if c.shape and c.shape.kind == "wall" then return true end
  if type(c.behavior) == "number" then
    local name = MB.nameOf(c.behavior)
    if name and name:find("DOOR") then return true end
  end
  return false
end

local function lumOf(r, g, b)
  return 0.299 * r + 0.587 * g + 0.114 * b
end

local function markRect(inF, w, h, x0, y0, x1, y1)
  for y = math.max(0, y0), math.min(h, y1) - 1 do
    for x = math.max(0, x0), math.min(w, x1) - 1 do inF[y * w + x + 1] = true end
  end
end

local function detectOnce(w, h, px0, inF, shine)
  local rgb = {}
  local function px(idx)
    local c = rgb[idx]
    if c then return c[1], c[2], c[3] end
    local r, g, b = px0((idx - 1) % w, math.floor((idx - 1) / w))
    c = { r, g, b }
    rgb[idx] = c
    return r, g, b
  end
  local function nbrs(idx)
    local x, y = (idx - 1) % w, math.floor((idx - 1) / w)
    local out = {}
    if x > 0 then out[#out + 1] = idx - 1 end
    if x < w - 1 then out[#out + 1] = idx + 1 end
    if y > 0 then out[#out + 1] = idx - w end
    if y < h - 1 then out[#out + 1] = idx + w end
    return out
  end
  local function isGlass(idx)
    local r, g, b = px(idx)
    local l = lumOf(r, g, b)
    return b >= g and l >= 55 and l <= 240
      and (b - r >= 48 or (b - r >= 36 and l <= 115))
  end
  local function isShine(idx)
    local r, g, b = px(idx)
    return b - r >= 12 and b - r <= 34 and b >= g and lumOf(r, g, b) >= 195
  end
  local function isLoose(idx)
    local r, g, b = px(idx)
    return b - r >= 20 and b >= g - 4
  end

  local top, bottom = h, -1
  for idx in pairs(inF) do
    local y = math.floor((idx - 1) / w)
    if y < top then top = y end
    if y > bottom then bottom = y end
  end
  local span = bottom - top + 1

  local stats = { comps = 0, kept = 0, rejArea = 0, rejBox = 0, rejTop = 0, grown = 0 }
  local keptComps, seen = {}, {}
  -- Reading order, not pairs(): pairs() order would make the mask differ per run.
  local order = {}
  for idx in pairs(inF) do order[#order + 1] = idx end
  table.sort(order)
  for _, idx in ipairs(order) do
    if not seen[idx] and isGlass(idx) then
      seen[idx] = true
      local sr, sg, sb = px(idx)
      local comp, queue, head = {}, { idx }, 1
      while head <= #queue do
        local p = queue[head]; head = head + 1
        comp[#comp + 1] = p
        for _, q in ipairs(nbrs(p)) do
          if inF[q] and not seen[q] and isGlass(q) then
            local r, g, b = px(q)
            if math.abs(r - sr) + math.abs(g - sg) + math.abs(b - sb) <= 36 then
              seen[q] = true; queue[#queue + 1] = q
            end
          elseif shine and inF[q] and not seen[q] and isShine(q) then
            seen[q] = true; queue[#queue + 1] = q
          end
        end
      end
      stats.comps = stats.comps + 1
      local area = #comp
      local x0, x1, y0, y1 = w, -1, h, -1
      local topXs, nTop = {}, 0
      for _, p in ipairs(comp) do
        local x, y = (p - 1) % w, math.floor((p - 1) / w)
        if x < x0 then x0 = x end
        if x > x1 then x1 = x end
        if y < y0 then y0 = y end
        if y > y1 then y1 = y end
        if y == top and not topXs[x] then topXs[x] = true; nTop = nTop + 1 end
      end
      local bw, bh = x1 - x0 + 1, y1 - y0 + 1
      if area < 10 or area > 520 then
        stats.rejArea = stats.rejArea + 1
      elseif y1 >= bottom - 5 and (bw < 5 or bh < 4) then
        stats.rejBox = stats.rejBox + 1
      elseif bw > 40 or bh > 34 or bw < 3 or bh < 3
          or bh > 2.5 * bw or bw > 4 * bh
          or (area < 0.45 * bw * bh and bw > 3 and bh > 3) then
        stats.rejBox = stats.rejBox + 1
      elseif (y0 == top and nTop * 2 > bw)
          or (y0 - top < 0.2 * span and bw >= 2 * bh) then
        stats.rejTop = stats.rejTop + 1
      else
        stats.kept = stats.kept + 1
        local all, have = {}, {}
        for _, p in ipairs(comp) do all[#all + 1] = p; have[p] = true end
        for _, p in ipairs(comp) do
          for _, q in ipairs(nbrs(p)) do
            if false and inF[q] and not have[q] and isLoose(q) then
              have[q] = true; all[#all + 1] = q; stats.grown = stats.grown + 1
            end
          end
        end
        keptComps[#keptComps + 1] = { pixels = all, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
      end
    end
  end
  return keptComps, stats
end
local function detect(w, h, px0, inF)
  local plain, stats = detectOnce(w, h, px0, inF, false)
  if not GlassMask.SHINE then return plain, stats end
  local joined = detectOnce(w, h, px0, inF, true)
  local covered = {}
  for _, c in ipairs(joined) do for _, p in ipairs(c.pixels) do covered[p] = true end end
  for _, c in ipairs(plain) do
    if not covered[c.pixels[1]] then joined[#joined + 1] = c end
  end
  stats.kept = #joined
  return joined, stats
end

local function pixelTexture(list, w, h)
  if #list == 0 or not (love.image and love.image.newImageData
     and love.graphics and love.graphics.newImage) then
    return false
  end
  local texture = false
  local built = pcall(function()
    local mask = love.image.newImageData(w, h)
    for _, p in ipairs(list) do
      mask:setPixel((p - 1) % w, math.floor((p - 1) / w), 1, 1, 1, 1)
    end
    texture = love.graphics.newImage(mask)
    texture:setFilter("nearest", "nearest")
  end)
  if not built then texture = false end
  return texture
end

GlassMask.log = false

local imageCache = setmetatable({}, { __mode = "k" })

local function overridesFor(id)
  local ok, t = pcall(function() return V.data("gen3_glass_overrides") end)
  if not (ok and type(t) == "table") then return nil end
  return t[id]
end

local function collect(w, h, px0, inF, ov)
  local comps, stats = detect(w, h, px0, inF)
  local list = {}
  for _, c in ipairs(comps) do
    local drop = false
    if ov and ov.drop then
      for _, r in ipairs(ov.drop) do
        if c.x1 >= r[1] and c.x0 <= r[1] + r[3] - 1 and c.y1 >= r[2] and c.y0 <= r[2] + r[4] - 1 then
          drop = true; break
        end
      end
    end
    if not drop then for _, p in ipairs(c.pixels) do list[#list + 1] = p end end
  end
  if ov and ov.add then
    for _, r in ipairs(ov.add) do
      for y = math.max(0, r[2]), math.min(h, r[2] + r[4]) - 1 do
        for x = math.max(0, r[1]), math.min(w, r[1] + r[3]) - 1 do
          list[#list + 1] = y * w + x + 1
        end
      end
    end
  end
  return list, comps, stats
end

local function bake(key, w, h, px0, inF, tag, ov, pic, extra)
  local hit = imageCache[key]
  if hit ~= nil then return hit or nil end
  local list, comps, stats = collect(w, h, px0, inF, ov)
  if extra then for _, p in ipairs(extra) do list[#list + 1] = p end end
  local texture = pixelTexture(list, w, h)
  imageCache[key] = texture
  if GlassMask.dump then
    GlassMask.dump({ tag = tag, pic = pic, w = w, h = h, px0 = px0, search = inF, mask = list, boxes = comps })
  end
  if GlassMask.log then
    print(string.format("[GlassMask] %s %dx%d glass comps %d kept %d rej area %d box %d top %d grown %d",
      tag, w, h, stats.comps, stats.kept, stats.rejArea, stats.rejBox, stats.rejTop, stats.grown))
  end
  return texture or nil
end

local function buildingSearch(data, cells, bld)
  local w, h = data:getDimensions()
  local inF = {}
  for dy = 0, bld.depth - 1 do
    local top = dy == 0 and bld.cy == 0
    for dx = 0, bld.width - 1 do
      local c = cells[(bld.cx + dx) .. ':' .. (bld.cy + dy)]
      if c and not top and GlassMask.isFacadeCell(c) then
        markRect(inF, w, h, dx * 16, dy * 16, dx * 16 + 16, dy * 16 + 16)
      end
    end
  end
  local function px0(x, y)
    local r, g, b = data:getPixel(x, y)
    return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
  end
  return w, h, inF, px0
end

local function buildingId(bld) return tostring(bld.name or bld.kind or bld.model or "?") end

-- The lit texels of a building's picture as a set of pixel indices (y * w + x + 1); nil when it has no windows.
function GlassMask.buildingSet(data, cells, bld)
  local ov = overridesFor(buildingId(bld))
  if ov and ov.off then return nil end
  local w, h, inF, px0 = buildingSearch(data, cells, bld)
  local list = collect(w, h, px0, inF, ov)
  local set = {}
  for _, p in ipairs(list) do set[p] = true end
  return set
end

-- m.twins: extra picture texels (copies of pane colours, made by BuildingVoxels) that light with the glass.
function GlassMask.building(m, cells, bld)
  local data = m and m.imageData
  if not (data and m.image) then return nil end
  local id = buildingId(bld)
  local ov = overridesFor(id)
  if ov and ov.off then return nil end
  local w, h, inF, px0 = buildingSearch(data, cells, bld)
  return bake(m.image, w, h, px0, inF,
    string.format("%s cell %d,%d", id, bld.cx, bld.cy), ov, data, m.twins)
end

local paneCache = setmetatable({}, { __mode = "k" })

function GlassMask.panes(ts, image)
  local data
  if image ~= nil and image == ts.image then data = ts.imageData
  elseif image ~= nil and image == ts.overImage then data = ts.overImageData end
  local f = data and facadeSets[ts]
  if not (f and f.n > 0) then return nil end
  local hit = paneCache[data]
  if hit and hit.n == f.n then return hit.texture or nil end
  if hit then imageCache[data] = nil end
  local w, h = data:getDimensions()
  local inF = {}
  for mid in pairs(f.mids) do
    local slot = ts.midToSlot[mid]
    if slot then
      local x0, y0 = (slot % ts.cols) * 16, math.floor(slot / ts.cols) * 16
      markRect(inF, w, h, x0, y0, x0 + 16, y0 + 16)
    end
  end
  local function px0(x, y)
    local r, g, b = data:getPixel(x, y)
    return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
  end
  local texture = bake(data, w, h, px0, inF, "atlas " .. (image == ts.image and "under" or "over"), nil, data)
  paneCache[data] = { n = f.n, texture = texture or false }
  return texture or nil
end

local blank = nil

function GlassMask.blank()
  if blank == nil then
    local ok, img = pcall(function()
      local data = love.image.newImageData(1, 1)
      data:setPixel(0, 0, 0, 0, 0, 0)
      return love.graphics.newImage(data)
    end)
    blank = (ok and img) or false
  end
  return blank or nil
end

function GlassMask.invalidate()
  for _, e in pairs(cache) do
    if e.texture and e.texture.release then pcall(e.texture.release, e.texture) end
    e.texture = false
  end
  for _, e in pairs(paneCache) do
    if e.texture and e.texture.release then pcall(e.texture.release, e.texture) end
  end
  for _, t in pairs(imageCache) do
    if t and t.release then pcall(t.release, t) end
  end
  cache = {}
  paneCache = setmetatable({}, { __mode = "k" })
  imageCache = setmetatable({}, { __mode = "k" })
  blank = nil
end

return GlassMask
