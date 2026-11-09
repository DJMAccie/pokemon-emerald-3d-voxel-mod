-- QA driver: which of the 386 species can show up as overworld wilds? Prints one [cov] line per map table
-- (national numbers, land/water slots) and the town list names, then the union. Run:
--   EM_DRIVER=<this file> tools/qa_tryp.sh "-" <abs out> "-" 4 0 60
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local Enc=require('src.core.game3.encounters');local Pk=require('src.core.game3.pokemon')
 Enc.ensureLoaded()
 local function nat(s) s=tonumber(s);return s and (Pk.national and Pk.national(s) or s) end
 local ids={};for id in pairs(Enc._tables) do ids[#ids+1]=tostring(id) end;table.sort(ids)
 local seen={}
 for _,id in ipairs(ids) do
  local t=Enc._tables[id];local parts={}
  if type(t)=='table' then
   for _,key in ipairs({'land','water','rock','fish','old','good','super'}) do
    local a=t[key];local slots=type(a)=='table' and (a.slots or a.mons or a) or nil;local l={}
    for _,e in ipairs(slots or {}) do local n=nat(e.species or e[1]);if n then l[#l+1]=n;seen[n]=seen[n] or {};seen[n][id]=true end end
    if #l>0 then parts[#parts+1]=key..'=['..table.concat(l,',')..']' end
   end
   local ks={};for k in pairs(t) do ks[#ks+1]=tostring(k) end;table.sort(ks)
   print('[cov]',id,table.concat(parts,' '),'keys',table.concat(ks,','))
  end
 end
 local missing,have={},0
 for n=1,386 do if seen[n] then have=have+1 else missing[#missing+1]=n end end
 print('[cov] union',have,'of 386; missing',#missing)
 print('[cov] missing list',table.concat(missing,','))
 local names={};for n=1,386 do names[#names+1]=n..'='..tostring(Pk.name and (function()
  for s=1,420 do if nat(s)==n then return Pk.name(s) end end end)() or '?') end
 print('[cov] names',table.concat(names,' '))
 -- species facts + every EM_ map's slots with levels, for tools/wild_extras.py
 local function kv(t) local o={};if type(t)=='table' then for k,v in pairs(t) do o[#o+1]=tostring(k)..'='..tostring(v) end end;table.sort(o);return table.concat(o,',') end
 print('[cov-meta]',kv(Pk.speciesMeta(Pk.speciesFromNational(25))))
 for n=1,386 do local s=Pk.speciesFromNational(n)
  if s then local ty=Pk.types(s);local st=Pk.stats(s);local ev={}
   for _,e in ipairs(Pk.evolutions(s) or {}) do ev[#ev+1]=(tonumber(e.method or e[1]) or 0)..':'..(tonumber(e.param or e[2]) or 0)..':'..tostring(nat(tonumber(e.target or e[3]) or 0)) end
   local m=Pk.speciesMeta(s) or {}
   print('[cov-sp]',n,s,tostring(Pk.name(s)),ty[1],ty[2],kv(st),'catch='..tostring(m.catchRate or m.catch_rate or m.catch),table.concat(ev,';'))
  else print('[cov-sp]',n,'NO INTERNAL ID') end end
 for _,id in ipairs(ids) do if id:find('^EM_') then local t=Enc._tables[id]
  for _,key in ipairs({'land','water'}) do local a=t[key];local slots=type(a)=='table' and (a.slots or a.mons or a) or nil;local l={}
   for _,e in ipairs(slots or {}) do l[#l+1]=nat(e.species or e[1])..':'..tostring(e.minLevel or e.level or e[2])..':'..tostring(e.maxLevel or e.level or e[2]) end
   if #l>0 then print('[cov-map]',id,key,table.concat(l,' ')) end end end end
 print('[cov] done')
end
