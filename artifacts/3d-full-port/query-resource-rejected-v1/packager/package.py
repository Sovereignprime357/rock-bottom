"""Root-owned, finite, byte-exact evidence copy. No engine/build/Git actions."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def inside(base: Path, relative: str) -> Path:
    part = Path(relative)
    if part.is_absolute() or '..' in part.parts:
        raise ValueError(f'Unsafe relative path: {relative}')
    path = (base / part).resolve()
    if not path.is_relative_to(base.resolve()) or path == base.resolve():
        raise ValueError(f'Path escapes root: {relative}')
    return path


def preflight() -> tuple[dict, list[tuple[dict, Path]]]:
    data = json.loads((HERE / 'PACKAGE-ALLOWLIST.json').read_text(encoding='utf-8'))
    if data.get('schema') != 1 or data.get('decision') != 'reject_query_resource_promotion':
        raise ValueError('Unrecognized allowlist')
    result = []
    destinations = set()
    for entry in data['copy']:
        source = inside(ROOT, entry['source'])
        dest = inside(ROOT, entry['destination']).relative_to(ROOT).as_posix().lower()
        if dest in destinations or source.suffix.lower() == '.exe':
            raise ValueError(f'Duplicate destination or executable copy: {dest}')
        destinations.add(dest)
        if source.stat().st_size != entry['bytes'] or digest(source) != entry['sha256']:
            raise ValueError(f'Input changed: {source}')
        result.append((entry, source))
    for entry in data['hash_only']:
        source = inside(ROOT, entry['source'])
        if source.stat().st_size != entry['bytes'] or digest(source) != entry['sha256']:
            raise ValueError(f'Hash-only input changed: {source}')
    return data, result


def main() -> None:
    parser = argparse.ArgumentParser()
    choice = parser.add_mutually_exclusive_group(required=True)
    choice.add_argument('--check', action='store_true')
    choice.add_argument('--output')
    args = parser.parse_args()
    data, files = preflight()
    if args.check:
        print(json.dumps({'check': 'PASS', 'files': len(files), 'bytes': sum(x['bytes'] for x, _ in files), 'hash_only': len(data['hash_only'])}))
        return
    output = inside(ROOT, args.output)
    if output.exists():
        raise FileExistsError(f'Output must be fresh; retained: {output}')
    # Fully validate every destination before publishing even the first file.
    targets = [(entry, source, inside(output, entry['destination'])) for entry, source in files]
    output.mkdir(parents=True, exist_ok=False)
    for entry, source, target in targets:
        target.parent.mkdir(parents=True, exist_ok=True)
        with source.open('rb') as incoming, target.open('xb') as outgoing:
            for chunk in iter(lambda: incoming.read(1024 * 1024), b''):
                outgoing.write(chunk)
        if target.stat().st_size != entry['bytes'] or digest(target) != entry['sha256']:
            raise ValueError(f'Copied bytes changed; partial output retained: {target}')
    receipt = {'schema': 1, 'decision': data['decision'], 'allowlist_sha256': digest(HERE / 'PACKAGE-ALLOWLIST.json'), 'packager_sha256': digest(Path(__file__)), 'copies': data['copy'], 'hash_only': data['hash_only'], 'performance_acceptance': False}
    with (output / 'PACKAGE-RECEIPT.json').open('x', encoding='utf-8', newline='\n') as handle:
        json.dump(receipt, handle, indent=2)
        handle.write('\n')
    print(json.dumps({'copied': len(files), 'output': str(output), 'performance_acceptance': False}))


if __name__ == '__main__':
    main()
