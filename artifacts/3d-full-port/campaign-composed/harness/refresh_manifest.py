"""Inventory this owned draft only. No engine/Git/source/saved-run writes."""
from pathlib import Path
import hashlib
import json
import re

draft = Path(__file__).resolve().parent
root = draft.parents[2]
assert root.name == "Rock Bottom" and (root / "VIBE.md").is_file()
path = draft / "candidate-manifest.json"
manifest = json.loads(path.read_text(encoding="utf-8"))
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def row(p): return {"path": p.relative_to(root).as_posix(), "sha256": digest(p), "bytes": p.stat().st_size}
checks = []
for name in ["campaign_continuation_probe.gd", "test_campaign_continuation_contract.gd"]:
    text = (draft / "tests" / name).read_text(encoding="utf-8")
    clean = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*', '""', text)
    stack = []
    for c in clean:
        if c in "([{": stack.append(c)
        elif c in ")]}": assert stack and stack.pop() == {")": "(", "]": "[", "}": "{"}[c], name
    assert not stack, name
    funcs = re.findall(r'^(?:static )?func (\w+)\(', text, re.M)
    assert len(funcs) == len(set(funcs)), "duplicate function"
    checks.append({"path": "tests/" + name, "check": "delimiter/string and duplicate-function scan; not Godot parse", "passed": True})
probe = (draft / "tests/campaign_continuation_probe.gd").read_text(encoding="utf-8")
for pattern in [r'game\.runtime\.(?:p|s)\.[\w.]+\s*(?:\+=|-=|=(?!=))', r'game\.player\.(?:position|global_position)\s*=', r'Engine\.time_scale\s*=', r'game\.runtime\.(?:combat|days|kingdom)\.[a-z_]+\(']:
    assert not re.search(pattern, probe), "forbidden authority mutation/bypass"
test = (draft / "tests/test_campaign_continuation_contract.gd").read_text(encoding="utf-8")
assert test.count("completed_groups += 1") == 11 and "completed_groups == 11" in test
checks.append({"check": "narrow authority scan; eleven actual completion tails; watchdog wiring", "passed": True, "scope": "static only; not execution"})
previous = root / ".build/3d/campaign-continuation-integration/game3d/tests/campaign_continuation_probe.gd"
if previous.is_file():
    extract = lambda s: re.search(r'^static func assess_campaign\(.*?(?=^func |^static func |\Z)', s, re.M | re.S).group()
    assert extract(previous.read_text(encoding="utf-8")) == extract(probe), "original uninterrupted assessor changed"
    checks.append({"check": "complete assess_campaign body equals retained root-staged previous driver", "passed": True, "scope": "normalized text comparison only"})
manifest["files"] = [row(p) for p in sorted(draft.rglob("*")) if p.is_file() and p.name not in {"candidate-manifest.json", "static-validation.json"} and "__pycache__" not in p.parts]
observations = []
for entry in manifest.get("source_bases", []):
    current = digest(root / entry["path"])
    observations.append({"path": entry["path"], "prior_sha256": entry["sha256"], "current_sha256": current, "matches_prior": current == entry["sha256"], "read_only": True})
manifest["current_dependency_observations"] = observations
manifest["static_checks"] = checks
manifest["scope"] = "normal-input four-claim campaign; explicit earned Tony prefix/Kingdom suffix composition optional; no all11/Web/performance acceptance"
manifest["next_production_context"] = {"revision": "2c32cb1", "reported_by": "/root", "verified_by_this_worker_with_git": False, "parent_office_provenance": "2a1f6ca retained/disclosed", "composition_requires_equal_actual_runtime_hashes": True}
manifest["verification_pending"] = ["exact JSON evidence correction import", "eleven-group contract requiring actual pinned v4 prefix/save paths", "native suffix from exact accepted v4 Tony prefix", "honest two-run aggregate review"]
manifest["limits"].update({"court_unique_guard_ids": 15, "court_bouts_per_id": 2, "court_bouts_total": 30, "court_ms_per_id": 10000, "court_ms_total": 150000, "shared_cot_commands_across_runs": 12, "shared_global_ms_across_runs": 1800000})
manifest["independent_review"]["v3_defense_checkpoint"] = {"agent": "/root/slice_world", "result": "No actionable budget-reset/prefix-acceptance blocker in read-only review; no engine/native claim", "inventory_scope": "actual scripts/shaders/data/project bytes; not Git tree"}
manifest["independent_review"]["v5_numeric_admission"] = {"agent": "/root/slice_characters/site_visual_audit", "result": "Read-only review found no concrete parse/type or false-rejection blocker. Three literal numeric containers and two mixed identity boundaries corrected; exact retained90-source/8-cot/545484ms evidence checked. Required retained-input guards and eleventh completion tail verified statically.", "engine_run": False, "native_acceptance": False}
amendment = "Native-v3 retained: all3claims/Tony3.454s/ending/blue marks, then guard death on viable route. Court ordinary input shares finite guard budgets including fallback. Real Pause-save prefix and explicit two-run aggregate add no authority. Original complete assessor unchanged."
if amendment not in manifest["review_amendment"]: manifest["review_amendment"] += " " + amendment
for name, outcome in [(".build/full-port/campaign-continuation/native-v3/campaign-continuation.json", "FAIL retained601.931s: claims/Tony3.454s/ending/blue marks, guard death; never accepted prefix"), (".build/3d/campaign-continuation-native-v3.log", "original native-v3 failure log retained")]:
    if not any(e["path"] == name for e in manifest["prior_evidence"]):
        manifest["prior_evidence"].append({"path": name, "sha256": digest(root / name), "outcome": outcome})
for name, outcome in [
    (".build/3d/campaign-2c32-resume-v5/native.log", "FAIL before startup retained: generic prefix admission rejected valid decoded numeric containers"),
    (".build/3d/campaign-2c32-resume-v5/prefix-admission-diagnostic.log", "retained diagnostic: three literal numeric-container failures; all90 source hashes and stored save match"),
    (".build/full-port/campaign-continuation/native-v4/campaign-continuation.json", "FAIL retained617.866s: no defense rows; hostile-only actual guards excluded by old driver"),
    (".build/3d/campaign-2c32-v4/native-v4.log", "original native-v4 log retained"),
    (".build/3d/campaign-contract-v4.log", "prior843-check/11-group contract passed but missed hostile-only actual guard admission"),
    (".build/full-port/campaign-continuation/native-v4/campaign-tony-prefix.json", "accepted Tony prefix ONLY; full run later failed"),
    (".build/full-port/campaign-continuation/native-v4/earned-tony-handoff.json", "actual immutable prefix Pause-save bytes; no repair")]:
    if not any(e["path"] == name for e in manifest["prior_evidence"]):
        manifest["prior_evidence"].append({"path": name, "sha256": digest(root / name), "outcome": outcome})
prefix_path = root / ".build/full-port/campaign-continuation/native-v4/campaign-tony-prefix.json"
save_path = prefix_path.with_name("earned-tony-handoff.json")
assert digest(prefix_path) == "6cb8aa6a7b21c9e8cc3b7b97eb2752f74c78fe173c1069e7ff150c60ebe836fa"
assert digest(save_path) == "5de5c3210a855e8f7cfd98945439bce1dc30a906cb7108bea079388d877d112a"
prefix = json.loads(prefix_path.read_text(encoding="utf-8"))
retained_source = root / ".build/3d/campaign-2c32-v4/game3d"
assert all(digest(retained_source / key.removeprefix("res://")) == value for key, value in prefix["source_hashes"].items())
manifest["accepted_prefix_input"] = {"report": row(prefix_path), "save": row(save_path), "scope": "Tony prefix only; no full campaign/suffix/aggregate acceptance", "retained_source_inventory_count": len(prefix["source_hashes"]), "retained_source_inventory_matches": True, "rest_count_carried": prefix["rest_count"], "wall_ms_carried": prefix["wall_ms"]}
v4_amendment = "Native-v4 retained FAIL617.866s; hostile-only source guards now admitted by OR predicate and actual Campaign-generated witnesses. Exact accepted v4 Tony prefix may resume unchanged2c32 source with reviewed test-only overlay changes."
if v4_amendment not in manifest["review_amendment"]: manifest["review_amendment"] += " " + v4_amendment
v5_amendment = "Resume-v5 failure retained unchanged. Exact finite evidence numeric equality fixes only three literal schema containers and two mixed-composition identities. Required actual pinned prefix/save JSON regression plus individual admission diagnostics; no epsilon/coercion, no original assess_campaign change, no evidence repair. Engine/native rerun pending."
if v5_amendment not in manifest["review_amendment"]: manifest["review_amendment"] += " " + v5_amendment
manifest["retained_input_contract"] = {"required_args": ["--retained-prefix=<absolute-original-v4-prefix>", "--retained-save=<absolute-original-v4-save>"], "read_only": True, "no_synthetic_fallback": True, "prefix_sha256": digest(prefix_path), "save_sha256": digest(save_path)}
path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
validation = {"status": "static_only_pass", "checks": checks, "manifest_sha256": digest(path), "changed_read_only_dependencies": [r for r in observations if not r["matches_prior"]], "production_edits": False, "godot_parse": "not_run", "native": "not_run", "failed_evidence_preserved": True}
(draft / "static-validation.json").write_text(json.dumps(validation, indent=2) + "\n", encoding="utf-8")
print(json.dumps(validation, indent=2))
