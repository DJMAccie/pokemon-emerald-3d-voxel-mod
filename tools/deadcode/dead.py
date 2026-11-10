import sys,os,glob,re,collections,json
sys.path.insert(0,os.path.dirname(__file__))
import lualex
TOOLS=os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..'))
ROOT=sys.argv[1]; ENGINE=sys.argv[2] if len(sys.argv)>2 else None
files=sorted(f for f in glob.glob(ROOT+'/lib/*.lua') if 'ReliefData' not in f)+[ROOT+'/main.lua']
OPEN={'function','do','if','repeat'};CLOSE={'end','until'}
class F: pass
def parse(path):
    s=open(path,encoding='utf-8',errors='replace').read()
    toks=[t for t in lualex.lex(s) if t[0]!='comment']
    # matching ends
    stack=[];match={}
    for i,t in enumerate(toks):
        if t[0]=='kw' and t[1] in OPEN: stack.append(i)
        elif t[0]=='kw' and t[1] in CLOSE: match[stack.pop()]=i
    funcs=[]
    for i,t in enumerate(toks):
        if not(t[0]=='kw' and t[1]=='function'): continue
        f=F();f.file=path;f.i=i;f.j=match[i];f.kind=None;f.name=None;f.defs=set()
        p=toks[i-1] if i else None
        if p and p[0]=='kw' and p[1]=='local':   # local function NAME
            f.kind='local';f.name=toks[i+1][1];f.defs={i+1};f.start=i-1
        elif toks[i+1][0]=='name':                 # function a.b:c(
            k=i+1;path_=[toks[k][1]];ids=[k]
            while toks[k+1][1] in('.',':'): k+=2;path_.append(toks[k][1]);ids.append(k)
            if len(path_)==1: f.kind='upval';f.name=path_[0];f.defs={ids[0]}
            else: f.kind='field';f.name=path_[-1];f.defs={ids[-1]}
            f.start=i
        elif p and p[1]=='=':                      # X = function / local X = function / {k=function}
            q=toks[i-2]
            if q[0]=='name':
                pp=toks[i-3]
                if pp[1]=='local': f.kind='local';f.name=q[1];f.defs={i-2};f.start=i-3
                elif pp[1] in('.',':'): f.kind='field';f.name=q[1];f.defs={i-2};f.start=None
                elif pp[1] in('{',',',';'): f.kind='field';f.name=q[1];f.defs={i-2};f.start=None
                else: f.kind='upval';f.name=q[1];f.defs={i-2};f.start=None
        funcs.append(f)
    return s,toks,funcs
data={p:parse(p) for p in files}
eng=set()
EXTRA=[TOOLS]
for root in EXTRA:
    for p in glob.glob(root+'/**/*',recursive=True):
        if p.endswith(('.lua','.sh','.py')):
            for m in re.finditer(r'[A-Za-z_][A-Za-z0-9_]*',open(p,errors='replace').read()): eng.add(m.group(0))
if ENGINE:
    for p in glob.glob(ENGINE+'/**/*.lua',recursive=True):
        if '/mods/' in p: continue
        try: s=open(p,encoding='utf-8',errors='replace').read()
        except: continue
        for m in re.finditer(r'[A-Za-z_][A-Za-z0-9_]*',s): eng.add(m.group(0))
allf=[f for p in files for f in data[p][2]]
dead=set()
def inside_dead(path,i):
    for f in allf:
        if id(f) in dead and f.file==path and f.i<i<=f.j: return True
    return False
def spans_dead(path):
    return [(f.i,f.j) for f in allf if id(f) in dead and f.file==path]
def refs(f):
    """count references to f's name outside f's defs and outside dead spans (and outside f itself for recursion)"""
    n=0
    for p,k in IDX[f.name]:
        if f.kind in('local','upval') and p!=f.file: continue
        toks=data[p][1];sp=SP.get(p,[]);t=toks[k]
        if True:
            if p==f.file and k in f.defs: continue
            if p==f.file and f.i<k<=f.j: continue
            if any(a<k<=b for a,b in sp): continue
            if t[0]=='name' and t[1]==f.name:
                prev=toks[k-1][1] if k else ''
                if f.kind in('local','upval'):
                    if prev in('.',':'): continue
                    # table key "name=" (not ==) is not a reference to the local
                    if toks[k+1][1]=='=' and prev in('{',',',';'): continue
                    n+=1
                else:
                    if prev in('.',':'): n+=1
                    elif toks[k+1][1]=='=' and prev in('{',',',';'): pass
                    elif p!=f.file: pass
                    else: n+=1   # same file bare name: could be a local alias
            elif t[0]=='str' and f.kind=='field':
                if lualex.strval(t)==f.name: n+=1
    return n
cand=[f for f in allf if f.name and f.kind]
IDX=collections.defaultdict(list)   # name -> [(path,k)]
for p in files:
    for k,t in enumerate(data[p][1]):
        if t[0]=='name': IDX[t[1]].append((p,k))
        elif t[0]=='str':
            v=lualex.strval(t)
            if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*',v): IDX[v].append((p,k))
changed=True;rounds=0
while changed:
    changed=False;rounds+=1
    SP=collections.defaultdict(list)
    for g in allf:
        if id(g) in dead: SP[g.file].append((g.i,g.j))
    for f in cand:
        if id(f) in dead: continue
        if f.kind=='field' and f.name in eng: continue
        if refs(f)==0: dead.add(id(f));changed=True
out=[]
for f in cand:
    if id(f) in dead:
        s,toks,_=data[f.file]
        # skip nested in other dead
        if any(id(g) in dead and g.file==f.file and g.i<f.i<=g.j for g in allf): continue
        a=toks[f.i][2];b=toks[f.j][3]
        l0=s.count('\n',0,a)+1;l1=s.count('\n',0,b)+1
        out.append((os.path.basename(f.file),f.kind,f.name,l0,l1))
tot=sum(b-a+1 for _,_,_,a,b in out)
print('rounds',rounds,'dead functions',len(out),'lines~',tot)
by=collections.Counter()
for o in out: by[o[0]]+=o[4]-o[3]+1
for k,v in by.most_common(40): print('  %-32s %5d'%(k,v))
os.makedirs('/tmp/deadscan',exist_ok=True)
json.dump(out,open('/tmp/deadscan/dead.json','w'),indent=0)
