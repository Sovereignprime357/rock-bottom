# Full-scene ending receipts and continuation

This closes the existing ending facade under SPEC-3D-FULL-PORT.md. It adds no
ending, reward, reset, save namespace or timer. Source owners remain Bosses,
Kingdom and Day; FullRuntime owns transitions and FullScene owns input/storage.

`src/systems/interactions.js:endingScreen` selects exact solo, co-op and kingdom
titles/subtitles, with `vibekoded · the possum still knows`. The bus receipt in
`daily_hideouts.js:takeTheBus` has its four original lines plus the captured day,
rocks-smoked and integer cred, ending `vibekoded · the possum stayed`. Rendering
must use the committed event's payload, not new-game defaults or later counters.
A small pure ending view maps these existing events to title/text; it owns no
state and must distinguish co-op even when the event supplies only `kind`.

`keyboard.js:continueAfterEnding` is the continuation authority. The 3D successor
uses its explicit `ending` mode. Return button and non-repeating Space share one
path, blocked while loading, saving or a queued save remains. Continue only with
the source endingContinue flag. After the accepted transition, clear that flag
and endingSavePromise, release held movement/squint/look input, close the receipt
and return to the same player/state/roster. Emit the exact 2400ms receipt:
`the block is still here.\nthe clipboard has another sheet.`

Source asynchronous saving is awaited through the existing save queue; it does
not trigger a fresh game/load or replay rewards. Cooking's committed resolution
guards remain authoritative. A stale ending button must fail its existing menu
generation check. Repeated continuation must not re-emit the receipt or change
the ledger. Existing failure handling for save writes remains unchanged.

Verification covers all four source receipts, captured bus counters, actual
FullScene Space/button dispatch, pending-save denial, retained dictionary
identity/progress, one-shot flags/toast and stale menu rejection. Native/Web tours
remain necessary for end-to-end boss/campaign acceptance; staging an ending
event is presentation/control evidence only, not proof of beating its boss.
