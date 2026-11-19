from pathlib import Path
import hashlib, json, subprocess
root = Path(__file__).resolve().parents[2]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
previous = json.loads((root / '.build/3d/resident-checkout-result.json').read_text())
expected = {row['path']: row['actual'] for row in previous['files']}
promotion = json.loads((root / '.build/3d/dave-sleep-promotion.json').read_text())
for row in promotion['files']:
    path = row['path']
    expected[path] = sha(root / path)
for directory in ['dave-sleep-support', 'query-resource-rejected-v1', 'positive-certificate-rejected-v2', 'feature-acceptance-audit']:
    for p in sorted((root / 'artifacts/3d-full-port' / directory).rglob('*')):
        if p.is_file(): expected[p.relative_to(root).as_posix()] = sha(p)
for name, digest in expected.items():
    assert sha(root / name) == digest, name
dest = root / '.build/3d/dave-checkout-v1'
assert not dest.exists(), 'Refusing existing checkout'
dest.mkdir()
paths = sorted(set(expected) | {'.gitattributes', 'tools/3d-parity-gate.mjs'})
subprocess.run(['git', 'checkout-index', '-z', '--stdin', '--prefix=' + dest.as_posix() + '/'], cwd=root, input=('\0'.join(paths) + '\0').encode(), check=True)
rows = [{'path': p, 'expected': digest, 'actual': sha(dest / p)} for p, digest in expected.items()]
failures = [r['path'] for r in rows if r['expected'] != r['actual']]
report = {'scope': 'Actual staged checkout: prior resident byte pins plus declared Dave promotion and unchanged raw evidence', 'method': 'git checkout-index', 'failures': failures, 'checks': len(rows), 'files': rows}
(root / '.build/3d/dave-checkout-result.json').write_text(json.dumps(report, indent=2) + '\n')
assert not failures, failures
print(f'DAVE ACTUAL CHECKOUT: PASS {len(rows)} raw-byte checks')
result = subprocess.run(['node', 'tools/parity-metadata-gate.mjs', '--pins=metadata-v3'], cwd=dest, capture_output=True, text=True)
(root / '.build/3d/dave-checkout-gate.log').write_text(result.stdout + result.stderr)
assert result.returncode == 0, result.stdout + result.stderr
print(result.stdout.strip().splitlines()[-1])
