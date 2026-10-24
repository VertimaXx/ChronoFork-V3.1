"""Portable, deterministic V3.1 assets/site builder. Python 3.10+, standard library only."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '3.1.0'
UPSTREAM = '99e77a35822bca389f25a4d27d4de21249b287e0'


def text(path):
    return (ROOT / path).read_text(encoding='utf-8-sig').replace('\r\n', '\n')


def nodes(folder, name):
    rows = []
    def walk(directory, path):
        init = directory / 'init.luau'
        row = {'path': path, 'class': 'ModuleScript' if init.exists() else 'Folder'}
        if init.exists():
            row['source'] = init.read_text(encoding='utf-8-sig').replace('\r\n', '\n')
        rows.append(row)
        for p in sorted(directory.iterdir(), key=lambda p: p.name):
            if p.is_dir():
                walk(p, path + [p.name])
            elif p.suffix == '.luau' and p.name != 'init.luau':
                rows.append({'path': path + [p.stem], 'class': 'ModuleScript',
                             'source': p.read_text(encoding='utf-8-sig').replace('\r\n', '\n')})
    walk(ROOT / folder, [name])
    return rows


def asset(rows, path):
    root, mapped = ET.Element('roblox', {'version': '4'}), {}
    for i, row in enumerate(rows):
        parent = mapped[tuple(row['path'][:-1])] if len(row['path']) > 1 else root
        item = ET.SubElement(parent, 'Item', {'class': row['class'], 'referent': f'CF{i}'})
        props = ET.SubElement(item, 'Properties')
        ET.SubElement(props, 'string', {'name': 'Name'}).text = row['path'][-1]
        if 'source' in row:
            ET.SubElement(props, 'ProtectedString', {'name': 'Source'}).text = row['source']
        if 'value' in row:
            ET.SubElement(props, 'string', {'name': 'Value'}).text = row['value']
        if row.get('disabled'):
            ET.SubElement(props, 'bool', {'name': 'Disabled'}).text = 'true'
        mapped[tuple(row['path'])] = item
    (ROOT / path).write_bytes(ET.tostring(root, encoding='utf-8', xml_declaration=True))


def remap(rows, prefix):
    return [{**r, 'path': prefix + r['path']} for r in rows]


def build():
    dist = ROOT / 'dist'
    dist.mkdir(exist_ok=True)
    core = nodes('src', 'Core')
    editor = [r for r in nodes('editor', 'Editor') if r['path'] != ['Editor', 'PluginMain']]
    plugin = [{'path': ['ChronoV3Setup'], 'class': 'Script', 'source': text('editor/PluginMain.luau')}]
    runtime = nodes('runtime', 'Runtime')
    plugin += remap(core + editor + runtime, ['ChronoV3Setup'])
    asset([{**r, 'path': ['ChronoV3'] + r['path'][1:]} for r in core], 'dist/ChronoV3.rbxmx')
    asset(plugin, 'dist/ChronoV3Setup.rbxmx')
    guides = [{'path': ['ChronoV3Guides'], 'class': 'ModuleScript', 'source': text('examples/Guides.luau')},
              {'path': ['ChronoV3Guides', 'Help'], 'class': 'ModuleScript', 'source': text('src/Help.luau')}]
    asset(guides, 'dist/ChronoV3Guides.rbxmx')
    toolkit = [{'path': ['ChronoV3Toolkit'], 'class': 'Folder'}] + remap(core, ['ChronoV3Toolkit'])
    toolkit += [{**r, 'path': ['ChronoV3Toolkit', 'Setup'] + r['path'][1:]} for r in plugin]
    example = nodes('examples', 'Examples')
    example.append({'path': ['Examples', 'Guides', 'Help'], 'class': 'ModuleScript', 'source': text('src/Help.luau')})
    toolkit += remap(example, ['ChronoV3Toolkit'])
    toolkit.append({'path': ['ChronoV3Toolkit', 'ReadMe'], 'class': 'StringValue',
                    'value': 'ChronoFork V3.1. Unofficial Chrono fork; original credit: Parihsz and contributors. Developed with OpenAI Codex / AI under VertimaXx direction. Save Setup as a Local Plugin. Open Plugins > Chrono V3 > ChronoSetup. Practice starts OFF and does not certify your game. Your server supplies checked positions and owns move authorization/outcomes. See README and CREDITS.'})
    asset(toolkit, 'dist/ChronoV3Toolkit.rbxmx')
    validation = [{'path': ['ChronoV3Validation'], 'class': 'Folder'}]
    validation += remap(core + editor + runtime, ['ChronoV3Validation'])
    for name in ['Campaign', 'EngineOracle', 'MatchedBenchmark', 'LoadBenchmark', 'ConnectionStudioChecks', 'ConnectionPlayChecks', 'ConnectionTestSetup']:
        validation.append({'path': ['ChronoV3Validation', name], 'class': 'ModuleScript', 'source': text(f'tests/{name}.luau')})
    tests = [{'path': ['UnitTest'], 'class': 'Folder'}, {'path': ['UnitTest', 'Cases'], 'class': 'Folder'}]
    for p in sorted((ROOT / 'tests').glob('*_Test.luau')):
        tests.append({'path': ['UnitTest', 'Cases', p.stem], 'class': 'ModuleScript', 'source': text(p.relative_to(ROOT))})
    tests.append({'path': ['UnitTest', 'RunUnitTest'], 'class': 'ModuleScript', 'source': text('tests/RunUnitTest.luau')})
    asset(validation + tests, 'dist/ChronoV3Tests.rbxmx')
    # Site uses repository Markdown and preserved raw JSON; no external JS/fonts/CDN.
    from site_build import build_site
    build_site(ROOT)
    inputs = ['src', 'editor', 'runtime', 'examples', 'tests', 'tools', 'docs', 'benchmarks', '.github']
    files = [p for name in inputs for p in (ROOT / name).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    files += [ROOT / n for n in ['README.md', 'LICENSE', 'NOTICE', 'CREDITS.md', 'CHANGELOG.md', 'CONTRIBUTING.md', 'SECURITY.md', 'default.project.json', '.gitattributes', '.gitignore']]
    files += list(dist.glob('*.rbxmx'))
    files += [p for p in (ROOT / 'site').rglob('*') if p.is_file() and 'downloads' not in p.parts]
    manifest = {'version': VERSION, 'sourceDate': '2026-10-21', 'packagedDate': '2026-10-24', 'connectionBuild': '2026-10-24', 'upstreamComparisonRevision': UPSTREAM,
                'scope': 'V3.1 code only; historical comparison data retain earlier labels',
                'files': {p.relative_to(ROOT).as_posix(): {'bytes': len(p.read_bytes()), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(files, key=lambda p: p.relative_to(ROOT).as_posix())}}
    (dist / 'MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')
    files.append(dist / 'MANIFEST.json')
    archive = dist / f'ChronoFork-{VERSION}.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in sorted(files, key=lambda p: p.relative_to(ROOT).as_posix()):
            info = zipfile.ZipInfo(p.relative_to(ROOT).as_posix(), date_time=(2026, 10, 24, 0, 0, 0))
            info.create_system = 3  # Fix the ZIP creator field across Windows and Unix.
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, p.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    downloads = ROOT / 'site/downloads'
    downloads.mkdir(exist_ok=True)
    for p in sorted(dist.iterdir()):
        if p.is_file():
            shutil.copyfile(p, downloads / p.name)
    print(json.dumps({'version': VERSION, 'manifestFiles': len(manifest['files']), 'zipBytes': archive.stat().st_size, 'models': 5}))


if __name__ == '__main__':
    build()
