"""Isolated development artifacts. Never rewrites V3.2 release evidence or site."""
from pathlib import Path
import hashlib,json,re,shutil,zipfile,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'dist-preview'
VERSION='3.3.0-dev'
def source(path): return path.read_text(encoding='utf-8-sig').replace('\r\n','\n')
def tree(directory,path):
    init=directory/'init.luau'
    model=directory/'init.model.json'
    cls=json.loads(source(model))['ClassName'] if model.exists() else ('ModuleScript' if init.exists() else 'Folder')
    rows=[dict(path=path,**{'class':cls})]
    if init.exists(): rows[0]['source']=source(init)
    for p in sorted(directory.iterdir(),key=lambda p:p.name):
        if p.is_dir(): rows+=tree(p,path+[p.name])
        elif p.suffix=='.luau' and p.name!='init.luau':
            is_client=p.stem.endswith('.client') and 'tests' in p.parts and 'full' in p.parts
            rows.append(dict(path=path+[p.stem.removesuffix('.client') if is_client else p.stem],**{'class':'LocalScript' if is_client else 'ModuleScript'},source=source(p),disabled=is_client))
        elif p.name.endswith('.model.json') and p.name!='init.model.json': rows.append(dict(path=path+[p.name[:-11]],**{'class':json.loads(source(p))['ClassName']}))
    return rows
def model(rows,path):
    root=ET.Element('roblox',{'version':'4'})
    mapped={}
    for i,row in enumerate(rows):
        parent=mapped[tuple(row['path'][:-1])] if len(row['path'])>1 else root
        obj=ET.SubElement(parent,'Item',{'class':row['class'],'referent':f'CF{i}'})
        props=ET.SubElement(obj,'Properties')
        ET.SubElement(props,'string',{'name':'Name'}).text=row['path'][-1]
        if 'source' in row: ET.SubElement(props,'ProtectedString',{'name':'Source'}).text=row['source']
        if row.get('disabled'): ET.SubElement(props,'bool',{'name':'Disabled'}).text='true'
        if 'value' in row: ET.SubElement(props,'string',{'name':'Value'}).text=row['value']
        mapped[tuple(row['path'])]=obj
    path.write_bytes(ET.tostring(root,encoding='utf-8',xml_declaration=True))
def runtime():
    rows=[dict(path=['ChronoFork'],**{'class':'ModuleScript'},source=source(ROOT/'framework/init.luau'))]
    for directory,name in [('src','Core'),('replication','Replication'),('framework/Competitive','Competitive'),('framework/Shared','Shared')]: rows+=tree(ROOT/directory,['ChronoFork',name])
    for name in ['Bootstrap','Hooks','DebugUI','Await']:
        rows.append(dict(path=['ChronoFork',name],**{'class':'ModuleScript'},source=source(ROOT/f'framework/{name}.luau')))
    # Original public child paths continue resolving to the same module instances.
    for path in sorted((ROOT/'replication/Shared').glob('*.luau'),key=lambda p:p.name):
        alias=f'local API=require(script.Parent.Parent.Replication.Shared.{path.stem})\n'
        for match in re.finditer(r'export type (\w+)(<[^>]*>)?\s*=',source(path)):
            name,params=match.groups()
            arguments=('<'+','.join(s.split('=')[0].strip() for s in params[1:-1].split(','))+'>') if params else ''
            alias+=f'export type {name}{params or ""} = API.{name}{arguments}\n'
        alias+='return API\n'
        rows.append(dict(path=['ChronoFork','Shared',path.stem],**{'class':'ModuleScript'},source=alias))
    for name in ['Client','Server']:
        rows.append(dict(path=['ChronoFork',name],**{'class':'Folder'}))
        for path in sorted((ROOT/'replication'/name).glob('*.luau'),key=lambda p:p.name):
            rows.append(dict(path=['ChronoFork',name,path.stem],**{'class':'ModuleScript'},source=f'return require(script.Parent.Parent.Replication.{name}.{path.stem})\n'))
    rows.append(dict(path=['ChronoFork','ReadyPaths'],**{'class':'StringValue'},value=json.dumps(['/'.join(r['path'][1:]) for r in rows if len(r['path'])>1],separators=(',',':'))))
    return rows
def build():
    OUT.mkdir(exist_ok=True)
    rows=runtime()
    model(rows,OUT/'ChronoFork.rbxmx')
    validation=[dict(path=['ChronoForkValidation'],**{'class':'Folder'})]
    validation += [{**r,'path':['ChronoForkValidation']+r['path']} for r in rows]
    validation += tree(ROOT/'tests/full',['ChronoForkValidation','Tests'])
    validation += [r for r in tree(ROOT/'framework/Editor',['ChronoForkValidation','Editor']) if r['path'][-1]!='PluginMain']
    validation += tree(ROOT/'vendor/chrono/src',['ChronoForkValidation','Original'])
    editor=ROOT/'framework/Editor'
    if (editor/'PluginMain.luau').exists():
        plugin=[dict(path=['ChronoForkSetup'],**{'class':'Script'},source=source(editor/'PluginMain.luau'))]
        plugin += [{**r,'path':['ChronoForkSetup']+r['path']} for r in rows]
        plugin += [r for r in tree(editor,['ChronoForkSetup','Editor']) if r['path'][-1]!='PluginMain']
        # Existing contact setup is bundled alongside the full runtime installer.
        plugin += [{**r,'path':['ChronoForkSetup','ContactEditor']+r['path'][1:]} for r in tree(ROOT/'editor',['ContactEditor']) if r['path'][-1]!='PluginMain']
        plugin += tree(ROOT/'src',['ChronoForkSetup','Core'])
        plugin += tree(ROOT/'runtime',['ChronoForkSetup','Runtime'])
        model(plugin,OUT/'ChronoForkSetup.rbxmx')
    model(validation,OUT/'ChronoForkTests.rbxmx')
    (OUT/'studio-fixture.json').write_text(json.dumps(validation,separators=(',',':')),encoding='utf-8',newline='\n')
    files=[p for d in ['framework','replication','vendor/chrono','tests','docs','src','runtime','editor','examples','benchmarks','tools','.github','dist','site'] for p in (ROOT/d).rglob('*') if p.is_file() and '__pycache__' not in p.parts and not ('site' in p.relative_to(ROOT).parts and 'downloads' in p.relative_to(ROOT).parts)]
    files += [p for p in ROOT.iterdir() if p.is_file() and (p.suffix in ['.md','.json'] or p.name in ['LICENSE','NOTICE','.gitignore','.gitattributes'])]
    files=sorted(set(files),key=lambda p:p.relative_to(ROOT).as_posix())
    manifest={'version':VERSION,'wireVersion':2,'coreVersion':'3.1.0','upstream':json.loads(source(ROOT/'vendor/chrono/UPSTREAM.json'))['revision'],
              'status':'development preview; see IMPLEMENTATION.md for validation gates','files':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
    (OUT/'MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
    for name in ['LICENSE','NOTICE','CREDITS.md']: shutil.copyfile(ROOT/name,OUT/name)
    archive=OUT/'ChronoFork-3.3.0-dev.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for p in sorted(files+list(OUT.glob('*.rbxmx'))+[OUT/'MANIFEST.json'],key=lambda p:p.relative_to(ROOT).as_posix()):
            info=zipfile.ZipInfo(p.relative_to(ROOT).as_posix(),date_time=(2026,10,27,0,0,0))
            info.create_system=3;info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16
            z.writestr(info,p.read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    checksummed=list(OUT.glob('*.rbxmx'))+[OUT/'MANIFEST.json',archive]
    (OUT/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in sorted(checksummed,key=lambda p:p.name)),encoding='utf-8',newline='\n')
    print(json.dumps({'runtimeInstances':len(rows),'fixtureInstances':len(validation),'version':VERSION}))
if __name__=='__main__': build()
