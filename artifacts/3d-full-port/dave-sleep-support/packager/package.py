"""Verify retained Dave evidence; copy exact bytes only with explicit --write."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RUNS = ROOT / '.build/full-port/dave-sleep-validation'
NAMES = ('focused-v1', 'native-v1', 'web-v1', 'focused-driver-v2', 'web-v2')
ART = 'd35234cd61c3a489f459da420b26d00118b66be1497ab83d500a95a46306b45e'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load(path: Path):
    return json.loads(path.read_bytes())


def require(condition, message: str) -> None:
    if not condition:
        raise ValueError(message)


def relative_path(base: Path, value: str) -> Path:
    require(isinstance(value, str) and value and '\\' not in value,
            'invalid relative path')
    parts = PurePosixPath(value)
    require(not parts.is_absolute() and not any(x in ('..', '.', '') for x in parts.parts)
            and ':' not in value, 'unsafe relative path: ' + value)
    path = base.joinpath(*parts.parts)
    require(path.resolve().is_relative_to(base.resolve()), 'escaped root: ' + value)
    cursor = base
    for part in parts.parts:
        cursor = cursor / part
        if cursor.exists():
            attrs = cursor.lstat()
            require(not cursor.is_symlink() and not
                    (getattr(attrs, 'st_file_attributes', 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT),
                    'reparse point: ' + str(cursor))
    return path


def check_row(row: dict) -> bytes:
    path = relative_path(ROOT, row['source'])
    require(path.is_file(), 'missing source: ' + row['source'])
    data = path.read_bytes()
    require(len(data) == row['bytes'] and sha(data) == row['sha256'],
            'changed input: ' + row['source'])
    return data


def audit(allow: dict) -> dict:
    archive = relative_path(ROOT, allow['source_archive']['path'])
    require(sha(archive.read_bytes()) == allow['source_archive']['sha256'], 'archive pin')
    with zipfile.ZipFile(archive) as z:
        names = [n for n in z.namelist() if not n.endswith('/')]
        require(len(names) == 495 and len(set(names)) == 495, '495 original source entries')
        require(all(n.startswith('game3d/') for n in names), 'archive prefix')
        original = {n.removeprefix('game3d/'): sha(z.read(n)) for n in names}
    stages = []
    for name in NAMES:
        folder = RUNS / name
        s = load(folder / 'staging.json')
        require(s['source_archive_sha256'] == allow['source_archive']['sha256'], name + ' archive')
        require(s['prepared_source']['scripts/actor_animation.gd'] == ART, name + ' art')
        require(set(original).issubset(s['prepared_source']), name + ' dropped original source')
        for rel, digest in s['prepared_source'].items():
            require(sha(relative_path(folder / 'game3d', rel).read_bytes()) == digest,
                    name + ' staged source: ' + rel)
            if original.get(rel) != digest:
                require(s['overlays'].get(rel, {}).get('new') == digest
                        and s['overlays'][rel]['old'] == original.get(rel), name + ' undeclared overlay: ' + rel)
        for rel, overlay in s['overlays'].items():
            require(s['prepared_source'].get(rel) == overlay['new'], name + ' unused overlay: ' + rel)
        run_path = folder / ('focused-result.json' if name == 'focused-v1' else 'root-run.json')
        outcome = load(run_path)
        require(outcome['status'] == 'pass' and all(x['exit_code'] == 0 for x in outcome['stages']),
                name + ' root stage exits')
        logs = [p for p in folder.iterdir() if p.is_file() and p.suffix == '.log']
        for log in logs:
            require(not re.search(r'(?im)^(?:SCRIPT ERROR:|ERROR:|WARNING:.*(?:leak|ObjectDB))',
                                  log.read_text(encoding='utf-8', errors='replace')),
                    name + ' engine error: ' + log.name)
        stages.append({'name': name, 'prepared_files': len(s['prepared_source']),
                       'declared_overlays': list(s['overlays']), 'stage_exits_zero': True})
    markers = {
        'test_dave_sleep_support': 'PASS; 2028 checks; 3/3 groups; 384 sleep samples; 71 other identities',
        'test_character_roster': 'PASS (2040 checks;',
        'test_pose_input_memo': 'PASS (13458 checks;',
        'test_presentation_visibility': 'PASS (2112 checks;',
        'test_dave_walkthrough_contract': 'PASS (103 checks; 4/4 groups;',
    }
    for name, marker in markers.items():
        require(marker in (RUNS / 'focused-v1' / (name + '.stdout.log')).read_text(), name + ' PASS')
    require('PASS (121 checks; 5/5 groups;' in
            (RUNS / 'focused-driver-v2/test_dave_walkthrough_contract.stdout.log').read_text(), 'driver121/5')
    reports = []
    for name in ('native-v1', 'web-v1', 'web-v2'):
        web = name.startswith('web')
        folder = RUNS / name / ('browser-evidence' if web else 'evidence')
        report = folder / ('browser-report.json' if web else 'dave-walkthrough.json')
        j = load(report)
        accepted = name != 'web-v1'
        require(j['finished'] and j['acceptance'] is accepted and j['fixture'] == 'none'
                and j['title_input'] and j['replacements'] == 0 and not j['overflow'], name + ' status')
        require(j['failures'] == ([] if accepted else ['certified normal return direction']), name + ' failures')
        require(j['wall_ms'] < 120000 and j['idle_active_ms'] >= 4000, name + ' watchdog/idle')
        require(j['wake']['pressed'] and j['wake']['reachable']
                and j['wake']['resolved'] == {'id': 'dave', 'kind': 'quest'}, name + ' ordinary E')
        before, after = j['wake']['before'], j['wake']['after']
        require(before['actor']['asleep'] is True and after['actor']['asleep'] is False, name + ' awake state')
        require({k: v for k, v in before['actor'].items() if k != 'asleep'} ==
                {k: v for k, v in after['actor'].items() if k != 'asleep'}
                and before['player'] == after['player'] and before['rng'] == after['rng'], name + ' immediate receipt')
        require(j['idle'] and all(not x['asleep'] and x['root_up'] > .98
                                 and x['sleep_markers'] == 0 for x in j['idle']), name + ' upright idle')
        require(j['inputs']['motion_frames'] > 0 and j['inputs']['mouse_motion'] > 0
                and j['inputs']['keys'] >= 2 and j['inputs']['clicks'] == 3, name + ' input counters')
        if accepted:
            require(j['movement']['metres'] > .15 and j['movement']['input_frames'] > 0
                    and j['movement']['mode'] == 'playing' and not j['movement']['modal'], name + ' resumed movement')
        else:
            require(j['movement'] == {}, 'failed Web movement retained')
        require(len(j['frames']) == 3, name + ' three captures')
        frames = []
        for n, f in enumerate(j['frames']):
            require(f['label'] == ('01_sleeping_dave', '02_awake_dave', '03_pigeon_dialogue')[n], name + ' phase')
            png = folder / (f['label'] + ('_960' if web else '') + '.png')
            b = png.read_bytes()
            require(b[:8] == b'\x89PNG\r\n\x1a\n', name + ' original PNG')
            dimensions = list(struct.unpack('>II', b[16:24]))
            require(dimensions == f['framebuffer'] == ([960, 540] if web else [1280, 720])
                    and sha(b) == f['png_sha256'] and len(b) == f['png_bytes'], name + ' PNG hash/size/dimensions')
            pg = f['posed_ground']
            require(pg['ok'] and pg['no_pose_or_simulation_writes']
                    and pg['format'] == 'dave-posed-ground-diagnostic-v2', name + ' passive diagnostic')
            g = pg['groups']
            require(all(g[k]['vertices'] > 0 and g[k]['support']['ok'] for k in
                        ('skinned_body', 'rigid_head', 'pillow')), name + ' actual support rays')
            require(all(pg['ray_origin_y'] > x['bounds_maximum_world'][1] for x in g.values()), name + ' above geometry rays')
            if n == 0:
                require(f['asleep'] and f['sleep_markers'] > 0 and f['root_up'] < .2
                        and g['skinned_body']['support']['clearance_m'] >= .004
                        and g['pillow']['support']['clearance_m'] >= .008, name + ' sleeping sample')
            else:
                require(not f['asleep'] and f['root_up'] > .98 and f['sleep_markers'] == 0
                        and pg['pillow_attachment']['bone'] == 8, name + ' restored awake binding')
            frames.append({'label': f['label'], 'sha256': sha(b), 'dimensions': dimensions,
                           'clearance_m': {k: v['support']['clearance_m'] for k, v in g.items()},
                           'root_up': f['root_up'], 'sleep_markers': f['sleep_markers']})
        require(j['frames'][2]['mode'] == 'dialogue'
                and j['frames'][2]['menu']['buttons'] == ['listen for a while. (-5 brain)', 'leave.'], name + ' actual pigeon menu')
        if web:
            require(j['pngs_verified'] and j['machine_checks_pass'] is accepted, name + ' Web checks')
            require(j['browser']['canvas'] == [960, 540], name + ' Web canvas')
            require(j['browser_errors'] == ([] if accepted else
                    ['ERROR: certified normal return direction', '   at: push_error (core/variant/variant_utility.cpp:1024)']),
                    name + ' raw browser errors')
            served = load(RUNS / name / 'served-copy.json')
            for item in served:
                data = (RUNS / name / 'web' / item['file']).read_bytes()
                require(sha(data) == item['sha256'] and len(data) == item['bytes'], name + ' served provenance')
        reports.append({'run': name, 'report_sha256': sha(report.read_bytes()), 'machine_pass': accepted,
                        'failures': j['failures'], 'inputs': j['inputs'], 'idle_samples': len(j['idle']),
                        'movement': j['movement'], 'wall_ms': j['wall_ms'], 'frames': frames})
    return {'format': 'dave-support-independent-evidence-audit', 'source_archive_files': 495,
            'stages': stages, 'reports': reports, 'original_pngs_verified': 9,
            'scope': 'Retained evidence verification only; no engine, export or browser run by this copier.'}


def verify() -> tuple[dict, list[dict], dict]:
    manifest = load(HERE / 'MANIFEST.json')
    for name, digest in manifest['files'].items():
        require(sha(relative_path(HERE, name).read_bytes()) == digest, 'changed packager: ' + name)
    allow = load(HERE / 'allowlist.json')
    require(allow['destination'] == 'artifacts/3d-full-port/dave-sleep-support', 'fixed destination')
    rows = list(allow['files'])
    for name in list(manifest['files']) + ['MANIFEST.json']:
        p = relative_path(HERE, name)
        b = p.read_bytes()
        rows.append({'source': p.relative_to(ROOT).as_posix(), 'destination': 'packager/' + name,
                     'bytes': len(b), 'sha256': sha(b)})
    names = set()
    for row in rows:
        relative_path(ROOT, row['source'])
        relative_path(ROOT / allow['destination'], row['destination'])
        key = row['destination'].casefold()
        require(key not in names and not key.endswith(('.exe', '.dll', '.wasm', '.pck', '.zip', '.pyc')),
                'duplicate or excluded output: ' + key)
        names.add(key)
        check_row(row)
    report = audit(allow)
    require(report == load(HERE / 'AUDIT.json'), 'retained evidence changed after independent audit')
    return allow, rows, report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('verify', 'copy'))
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    require(args.write == (args.command == 'copy'), 'copy requires --write; verify forbids it')
    allow, rows, report = verify()
    result = {'command': args.command, 'files': len(rows), 'bytes': sum(x['bytes'] for x in rows),
              'original_pngs_verified': report['original_pngs_verified'], 'source_archive_referenced_not_copied': True}
    if args.command == 'copy':
        destination = relative_path(ROOT, allow['destination'])
        require(not destination.exists(), 'destination exists; retained without overwrite')
        destination.mkdir(parents=True, exist_ok=False)
        for row in rows:
            data = check_row(row)
            target = relative_path(destination, row['destination'])
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as stream:
                stream.write(data)
            require(sha(target.read_bytes()) == row['sha256'], 'copied hash: ' + row['destination'])
        receipt = {'schema': 1, 'status': 'byte-copy-verified', 'scope': 'No acceptance promotion or source edits.',
                   'source_archive': allow['source_archive'], 'files': rows,
                   'packager_manifest_sha256': sha((HERE / 'MANIFEST.json').read_bytes())}
        with (destination / 'PACKAGE-RECEIPT.json').open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(json.dumps(receipt, indent=2) + '\n')
        result['destination'] = destination.relative_to(ROOT).as_posix()
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        raise SystemExit('REFUSED: ' + str(error)) from error
