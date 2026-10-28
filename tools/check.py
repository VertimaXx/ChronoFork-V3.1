"""Packaging checks only. Roblox runtime tests are documented separately."""
from pathlib import Path
import argparse
import hashlib
from html.parser import HTMLParser
import json
import re
import subprocess
import urllib.parse
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links, self.ids = [], set()
    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        self.links += [d[k] for k in ['href', 'src'] if k in d]
        if 'id' in d:
            assert d['id'] not in self.ids, 'duplicate HTML id: ' + d['id']
            self.ids.add(d['id'])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--luau-compile')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'dist/MANIFEST.json').read_text())
    # V3.2 is immutable release evidence. New preview docs/tools intentionally
    # differ from its sources; verify the original bytes inside its retained ZIP.
    stable_archive=zipfile.ZipFile(ROOT / 'dist/ChronoFork-3.2.0.zip')
    for name, row in manifest['files'].items():
        p = ROOT / name
        b = stable_archive.read(name)
        assert hashlib.sha256(b).hexdigest() == row['sha256'] and len(b) == row['bytes'], 'rebuild after editing: ' + name
    stable_archive.close()
    latest = json.loads((ROOT / 'benchmarks/data/v3.1-validation.json').read_text())
    assert latest['version'] == '3.1.0' and latest['unit']['passed'] == 63
    assert latest['timelineRegression']['passed'] == 8192 and latest['nativeNetworkTested'] is False
    old = json.loads((ROOT / 'benchmarks/data/v3.0-numerical.json').read_text())
    assert old['version'] == '3.0.0' and old['benchmark']['queries'] == 34000
    connections = json.loads((ROOT / 'benchmarks/data/v3.1-connections-2026-10-24.json').read_text())
    assert connections['version'] == '3.1.0'
    expanded = json.loads((ROOT / 'benchmarks/data/v3.2-connector-2026-10-25.json').read_text())
    assert expanded['version'] == '3.2.0' and expanded['coreVersion'] == '3.1.0'
    for key in ['expandedRuntime', 'existingRuntime', 'coreTests', 'expandedEditor', 'existingEditor']:
        suite = expanded[key]
        assert suite['run'] == suite['passed'] and suite['failed'] == 0, key
        assert all(row['passed'] for row in suite['cases']), key
    assert sum(expanded[key]['run'] for key in ['expandedRuntime', 'existingRuntime', 'coreTests', 'expandedEditor', 'existingEditor']) == expanded['summary']['run']
    for name, digest in expanded['sourceHashes'].items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, 'source changed after 3.2 validation: ' + name
    combat = json.loads((ROOT / 'benchmarks/data/v3.1-combat-integration-2026-10-24.json').read_text())
    assert combat['summary']['totalPassed'] == 80 and combat['summary']['onlyGeneratedBlocksOutsidePackage'] == 3
    assert combat['workflow']['passed'] and combat['movement']['passed']
    for key, expected in [('parity', 59), ('input', 8), ('refusals', 9)]:
        rows = combat['workflow'][key]
        assert len(rows) == expected and all(row['passed'] for row in rows), key
    assert len(combat['movement']['rows']) == 4
    assert all(row['passed'] and row['refused'] == 0 for row in combat['movement']['rows'])
    assert not combat['summary']['rewindEnabled'] and all(value == 0 for value in combat['summary']['networkImpairment'].values())
    example = combat['exampleSource']
    assert hashlib.sha256((ROOT / example['path']).read_bytes()).hexdigest() == example['sha256']
    for name, digest in combat['harnessSources'].items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
    model_sources = 0
    allowed = {p.read_text(encoding='utf-8-sig').replace('\r\n', '\n') for folder in ['src', 'editor', 'runtime', 'examples', 'tests'] for p in (ROOT / folder).glob('*.luau')}
    for p in (ROOT / 'dist').glob('*.rbxmx'):
        xml = ET.parse(p)
        assert xml.getroot().tag == 'roblox'
        for source in xml.findall('.//ProtectedString[@name="Source"]'):
            assert (source.text or '').replace('\r\n', '\n') in allowed, 'embedded source differs: ' + p.name
            model_sources += 1
        assert 'V2WorldBridge' not in p.read_text(), 'legacy bridge shipped'
        assert not xml.findall('.//Item[@class="RemoteEvent"]'), 'unexpected remote'
    pages = {}
    for p in (ROOT / 'site').glob('*.html'):
        data = p.read_text(encoding='utf-8')
        tree = Links()
        tree.feed(data)
        assert '<html lang="en">' in data and '<main' in data and '<title>' in data
        pages[p.resolve()] = tree
    local_links = 0
    def check_link(p, url):
        nonlocal local_links
        u = urllib.parse.urlsplit(url)
        if u.scheme or u.netloc or not u.path and not u.fragment:
            return
        target = (p.parent / urllib.parse.unquote(u.path)).resolve() if u.path else p.resolve()
        assert target.is_relative_to(ROOT), 'outside repo link: ' + str(p) + ':' + url
        assert target.exists(), 'broken link: ' + str(p) + ':' + url
        if u.fragment and target in pages:
            assert urllib.parse.unquote(u.fragment) in pages[target].ids, 'missing fragment: ' + url
        local_links += 1
    for p, tree in pages.items():
        for link in tree.links:
            check_link(p, link)
    for p in [*ROOT.glob('*.md'), *(ROOT / 'docs').rglob('*.md')]:
        for url in re.findall(r'\]\(([^\s)]+)\)', p.read_text(encoding='utf-8')):
            check_link(p, url)
    archive = ROOT / ('dist/ChronoFork-' + manifest['version'] + '.zip')
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        assert 'dist/ChronoV3Setup.rbxmx' in z.namelist() and 'LICENSE' in z.namelist()
        assert not any('V2WorldBridge' in n or n.endswith('.rbxl') for n in z.namelist())
    help_data = json.loads((ROOT / 'site/assets/help.json').read_text())
    assert len(help_data['terms']) == 50 and len(help_data['messages']) == 48
    connector_help = json.loads((ROOT / 'site/assets/connector-help.json').read_text())
    assert connector_help['version'] == '3.2.0' and len(connector_help['messages']) == 18
    assert 'move_already_checked' in connector_help['messages']
    count = 0
    if args.luau_compile:
        for folder in ['src', 'editor', 'runtime', 'examples', 'tests']:
            for p in sorted((ROOT / folder).glob('*.luau')):
                subprocess.run([args.luau_compile, '--null', str(p)], check=True, capture_output=True)
                count += 1
    print(json.dumps({'manifestFiles': len(manifest['files']), 'embeddedSourcesChecked': model_sources,
                      'htmlPages': len(pages), 'localLinks': local_links, 'luauCompiled': count,
                      'runtimeTestsRerun': False, 'status': 'passed'}))
    from full_check import verify
    assert verify(args.luau_compile), 'preview checks failed'
    for name in ['ChronoFork.rbxmx','ChronoForkSetup.rbxmx','ChronoForkTests.rbxmx','ChronoFork-3.3.0-dev.zip','MANIFEST.json','SHA256SUMS.txt']:
        assert (ROOT/'dist-preview'/name).read_bytes()==(ROOT/'site/downloads/preview'/name).read_bytes(),'stale website preview download: '+name


if __name__ == '__main__':
    main()
