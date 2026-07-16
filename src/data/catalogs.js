/* Generated from frozen rock_bottom_v19.html.
 * Source seams: chatter, equipment, phones, graffiti, and vendor catalogs.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { P, applyEquipStats, runtime, state } from '../core/runtime_ui.js';
import { buildGraffiti } from '../render/structures.js';
import { manageCops } from '../systems/combat.js';
import { feedPost } from '../systems/communications.js';

export let EQUIPMENT, PUBLIC_PHONE_LINES, GRAFFITI_LINES, SCRAP_GRAFFITI_LINES, SPIRITUAL_GRAFFITI_LINES, VENDOR_FLOATER_IDS, VENDOR_INDEX_META, CROWN_SPOTS;

export function vendorPrice(base) {
  const c = (P && P.charisma) || 0;
  if (c >= 1) return Math.max(1, Math.round(base * 0.9));
  return base;
}

export function init_catalogs() {
  // ---------- equipment ----------
  EQUIPMENT = {
    airpods:       { slot:'shoes', n:"a single airpod (left)",      speed: 0,    cred: -1, hp: 0 },
    crocs:         { slot:'shoes', n:"one croc (red)",               speed: 0.6,  cred: -5, hp: 0 },
    walmart_sneak: { slot:'shoes', n:"walmart sneakers",              speed: 0.2,  cred: 0,  hp: 0 },
    vibrams:       { slot:'shoes', n:"vibram five-fingers",           speed: 0.4,  cred: -3, hp: 0 },
    mesh_cap:      { slot:'hat',   n:"a mesh hat (HONK IF U LOVE PETE)", speed:0, cred: 2,  hp: 0 },
    ski_mask:      { slot:'hat',   n:"a ski mask in june",            speed: 0,   cred: 4,  hp: 0 },
    helmet:        { slot:'hat',   n:"a tiny construction helmet",    speed: 0,   cred: 6,  hp: 8 },
    cowboy:        { slot:'hat',   n:"a cowboy hat (decorative)",     speed: 0,   cred: 3,  hp: 0 },
    trench:        { slot:'coat',  n:"a trench coat",                  speed:-0.1, cred: 3,  hp: 8 },
    windbreaker:   { slot:'coat',  n:"a faded windbreaker",            speed: 0.1, cred: 1,  hp: 4 },
    bathrobe:      { slot:'coat',  n:"a hotel bathrobe (yours now)",   speed: 0,   cred:-2,  hp: 6 },
    parka:         { slot:'coat',  n:"a parka in august",              speed:-0.2, cred: 4,  hp: 12 },
    // v13 wave 3 — the pigeon king's lost crown. cursed: -3 cred for the wearer. but vendors
    // recognize the bird-blessing and shave 10% off the base price. charisma is a hidden field
    // summed across equipment in applyEquipStats.
    pigeon_crown:  { slot:'hat',   n:"the pigeon king's crown (cursed)", speed: 0, cred: -3, hp: 0, charisma: 1 },
    // v13 wave 4 — propane torch unlocks the 4th cook mode. fits in the new 'tool' slot.
    // no movement / hp / cred mods — it's a kitchen tool, not a fit.
    propane_torch: { slot:'tool',  n:"a propane torch (dented)",        speed: 0, cred: 0,  hp: 0 },
    // v13 wave 5 — taken from father o'malley fallen. cred for showing up in a thing you didn't earn.
    // wantedDecay is a multiplier on the cop-decay timer (1.3 = 30% faster) applied in manageCops.
    priest_collar: { slot:'hat',   n:"the priest's collar (reversed)",  speed: 0, cred: 2,  hp: 0, wantedDecay: 0.3 },
  };
  
  // ---------- v13 wave 6: PUBLIC PHONE LINES + GRAFFITI LINES ----------
  // the pay phone in the scrap yard rings every 4-8 min. answer with E during the 30s window.
  // most are pure flavor; one (~10% roll) plants a $50 cash pile behind the church.
  PUBLIC_PHONE_LINES = [
    { text: "a voice. it has been waiting.\n'is this still working?\nthey took the rest of them down.'", action: () => {} },
    { text: "a voice. it knows your name.\nit does not say your name.\nit just knows.", action: () => {} },
    { text: "silence. then a long beep.\nthen nothing.\nyou hang up.", action: () => {} },
    { text: "a voice: 'tell pinky the package is ready.'\nyou don't know what package.\nyou won't.", action: () => {} },
    { text: "breathing. close breathing.\nyou hear your own breathing.\nyou are also on the other end.", action: () => {} },
    { text: "'mom?'\nit is a child's voice.\nyou say 'yes.' you don't know why.", action: () => { P.brain = Math.max(0, P.brain - 4); } },
    { text: "'this is dolores. is carl there.\ncarl owes me forty.\ntell carl i found out.'", action: () => {} },
    { text: "a recording: 'press 1 for english.'\nyou press nothing.\nthe recording continues in english anyway.", action: () => {} },
    { text: "'the soup kitchen is closed today.\nthe soup kitchen has been closed since 1998.\nyou are welcome anyway.'", action: () => { P.hp = Math.min(P.maxHp, P.hp + 4); } },
    // 10% — plants a loaded dumpster behind the church
    { text: "a voice: 'check the dumpster behind the church.\nthere is something for you.\ndo not bring anyone.'", planted: true, action: () => {
        // plant a $50 cash pile behind the church (church is at 1680,1360 w240 h200; place behind = above)
        const id = 'cp_phone_church_'+Date.now();
        runtime.cashPiles.push({ id, x: 1800, y: 1320, amt: 50, collected: false, intro: false });
        state.flags.churchLoadedDumpsterX = 1800;
        state.flags.churchLoadedDumpsterY = 1320;
        feedPost("got a tip on a dumpster behind the church. anonymous. probably a setup.", '@crackheadcent');
      } },
  ];
  
  // graffiti tags — lowercased fragments, cursed-mundane, no fourth-wall.
  GRAFFITI_LINES = [
    "if you are reading this you owe sherri money",
    "crawdad on hudson",
    "BAGGIE BARB CHEATS AT THE CROSSWORD",
    "the priest knew. the priest knew.",
    "call mom",
    "the bus is late",
    "don't trust pinky on tuesdays",
    "yuri sees you in the metal",
    "STRIPE LIED. STRIPE LIES.",
    "ben is not your dad",
    "the dog was here. the dog is here.",
    "tony does not blink",
    "i lost a sock here in 2011",
    "the conductor is real",
    "DAVE WAS RIGHT ABOUT THE PIGEONS",
    "WHEN U SEE PAULIE LOOK AT THE FACE",
    "i was a person once",
    "FREE THE POSSUM (he is free)",
    "carl owes dolores forty",
    "the train is coming. the train is coming. the train is coming.",
    "ECCLESIASTES 1:9",
    "if found return to nobody",
    "honk if you remember mondays",
    "BRENDAN GOT TAZED HIMSELF",
    "soap is a rock if you believe",
    "BOOK 14 ACROSS IS BLAME",
    "the underpass has ears",
    "i traded a coat for a coat for a coat",
    "PETE WEIGHED MY SOUL. $1.",
    "the corner belongs to nobody",
    "ROCK BOTTOM SAYS HI",
    "i kissed lurch on a dare in 2007",
    "the soup kitchen closed in 1998 (it is open)",
    "MAYOR'S COUSIN IS NOT THE MAYOR",
    "yell louder. larry is listening.",
    "the pothole knows my name",
  ];
  
  // v13 wave 8b — faction-themed graffiti pools. buildGraffiti() picks per-zone-faction.
  // fallback (street default) is GRAFFITI_LINES above. these two are SCRAP and SPIRITUAL.
  SCRAP_GRAFFITI_LINES = [
    "5/8 inch socket missing",
    "PETE TAKES NUMBERS",
    "yuri's bird is plastic",
    "the wire is copper. probably.",
    "DO NOT TRUST THE SCALE",
    "the dog is not the dog",
    "WEIGHED IT TWICE STILL OWED",
    "rebar is rebar.",
    "if it bends it bends. so do you.",
    "MAGNET CHECKED. MAGNET LIED.",
    "pete owes me a dollar from 2009",
    "the gate squeaks louder on wednesdays",
    "BRUTUS COUNTS IN BARKS",
    "every pipe used to be a wall",
    "WIRES OUT OF THE WALLS GO INTO THE WALLS",
  ];
  SPIRITUAL_GRAFFITI_LINES = [
    "FATHER O'MALLEY KNOWS",
    "the bus does not come for sinners",
    "pigeons remember",
    "MOM IS LISTENING",
    "the wages of sin are eleven dollars",
    "the bench is a pew if you sit right",
    "PRAY FOR DOLORES",
    "the fountain agrees",
    "GOD IS A WEDNESDAY",
    "the possum saw and the possum spoke",
    "we are here. we were here. we will be here.",
    "BLESSED ARE THE BROKE",
    "the philosopher said the same thing twice",
    "kneel where the chalk is",
    "AMEN MEANS COME BACK TOMORROW",
  ];
  
  // ---------- v13 wave 3: discoverability + vendor index ----------
  // the canonical list of NPCs that get the "?" floater + appear in the people-met index.
  // excludes ambient pedestrians (cubscout/jogger/busker/dogwalker), dave (the steal target),
  // and the rest of the random-flavor crew.
  VENDOR_FLOATER_IDS = new Set([
    'tony','yuri','pete','barb','biggu','conductor','larry','paulie','stripe','mom','priest','pinky','math',
    // v13 wave 8a — new lore NPCs that should show up in the "people you've met" index
    'train_hopper','philosopher','lease_guy','gutter_greg'
  ]);
  VENDOR_INDEX_META = {
    tony:      { zone:'the block (the corner)',     tag:'rocks ten dollars. simple math.' },
    yuri:      { zone:'scrap yard',                 tag:'copper at $25 a piece. brutus remembers.' },
    pete:      { zone:'pawn shop',                  tag:'$15 copper. one second. weighing.' },
    barb:      { zone:'the laundromat',             tag:'packets $5. the crossword. she does not look up.' },
    biggu:     { zone:'highway underpass',          tag:'tall. trades the cart for 5 copper.' },
    // v13 wave 8a — conductor relocated to the train yard
    conductor: { zone:'the train yard',             tag:'3 copper for $90. the train is coming.' },
    larry:     { zone:'the projects',               tag:'WHAT. fights. yells. big damage.' },
    paulie:    { zone:'back alley',                 tag:'the face. it is, in fact, just the face.' },
    stripe:    { zone:'the projects',               tag:'$8 rocks. 40% soap. fences yours at $6.' },
    mom:       { zone:'marketplace (daytime)',      tag:'$10 and pity. likes lavender kombucha.' },
    priest:    { zone:'the church',                 tag:'blessed tic-tacs. -30 shakes. donate for cred.' },
    pinky:     { zone:'the bus stop',               tag:'house cut packets $4. dirty. amore.' },
    math:      { zone:'highway underpass',          tag:'the math. expectation. every third number is a tip.' },
    // v13 wave 8a — new NPCs
    train_hopper: { zone:'the train yard',          tag:'wiry. denim. stories about bremerton. no money changes hands.' },
    philosopher:  { zone:'the park',                tag:'one question per day. +1 spiritual once daily for thinking about it.' },
    lease_guy:    { zone:'the lot',                 tag:'one unit. one key ring. the office is structurally a rumor.' },
    gutter_greg:  { zone:'the drainage canal',      tag:'counts canal inventory once per day. the duck is inventory.' },
  };
  
  // pigeon king's lost crown — 6 candidate locations, picked deterministically when the quest starts.
  CROWN_SPOTS = [
    { x: 1900, y: 440, where: 'behind the abandoned building' },
    { x: 340,  y: 612, where: 'on a pawn-shop sill' },
    { x: 150,  y: 1290,where: 'next to the alley dumpster' },
    { x: 160,  y: 410, where: 'against the scrap-yard fence' },
    { x: 1880, y: 1340,where: 'in the church gutter' },
    { x: 1380, y: 460, where: 'under the underpass rebar' },
  ];
  
  // vendor base prices are routed through this so the pigeon crown can shave 10% off.
  // charisma >= 1 → 10% off, rounded to nearest dollar, floor of $1.
  
  
  
}
