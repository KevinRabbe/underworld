"""Deterministic reference-crop validation for character evidence.

Keeps exactly one connected person component per source panel and fails closed
when a plausible full-height component cannot be identified. No mesh or GLB is
modified by this utility.
"""
from pathlib import Path
from PIL import Image, ImageFilter
import hashlib, re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/character_visuals/final_comparison"
SOURCES = {
    "male": ROOT / "docs/character_visuals/reference_inputs/male_source.png",
    "female": ROOT / "docs/character_visuals/reference_inputs/female_source.png",
}
BOXES = {
    ("male", "front"): (24, 12, 100, 140), ("male", "side"): (45, 140, 92, 278),
    ("female", "front"): (30, 12, 122, 142), ("female", "side"): (55, 143, 100, 282),
}

manifest = ROOT / "docs/character_visuals/reference_inputs/SHA256SUMS.txt"
if not manifest.exists(): raise SystemExit("FAIL: missing SHA256SUMS.txt")
expected = {}
for line in manifest.read_text(encoding="utf-8").splitlines():
    parts=line.split()
    if len(parts)!=2 or not re.fullmatch(r"[0-9A-Fa-f]{64}",parts[0]): raise SystemExit(f"FAIL: malformed manifest line: {line!r}")
    expected[parts[1]]=parts[0].lower()
for name,path in (("male_source.png",SOURCES["male"]),("female_source.png",SOURCES["female"])):
    if name not in expected or not path.is_file(): raise SystemExit(f"FAIL: missing manifest entry or source: {name}")
    actual=hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected[name]: raise SystemExit(f"FAIL: SHA-256 mismatch for {name}")

def components(mask):
    px, w, h = mask.load(), mask.width, mask.height; seen=set(); out=[]
    for y in range(h):
        for x in range(w):
            if not px[x,y] or (x,y) in seen: continue
            q=[(x,y)]; seen.add((x,y)); c=[]
            while q:
                a,b=q.pop(); c.append((a,b))
                for n in ((a-1,b),(a+1,b),(a,b-1),(a,b+1),(a-1,b-1),(a+1,b-1),(a-1,b+1),(a+1,b+1)):
                    if 0<=n[0]<w and 0<=n[1]<h and px[n[0],n[1]] and n not in seen: seen.add(n); q.append(n)
            out.append(c)
    return out

for gender in ("male", "female"):
    source=Image.open(SOURCES[gender]).convert("RGB")
    for view in ("front", "side"):
        crop=source.crop(BOXES[(gender,view)]); rgb=crop.load(); mask=Image.new("L",crop.size,0); mp=mask.load()
        for yy in range(crop.height):
            for xx in range(crop.width):
                rr,gg,bb=rgb[xx,yy]
                if max(rr,gg,bb)-min(rr,gg,bb)>=14 and max(rr,gg,bb)>=48: mp[xx,yy]=255
        mask=mask.filter(ImageFilter.MaxFilter(3))
        comps=components(mask); viable=[]
        for c in comps:
            ys=[p[1] for p in c]; xs=[p[0] for p in c]; height=max(ys)-min(ys)+1
            if height >= crop.height*0.55 and len(c) >= 20: viable.append((height*len(c),c))
        if not viable: raise SystemExit(f"FAIL: no single full-height component for {gender}/{view}")
        chosen=max(viable,key=lambda x:x[0])[1]
        alpha=Image.new("L",crop.size,0); ap=alpha.load()
        for x,y in chosen: ap[x,y]=255
        b=alpha.getbbox(); pad=3; b=(max(0,b[0]-pad),max(0,b[1]-pad),min(crop.width,b[2]+pad),min(crop.height,b[3]+pad))
        clean=crop.crop(b); alpha=alpha.crop(b)
        canvas=Image.new("RGB",(clean.width,clean.height),(58,58,58)); canvas.paste(clean,(0,0),alpha)
        canvas.save(OUT/f"validated_reference_{gender}_{view}.png")
