"""Check preview provenance, original API preservation, packaged paths and syntax.
The release's tools/check.py remains separate; old evidence is never relabelled.
"""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,xml.etree.ElementTree as ET
from full_build import ROOT,OUT,build
def verify(compiler=None):
    build()
    problems=[]
    upstream=json.loads((ROOT/'vendor/chrono/UPSTREAM.json').read_text())
    for relative,expected in upstream['files'].items():
        p=ROOT/'vendor/chrono'/relative
        if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=expected['sha256']: problems.append('upstream baseline changed: '+relative)
    count=0
    for p in (ROOT/'vendor/chrono/src').rglob('*.luau'):
        active=ROOT/'replication'/p.relative_to(ROOT/'vendor/chrono/src')
        if not active.is_file(): problems.append('original module missing: '+str(p))
        old=set(re.findall(r'^function (\w+\.\w+)\(',p.read_text(),re.M))
        new=set(re.findall(r'^function (\w+\.\w+)\(',active.read_text(),re.M)) if active.exists() else set()
        for name in sorted(old-new): problems.append('original public function missing: '+str(p)+' '+name)
        count+=1
    artifacts={}
    for path in sorted(OUT.glob('*.rbxmx'),key=lambda p:p.name):
        tree=ET.parse(path).getroot();paths=set();sources=[]
        def walk(item,parent):
            props=item.find('Properties');name=props.find("string[@name='Name']").text;key=parent+(name,)
            if key in paths: problems.append('duplicate asset path: '+repr(key))
            paths.add(key)
            script=props.find("ProtectedString[@name='Source']")
            if script is not None: sources.append((key,script.text or ''))
            for child in item.findall('Item'): walk(child,key)
        for item in tree.findall('Item'): walk(item,())
        for key,text in sources:
            # Check literal script.Parent paths against the serialized tree.
            # Ignore comments and strings containing generated future scripts.
            code=re.sub(r'--\[(?P<c>=*)\[.*?\](?P=c)\]|--[^\n]*|\[(?P<s>=*)\[.*?\](?P=s)\]|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27',' ',text,flags=re.S)
            for match in re.finditer(r'require\((script(?:\.[A-Za-z_]\w*)+)\)',code):
                target=list(key)
                for piece in match.group(1).split('.')[1:]:
                    if piece=='Parent': target.pop()
                    else: target.append(piece)
                if tuple(target) not in paths: problems.append('missing packaged require: '+repr(key)+' '+match.group(1))
        artifacts[path.name]={'instances':len(paths),'scripts':len(sources),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        if compiler:
            temp=OUT/'compile-input.luau'
            for key,text in sources:
                temp.write_text(text,encoding='utf-8',newline='\n')
                proc=subprocess.run([compiler,'--null',str(temp)],capture_output=True,text=True)
                if proc.returncode: problems.append('syntax: '+repr(key)+' '+proc.stderr.strip())
            temp.unlink(missing_ok=True)
    # Verify retained release sources even when Git is not on PATH.
    retained=json.loads((ROOT/'dist/MANIFEST.json').read_text())['files']
    retained_count=0
    for relative,expected in retained.items():
        if relative.split('/')[0] in ['src','runtime','editor']:
            retained_count+=1;p=ROOT/relative
            if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=expected['sha256']: problems.append('published source changed: '+relative)
    # Competitive Core and existing connector remain byte-for-byte at this branch's base.
    git_args=['git','diff','--name-only','HEAD','--','src','runtime','editor']
    try:
        changed=subprocess.run(git_args,cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
        if changed: problems.append('existing published Core/Connector changed: '+changed)
    except FileNotFoundError: pass
    report={'ok':not problems,'originalModulesPresent':count,'retainedReleaseSourcesVerified':retained_count,'artifacts':artifacts,'problems':problems,'scope':'static/packaging checks; runtime evidence is in docs/full/validation'}
    (OUT/'STATIC-CHECKS.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(report,indent=2));return report['ok']
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--compiler');args=parser.parse_args();raise SystemExit(0 if verify(args.compiler) else 1)
