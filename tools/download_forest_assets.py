#!/usr/bin/env python3
"""Poly Haven meşə modellərini (1K glTF) bütün asılılıqları ilə yükləyir.

Orijinal `download_assets.py` skriptindəki xəta düzəldilib: o, `include` bölməsinə (`.bin` və tekstura
faylları) girmirdi, ona görə yalnız `.gltf` JSON faylları yüklənirdi.

İstifadə: python tools/download_forest_assets.py [--resolution 1k]
Çıxış: assets_src/polyhaven/<id>/ (Godot bu qovluğu `.gdignore` ilə import etmir).
Mənbə: https://api.polyhaven.com/files/{id}, lisenziya CC0.
"""
import argparse, hashlib, json, sys, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UA = 'Offroad-Forest-Asset-Pack/1.0 (personal game development)'


def get_json(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def md5_of(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def download(url, path, md5, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.stat().st_size == size and (not md5 or md5_of(path) == md5):
        return 'var'
    part = Path(str(path) + '.part')
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': UA})
            with urllib.request.urlopen(req, timeout=120) as src, open(part, 'wb') as dst:
                while True:
                    chunk = src.read(1 << 20)
                    if not chunk:
                        break
                    dst.write(chunk)
            if md5 and md5_of(part) != md5:
                raise ValueError('md5 uyğun gəlmir')
            part.replace(path)
            return 'yükləndi'
        except Exception as e:
            part.unlink(missing_ok=True)
            if attempt == 2:
                raise
            time.sleep(2 * (attempt + 1))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--resolution', default='1k', choices=['1k', '2k', '4k'])
    args = ap.parse_args()
    assets = json.loads((ROOT / 'tools' / 'forest_assets.json').read_text(encoding='utf8'))
    out_root = ROOT / 'assets_src' / 'polyhaven'
    errors = []
    for a in assets:
        ident = a['id']
        print('\n==', ident, flush=True)
        try:
            data = get_json('https://api.polyhaven.com/files/' + ident)
            entry = data['gltf'][args.resolution]['gltf']
            files = [(Path(entry['url']).name, entry)]
            for rel, item in entry.get('include', {}).items():
                files.append((rel, item))
            # alfa xəritələri glTF `include` siyahısında yoxdur, ayrıca maplardandır (PNG, kartlar üçün lazımdır)
            for key, maps in data.items():
                if 'alpha' in key.lower() and isinstance(maps, dict) and args.resolution in maps:
                    png = maps[args.resolution].get('png')
                    if png:
                        files.append(('textures/%s_%s_%s.png' % (ident, key.lower(), args.resolution), png))
            for rel, item in files:
                rp = Path(rel)
                if rp.is_absolute() or '..' in rp.parts:
                    raise RuntimeError('təhlükəli yol: ' + rel)
                state = download(item['url'], out_root / ident / rp, item.get('md5'), item.get('size', 0))
                print('  %-8s %s (%.1f MB)' % (state, rel, item.get('size', 0) / 1e6), flush=True)
        except Exception as e:
            errors.append((ident, str(e)))
            print('  XƏTA:', e, flush=True)
    print('\nXətalar:', len(errors))
    for ident, e in errors:
        print(' ', ident, e)
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
