import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import {
  ROOT, OUTPUT, FIXED_EPOCH_MS, ACTOR_ALIASES, GENERATED_FAMILIES,
  buildContent, stableStringify, makeSerializer, loadSeededSource,
  parseRegistry, sourceFiles, ensureVmFlag, extractItemData,
} from './export-3d-content.mjs';

ensureVmFlag(fileURLToPath(import.meta.url));
let checks = 0;
const check = (condition, message) => { assert.ok(condition, message); checks++; };
const equal = (actual, expected, message) => { assert.deepEqual(actual, expected, message); checks++; };
const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');
const own = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
const baseIds = 'tony yuri brutus scrap_dog pete lurch sherri paulie dave mom possum priest conductor larry stripe pigeon biggu cubscout jogger dogwalker busker horsecop vapelord pothole mayorscousin phoneguy barb pinky math train_hopper philosopher lease_guy gutter_greg laundromat_lady meter_maid food_truck priests_son karaoke skid_brutus_1 skid_lurch skid_sherri'.split(' ');
const guardIds = ['blue_tarp', 'cart_cavalry', 'copper_choir'].flatMap(clan =>
  Array.from({ length: 4 }, (_, i) => `kingdom_guard_${clan}_1_${i}`))
  .concat(Array.from({ length: 3 }, (_, i) => `kingdom_guard_throne_1_${i}`));

function assertCoverage(content) {
  equal(content.schema, 1, 'schema must remain explicitly versioned');
  equal(content.format, 'rock-bottom-source-content', 'format identity');
  equal(content.world.bounds, { w: 8600, h: 5600 }, 'untransformed full source world');
  for (const [key, expected] of Object.entries({
    zones: 23, terrainRegions: 15, roadSegments: 28, crosswalks: 26,
    groundPaths: 8, railLines: 4, landmarkFacades: 28, decor: 96,
    utilityWires: 20, lights: 24, structures: 53,
  })) equal(content.world[key].length, expected, `world.${key} complete`);
  equal(content.buildings.length, 25, 'all legacy buildings');
  equal(content.props.length, 193, 'all placed props');
  equal(content.interactiveProps.length, 14, 'all day-one interactive props');
  equal(content.initial.cashPiles.length, 29, '28 standard and one intro cash pile');
  equal(content.initial.projectiles, [], 'fresh source has no projectiles');
  equal(content.actors.base.map(actor => actor.id), baseIds, 'base actor IDs and authored order');
  equal(content.actors.day1.map(actor => actor.id), [...baseIds, ...guardIds], 'fresh guard population and authored order');
  equal(content.actors.registry.length, 63, 'canonical VIBE registry count');
  equal(content.actors.aliases, ACTOR_ALIASES, 'canonical alias map');
  equal(content.actors.generatedFamilies, GENERATED_FAMILIES, 'canonical generated-name family');
  const registry = new Set(content.actors.registry.map(actor => actor.name));
  equal(registry.size, 63, 'no duplicate registry identities');
  for (const actor of content.actors.day1) {
    const canonical = content.actors.aliases[actor.name] || actor.name;
    check(registry.has(canonical), `actor identity is registered: ${actor.id}/${actor.name}`);
    check(Number.isFinite(actor.x) && Number.isFinite(actor.y) && actor.w > 0 && actor.h > 0,
      `actor has actual source position/body: ${actor.id}`);
    check(typeof actor.hp === 'number' && typeof actor.maxHp === 'number', `actor stats retained: ${actor.id}`);
    check(!own(actor, 'interact') || actor.interact === null, `actor callback omitted: ${actor.id}`);
  }
  equal(Object.keys(content.catalogs.equipment).length, 16, 'equipment count');
  equal(Object.keys(content.catalogs.weapons).length, 9, 'weapon count');
  equal(content.catalogs.ranks.length, 8, 'rank count');
  equal(Object.keys(content.catalogs.achievements).length, 49, 'achievement count');
  equal(content.catalogs.items.length, 19, 'all exact item/name variants');
  equal([...new Set(content.catalogs.items.map(item => item.id))].sort(),
    ['aflashlightdead', 'areceipt', 'bus_pass', 'cone', 'crossword', 'detergent', 'food', 'gold_tooth', 'junk', 'license', 'lottery', 'soap', 'stripe_package'],
    'all source inventory IDs, including deterministic dumpster fallback');
  equal(content.catalogs.itemLoot.length, 29, 'all22 dumpster pool entries plus7 outcome declarations');
  equal(content.catalogs.itemDeclarations.reduce((counts, item) =>
    (counts[item.kind] = (counts[item.kind] || 0) + 1, counts), {}),
  { inventory_push: 18, site_loot: 5, dumpster_pool: 22, dumpster_outcome: 7 },
  'every audited inline inventory/loot declaration accounted for');
  equal(Object.keys(content.initial.state.quests).length, 24, 'fresh quest count');
  equal(content.definitions['src/systems/progression_routes.js'].HUSTLE_TEMPLATES.length, 14, 'hustle template count');
  equal(content.definitions['src/systems/progression_routes.js'].ROUTE_STOPS.length, 23, 'route stop count');
  equal(content.definitions['src/systems/campaigns.js'].CLAIM_SITES.length, 11, 'claim site count');
  equal(Object.keys(content.definitions['src/systems/campaigns.js'].QUEST_TARGETS).length, 10, 'quest target count');
  equal(content.definitions['src/systems/concessions.js'].SMOKE_SPOTS.length, 5, 'smoke spot count');
  equal(content.definitions['src/systems/recognition.js'].REGULAR_VENUES.length, 4, 'recognition venue count');
  equal(content.definitions['src/data/props.js'].COPPER_SITES.map(site => site.id),
    ['abandoned', 'cold_not', 'water_dept', 'rust_car'], 'all copper site IDs');
  equal(content.definitions['src/data/props.js'].BREAKIN_SITES.map(site => site.id),
    ['model_home', 'spoil_bank', 'sod_office', 'drained_pool', 'visitor_center'], 'all break-in IDs');
  const types = content.props.reduce((counts, prop) => (counts[prop.type] = (counts[prop.type] || 0) + 1, counts), {});
  equal(types, {
    dumpster: 10, cart: 1, lamp: 11, hydrant: 4, mailbox: 3, cone: 6, trash: 23,
    crate: 4, syringe: 5, bottle: 6, tent: 8, cardsign: 12, scrap_pile: 10,
    car_wreck: 6, leash_post: 1, pay_phone: 1, freight_car: 3, chalk_message: 1,
    weeds: 37, fountain: 1, park_bench: 6, swing_set: 2, drink_fountain: 2,
    tree: 7, school_mural: 1, broken_hoop: 1, school_fence: 5,
    broken_window: 5, cart_husk: 6, breakin_shell: 5,
  }, 'every source prop type/count');
  check(content.world.structures.every(structure => structure.solid === true), 'all53 authored solids retained');
  equal(content.world.structures, [...content.buildings, ...content.world.landmarkFacades], 'physicality composition order');
  equal(content.initial.player.cash, 0, 'fresh-start cash, not pre-start initialization cash');
  equal(content.initial.player.speed, 2.2, 'source pixel movement constant');
  equal(content.initial.player.w, 24, 'source player width');
  equal(content.initial.player.h, 28, 'source player height');
  equal(content.initial.state.day, 1, 'fresh day');
  equal(content.initial.state.dayTime, 0.35, 'fresh clock');
  equal(content.initial.state.achievements, { $type: 'Set', values: [] }, 'set encoding retained');
  check(!own(content.initial.state, 'endingSavePromise'), 'session persistence Promise omitted');
}

function assertAliases(content) {
  const world = 'src/data/world.js', props = 'src/data/props.js', catalogs = 'src/data/catalogs.js';
  const mappings = [
    ['world.bounds', world, 'WORLD'], ['world.tile', world, 'TILE'], ['world.zones', world, 'ZONES'],
    ['world.terrainRegions', world, 'TERRAIN_REGIONS'], ['world.roadSegments', world, 'ROAD_SEGMENTS'],
    ['world.crosswalks', world, 'CROSSWALKS'], ['world.groundPaths', world, 'GROUND_PATHS'],
    ['world.railLines', world, 'RAIL_LINES'], ['world.landmarkFacades', world, 'LANDMARK_FACADES'],
    ['world.decor', world, 'WORLD_DECOR'], ['world.utilityWires', world, 'UTILITY_WIRES'],
    ['world.lights', world, 'WORLD_LIGHTS'], ['world.ambientGrades', world, 'AMBIENT_GRADES'],
    ['world.diegeticLightRgb', world, 'DIEGETIC_LIGHT_RGB'],
    ['world.structures', 'src/systems/physicality.js', 'STRUCTURES'],
    ['buildings', props, 'BUILDINGS'], ['props', props, 'PROPS'], ['interactiveProps', props, 'interactiveProps'],
    ['catalogs.equipment', catalogs, 'EQUIPMENT'], ['catalogs.ranks', world, 'RANKS'],
    ['catalogs.weapons', 'src/minigames/activities.js', 'WEAPONS'],
    ['catalogs.achievements', 'src/systems/progression_routes.js', 'ACHIEVEMENTS'],
    ...Object.entries({ publicPhoneLines: 'PUBLIC_PHONE_LINES', graffitiLines: 'GRAFFITI_LINES',
      scrapGraffitiLines: 'SCRAP_GRAFFITI_LINES', spiritualGraffitiLines: 'SPIRITUAL_GRAFFITI_LINES',
      vendorFloaterIds: 'VENDOR_FLOATER_IDS', vendorIndexMeta: 'VENDOR_INDEX_META', crownSpots: 'CROWN_SPOTS',
    }).map(([alias, name]) => [`catalogs.${alias}`, catalogs, name]),
  ];
  for (const [alias, file, name] of mappings) {
    const actual = alias.split('.').reduce((value, key) => value[key], content);
    equal(actual, content.definitions[file][name], `convenience alias exactly equals ${file}:${name}`);
  }
}

function assertProvenance(content) {
  const expected = [...sourceFiles(), path.join(ROOT, 'VIBE.md')]
    .map(file => path.relative(ROOT, file).replaceAll('\\', '/')).sort();
  equal(Object.keys(content.source.hashes).sort(), expected, 'hash manifest covers every src file plus VIBE');
  for (const [file, hash] of Object.entries(content.source.hashes)) {
    equal(hash, sha256(fs.readFileSync(path.join(ROOT, file))), `source hash ${file}`);
  }
  equal(content.source.corpusSha256, sha256(stableStringify(content.source.hashes)), 'corpus digest');
  for (const [file, hash] of Object.entries(content.source.toolHashes)) {
    equal(hash, sha256(fs.readFileSync(path.join(ROOT, file))), `tool hash ${file}`);
  }
  equal(content.actors.registry, parseRegistry(), 'registry exact source rows');
  const itemOmissions = [], items = extractItemData(itemOmissions);
  equal(content.catalogs.items, items.items, 'derived item variants match current source literals');
  equal(content.catalogs.itemLoot, items.loot, 'derived loot retains literal quantities/values');
  equal(content.catalogs.itemDeclarations, items.declarations, 'inline item declaration audit matches source');
  equal(content.omissions.filter(entry => entry.reason === 'computed_item_data'),
    itemOmissions.sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0), 'every computed item field recorded');
  for (const item of content.catalogs.items) {
    check(item.derived === true && item.sources.length > 0, `derived item has source refs: ${item.id}`);
    for (const source of item.sources) {
      const line = fs.readFileSync(path.join(ROOT, source.file), 'utf8').split(/\r?\n/)[source.line - 1];
      check(!!line && line.includes(item.n), `item source line retains exact name: ${item.id}`);
    }
    if (item.derivation) {
      equal(item.derivation.result, item.n.replace(/\W/g, ''), 'generated ID uses the exact source literal normalization');
      equal(item.id, item.derivation.result, 'generated ID result matches record');
    }
  }
  const omissionPaths = new Set(content.omissions.map(entry => entry.path));
  equal(omissionPaths.size, content.omissions.length, 'unique omission paths');
  for (const omission of content.omissions) {
    check(['function', 'undefined', 'runtime_resource', 'computed_item_data'].includes(omission.reason), 'documented omission reason');
    if (omission.reason === 'function') check(!!omission.name, `function omission is named: ${omission.path}`);
  }
  for (const [file, exports] of Object.entries(content.source.exports)) {
    const dataNames = Object.entries(exports).filter(([, entry]) => entry.kind === 'data').map(([name]) => name).sort();
    equal(Object.keys(content.definitions[file]).sort(), dataNames, `module data coverage ${file}`);
    for (const [name, entry] of Object.entries(exports)) {
      check(entry.kind === 'data' || omissionPaths.has(entry.path), `export accounted for ${file}:${name}`);
    }
  }
  check(content.omissions.some(entry => entry.path === 'initial.state["endingSavePromise"]'
    && entry.reason === 'runtime_resource'), 'async omission explicitly documented');
  check(content.omissions.some(entry => entry.name === 'unlockAchievement' && entry.reason === 'function'),
    'achievement behavior has explicit mapping debt');
  check(content.omissions.some(entry => entry.path.startsWith('actors.base[') && entry.name === 'tonyDialogue'),
    'Tony behavior has explicit binding name');
  equal(Object.keys(content.definitions).sort(), expected.filter(file => file.endsWith('.js')).sort(),
    'every production module loaded and classified');
}

function serializerCounterexamples() {
  const omissions = [], encode = makeSerializer(omissions);
  const result = encode({ callable: function onUse() {}, missing: undefined,
    values: [1, undefined, function onTick() {}, 4],
    unique: new Set(['b', 'a']), lookup: new Map([['x', 3], ['y', 4]]),
  }, 'fixture');
  equal(result, { values: [1, null, null, 4],
    unique: { $type: 'Set', values: ['b', 'a'] }, lookup: { $type: 'Map', entries: [['x', 3], ['y', 4]] },
  }, 'serializer preserves collection order and array slots without executable behavior');
  equal(omissions.map(entry => entry.reason).sort(), ['function', 'function', 'undefined', 'undefined'],
    'every unavailable property explicitly recorded');
  for (const bad of [Infinity, NaN, 1n, { getContext() {} }]) {
    assert.throws(() => makeSerializer([])(bad, 'bad')); checks++;
  }
  const cycle = {}; cycle.self = cycle;
  assert.throws(() => makeSerializer([])(cycle, 'cycle'), /Cyclic/); checks++;
  const promiseOmissions = [];
  makeSerializer(promiseOmissions)({ pending: Promise.resolve() }, 'session');
  equal(promiseOmissions, [{ path: 'session["pending"]', reason: 'runtime_resource', detail: 'Promise' }],
    'unexpected Promise slot cannot serialize as an empty object');
  const protoRecord = JSON.parse('{"__proto__":{"safe":true},"constructor":"data"}');
  equal(JSON.parse(stableStringify(encode(protoRecord, 'keys'))), protoRecord, 'literal object keys remain data');
}

try {
  const disk = fs.readFileSync(OUTPUT, 'utf8'), content = JSON.parse(disk);
  assertCoverage(content);
  assertAliases(content);
  assertProvenance(content);
  serializerCounterexamples();
  const first = await buildContent(), second = await buildContent();
  equal(stableStringify(first), stableStringify(second), 'two fresh seeded runs must be byte-identical');
  equal(disk, stableStringify(first), 'checked-in artifact must exactly match current source and exporter');
  const source = await loadSeededSource();
  equal(vm.runInContext('Date.now()', source.context), FIXED_EPOCH_MS, 'fixed Date installed in source realm');
  equal(vm.runInContext('+new Date()', source.context), FIXED_EPOCH_MS, 'fixed Date constructor');
  for (const [file, module] of source.cache) {
    const relative = path.relative(ROOT, file).replaceAll('\\', '/');
    equal(Object.keys(content.source.exports[relative]).sort(), Object.keys(module.namespace).sort(),
      `actual runtime namespace coverage: ${relative}`);
  }
  // Counterexamples prove the census detects replacement/omission, not just length.
  const brokenIdentity = structuredClone(content); brokenIdentity.actors.base[0].id = 'generic_vendor';
  assert.throws(() => assertCoverage(brokenIdentity), /base actor IDs/); checks++;
  const missingProp = structuredClone(content); missingProp.props.pop();
  assert.throws(() => assertCoverage(missingProp), /all placed props/); checks++;
  const aliasDrift = structuredClone(content); aliasDrift.catalogs.equipment.crocs.cost = -999;
  assert.throws(() => assertAliases(aliasDrift), /convenience alias/); checks++;
  const hiddenItem = structuredClone(content); hiddenItem.catalogs.items[0].id = 'made_up_quest_key';
  assert.throws(() => assertCoverage(hiddenItem), /all source inventory IDs/); checks++;
  const missingCallback = structuredClone(content);
  missingCallback.omissions = missingCallback.omissions.filter(entry => entry.name !== 'tonyDialogue');
  assert.throws(() => assertProvenance(missingCallback), /export accounted for|Tony behavior/); checks++;
  const count = key => Object.values(content.source.exports).reduce((n, fields) =>
    n + Object.values(fields).filter(entry => !key || entry.kind === key).length, 0);
  console.log(`3D CONTENT GATE PASS: ${checks} assertions`);
  console.log(`source: ${Object.keys(content.source.hashes).length} hashes; ${Object.keys(content.definitions).length} modules; ${count()} exports (${count('data')} data)`);
  console.log('world: 23 zones / 53 solids / 193 props / 14 interactive props / 29 cash piles');
  console.log('actors: 41 base / 56 real day-one / 63 canonical registry rows; exact IDs and order');
  console.log('catalogs: 16 equipment / 9 weapons / 49 achievements / 24 quests / 23 route stops / 13 inventory IDs (19 variants)');
  console.log('items: 52 audited declarations / 29 dumpster outcomes / 6 explicit computed-field omissions');
  console.log(`omissions: ${content.omissions.length} explicit callback/resource/undefined/computed paths; data coverage is not gameplay parity`);
  console.log('determinism: two fresh seeded/fixed-clock runs and committed artifact byte-identical');
  console.log('counterexamples: missing prop, replaced actor, stale alias, hidden callback, host resource, cycle and non-finite data rejected');
} catch (error) {
  console.error(`3D CONTENT GATE FAIL: ${error.message}`);
  process.exitCode = 1;
}
