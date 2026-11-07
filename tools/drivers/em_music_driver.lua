-- Renders one game song to raw PCM through the game's own audio engine (tools/music.sh).
--   EM_SONG=MUS_RAYQUAZA_APPEARS EM_SECS=100 -> $SHOT_DIR/song.raw (s16le stereo) + song.rate
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 local song=os.getenv('EM_SONG') or 'MUS_RAYQUAZA_APPEARS'
 local secs=tonumber(os.getenv('EM_SECS') or 100)
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(60)
 local Audio=require('src.core.game3.audio')
 local Mix=require('src.core.game3.m4a_mix')
 local C=require('src.core.game3.constants').of(require('src.core.GameVersion').get())
 local f=assert(io.open(dir..'/song.raw','wb'))
 local rec=false;local bytes=0;local chans
 local msgs,got=0,0
 local function rec1(sd)
  chans=sd:getChannelCount()
  local n=sd:getSampleCount()*chans
  local t={}
  for i=0,n-1 do local v=sd:getSample(i);local x=math.floor(v*32767+0.5);if x<0 then x=x+65536 end;t[#t+1]=string.char(x%256,math.floor(x/256)) end
  local str=table.concat(t);f:write(str);bytes=bytes+#str
 end
 Audio.pumpBgm=function()
  local ch=Audio._outCh
  if not (rec and ch) then return end
  local m=ch:pop()
  while m do
   msgs=msgs+1
   if type(m)=='table' and m.data and (m.gen==nil or m.gen==Audio._bgmGen) then got=got+1;if got<3 then print('[music] data',type(m.data),tostring(m.data),m.n,m.data.getSampleCount and m.data:getSampleCount()) end;rec1(m.data) end
   m=ch:pop()
  end
 end
 Audio.stopAll()
 local id=C:require('songs',song)
 print('[music] song',song,id,'rate',Mix.SAMPLE_RATE)
 rec=true;print('[music] ready',tostring(Audio.isReady()),'suspended',tostring(Audio._suspended),'src',tostring(Audio._bgmSource),'out',tostring(Audio._outCh));print('[music] play',tostring(Audio.playSong(id)));print('[music] after: worker',tostring(Audio._worker),'src',tostring(Audio._bgmSource),'paused',tostring(Audio._bgmPaused),'cur',tostring(Audio._currentSong and Audio._currentSong.id))
 local t0=love.timer.getTime()
 while love.timer.getTime()-t0<secs do U.wait(1);love.timer.sleep(0.01) end
 rec=false;f:close()
 local r=io.open(dir..'/song.rate','w');r:write(Mix.SAMPLE_RATE,' ',tostring(chans),' ',bytes);r:close()
 print('[music] msgs',msgs,'got',got,'bytes',bytes,'chans',chans)
 love.event.quit()
end
