import struct, json, sys, io
from PIL import Image

MAXDIM = 1024

def resize_glb(path, maxdim=MAXDIM):
    with open(path, 'rb') as f:
        data = f.read()
    magic, ver, length = struct.unpack('<III', data[:12])
    assert magic == 0x46546C67, "not glb"
    off = 12
    json_chunk = bin_chunk = None
    while off < length:
        clen, ctype = struct.unpack('<II', data[off:off+8])
        cdata = data[off+8:off+8+clen]
        if ctype == 0x4E4F534A:   # JSON
            json_chunk = cdata
        elif ctype == 0x004E4942: # BIN
            bin_chunk = cdata
        off += 8 + clen
    js = json.loads(json_chunk)
    bin_data = bytearray(bin_chunk)
    bvs = js.get('bufferViews', [])
    images = js.get('images', [])

    # image bufferView index -> new bytes
    img_bv = {}
    changed = 0
    for im in images:
        bv_i = im.get('bufferView')
        if bv_i is None:
            continue
        bv = bvs[bv_i]
        o = bv.get('byteOffset', 0); l = bv['byteLength']
        raw = bytes(bin_data[o:o+l])
        try:
            img = Image.open(io.BytesIO(raw))
        except Exception as e:
            continue
        w, h = img.size
        if max(w, h) <= maxdim:
            img_bv[bv_i] = raw  # keep
            continue
        scale = maxdim / max(w, h)
        nw, nh = max(1, round(w*scale)), max(1, round(h*scale))
        img2 = img.resize((nw, nh), Image.LANCZOS)
        out = io.BytesIO()
        mime = im.get('mimeType', 'image/png')
        if 'jpeg' in mime or 'jpg' in mime:
            if img2.mode in ('RGBA','P'): img2 = img2.convert('RGB')
            img2.save(out, format='JPEG', quality=85, optimize=True)
        else:
            img2.save(out, format='PNG', optimize=True)
        img_bv[bv_i] = out.getvalue()
        changed += 1

    if changed == 0:
        return None

    # rebuild BIN: keep each bufferView's bytes (resized for images), reassign
    # offsets in bufferView-index order, 4-byte aligned.
    new_bin = bytearray()
    for i, bv in enumerate(bvs):
        o = bv.get('byteOffset', 0); l = bv['byteLength']
        if i in img_bv:
            b = img_bv[i]
        else:
            b = bytes(bin_data[o:o+l])
        # 4-byte align
        while len(new_bin) % 4 != 0:
            new_bin.append(0)
        bv['byteOffset'] = len(new_bin)
        bv['byteLength'] = len(b)
        new_bin += b
    while len(new_bin) % 4 != 0:
        new_bin.append(0)
    if js.get('buffers'):
        js['buffers'][0]['byteLength'] = len(new_bin)

    # rebuild GLB
    new_json = json.dumps(js, separators=(',', ':')).encode('utf-8')
    while len(new_json) % 4 != 0:
        new_json += b' '
    out = bytearray()
    total = 12 + 8 + len(new_json) + 8 + len(new_bin)
    out += struct.pack('<III', 0x46546C67, 2, total)
    out += struct.pack('<II', len(new_json), 0x4E4F534A) + new_json
    out += struct.pack('<II', len(new_bin), 0x004E4942) + new_bin
    return bytes(out)

import os
for name in sys.argv[1:]:
    p = f"assets/models/test/{name}"
    before = os.path.getsize(p)
    res = resize_glb(p)
    if res is None:
        print(f"{name}: degisiklik yok (<= {MAXDIM}px)")
        continue
    with open(p, 'wb') as f:
        f.write(res)
    after = len(res)
    print(f"{name}: {before/1048576:.1f} MB -> {after/1048576:.1f} MB")
