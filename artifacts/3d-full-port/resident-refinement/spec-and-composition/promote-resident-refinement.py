from pathlib import Path
import hashlib, json
root = Path(__file__).resolve().parents[2]
candidate = root / '.build/3d/resident-art-integration'
mapping = json.loads((candidate / 'overlays.json').read_text())
old = {
'game3d/scripts/cast_profiles.gd':'4bc71adc2c9d2e89ba6d207ec8bc7904d7655251cb74d9c30f3e966f1ea6d3cd',
'game3d/tests/test_character_roster.gd':'75c992e163dd39756483b57ce6bb52dbfca8a8a6594bcc022515c733685c0c5c',
'game3d/tests/test_full_scene.gd':'355cdc4d93e0c045f8693bc1c0785f1a673e566391437c135e5dd6287d3b4378',
}
sha = lambda b: hashlib.sha256(b).hexdigest()
prepared = {}
records = []
for name, expected in mapping.items():
 source = candidate / name
 data = source.read_bytes()
 assert sha(data) == expected, name
 target = root / name
 if name in old:
  assert sha(target.read_bytes()) == old[name], name
 else:
  assert not target.exists(), name
 normalized = name == 'game3d/tests/test_character_roster.gd'
 if normalized:
  assert data.count(b'\r\n') == data.count(b'\n') == 1052
  data = data.replace(b'\r\n',b'\n')
 prepared[target] = data
 records.append({'path':name,'old_sha256':old.get(name),'reviewed_candidate_sha256':expected,'final_sha256':sha(data),'eol_only_adjustment':'CRLF to existing LF checkout policy' if normalized else None})
for target, data in prepared.items(): target.write_bytes(data)
(root / '.build/3d/resident-promotion.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps(records,indent=2))
