"""Build the current preview and website; preserve immutable V3.2 downloads.
To reproduce V3.2 itself, check out its v3.2.0 tag and use that tag\'s builder.
"""
from pathlib import Path
import shutil
from site_build import build_site
from full_build import build as build_preview
ROOT=Path(__file__).resolve().parents[1]
def build():
    build_site(ROOT)
    build_preview()
    downloads=ROOT/"site/downloads/preview"
    downloads.mkdir(parents=True,exist_ok=True)
    for name in ["ChronoFork.rbxmx","ChronoForkSetup.rbxmx","ChronoForkTests.rbxmx","ChronoFork-3.3.0-dev.zip","MANIFEST.json","SHA256SUMS.txt"]:
        shutil.copyfile(ROOT/"dist-preview"/name,downloads/name)
if __name__=="__main__": build()
