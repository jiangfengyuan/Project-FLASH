// Reference contract checker, not a replacement for native import/repair flows.
const fs = require('node:fs');
const path = require('node:path');
const { TextDecoder } = require('node:util');
const Ajv2020 = require(process.env.FLASH_AJV_PATH ?
  path.join(process.env.FLASH_AJV_PATH, 'dist/2020.js') : 'ajv/dist/2020').default;
const schema = require('../../docs/contracts/flash-backup-v2.schema.json');
const MAX_BYTES = 50 * 1024 * 1024;

// JSON.parse silently keeps the last occurrence. Walk the raw text so escaped
// and unescaped spellings of the same key are compared after decoding.
function rejectDuplicateKeys(text) {
  let index = 0;
  const whitespace = () => { while (' \t\r\n'.includes(text[index])) index++; };
  const take = character => { whitespace(); if (text[index] !== character) return false; index++; return true; };
  const expect = character => { if (!take(character)) throw new Error('Invalid JSON'); };
  function string() {
    if (text[index++] !== '"') throw new Error('Invalid JSON');
    let result = '';
    while (index < text.length) {
      const character = text[index++];
      if (character === '"') return result;
      if (character !== '\\') { result += character; continue; }
      const escape = text[index++];
      if ('"\\/'.includes(escape)) result += escape;
      else if ('bfnrt'.includes(escape)) result += ({ b: '\b', f: '\f', n: '\n', r: '\r', t: '\t' })[escape];
      else if (escape === 'u') {
        const hex = text.slice(index, index + 4);
        if (!/^[0-9a-fA-F]{4}$/.test(hex)) throw new Error('Invalid JSON');
        result += String.fromCharCode(parseInt(hex, 16)); index += 4;
      } else throw new Error('Invalid JSON');
    }
    throw new Error('Invalid JSON');
  }
  function value() {
    whitespace();
    if (text[index] === '{') {
      index++;
      if (take('}')) return;
      const keys = new Set();
      do {
        whitespace(); const key = string();
        if (keys.has(key)) throw new Error('Duplicate JSON key');
        keys.add(key); expect(':'); value();
      } while (take(','));
      expect('}');
    } else if (text[index] === '[') {
      index++;
      if (take(']')) return;
      do value(); while (take(','));
      expect(']');
    } else if (text[index] === '"') string();
    else {
      while (index < text.length && !' \t\r\n,]}'.includes(text[index])) index++;
    }
  }
  value(); whitespace();
  if (index !== text.length) throw new Error('Invalid JSON');
}

function validDay(value) {
  if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(value)) return false;
  const [y, m, d] = value.split('-').map(Number);
  const leap = y % 4 === 0 && (y % 100 !== 0 || y % 400 === 0);
  return y >= 1 && m >= 1 && m <= 12 && d >= 1 &&
    d <= [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1];
}

function validInstant(value) {
  const match = /^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(Z|[+-](\d{2}):(\d{2}))$/.exec(value);
  if (!match || !validDay(match[1]) || +match[2] > 23 || +match[3] > 59 || +match[4] > 59 ||
      match[5] === '-00:00' || (match[5] !== 'Z' && (+match[6] > 23 || +match[7] > 59))) return false;
  const instant = Date.parse(value);
  if (!Number.isFinite(instant)) return false;
  const year = new Date(instant).getUTCFullYear();
  return year >= 1 && year <= 9999;
}

const ajv = new Ajv2020({ allErrors: true, strict: true });
ajv.addFormat('date', validDay);
ajv.addFormat('date-time', validInstant);
const validateStructure = ajv.compile(schema);

function validateDocument(document) {
  if (!validateStructure(document)) return { valid: false, errors: validateStructure.errors.map(e => ({
    path: e.instancePath || '/', code: 'SCHEMA', message: e.message
  })) };
  const errors = [];
  const fail = (location, code, message) => errors.push({ path: location, code, message });
  function textLimit(value, limit, location) {
    if (typeof value === 'string' && value.length > limit) fail(location, 'TEXT_LIMIT', `UTF-16 length exceeds ${limit}`);
  }
  textLimit(document.notes, 100000, '/notes');
  for (const section of ['logs', 'emotions', 'tasks']) {
    const ids = new Set();
    document.data[section].forEach((item, index) => {
      const location = `/data/${section}/${index}`;
      if (ids.has(item.id)) fail(`${location}/id`, 'DUPLICATE_ID', 'ID must be unique within its section (case-sensitive)');
      ids.add(item.id);
      for (const field of ['content', 'note', 'status', 'notes', 'title']) {
        textLimit(item[field], field === 'title' ? 200 : 100000, `${location}/${field}`);
      }
      if (section !== 'tasks') return;
      if (Date.parse(item.updatedAt) < Date.parse(item.createdAt)) {
        fail(`${location}/updatedAt`, 'TIME_ORDER', 'updatedAt precedes createdAt at millisecond precision');
      }
      if (item.due.kind === 'dateTime') {
        try {
          if (/^(?:[+-]|GMT[+-]|UTC[+-])/.test(item.due.timeZone)) throw new Error('Expected named IANA zone');
          new Intl.DateTimeFormat('en', { timeZone: item.due.timeZone });
        }
        catch (_) { fail(`${location}/due/timeZone`, 'TIME_ZONE', 'Time zone is unsupported by this validator runtime'); }
      }
    });
  }
  return { valid: errors.length === 0, errors };
}

function validateBytes(bytes) {
  if (bytes.byteLength > MAX_BYTES) return { valid: false, errors: [{ path: '/', code: 'FILE_SIZE', message: 'File exceeds 50 MiB' }] };
  let value;
  try {
    // Reject BOM instead of silently stripping it; canonical UTF-8 has no BOM.
    if (bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) throw new Error('BOM');
    const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
    rejectDuplicateKeys(text);
    value = JSON.parse(text);
  } catch (_) {
    return { valid: false, errors: [{ path: '/', code: 'ENCODING_OR_JSON', message: 'Expected UTF-8 JSON without BOM' }] };
  }
  return validateDocument(value);
}

if (require.main === module) {
  const files = process.argv.slice(2);
  if (!files.length) {
    console.error('Usage: node scripts/backup-contract/validate.cjs <backup.json> [...]');
    process.exitCode = 2;
  }
  for (const file of files) {
    try {
      // This is a local development tool. Production adapters must cap bytes while reading.
      const result = validateBytes(fs.readFileSync(file));
      console.log(JSON.stringify({ file, ...result }));
      if (!result.valid) process.exitCode = 1;
    } catch (error) {
      console.error(`${file}: ${error.message}`);
      process.exitCode = 2;
    }
  }
}

module.exports = { validateDocument, validateBytes, validDay, validInstant, MAX_BYTES };
