"""Draft-only inventory and conservative static checks. Never starts Godot/Git."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[3]
DRAFT = Path(__file__).resolve().parent
# parents[3] is .build's parent only for this fixed .build/3d/<draft> layout.
assert ROOT.name == "Rock Bottom" and (ROOT / "VIBE.md").is_file()

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def relative(path):
    return path.relative_to(ROOT).as_posix()

def check_script(path):
    text = path.read_text(encoding="utf-8")
    stripped = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*', '""', text)
    stack = []
    partners = {')': '(', ']': '[', '}': '{'}
    for character in stripped:
        if character in '([{': stack.append(character)
        elif character in ')]}':
            assert stack and stack.pop() == partners[character], f"delimiter mismatch: {path}"
    assert not stack, f"unclosed delimiter: {path}"
    declarations = re.findall(r'^(?:static )?func (\w+)\(', text, re.M)
    assert len(declarations) == len(set(declarations)), f"duplicate function: {path}"
    forbidden = [r'game\.runtime\.(?:p|s)\.[\w.]+\s*(?:\+=|-=|=(?!=))',
                 r'game\.player\.(?:position|global_position)\s*=',
                 r'game\.runtime\.(?:combat|days|kingdom)\.[a-z_]+\(',
                 r'Engine\.time_scale\s*=', r'rng_seed\s*=']
    for pattern in forbidden:
        assert not re.search(pattern, stripped), f"authority write/call: {path}: {pattern}"
    return {"path": relative(path), "sha256": sha(path), "functions": len(declarations),
            "delimiter_scan": "pass", "duplicate_function_scan": "pass",
            "narrow_authority_write_scan": "pass", "godot_parse": "not_run"}

dependencies = [
    ".build/3d/campaign-continuation-draft/tests/campaign_continuation_probe.gd",
    ".build/3d/campaign-continuation-draft/tests/test_campaign_continuation_contract.gd",
    ".build/3d/campaign-continuation-draft/candidate-manifest.json",
    "game3d/tests/office_endpoint_driver.gd", "game3d/tests/office_acceptance_probe.gd",
    "game3d/tests/boss_acceptance_probe.gd", "game3d/scripts/campaign_system.gd",
    "game3d/scripts/kingdom_campaign.gd", "game3d/scripts/travel_system.gd",
    "game3d/scripts/day_system.gd", "game3d/scripts/combat_system.gd",
    "game3d/data/source_content.json", "src/systems/campaigns.js",
    "src/systems/daily_hideouts.js", "VIBE.md",
]
previous_campaign_pins = {
    dependencies[0]: "cad552c987335addd7223b318e7e2aa0f9b5a519d85ddea3a6185219e28d0301",
    dependencies[1]: "eb81d8587c03b97a8785968cbbe2eaaae05f52889c039f6ed9b9406062a6b136",
    dependencies[2]: "68c6a95b35116a8e228f9048f037b4e3a26824247e1657be325e3c448692de30",
}
held = {
    dependencies[0]: "7801ef1f37a86703a14bda0fdbb9055a1326269bd4609030660710686f6b798c",
    dependencies[1]: "5091ba1f4fb5125a371e9282c6f2bb7829955adfcc7e33a1364b0b5b4a9bdaa2",
    dependencies[2]: "3031226845db5bda4c179125892f514c7edb7d6a8d1bf91dba22614327e8064b",
}
for name, pinned in held.items():
    assert sha(ROOT / name) == pinned, f"held campaign dependency changed: {name}"
scripts = sorted((DRAFT / "tests").glob("*.gd"))
assert {p.name for p in scripts} == {"pretender_continuation_probe.gd", "test_pretender_continuation_contract.gd"}
checks = [check_script(path) for path in scripts]
probe_bytes = (DRAFT / "tests/pretender_continuation_probe.gd").read_bytes()
numeric_term = b'not CampaignProof.evidence_value_equal(persistence.get("stored"),saved)'
assert probe_bytes.count(numeric_term) == 1
baseline_path = DRAFT / "evidence/native-v1-probe.gd.txt"
assert sha(baseline_path) == "1a0b8fd72b7d13aeac9a9cf2f9ea473f3181520a140f58192301d9e0f5bfe18c"
baseline = baseline_path.read_text(encoding="utf-8")
current = probe_bytes.decode("utf-8").replace("\r\n", "\n")
def functions(text):
    matches = list(re.finditer(r"^(?:static )?func (\w+)\(", text, re.M))
    return {m.group(1): text[m.start():matches[i+1].start() if i+1 < len(matches) else len(text)].strip()
            for i, m in enumerate(matches)}
before_functions = functions(baseline)
after_functions = functions(current)
changed = {name for name in before_functions if before_functions[name] != after_functions.get(name)}
assert changed == {"_alive", "assess_pretender_tour"}, f"unexpected changed existing method: {changed}"
assert set(after_functions)-set(before_functions) == {"guard_transit_allowed", "assess_transit_defenses", "_court_defensive_target", "_court_defend"}
assert current[:current.index("static func")] == baseline[:baseline.index("static func")], "constants/limits/state declarations changed"
assert sha(ROOT / ".build/full-port/pretender-continuation/native-v1/pretender-continuation.json") == "53fe58f5d50417fbbbb01fc7dfea8a700cc6c04b95f165dc9ef198332b8e637d"
contract = (DRAFT / "tests/test_pretender_continuation_contract.gd").read_text(encoding="utf-8")
assert "const GROUPS := 11" in contract and contract.count("completed_groups += 1") == 11
files = [p for p in DRAFT.rglob("*") if p.is_file() and p.name not in {"candidate-manifest.json", "static-validation.json"} and "__pycache__" not in p.parts]
manifest = {
    "schema": 1, "format": "rock-bottom-pretender-continuation-draft", "status": "held_draft",
    "scope": "two new isolated test scripts, spec and inventory; no production changes",
    "accepted_input": {"path": ".build/full-port/campaign-continuation/resume-v6/campaign-two-run-aggregate.json",
        "sha256": "c3c00e775243fa10d1d0caf2e88173b67e827b32cef423a502fdc5c4d31af1a9",
        "source": "root accepted actual two-run aggregate; launch still checks actual supplied report/save pins and full inherited proof"},
    "campaign_dependency_repin": {"authorized_by": "/root", "previous": previous_campaign_pins, "reviewed": held,
        "reason": "Reviewed hostile-only guard correction and exact parsed JSON admission; root reports actual-retained contract1072/11 PASS and actual resume-v6 composed campaign accepted.",
        "campaign_files_written_by_this_packet": False},
    "admission_numeric_amendment": "Only stored-save nested identity delegates to the reviewed exact finite Campaign evidence helper. Raw SHA pins/full proof/status/failures/source inventory/final suffix selection and budgets unchanged.",
    "native_v1_correction": {"failed_report_sha256": "53fe58f5d50417fbbbb01fc7dfea8a700cc6c04b95f165dc9ef198332b8e637d",
        "previous_probe_sha256": sha(baseline_path), "changed_existing_methods": sorted(changed),
        "new_methods": sorted(set(after_functions)-set(before_functions)), "all_other_methods_unchanged": True,
        "all_existing_constants_and_limits_unchanged": True,
        "scope": "day_N proactive transit guard selector; inherited shared budget plus active watchdog and detached audit; no recovery policy, boss combat, admission or gameplay changes"},
    "input_requirement": "accepted uninterrupted full campaign or explicitly accepted two-run aggregate; complete inherited assessor, exact raw top-level report SHA and final save bytes; no standalone or failed prefix/suffix",
    "files": [{"path": relative(p), "sha256": sha(p)} for p in sorted(files)],
    "read_only_dependencies": [{"path": name, "sha256": sha(ROOT / name)} for name in dependencies],
    "staging_overlays": [{"source": relative(p), "target": "game3d/tests/" + p.name, "sha256": sha(p)} for p in scripts],
    "limits": {"cold_ms": 120000, "tour_ms": 600000, "day_ms": 180000,
               "approach_fight_ms": 90000, "cot_commands": 9, "captures": 12, "finalizer_ms": 15000},
    "validation": {"static": "pass", "godot_parse": "not_run", "headless_contract": "not_run", "native": "not_run", "web": "not_run"},
}
(DRAFT / "candidate-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
validation = {"status": "static_only_pass", "scripts": checks, "held_campaign_hashes_unchanged": True,
              "contract_completion_tails": 11,
              "manifest_sha256": sha(DRAFT / "candidate-manifest.json"),
              "caveat": "A text scan is not a Godot parser or a runtime/native acceptance result."}
(DRAFT / "static-validation.json").write_text(json.dumps(validation, indent=2) + "\n", encoding="utf-8")
print(json.dumps(validation, indent=2))
