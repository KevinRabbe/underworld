"""Build deterministic front/side evidence comparisons.

The validated reference image is aligned to the evaluated evidence render by
uniform scale and translation only. Component masks are used only to locate
the measurable colored reference pixels; they are never presented as a full
body silhouette or used to infer hidden anatomy.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/character_visuals/final_comparison'

def mask(im, threshold):
    return im.convert('L').point(lambda p: 255 if p > threshold else 0)

def measurable_mask(im):
    rgb=im.convert('RGB'); out=Image.new('L',rgb.size,0); src=rgb.load(); dst=out.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            r,g,b=src[x,y]
            if max(r,g,b)-min(r,g,b)>=14 and max(r,g,b)>=48: dst[x,y]=255
    return out

for gender in ('male','female'):
    for view in ('front','side'):
        result=Image.open(OUT/f'{gender}_armsdown_{view}.png').convert('RGB')
        reference=Image.open(OUT/f'validated_reference_raw_{gender}_{view}.png').convert('RGB')
        result_mask=mask(result,115); ref_mask=measurable_mask(reference)
        rb=result_mask.getbbox(); fb=ref_mask.getbbox()
        if not rb or not fb: raise SystemExit(f'FAIL: missing measurable body bounds {gender}/{view}')
        scale=(rb[3]-rb[1])/float(fb[3]-fb[1])
        reference=reference.resize((round(reference.width*scale),round(reference.height*scale)),Image.Resampling.LANCZOS)
        ref_mask=measurable_mask(reference); fb=ref_mask.getbbox()
        dx=round((rb[0]+rb[2])/2-(fb[0]+fb[2])/2); dy=round(rb[1]-fb[1])
        aligned=Image.new('RGB',result.size,(58,58,58)); alpha=Image.new('L',result.size,0)
        aligned.paste(reference,(dx,dy)); alpha.paste(ref_mask,(dx,dy))
        aligned.save(OUT/f'clean_reference_{gender}_{view}.png')
        overlay=Image.blend(aligned,result,0.5)
        overlay.save(OUT/f'clean_overlay_{gender}_{view}.png')
        thumb=lambda im: im.resize((512,512),Image.Resampling.LANCZOS)
        sheet=Image.new('RGB',(1536,512),(30,30,30)); sheet.paste(thumb(aligned),(0,0)); sheet.paste(thumb(result),(512,0)); sheet.paste(thumb(overlay),(1024,0))
        draw=ImageDraw.Draw(sheet); draw.text((16,16),f'{gender} {view} CLEAN REFERENCE',fill='white'); draw.text((528,16),'ARMS-DOWN EVALUATED ARMATURE',fill='white'); draw.text((1040,16),'50% OVERLAY',fill='white')
        sheet.save(OUT/f'clean_comparison_{gender}_{view}.png')
