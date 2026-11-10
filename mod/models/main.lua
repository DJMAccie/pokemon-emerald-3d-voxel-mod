-- The host keeps a mod's modules in package.loaded across game sessions; evict them when the build changes.
-- MOD_BUILD must match manifest.json's version.
local MOD_BUILD = "0.2.0"
do
  local PREFIX = "mods.emerald_3d_voxel_mod.models."
  local STAMP = PREFIX .. "__build"
  if package.loaded[STAMP] ~= MOD_BUILD then
    for name in pairs(package.loaded) do
      if type(name) == "string" and name:sub(1, #PREFIX) == PREFIX then
        package.loaded[name] = nil
      end
    end
    package.loaded[STAMP] = MOD_BUILD
  end
end

local Importer = require("mods.emerald_3d_voxel_mod.models.lib.importer")
local Fx = require("mods.emerald_3d_voxel_mod.models.lib.fx")
local ModelApi = require("mods.emerald_3d_voxel_mod.models.lib.model_api")

-- The world draws Emerald attack scenes; this serves them the 3D models made from your own files.
return function(mod)
  local lifecycle=require("mods.emerald_3d_voxel_mod.models.lib.mod_lifecycle").new(mod)
  Importer.bind(mod)
  require("mods.emerald_3d_voxel_mod.models.lib.colosseum").bind(mod)
  Fx.bind(mod)
  local Models = ModelApi.new(Importer)

  mod.options:define({
    { key="stadium2_models", label="3D Pokemon Models", type="toggle", default=true },
    { key="stadium2_battle", label="3D Battle Scene", type="toggle", default=true },
    { key="stadium2_shader", label="Shader Style", type="choice", default="stadium",
      choices={{"Stadium","stadium"},{"Watercolor Manga","cel"}},
      help="Stadium shading or watercolor manga for the 3D Pokemon." },
    { key="stadium2_rapidash_cut_fx", label="Rapidash Cut Particles", type="toggle", default=true,
      help="Restore Rapidash's disconnected prototype particle callback." },
  })

  mod.exports.version = MOD_BUILD
  mod.exports.status = Importer.status
  mod.exports.cacheStatus = Importer.cacheStatus
  mod.exports.available = Importer.available
  mod.exports.speciesMax = Importer.speciesMax
  mod.exports.modelsEnabled = Importer.modelsEnabled
  mod.exports.battleEnabled = Importer.battleEnabled
  mod.exports.shaderStyle = Importer.shaderStyle
  mod.exports.reimport = Importer.reimport
  mod.exports.models = Models
  lifecycle:add(Importer.releaseModels)

  local activated
  mod.hooks:wrap("input.step", function(next, game, dt)
    local result = next(game, dt)
    -- Configure and check the cache once the playthrough's field is live, not at boot.
    local owner = game and game.session and game.phase == "field" and (game.save or game.session)
    if owner and activated ~= owner then
      activated = owner
      Importer.setPlaythroughReady(false)
      Importer.configure({ count = 251 })
      Importer.setPlaythroughReady(true)
      local cache = Importer.cacheStatus()
      if mod.log and cache then
        local ctx = cache.context or {}
        pcall(function()
          mod.log:info("stadium2 cache: state=%s code=%s game=%s playthrough=%s",
            tostring(cache.state), tostring(cache.code),
            tostring(ctx.gameVersion or "?"), tostring(ctx.playthroughId or "?"))
        end)
      end
      -- Missing/stale/incomplete rebuilds; a storage error becomes Failed and never rebuilds.
      if cache.state ~= "valid" then Importer.autoImport() end
    end
    Importer.step()
    return result
  end, 5)

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) == "table" then Importer.appendRow(out) end
    return out
  end, 95)
end
