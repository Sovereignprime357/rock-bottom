# Driver timing: read-only findings, unchanged benchmark

The roughly14ms driver number is p95, not average. In the retained unpooled
query-pair baseline, day/night means are3.553/3.433ms and p95s14.189/14.023ms.
Measured driver physics queries are25753/25122 (23.85/23.26 per frame); Scene-only
queries are267264/181010. These totals are independently accumulated scalars and
are not the aliased first-phase timelines described in `AUDIT-LIMITS.md`.

The existing actual contact-attribution report SHA256
`9de924885a350569d8263f432f06b92d85bb0e71e0df429935a750a305e38cc8`
at `.build/full-port/contact-attribution/effects-contact-v1/evidence/full-actor-performance.json`
separates driver body tests494520/447272 from Scene-interval230664/195455. Driver
p95 tests2040/1904 versus median120/112 directly fit the source driver structure:
two retained long/1px sweeps on an ordinary frame, up to16 candidate long/1px pairs
plus those two retained sweeps on a decision frame; player sweeps test all current
visible peers (60 day,56 night in these counts). Not every candidate succeeds or
uses only one collision iteration, so this is a mechanism explaining the observed
simple percentiles, not a universal query-count formula.

Concrete code sites in the frozen common workload:

- `sustained_actor_driver.gd:148–169`: every200ms, all16 finite candidate edges;
  each successful long edge also needs its distinct1px corner proof. These two
  lengths are not redundant: prior actual-world corner evidence required both.
- `:171–179`: the freshly selected winner is immediately queried again long and
  short. Its inputs use the same source snapshot, but `WorldAdapter.move_body`
  updates query/contact counters and the placement certificate. Therefore this
  is an output-equivalent-result hypothesis, not a proven side-effect-free
  deletion or license to cache across frames. A fresh proof remains required on
  non-decision frames because actors/player/props can move.
- `:150` and `:184`: `_threats(origin)` is repeated on successful decision frames.
  With the concrete current player Adapter path, this reads the same owner/roster
  and produces detached peer/hostile lists; there is no await or authoritative
  mutation between these two reads. Unlike `_edge`, that player `_contact_peers`
  branch writes no counters/index/cache. Reusing this local list is the smallest
  source-level same-output redundant work identified, but no edit is proposed in
  the frozen workload. It has no separately measured time saving.

`full_actor_performance_probe.gd:362–400` times `_drive` outside MeasuredScene.
The synchronous `frame_sampled` callback resumes probe bookkeeping and the next
driver call after the Scene timer stops. Its CPU still delays the next rendered
frame. `FullScene._process:320–326` admits up to100ms of the supplied real delta;
`FullRuntime.advance:782–789` divides it into16.667ms pieces and a final partial
piece. Each piece runs the normal source stages; it is not a fixed60-calls-per-
second accumulator. A delayed~40ms frame normally executes3 actor stages; another
~13ms decision-frame cost can move the following delta into4 stages. Added source
work can further delay frames. The current data does not isolate a causal cost
coefficient and does not pair a particular driver's p95 with a Scene p95.

Baseline scalars quantify the effect without claiming causation: day3266 actor
stages over44.888 active seconds=72.76 stages/active-second (3.024/render-frame);
night3081 over42.588=72.35 (2.853/render-frame). Partial steps account for a rate
above60. Driver14ms is already outside Scene p95; subtracting it would be invalid.
Source movement/AI/physics costs remain genuine work under this workload. Driver
candidate search and evidence serialization are test overhead. Report them
separately, keep actual per-call/active-time denominators, and preserve the
original failed performance threshold. No alternate driver, cache or profiler
has been implemented here.
