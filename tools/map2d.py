# Render an Emerald map crop in 2D, both layers, 64 px per metatile.
# render.py <pretName> x0 y0 x1 y1 out.png  : 2D crop of an Emerald map, 16 px per metatile, both layers
import glob,json,os,struct,sys
from PIL import Image
T=os.path.expanduser('~/Library/Application Support/pokemon-love2d/emerald/data/generated/gba/map_tree')
name,x0,y0,x1,y1,out=sys.argv[1],*map(int,sys.argv[2:6]),sys.argv[6]
for d in glob.glob(T+'/maps/*'):
    h=json.load(open(d+'/header.json'))
    if h['pretName']==name: break
else: sys.exit('no map')
w,hh=h['width'],h['height']
grid=struct.unpack('<%dH'%(w*hh),open(d+'/grid.bin','rb').read()[:w*hh*2])
def ts(n):
    p=T+'/tilesets/'+n
    return dict(tiles=open(p+'/tiles.4bpp','rb').read(),meta=open(p+'/metatiles.bin','rb').read(),pal=open(p+'/palettes.bin','rb').read())
P,S=ts(h['primaryTileset']),ts(h['secondaryTileset'])
def col(i,c):
    src=P['pal'] if i<6 else S['pal']
    v=struct.unpack_from('<H',src,(i*16+c)*2)[0]
    return ((v&31)*255//31,((v>>5)&31)*255//31,((v>>10)&31)*255//31)
def tile(idx):
    src,i=(P['tiles'],idx) if idx<512 else (S['tiles'],idx-512)
    b=src[i*32:i*32+32]
    return [[(b[y*4+x//2]>>(4*(x&1)))&15 if len(b)==32 else 0 for x in range(8)] for y in range(8)]
img=Image.new('RGB',((x1-x0+1)*16,(y1-y0+1)*16))
px=img.load()
for my in range(y0,y1+1):
  for mx in range(x0,x1+1):
    mid=grid[my*w+mx]&0x3FF
    src,m=(P['meta'],mid) if mid<512 else (S['meta'],mid-512)
    ents=struct.unpack_from('<8H',src,m*16)
    for layer in range(2):
      for q in range(4):
        e=ents[layer*4+q];t=tile(e&0x3FF);hf=e>>10&1;vf=e>>11&1;pal=e>>12
        for y in range(8):
          for x in range(8):
            c=t[7-y if vf else y][7-x if hf else x]
            if c==0 and layer==1: continue
            if c==0 and layer==0: c=0
            px[(mx-x0)*16+(q%2)*8+x,(my-y0)*16+(q//2)*8+y]=col(pal,c)
img=img.resize((img.width*4,img.height*4),Image.NEAREST);img.save(out)
