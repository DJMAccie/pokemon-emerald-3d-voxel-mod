#!/usr/bin/env python3
"""Pokemon Center roof: close the six 1 px slots in the hump (x17..46, z-44..-5) of the baked model, so it is one solid
stepped hump. A slot column rises to its lower neighbour; all other paint stays. Safe to run twice."""
SRC='mod/data/buildings/pokemon_center.lua'
BASE,X0,X1,Z0,Z1=36,17,46,-44,-5
s=open(SRC).read()
a=s.index('quads={')+7;b=s.index('}',a)
n=[int(float(v)) for v in s[a:b].split(',') if v.strip()]
Q=[n[i:i+10] for i in range(0,len(n),10)]
H={q[1]:q[3] for q in Q if q[0]==3 and X0<=q[1]<=X1 and q[5]==Z0}
slot={x:min(H[x-1],H[x+1]) for x in H if X0<x<X1 and H[x]<min(H[x-1],H[x+1])}
out=[]
for q in Q:
    f,x,_,y=q[:4]
    if Z0<=q[5]<=Z1+1 and y>=BASE:
        if f==3 and x in slot and q[5]<=Z1: q[3]=q[4]=slot[x]
        if f==4 and x in slot and y<slot[x]: continue
        if f==5 and x-1 in slot and y<slot[x-1]: continue
    out+=q
for x,h in slot.items():
    for y in range(H[x],h): out+=[1,x,x+1,y,y+1,Z1+1,Z1+1,x,59-y,0]+[2,x,x+1,y,y+1,Z0,Z0,x,59-y,0]
rows=[','.join(map(str,out[i:i+60])) for i in range(0,len(out),60)]
open(SRC,'w').write(s[:a]+'\n '+',\n  '.join(rows)+s[b:])
