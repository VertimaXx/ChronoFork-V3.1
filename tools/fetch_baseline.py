"""Optional original-Chrono benchmark fixture; never part of runtime/download assets."""
from pathlib import Path
import hashlib
import json
import re
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
REV = '99e77a35822bca389f25a4d27d4de21249b287e0'


def main():
    out = ROOT / 'vendor/upstream-baseline'
    out.mkdir(parents=True, exist_ok=True)
    root = ET.Element('roblox', {'version': '4'})
    parent = ET.SubElement(root, 'Item', {'class': 'Folder', 'referent': 'BASE'})
    props = ET.SubElement(parent, 'Properties')
    ET.SubElement(props, 'string', {'name': 'Name'}).text = 'OriginalChronoBaseline'
    shared = ET.SubElement(parent, 'Item', {'class': 'Folder', 'referent': 'SHARED'})
    props = ET.SubElement(shared, 'Properties')
    ET.SubElement(props, 'string', {'name': 'Name'}).text = 'Shared'
    records = {}
    for i, name in enumerate(['Types', 'Config', 'Warn', 'InterpolationMath', 'Snapshots']):
        url = f'https://raw.githubusercontent.com/Parihsz/Chrono/{REV}/src/Shared/{name}.luau'
        original = urllib.request.urlopen(url, timeout=30).read()
        (out / f'{name}.upstream.luau').write_bytes(original)
        # Token-aware replacement: do not change text inside strings/comments.
        source = original.decode('utf-8-sig').replace('\r\n', '\n')
        token = re.compile(r'--\[(=*)\[.*?\]\1\]|--[^\n]*|\[(=*)\[.*?\]\2\]|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|`(?:\\.|[^`\\])*`|\bconst\b', re.S)
        normalized = token.sub(lambda m: 'local' if m.group() == 'const' else m.group(), source)
        item = ET.SubElement(shared, 'Item', {'class': 'ModuleScript', 'referent': f'M{i}'})
        props = ET.SubElement(item, 'Properties')
        ET.SubElement(props, 'string', {'name': 'Name'}).text = name
        ET.SubElement(props, 'ProtectedString', {'name': 'Source'}).text = normalized
        records[name] = {'url': url, 'originalSha256': hashlib.sha256(original).hexdigest(),
                         'normalizedSha256': hashlib.sha256(normalized.encode()).hexdigest()}
    license_data = urllib.request.urlopen(f'https://raw.githubusercontent.com/Parihsz/Chrono/{REV}/LICENSE', timeout=30).read()
    (out / 'LICENSE').write_bytes(license_data)
    (out / 'PROVENANCE.json').write_text(json.dumps({'revision': REV, 'change': 'const tokens to local for engine compatibility; arithmetic unchanged', 'files': records}, indent=2) + '\n')
    ET.ElementTree(root).write(out / 'OriginalChronoBaseline.rbxmx', encoding='utf-8', xml_declaration=True)
    print('Created ignored vendor/upstream-baseline/OriginalChronoBaseline.rbxmx; import into ServerStorage for the matched test only.')


if __name__ == '__main__':
    main()
