#!/usr/bin/env python3
"""Pokemon Center roof: flatten the raised, slotted middle (x17..46, z-44..-5) of the baked model to the roof plane (h36),
painted the way the flat roof beside it lays the art. Safe to run twice."""
SRC='mod/data/buildings/pokemon_center.lua'
BASE,X0,X1,Z0,Z1=36,17,46,-44,-5
s=open(SRC).read()
a=s.index('quads={')+7;b=s.index('}',a)
n=[int(float(v)) for v in s[a:b].split(',') if v.strip()]
keep,ROW=[],{}
for i in range(0,len(n),10):
    f,x0,x1,h0,h1,z0,z1=n[i:i+7]
    mid=X0<=x0<=X1+1 and Z0<=z0<=Z1+1
    if f==3 and x0==X0-2: ROW[z0]=n[i+8]
    if not(mid and h0>=BASE and (f!=3 or x0<=X1 and z0<=Z1)): keep+=n[i:i+10]
for x in range(X0,X1+1):
    for z in range(Z0,Z1+1): keep+=[3,x,x+1,BASE,BASE,z,z+1,x,ROW[z],0]
rows=[','.join(map(str,keep[i:i+60])) for i in range(0,len(keep),60)]
open(SRC,'w').write(s[:a]+'\n '+',\n  '.join(rows)+s[b:])
