# Failed different-point query: retain the valid positive certificate

Root approved this isolated candidate after the static review in
../clearance-certificate-retention-review. The query-resource reuse candidate was
rejected and remains untouched. This packet is based on the same exact current
unpooled/unindexed495-file resident archive; no weighted-node packing is included.
No engine/Git/build or production changes are authorized here.

Change only the failed-overlap branch in WorldAdapter._clear_prepared. A failed
query may leave the existing positive certificate intact only when its point
differs exactly and width, depth, resolved height and collision revision match.
The certificate remains under the same ID. All existing render/physics/p/s/body
invalidation paths execute unchanged before that branch. A forced failed query
at the same point invalidates the entry, as do any key mismatches. An empty entry
stays empty. No new cache class, negative result, key approximation or lifetime.

Every forced endpoint still executes the real same-margin overlap. Actual casts,
wall normals, Contact tests, navigation, recovery, source cadence and returned
position/blocked/contact values are unchanged. The only intended query-count
difference is a later ordinary read at a still-certified different point. Contact
and current-player separation must still execute even on such a cache hit.

Focused tests compare against the byte-exact unmodified Adapter reference (only
its class_name removed). Real StaticBody3D walls and Shape queries establish the
positive/negative points. They cover failed same-point rechecks, repeated
uncached negatives, exact float32 equality, ID/movement/width/depth/height changes,
registration/unregister, collider layer publication, logical revision changes,
render and actual physics-frame expiry, p-only/s-only replacement and current
player contact. No test may insert a fake positive certificate.

A deterministic real-wall eight-probe bisection checks the specific accepted-low
case, requiring a successful low followed by a failed high and a final retained
low proof. Its probe loop is a test sequence through the real _clear API, not a
claim that a particular engine cast naturally enters the rare production
bisection branch. Paired actual movement/recovery witnesses separately compare
ordinary, blocked, slide, charge and peer-contact returns and authoritative input
immutability. Report actual savings only for the observed focused sequence.

The existing invalidation contract remains mandatory: mask1 collider writers
must publish through update_navigation_obstacles/invalidate_placement_cache.
Adding a collider at A while failing another point B without publishing is not
a valid way to extend any certificate. The focused same-point test performs an
actual forced query after a synchronized collider change; it must erase the old
proof and cannot leave a stale success. No physics/render reset is removed.

Meaningful differential/negative gates precede any unchanged120+1080-frame
sustained60 measurement. A local saved-query count is not a speed result. Root
alone runs central gates and measures; current strict performance failure stays.
All original evidence and prior candidates are retained. No promotion follows
from this specification or the static preparation checks.
