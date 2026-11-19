# Native-v4 defense correction: bounded static trace

No engine or production changes. The failed full run and its accepted prefix are
separate artifacts. The former remains failed; only the prefix may admit resume.

- `Campaign._actor` supplies hostile=true and aggro=false unless explicitly
  overridden. `plan_for_state` does not set the guard aggro override. The source
  Director uses hostile OR aggro. The old test demanded both and changed exported
  records before its positive check. The corrected predicate and four actual
  generated-plan witnesses now cover that mismatch without modifying the rows.
- `_court_defensive_target` permits an empty expected_boss during court traversal,
  then selects current-day canonical threats within85px with fresh LOS.
  `_court_defend` passes this actual target directly to inherited `_combat_input`.
  Office's `_combat_input` never substitutes Tony: it requires that preferred
  target, aims at its current center, checks current hit LOS, and uses the existing
  strict57px/alignment/cooldown/stun readiness before `_send_attack`.
- Campaign `_send_attack` always calls the inherited real mouse-input dispatcher
  before its receipt audit. `_actor("")` is only an empty optional boss annotation;
  it is not an attack gate. The authoritative geometry still contains the guard's
  target_id. Empty expected_boss cannot match a Kingdom reward key, so no boss
  reward is invented. Normal hit/weapon/cooldown receipts remain mandatory.
- The no-route `_defend_exit` asks for the same canonical target with LOS optional
  only at selection, then enters `_court_defend` and the same shared finite budget.
  `_combat_input` still requires actual LOS before clicking and uses swept routes
  while occluded. Non-guard fallback remains the inherited bounded behavior.
- `combat_replans`, per-guard/total time and bout counts are never reset by this
  correction. Service endpoint ownership is temporarily cleared for the bout and
  selected geometry is invalidated after actual movement. The original complete
  campaign, prefix, suffix and aggregate assessors are unchanged.

The four actual production plans cover day1 summons(15 guards), day10 the source
blue-tarp marks stage(15), day10 its source boss stage(11), and complete day11 with
all ruler defeats(8 guards plus the excluded pretender). Stage names come from the
exported clan table. Flag counterexamples cover hostile-only, aggro-only, both,
neither and omitted flags. Existing invalid identities, dead/essential/boss roles,
strict range edges and all cumulative budget counterexamples remain.

Static reasoning does not prove the fight succeeds under the current real crowd.
Root's next normal-input suffix run must record real defense bouts/accepted hits,
stay within the unchanged budgets, and pass the existing complete suffix and
aggregate contracts. No failed run is automatically retried by the driver.
