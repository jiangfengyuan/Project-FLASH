const test = require('node:test');
const assert = require('node:assert/strict');
const { validateDocument, validateBytes, validDay, validInstant, MAX_BYTES } = require('./validate.cjs');
const minimal = require('../../docs/contracts/fixtures/valid-minimal.json');
const full = require('../../docs/contracts/fixtures/valid-full.json');
const schema2 = require('../../docs/contracts/fixtures/valid-schema2.json');
const legacy = require('../../docs/contracts/fixtures/legacy-v1.json');

for (const [name, value] of Object.entries({ minimal, full, schema2 })) {
  test(`${name} fixture passes structure and semantics`, () => {
    assert.deepEqual(validateBytes(Buffer.from(JSON.stringify(value))), { valid: true, errors: [] });
  });
}

const invalidCases = {
  'unknown envelope': d => { d.version = 'flash-backup-v3'; },
  'unknown section version': d => { d.schemas.tasks = 3; },
  'unknown section': d => { d.data.attachments = []; },
  'unknown record field': d => { d.data.tasks[0].notificationId = 123; },
  'missing required section': d => { delete d.data.tasks; },
  'missing export metadata': d => { delete d.exportedAt; },
  'invalid calendar date': d => { d.data.logs[0].recordDate = '2026-02-30'; },
  'invalid enum': d => { d.data.logs[0].colorTag = 'blue'; },
  'out-of-range log importance': d => { d.data.logs[0].importance = 9; },
  'fractional emotion level': d => { d.data.emotions[0].level = 1.5; },
  'blank title': d => { d.data.tasks[0].title = ' \t\n\uFEFF'; },
  'emoji title UTF-16 limit': d => { d.data.tasks[0].title = '😀'.repeat(101); },
  'text UTF-16 limit': d => { d.data.logs[0].content = '😀'.repeat(50001); },
  'mixed due variants': d => { d.data.tasks[0].due.date = '2026-09-06'; },
  'unknown time zone': d => { d.data.tasks[0].due.timeZone = 'Flash/Unknown'; },
  'updated before created': d => { d.data.tasks[0].updatedAt = '2026-09-03T23:59:59.999Z'; },
  'duplicate ID with different content': d => { d.data.logs.push({ ...d.data.logs[0], content: '另一条记录' }); },
  'array exceeds input cap': d => { d.data.logs = Array(100001).fill(d.data.logs[0]); }
};
for (const [name, mutate] of Object.entries(invalidCases)) {
  test(`reject ${name}`, () => {
    const document = structuredClone(full);
    mutate(document);
    assert.equal(validateDocument(document).valid, false);
  });
}

test('legacy v1 is deliberately outside the v2 schema', () => {
  assert.equal(validateDocument(legacy).valid, false);
});

test('schema 2: new fields are rejected under section version 1 (version declares structure)', () => {
  for (const mutate of [
    d => { d.data.logs[0].isFavorite = true; },
    d => { d.data.emotions[0].intensity = 3; },
    d => { d.data.tasks[0].sourceLogId = '55555555-5555-4555-8555-555555555555'; }
  ]) {
    const d = structuredClone(full); // valid-full 全部分区为 schema 1
    mutate(d);
    assert.equal(validateDocument(d).valid, false);
  }
});

test('schema 2: field value rules (intensity range, boolean, id shape)', () => {
  for (const mutate of [
    d => { d.data.emotions[0].intensity = 0; },
    d => { d.data.emotions[0].intensity = 6; },
    d => { d.data.emotions[0].intensity = 1.5; },
    d => { d.data.emotions[0].intensity = '4'; },
    d => { d.data.logs[0].isFavorite = 'yes'; },
    d => { d.data.tasks[0].sourceLogId = 'not-a-uuid'; }
  ]) {
    const d = structuredClone(schema2);
    mutate(d);
    assert.equal(validateDocument(d).valid, false);
  }
});

test('schema 2: versions mix per section; new fields follow their own section version', () => {
  const d = structuredClone(schema2);
  d.schemas.emotions = 1; // emotions 回到 1：intensity/isFavorite 即非法
  assert.equal(validateDocument(d).valid, false);
  const e = structuredClone(schema2);
  e.schemas.emotions = 1;
  for (const item of e.data.emotions) { delete item.intensity; delete item.isFavorite; }
  assert.equal(validateDocument(e).valid, true);
});

test('optional fields support omission and null without conflating empty text', () => {
  const d = structuredClone(full);
  d.data.tasks[1].notes = '';
  d.data.tasks[1].completedAt = null;
  delete d.data.emotions[0].subEmotion;
  assert.equal(validateDocument(d).valid, true);
});

test('real Gregorian dates, offset timestamps and rejected ambiguous instants', () => {
  for (const value of ['2024-02-29', '2000-02-29', '0001-01-01']) assert.equal(validDay(value), true, value);
  for (const value of ['1900-02-29', '2026-02-29', '0000-01-01', '2026-13-01']) assert.equal(validDay(value), false, value);
  for (const value of ['2026-09-05T08:00:00+08:00', '2026-09-05T00:00:00.123456789Z']) assert.equal(validInstant(value), true, value);
  for (const value of ['2026-02-30T00:00:00Z', '2026-09-05T24:00:00Z', '2026-09-05T00:00:60Z',
    '2026-09-05T00:00:00', '2026-09-05T00:00:00-00:00', '0001-01-01T00:00:00+01:00']) {
    assert.equal(validInstant(value), false, value);
  }
});

test('due.timeZone matches canonical-timezones.json exactly (no ICU aliases)', () => {
  const listed = new Set(require('./canonical-timezones.json'));
  const probe = ['Asia/Shanghai', 'America/New_York', 'Europe/Berlin', 'Asia/Tokyo', 'Australia/Sydney',
    'utc', 'Zulu', 'GMT0', 'GMT', 'US/Eastern', 'Etc/UTC', 'UTC', 'Etc/GMT+1', 'CET',
    'GMT+08:00', '+08:00', 'Flash/Unknown', 'asia/shanghai'];
  for (const zone of probe) {
    const d = structuredClone(full);
    d.data.tasks[0].due.timeZone = zone;
    const result = validateDocument(d);
    if (listed.has(zone)) {
      assert.equal(result.valid, true, `expected accepted: ${zone}`);
    } else {
      assert.equal(result.valid, false, `expected rejected: ${zone}`);
      assert.equal(result.errors.some(e => e.path === '/data/tasks/0/due/timeZone' && e.code === 'TIME_ZONE'), true, zone);
    }
  }
});

test('compare normalized milliseconds, not timestamp text or submillisecond precision', () => {
  const d = structuredClone(full);
  d.data.tasks[0].createdAt = '2026-09-05T08:00:00.000999999+08:00';
  d.data.tasks[0].updatedAt = '2026-09-05T00:00:00.000000001Z';
  assert.equal(validateDocument(d).valid, true);
});

test('UTF-8, BOM and file-size guards', () => {
  assert.equal(validateBytes(Buffer.from([0xc3, 0x28])).errors[0].code, 'ENCODING_OR_JSON');
  assert.equal(validateBytes(Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from(JSON.stringify(minimal))])).valid, false);
  assert.equal(validateBytes(Buffer.alloc(MAX_BYTES + 1)).errors[0].code, 'FILE_SIZE');
});

test('UUID identity is section-local and case-sensitive for existing storage compatibility', () => {
  const d = structuredClone(full);
  d.data.logs[0].id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  d.data.logs.push({ ...d.data.logs[0], id: d.data.logs[0].id.toUpperCase() });
  d.data.emotions[0].id = d.data.logs[0].id;
  assert.equal(validateDocument(d).valid, true);
});

for (const item of require('../../docs/contracts/fixtures/cases.json')) {
  test(`shared corpus: ${item.file}`, () => {
    const bytes = require('node:fs').readFileSync(require('node:path').join(__dirname, '../../docs/contracts/fixtures', item.file));
    assert.equal(validateBytes(bytes).valid, item.valid);
  });
}

for (const name of ['merge-local', 'merge-incoming', 'merge-expected', 'overwrite-expected']) {
  test(`merge golden document passes Schema: ${name}`, () => {
    const document = require(`../../docs/contracts/fixtures/${name}.json`);
    assert.deepEqual(validateDocument(document), { valid: true, errors: [] });
  });
}


test('generated IANA policy accepts modern names and retains authoritative rename spelling', () => {
  for (const zone of ['Europe/Kyiv', 'Europe/Kiev', 'Asia/Kolkata', 'Asia/Calcutta', 'Asia/Kathmandu', 'Africa/Asmara', 'Pacific/Chuuk']) {
    const input = structuredClone(full); input.data.tasks[0].due.timeZone = zone;
    assert.equal(validateDocument(input).valid, true, zone);
    assert.equal(input.data.tasks[0].due.timeZone, zone);
  }
});

// ---- flash-backup-enc-v1 (docs/contracts/flash-backup-enc-v1.md) ----
{
  const fs = require('node:fs');
  const path = require('node:path');
  const envelope = require('./envelope.cjs');
  const generator = require('./generate-encrypted.cjs');
  const Ajv2020 = require(process.env.FLASH_AJV_PATH ?
    path.join(process.env.FLASH_AJV_PATH, 'dist/2020.js') : 'ajv/dist/2020').default;
  const encSchema = new Ajv2020({ strict: true }).compile(require('../../docs/contracts/flash-backup-enc-v1.schema.json'));
  const fixtures = path.join(__dirname, '../../docs/contracts/fixtures');
  const manifest = require('../../docs/contracts/fixtures/encrypted/cases.json');

  test('encrypted corpus is regenerated byte-for-byte and has no strays', () => {
    const built = generator.build();
    const onDisk = fs.readdirSync(path.join(fixtures, 'encrypted')).sort();
    assert.deepEqual(onDisk, [...built.keys()].sort());
    for (const [file, contents] of built) assert.ok(fs.readFileSync(path.join(fixtures, 'encrypted', file)).equals(contents), file);
  });

  test('manifest passphrase is NFC and the NFD case really is a different spelling', () => {
    assert.equal(manifest.passphrase, manifest.passphrase.normalize('NFC'));
    assert.notEqual(generator.PASSPHRASE_NFD, generator.PASSPHRASE);
    assert.equal(generator.PASSPHRASE_NFD.normalize('NFC'), generator.PASSPHRASE);
  });

  for (const item of manifest.cases) {
    test(`encrypted corpus: ${item.file} → ${item.expect}${item.passphrase ? ' (alternate passphrase)' : ''}`, () => {
      const bytes = fs.readFileSync(path.join(fixtures, 'encrypted', item.file));
      const passphrase = item.passphrase ?? manifest.passphrase;
      if (item.expect === 'ok') {
        const plaintext = envelope.decryptBytes(bytes, passphrase);
        assert.ok(plaintext.equals(fs.readFileSync(path.join(fixtures, item.plaintext))));
        assert.equal(validateBytes(plaintext).valid, item.innerValid);
      } else {
        assert.throws(() => envelope.decryptBytes(bytes, passphrase), e => e.code === item.expect);
      }
      // Schema agrees on shape: only well-formed envelopes pass it (auth failures are well-formed).
      if (item.expect !== 'invalidJSON') {
        const shapeOK = encSchema(JSON.parse(bytes.toString('utf8')));
        assert.equal(shapeOK, item.expect === 'ok' || item.expect === 'authenticationFailed');
      }
    });
  }

  test('encrypted envelopes never pass the plaintext v2 validator', () => {
    assert.equal(validateBytes(fs.readFileSync(path.join(fixtures, 'encrypted/valid-enc-full.json'))).valid, false);
  });

  test('round trip with random salt and nonce; header fields and AAD are bound', () => {
    const plaintext = fs.readFileSync(path.join(fixtures, 'valid-full.json'));
    const a = envelope.encryptBytes(plaintext, 'correct horse', { iterations: envelope.MIN_ITERATIONS });
    const b = envelope.encryptBytes(plaintext, 'correct horse', { iterations: envelope.MIN_ITERATIONS });
    assert.notEqual(JSON.parse(a).kdf.salt, JSON.parse(b).kdf.salt);
    assert.notEqual(JSON.parse(a).cipher.nonce, JSON.parse(b).cipher.nonce);
    assert.ok(envelope.decryptBytes(a, 'correct horse').equals(plaintext));
    // Wrong AAD (as a different envelope version would use) fails authentication.
    const parsed = envelope.parseEnvelope(JSON.parse(a));
    const crypto = require('node:crypto');
    const key = envelope.deriveKey('correct horse', parsed.salt, parsed.iterations);
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, parsed.nonce);
    decipher.setAAD(Buffer.from('flash-backup-enc-v2'));
    decipher.setAuthTag(parsed.sealed.subarray(-16));
    decipher.update(parsed.sealed.subarray(0, -16));
    assert.throws(() => decipher.final());
  });

  test('exported envelope uses 600,000 iterations and fresh 16/12-byte salt/nonce', () => {
    const out = JSON.parse(envelope.encryptBytes(Buffer.from('{}'), 'correct horse'));
    assert.equal(out.kdf.iterations, envelope.EXPORT_ITERATIONS);
    assert.equal(Buffer.from(out.kdf.salt, 'base64').length, 16);
    assert.equal(Buffer.from(out.cipher.nonce, 'base64').length, 12);
    assert.equal(encSchema(out), true);
  });

  test('export passphrase rule counts NFC code points: 8 minimum, 1024 maximum', () => {
    assert.equal(envelope.exportPassphraseProblem('1234567'), 'tooShort');
    assert.equal(envelope.exportPassphraseProblem('12345678'), null);
    assert.equal(envelope.exportPassphraseProblem('😀'.repeat(7)), 'tooShort'); // 7 code points, 14 UTF-16 units
    assert.equal(envelope.exportPassphraseProblem('café 12'), 'tooShort'); // NFC: 7 code points
    assert.equal(envelope.exportPassphraseProblem('x'.repeat(1025)), 'tooLong');
  });

  test('ciphertext base64 cap equals 50 MiB plaintext plus tag', () => {
    assert.equal(envelope.MAX_CIPHERTEXT_BASE64, 69905088);
    assert.ok(envelope.MAX_CIPHERTEXT_BASE64 + 1024 < envelope.MAX_ENVELOPE_BYTES);
  });
}

const libraryV3 = require('../../docs/contracts/fixtures/valid-library-v3.json');
test('v3 complete snapshot validates and rejects orphan metadata', () => {
  assert.equal(validateDocument(libraryV3).valid,true);
  const copy = structuredClone(libraryV3);
  copy.personalLibrary.links['log:missing'] = [];
  assert.equal(validateDocument(copy).valid,false);
});
test('v3 rejects unknown personal library keys', () => {
  const copy = structuredClone(libraryV3); copy.personalLibrary.unrecognized = true;
  assert.equal(validateDocument(copy).valid,false);
});

const libraryV4 = require('../../docs/contracts/fixtures/valid-library-v4.json');
const archivedIdea = d=>d.trash.find(t=>t.log?.category==='idea');
test('native v4 archive snapshot passes the reference validator', () => {
  assert.deepEqual(validateDocument(libraryV4),{valid:true,errors:[]});
});
for (const [name,change] of Object.entries({
  'unknown archive field':d=>{d.trash[0].unknown=true;},
  'duplicate archive':d=>{d.trash.push(structuredClone(d.trash[0]));},
  'two archived payloads':d=>{archivedIdea(d).emotion={id:libraryV3.data.logs[0].id,level:0,createdAt:'2026-11-14T00:00:00.000Z',recordDate:'2026-11-14'};},
  'bad retention':d=>{d.preferences.retentionDays=366;},
  'unknown mode':d=>{d.preferences.taggingMode='remote';},
  'dangling origin':d=>{d.automaticTags['log:missing']=[archivedIdea(d).tags[0].id];},
  'dangling archived origin':d=>{archivedIdea(d).automaticTagIDs=['00000000-0000-4000-8000-000000000000'];},
  'invalid archived content date':d=>{archivedIdea(d).log.recordDate='2026-02-30';},
  'expired before deletion':d=>{d.trash[0].expiresAt=d.trash[0].deletedAt-1;}
})) test(`v4 rejects ${name}`,()=>{
  const copy=structuredClone(libraryV4);change(copy);assert.equal(validateDocument(copy).valid,false);
});
