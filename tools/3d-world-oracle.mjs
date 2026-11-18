import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { ROOT, loadSeededSource, ensureVmFlag, stableStringify } from './export-3d-content.mjs';

// Development fixture only: execute unchanged objective selectors in the seeded
// harness. The exported fixture contains coordinates, never executable behavior.
const OUTPUT = path.join(ROOT, 'game3d/tests/fixtures/world_routes_reference.json');
const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');

export async function buildWorldOracle() {
  const game = await loadSeededSource();
  const { P, state } = game.module('src/core/runtime_ui.js');
  const campaign = game.module('src/systems/campaigns.js');
  const progression = game.module('src/systems/progression_routes.js');
  const legs = [];
  const point = (value, label) => {
    assert.ok(value && Number.isFinite(value.x) && Number.isFinite(value.y), `No selector endpoint: ${label}`);
    return { x: value.x, y: value.y };
  };
  const need = (value, label) => ({ ...point(value, label), kind: value.kind || 'source', text: value.text || label });
  const add = (name, a, b) => legs.push({ name, a: point(a, name), b: point(b, name) });
  const spawn = { x: P.x + P.w / 2, y: P.y + P.h / 2 };
  const pile = need(campaign.currentPrimaryObjective(), 'intro cash');
  state.quests.intro_remember.done = true;
  const tony = need(campaign.currentPrimaryObjective(), 'intro Tony');
  state.quests.intro_tony.done = true; P.rocks = 1;
  const crate = need(campaign.currentPrimaryObjective(), 'intro crate'); P.rocks = 0;
  add('intro spawn -> find-cash', spawn, pile);
  add('intro find-cash -> tony', pile, tony);
  add('intro tony -> crate', tony, crate);
  state.flags.introDone = true;
  state.quests.office_space.available = true;
  const leasing = need(campaign.currentOfficeObjective(), 'office leasing guy');
  add('crate -> leasing guy (office_space)', crate, leasing);
  state.office.owned = true; state.office.upgrades.desk = true;
  state.office.claimJob = { id: campaign.CLAIM_SITES[0].id, stage: 'file' };
  const office = need(campaign.currentOfficeObjective(), 'office filing');
  add('leasing guy -> office', leasing, office);
  for (const site of campaign.CLAIM_SITES) {
    state.office.claimJob = { id: site.id, stage: 'survey' };
    const survey = need(campaign.currentOfficeObjective(), `${site.id} survey`);
    state.office.claimJob = { id: site.id, stage: 'install' };
    const sign = need(campaign.currentOfficeObjective(), `${site.id} sign`);
    add(`claim ${site.id}: office -> survey`, office, survey);
    add(`claim ${site.id}: survey -> office`, survey, office);
    add(`claim ${site.id}: office -> sign`, office, sign);
    add(`work ${site.id}: sign -> office`, sign, office);
  }
  state.office.claimJob = null;
  for (const site of campaign.CLAIM_SITES.slice(0, 4)) state.districtClaims[site.id] = true;
  state.kingdom.stage = 'locked';
  const corner = need(campaign.currentKingdomObjective(), 'kingdom prerequisite');
  add('kingdom prereq: office -> corner', office, corner);
  state.kingdom.stage = 'summons'; state.office.upgrades.radio = true;
  const summons = need(campaign.currentKingdomObjective(), 'kingdom summons');
  add('kingdom summons: corner -> office', corner, summons);
  let previous = summons, previousName = 'office';
  for (const clan of campaign.KINGDOM_CLAN_LIST) {
    state.kingdom.stage = clan.marksStage;
    for (const [marks, index] of [[0, 0], [1, 1], [3, 2]]) {
      state.kingdom.marks = marks;
      const objective = need(campaign.currentKingdomObjective(), `${clan.id} mark${index}`);
      add(`kingdom ${clan.id}: ${previousName} -> mark${index}`, previous, objective);
      previous = objective; previousName = `mark${index}`;
    }
    state.kingdom.marks = 7;
    const banner = need(campaign.currentKingdomObjective(), `${clan.id} banner`);
    add(`kingdom ${clan.id}: ${previousName} -> banner`, previous, banner);
    state.kingdom.stage = clan.bossStage; state.kingdom.marks = 0;
    const boss = need(campaign.currentKingdomObjective(), `${clan.id} boss`);
    add(`kingdom ${clan.id}: banner -> boss`, banner, boss);
    previous = boss; previousName = `${clan.id} boss`;
  }
  state.kingdom.stage = 'anoint';
  const anoint = need(campaign.currentKingdomObjective(), 'kingdom anoint');
  add(`kingdom anoint: ${previousName} -> block`, previous, anoint);
  state.kingdom.stage = 'emperor_gate';
  const throne = need(campaign.currentKingdomObjective(), 'emperor gate');
  add('kingdom emperor: block -> throne banner', anoint, throne);
  state.kingdom.stage = 'emperor_boss';
  const emperor = need(campaign.currentKingdomObjective(), 'emperor boss');
  add('kingdom emperor: banner -> boss', throne, emperor);

  const routePairs = [], excludedRoutePairs = [];
  const budget = progression.routeLegBudgetPx();
  assert.equal(budget, 8250, 'source route budget changed');
  for (let i = 0; i < progression.ROUTE_STOPS.length; i++) {
    for (let j = i + 1; j < progression.ROUTE_STOPS.length; j++) {
      const a = progression.ROUTE_STOPS[i], b = progression.ROUTE_STOPS[j];
      const record = { name: `${a.id} <-> ${b.id}`, fromId: a.id, toId: b.id,
        a: point(a, a.id), b: point(b, b.id) };
      (Math.hypot(a.x - b.x, a.y - b.y) <= budget + 1e-8 ? routePairs : excludedRoutePairs).push(record);
    }
  }
  assert.equal(legs.length, 69, 'all source campaign selector transitions');
  assert.equal(routePairs.length, 252, 'all legal source route pairs');
  assert.deepEqual(excludedRoutePairs.map(pair => pair.name), ['scrap_gate <-> ditch_gauge']);
  const endpoints = new Map();
  for (const leg of [...legs, ...routePairs]) {
    for (const endpoint of [leg.a, leg.b]) endpoints.set(`${endpoint.x},${endpoint.y}`, endpoint);
  }
  const content = JSON.parse(fs.readFileSync(path.join(ROOT, 'game3d/data/source_content.json'), 'utf8'));
  for (const [file, hash] of Object.entries(content.source.hashes)) {
    assert.equal(sha256(fs.readFileSync(path.join(ROOT, file))), hash, `source content stale: ${file}`);
  }
  return {
    schema: 1, format: 'rock-bottom-world-route-reference',
    source: { corpusSha256: content.source.corpusSha256,
      generatorSha256: sha256(fs.readFileSync(fileURLToPath(import.meta.url))),
      harnessSha256: sha256(fs.readFileSync(path.join(ROOT, 'tools/runtime-harness.mjs'))),
      authority: 'unchanged live currentPrimaryObjective/currentOfficeObjective/currentKingdomObjective selectors; routeLegBudgetPx',
      comparison: 'tools/solidity-gate.mjs campaign and assignable route inventory',
    },
    units: 'source pixels', body: { w: P.w, h: P.h },
    timing: { baseSpeedPxPer16Ms: 2.2, metresPerPixel: 0.04, baseWalkMetresPerSecond: 5.5,
      legBudgetPx: budget, legBudgetSeconds: budget / (2.2 / 0.016) },
    endpoints: [...endpoints.values()], campaignLegs: legs, routePairs, excludedRoutePairs,
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  ensureVmFlag(fileURLToPath(import.meta.url));
  try {
    const unknown = process.argv.slice(2).filter(arg => arg !== '--check');
    assert.equal(unknown.length, 0, `Unknown args ${unknown.join(' ')}`);
    const first = await buildWorldOracle(), second = await buildWorldOracle();
    const text = stableStringify(first);
    assert.equal(text, stableStringify(second), 'source route fixture must be deterministic');
    if (process.argv.includes('--check')) {
      assert.equal(fs.readFileSync(OUTPUT, 'utf8'), text, 'world route fixture is stale');
      console.log('3D WORLD ORACLE CHECK PASS: source hashes, selectors and deterministic fixture match');
    } else {
      fs.mkdirSync(path.dirname(OUTPUT), { recursive: true }); fs.writeFileSync(OUTPUT, text);
      console.log(`3D WORLD ORACLE GENERATED: ${first.campaignLegs.length} campaign legs / ${first.routePairs.length} legal route pairs / ${first.excludedRoutePairs.length} excluded pair / ${first.endpoints.length} exact endpoints`);
    }
  } catch (error) { console.error(`3D WORLD ORACLE FAIL: ${error.message}`); process.exitCode = 1; }
}
