import json, struct, sys
for p in sys.argv[1:]:
    with open(p, 'rb') as f:
        f.read(12)
        ln, ty = struct.unpack('<II', f.read(8))
        j = json.loads(f.read(ln))
    print('==', p)
    print(' asset:', json.dumps(j.get('asset'), ensure_ascii=False)[:600])
    print(' nodes', len(j.get('nodes', [])), 'meshes', len(j.get('meshes', [])), 'images', len(j.get('images', [])), 'materials', len(j.get('materials', [])))
    print(' exts', j.get('extensionsUsed'))
    names = [n.get('name') for n in j.get('nodes', []) if n.get('name')]
    print(' wheel-ish:', [n for n in names if any(k in n.lower() for k in ('whe','kole','tire','tyre','rim','disk','wheel'))][:40])
    sc = j.get('scenes', [{}])[0].get('nodes')
    print(' root nodes:', [(j['nodes'][i].get('name'), j['nodes'][i].get('scale'), j['nodes'][i].get('rotation')) for i in sc][:5])
