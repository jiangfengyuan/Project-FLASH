// 静态时区表完整性：条目非空、无重复、IANA ID 形态合法，且与契约 canonical-timezones.json 集合一致。
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');

const CONTRACT_JSON = path.resolve(__dirname, '../../scripts/backup-contract/canonical-timezones.json');

function zones() {
  return createLoader()('data/CanonicalTimeZones').CANONICAL_TIME_ZONES;
}

// Area/Location 形态：字母为主体，允许下划线与连字符分段，至少一级区域前缀；
// "UTC" 是无前缀的合法特例。
const IANA_SHAPE = /^[A-Za-z]+(?:[-_][A-Za-z]+)*(?:\/[A-Za-z]+(?:[-_][A-Za-z]+)*)+$/;

test('the table is a non-empty list of non-blank strings', () => {
  const list = zones();
  assert.ok(list.length > 0, 'the table must not be empty');
  for (const zone of list) {
    assert.equal(typeof zone, 'string');
    assert.ok(zone.length > 0, 'no empty entries');
    assert.equal(zone, zone.trim(), 'no surrounding whitespace');
  }
});

test('the table has no duplicate entries', () => {
  const list = zones();
  assert.equal(new Set(list).size, list.length, 'every zone id appears exactly once');
});

test('every entry has a valid IANA identifier shape and resolves in Intl', () => {
  for (const zone of zones()) {
    assert.ok(zone === 'UTC' || IANA_SHAPE.test(zone), `${zone} looks like an IANA id`);
    assert.doesNotThrow(() => new Intl.DateTimeFormat('en', { timeZone: zone }),
      `${zone} is accepted by the platform time zone database`);
  }
});

test('the table matches the contract canonical-timezones.json exactly', () => {
  const contract = require(CONTRACT_JSON);
  assert.ok(Array.isArray(contract) && contract.length > 0, 'contract file holds the zone list');
  const fromTable = new Set(zones());
  const fromContract = new Set(contract);
  const onlyInTable = [...fromTable].filter(z => !fromContract.has(z));
  const onlyInContract = [...fromContract].filter(z => !fromTable.has(z));
  assert.deepEqual(onlyInTable, [], 'no zone in the .ets table is missing from the contract');
  assert.deepEqual(onlyInContract, [], 'no zone in the contract is missing from the .ets table');
  assert.equal(zones().length, contract.length, 'same entry count on both sides');
});
