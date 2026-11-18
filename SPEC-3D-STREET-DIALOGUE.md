# SPEC — Street resident dialogue P06b3a

Captured before code, 2026-11-18. Root approved15 IDs and compatibility decisions.
Parent SPEC-3D-FULL-PORT.md. Source: npc_spawns.js113–345; vendors_places.js218–306;
communications.js98–116; activities.js186–217. This model packet is not full scene parity.
P06b2 quest files remain unchanged.

## Authority and API

New RockBottomStreetDialogue(owner,spatial,memory,travel,activities,communications), all external
owners held weakly. Public supports(id), open(id), select(token,action), close() use the existing
menu envelope and ActionSession. No new resource, save, actor, phone or minigame authority.
Canonical IDs: pinky,cubscout,jogger,dogwalker,busker,horsecop,vapelord,pothole,mayorscousin,
phoneguy,laundromat_lady,meter_maid,food_truck,priests_son,karaoke. Use source title/text/options.
Unknown IDs refuse. Root owns dispatch priority and cross-domain token invalidation/presentation.

Open and selection require playing/dialogue, living exact actor, strict60px and current actual
LOS, and bossKind!=kingdom. No blanket Tony-fight lock, new night refusal, HP gate or daily cap.
Selection revalidates resource/flag/faction eligibility without replaying opening RNG/effects.
Common real opening records metVendors and Memory.bother exactly once. Same-epoch tokens are
one-use; replaced state and stale tokens cannot spend/grant. Every cash mutation follows fresh
validation. Inline residents use fixed literal prices; only Pinky's source vendorPrice calls
use the existing charisma discount.

## Transactions

| ID | Source behavior |
| --- | --- |
| pinky | Street hated refuses entire menu. Single vendor_price4 grants1 supplies/dirtySupplies, rep street1/spiritual-1; bulk vendor_price18 grants5, rep2/-2. First purchase alone sets pinkyFirstBuy, barbAside, due_dealer_system, exact news/feed. Coin/save on purchase. No Barb-style supply cap. |
| cubscout |8cash→4cred; mom banter. No inventory popcorn record. |
| jogger |Request1cash: RNG<.4 grants1; failure changes no speed despite toast. |
| dogwalker |Pet Paisley→1cred each request, no invented once/day governor. |
| busker |1cash→1cred; different-song banter changes no simulation speed/music system. |
| horsecop |Nod2cred; compliment3cred+authored feed; pet RNG<.4 grants4cred, else raw hp-=6 and wanted+1 capped3. |
| vapelord |6cash→brain+10 capped100; free-hit banter. |
| pothole |Argue brain-4 floor0; throw conditionally1cash→1cred, otherwise exact no-money toast. Throw remains enabled even when poor. |
| mayorscousin |Mayor banter; favor RNG<.3 wanted-1 floor0;5cash→8cred. |
| phoneguy |Opening reveals actual phone feed. Ask chooses one of five authored posts; content3cash posts exact paid line. Feed ownership is delegated, see partial boundary below. |
| laundromat_lady |2cash heals12 cappedmaxHp, laundryDone++, exact laundry_service recognition;5cash adds detergent record and exact detergent recognition; why brain-2 floor0. |
| meter_maid |2cash wanted-1 floor0; flirt wanted+1 capped3. |
| food_truck |Taco4 heals20 cappedmaxHp then tacosEaten++: RNG<.15 shakes-20 floor0; [.15,.25) raw hp-=30+hurt sound; else plain taco. Horchata8→brain30 cap100. Burrito15→rock1,wanted1cap3+authored feed. |
| priests_son |Father question brain-1 floor0;10cash then RNG<.5 rock1, otherwise no item/brain bonus. |
| karaoke |Request-song banter; sing5 delegates actual rhythm session and its recognition transaction. |

All ordinary inline actions preserve the source absence of immediate save requests; first
met-vendor and recognition can independently request saves. No global save-on-dialogue wrapper.
Pinky bus-pass sale remains literal20, independent of charisma and supply first-buy/rep rewards.

## Delegated transactions and honest partial scope

Travel alone owns bus-pass sale/use. World worker extracts public buy_pinky_pass()->Dictionary
from existing Travel branch, with current Pinky eligibility/LOS/pass/cash checks; both Travel
and Street use it. has_bus_pass() determines exact menu option. open("bus") returns original
destination menu; Street adds domain:"travel" to hand off future token selections to Runtime.
Missing Travel refuses its action before payment. No synthetic opening of a partial Pinky menu.

Phone/Karaoke are authored here but remain explicit partial rows until real B3b owners and UI
are integrated. Missing phone owner refuses Phone Guy opening before opening effects, rather
than claiming a feed appeared. Required feed seam: show_feed()->bool; post(text,author)->bool
accepts a valid post transaction even when silence suppresses display/storage. A live valid
post owner is checked before choosing a random line or charging3. It owns no player money.
Phone content selection checks the same owner before payment; normal direct producers (Horse,
Burrito,Pinky) emit existing feed/news events for the future common consumer.

Karaoke requires activities.start_paid_karaoke()->Dictionary. The actual P09 owner must
preflight player/actor/current geometry5cash+Memory, then own the sole charge, rhythm state,
karaoke recognition and returned menu; Street never precharges. Returned menu gets
domain:"activities". Missing capability refuses before cash/RNG. Exact8-arrow source sequence,
step/hit/forfeit/reward and input UI are a separately reviewed B3b packet, not a placeholder win.
Phone feed storage/display/silence clock are likewise a separate B3b packet. Tests of these
seams are delegation contracts, not claims that those systems are implemented.

## Executed compatibility ledger

Root explicitly approved preserving:

- Horse pet failure and bad Taco use direct HP subtraction, bypassing hurt(), iframe/contact/
  death effects. At5HP they can leave -1HP/-5HP respectively. Do not invent immediate respawn.
- Burrito's label checks rocks<3, but enabled/action checks cash only. At3+ rocks and15cash
  the terse "specials are $15." option remains enabled and buys another rock.
- Repeatable Paisley/Horse/Jogger grants, fixed inline prices and Cubscout render-only
  daytimeOnly remain source behavior. No new caps, night gates, actor-speed changes or saves.

P14 day-event actors (Price Guy, day3 visitor, day30 Bus Driver) belong world worker's packet,
not this one. Shared feed silence uses injected Unix milliseconds for persisted silenceUntilT,
separate from monotonic combat time.

## Acceptance

Unchanged-source fixtures cover every menu/action, low/short resources, exact RNG boundaries,
HP/brain/shakes/wanted clamps, direct-negative-HP exceptions, repeat grants, Pinky tier/discount/
first-purchase/Barb aside and pass ownership, and the Burrito label/enable asymmetry.
Property tests exercise live LOS/death/kingdom/state epoch, stale source callbacks, absent
Travel/Memory/Phone/Activities and no partial spends, one pass transaction and explicit handoff.
No engine runs by this worker. Root runs central gates and scene/native/Web integration.
