# deadq.py <mod> : like dead.py, but exports (function M.f) only count uses through an alias of their own module
# (local A=V.require('M') ... A.f / A:f, or V.require('M').f). Modules whose table escapes (passed as a value,
# A[k] with a computed key, metatable classes) fall back to name-based counting. Output /tmp/deadscan/deadq.json.
import sys,os,glob,re,collections,json
sys.path.insert(0,os.path.dirname(__file__))
import lualex
TOOLS=os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..'))
ROOT=sys.argv[1]
files=sorted(f for f in glob.glob(ROOT+'/lib/*.lua') if 'ReliefData' not in f)+[ROOT+'/main.lua']
users=[p for r in (TOOLS+'/drivers',TOOLS+'/deadcode',TOOLS+'/qa_cases',TOOLS)
       for p in glob.glob(r+'/*.lua')]
OPEN={'function','do','if','repeat'};CLOSE={'end','until'}
class F: pass
def lexf(path):
    s=open(path,encoding='utf-8',errors='replace').read()
    return s,[t for t in lualex.lex(s) if t[0]!='comment']
def parse(path):
    s,toks=lexf(path)
    stack=[];match={}
    for i,t in enumerate(toks):
        if t[0]=='kw' and t[1] in OPEN: stack.append(i)
        elif t[0]=='kw' and t[1] in CLOSE: match[stack.pop()]=i
    funcs=[]
    for i,t in enumerate(toks):
        if not(t[0]=='kw' and t[1]=='function'): continue
        f=F();f.file=path;f.i=i;f.j=match[i];f.kind=None;f.name=None;f.defs=set();f.owner=None
        p=toks[i-1] if i else None
        if p and p[0]=='kw' and p[1]=='local':
            f.kind='local';f.name=toks[i+1][1];f.defs={i+1}
        elif toks[i+1][0]=='name':
            k=i+1;path_=[toks[k][1]];ids=[k]
            while toks[k+1][1] in('.',':'): k+=2;path_.append(toks[k][1]);ids.append(k)
            if len(path_)==1: f.kind='upval';f.name=path_[0];f.defs={ids[0]}
            else:
                f.kind='field';f.name=path_[-1];f.defs={ids[-1]}
                if len(path_)==2: f.owner=path_[0]
        elif p and p[1]=='=':
            q=toks[i-2]
            if q[0]=='name':
                pp=toks[i-3]
                if pp[1]=='local': f.kind='local';f.name=q[1];f.defs={i-2}
                elif pp[1] in('.',':'):
                    f.kind='field';f.name=q[1];f.defs={i-2}
                    if toks[i-4][0]=='name' and toks[i-5][1] not in('.',':'): f.owner=toks[i-4][1]
                elif pp[1] in('{',',',';'): f.kind='field';f.name=q[1];f.defs={i-2}
                else: f.kind='upval';f.name=q[1];f.defs={i-2}
        funcs.append(f)
    return s,toks,funcs
data={p:parse(p) for p in files}
udata={p:lexf(p) for p in users}
alltoks={p:data[p][1] for p in files}; alltoks.update({p:udata[p][1] for p in users})
modname=lambda p:os.path.basename(p)[:-4]
# export table name per lib module: last top-level "return NAME"
export={}
for p in files:
    toks=data[p][1]
    for k in range(len(toks)-2,-1,-1):
        if toks[k][1]=='return' and toks[k+1][0]=='name' and k+2==len(toks): export[modname(p)]=toks[k+1][1];break
def req_at(toks,k):
    """module name if toks[k] starts V.require('M') / V.require'M' / require('M'); returns (M, index after call)"""
    if toks[k][1]!='require': return None
    j=k+1
    if toks[j][1]=='(' and toks[j+1][0]=='str' and toks[j+2][1]==')': return lualex.strval(toks[j+1]),j+3
    if toks[j][0]=='str': return lualex.strval(toks[j]),j+1
    return None
aliases=collections.defaultdict(lambda:collections.defaultdict(set))  # file -> module -> {alias}
direct=collections.defaultdict(list)   # module -> [(file,k of field name)]
escaped=set()
for p,toks in alltoks.items():
    if p in data and modname(p) in export:
        aliases[p][modname(p)].add(export[modname(p)])
    for k in range(len(toks)):
        r=req_at(toks,k)
        if not r: continue
        m,j=r
        if j<len(toks)-1 and toks[j][1] in('.',':') and toks[j+1][0]=='name': direct[m].append((p,j+1));continue
        if j<len(toks) and toks[j][1]=='[': escaped.add(m);continue
        # "A = [V.]require(M)" possibly after "or"
        b=k-1
        while toks[b][1]=='.' and toks[b-1][0]=='name': b-=2   # V.require / lib.require / export.lib.require
        if toks[b][1] in('or','and'): b-=2   # A = A or V.require / A = V and V.require
        if toks[b][1]=='=' and toks[b-1][0]=='name' and toks[b-2][1] not in('.',':'): aliases[p][m].add(toks[b-1][1])
        elif toks[b][1]=='=' and toks[b-1][0]=='name': escaped.add(m)   # stored in a field (M.X=V.require): uses go through M.X.f
        else: escaped.add(m)   # passed somewhere
# escape scan: alias used as a bare value
OKNEXT={'.',':','=','or','and','then','==','~=',')'}
for p,mods in aliases.items():
    toks=alltoks[p]
    for m,names in mods.items():
        for k,t in enumerate(toks):
            if t[0]!='name' or t[1] not in names: continue
            prev=toks[k-1][1] if k else ''
            if prev in('.',':'): continue
            nxt=toks[k+1][1] if k+1<len(toks) else ''
            if prev=='local' or (prev=='return' and k+1==len(toks)): continue
            if nxt=='[':
                if toks[k+2][0]=='str' and toks[k+3][1]==']': continue
                escaped.add(m);break
            if nxt==')' and toks[k-1][1] in('(',) and toks[k-2][1] in('type','assert','pcall'): continue
            if nxt in OKNEXT and nxt!=')': continue
            if nxt==')' : escaped.add(m);break
            if prev in('not','if','and','or','elseif','==','~=') and nxt in('then','or','and',')','==','~='): continue
            escaped.add(m);break
        # metatable classes: instances call methods by name
        src=data[p][0] if p in data else ''
        if p in data and modname(p)==m and re.search(r'__index\s*=\s*'+re.escape(export.get(m,'#'))+r'\b|setmetatable\(\s*\w+\s*,\s*'+re.escape(export.get(m,'#'))+r'\b',src): escaped.add(m)
allf=[f for p in files for f in data[p][2]]
for f in allf:
    m=modname(f.file);f.mod=m
    f.export=f.kind=='field' and f.owner is not None and export.get(m)==f.owner and m not in escaped
IDX=collections.defaultdict(list)
for p in files:
    for k,t in enumerate(data[p][1]):
        if t[0]=='name': IDX[t[1]].append((p,k))
        elif t[0]=='str':
            v=lualex.strval(t)
            if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*',v): IDX[v].append((p,k))
uname=set()
for p in glob.glob(os.path.join(TOOLS,'..','gen1recomp','**','*.lua'),recursive=True):   # engine calls table fields by name (menu rows: activate)
    if '/mods/' not in p:
        for m in re.finditer(r'[A-Za-z_][A-Za-z0-9_]*',open(p,encoding='utf-8',errors='replace').read()): uname.add(m.group(0))
for p in users:
    for t in udata[p][1]:
        if t[0]=='name': uname.add(t[1])
dead=set()
def ok(p,k,f,sp):
    if p==f.file and (k in f.defs or f.i<k<=f.j): return False
    return not any(a<k<=b for a,b in sp.get(p,[]))
def refs(f,sp):
    n=0
    if f.export:
        for p,mods in aliases.items():
            names=mods.get(f.mod)
            if not names: continue
            toks=alltoks[p]
            for k in range(1,len(toks)-2):
                if toks[k][1] in('.',':') and toks[k+1][1]==f.name and toks[k-1][0]=='name' and toks[k-1][1] in names \
                   and (k<2 or toks[k-2][1] not in('.',':')) and ok(p,k+1,f,sp): n+=1
                elif p==f.file and toks[k][1] in('.',':') and toks[k+1][1]==f.name and toks[k-1][1]=='self' and ok(p,k+1,f,sp): n+=1
                elif toks[k][1]=='[' and toks[k-1][1] in names and toks[k+1][0]=='str' and lualex.strval(toks[k+1])==f.name and ok(p,k+1,f,sp): n+=1
        for p,k in direct.get(f.mod,[]):
            if alltoks[p][k][1]==f.name and ok(p,k,f,sp): n+=1
        return n
    for p,k in IDX[f.name]:
        if f.kind in('local','upval') and p!=f.file: continue
        if not ok(p,k,f,sp): continue
        toks=data[p][1];t=toks[k];prev=toks[k-1][1] if k else ''
        if t[0]=='name':
            if f.kind in('local','upval'):
                if prev in('.',':'): continue
                if toks[k+1][1]=='=' and prev in('{',',',';'): continue
                n+=1
            else:
                if prev in('.',':'): n+=1
                elif toks[k+1][1]=='=' and prev in('{',',',';'): pass
                elif p==f.file: n+=1
        elif t[0]=='str' and f.kind=='field': n+=1
    return n
cand=[f for f in allf if f.name and f.kind and f.name!='_source']   # _source: shader text for the test suites
changed=True;rounds=0
while changed:
    changed=False;rounds+=1
    sp=collections.defaultdict(list)
    for g in allf:
        if id(g) in dead: sp[g.file].append((g.i,g.j))
    for f in cand:
        if id(f) in dead: continue
        if f.name in uname and f.kind=='field' and not f.export: continue   # tools/drivers may call it by name
        if refs(f,sp)==0: dead.add(id(f));changed=True
out=[]
for f in cand:
    if id(f) not in dead: continue
    if any(id(g) in dead and g.file==f.file and g.i<f.i<=g.j for g in allf): continue
    s,toks,_=data[f.file];a=toks[f.i][2];b=toks[f.j][3]
    out.append((os.path.basename(f.file),f.kind,(f.owner+'.' if f.owner else '')+f.name,s.count('\n',0,a)+1,s.count('\n',0,b)+1))
print('escaped modules:',' '.join(sorted(m for m in escaped if m in export)))
print('rounds',rounds,'dead functions',len(out),'lines~',sum(b-a+1 for *_,a,b in out))
for o in sorted(out): print('  %-28s %-6s %-40s %d-%d'%o)
os.makedirs('/tmp/deadscan',exist_ok=True)
json.dump(out,open('/tmp/deadscan/deadq.json','w'),indent=0)
