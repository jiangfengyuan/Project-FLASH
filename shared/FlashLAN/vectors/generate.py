#!/usr/bin/env python3
"""Independent candidate encoding/KDF vectors. RFC7748 test keys only.

Uses libsodium's C X25519/HKDF/HMAC as the reference for the Rust SAS primitive
building blocks; AEAD intentionally uses the selected shared libsodium primitive.
Never load real keys or backups. Does not patch/seed vodozemac's opaque Sas API.
"""
import argparse
import ctypes as C
import hashlib
import json
from pathlib import Path
import struct

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--sodium-library', type=Path, required=True)
p.add_argument('--check', action='store_true')
args = p.parse_args()
s = C.CDLL(str(args.sodium_library.resolve()))
s.sodium_version_string.restype = C.c_char_p
assert s.sodium_init() >= 0 and s.sodium_version_string() == b'1.0.22'
P = C.c_void_p
def native(name, types):
    f = getattr(s, name); f.argtypes = types; f.restype = C.c_int
    return f
base = native('crypto_scalarmult_curve25519_base', [P, P])
dh = native('crypto_scalarmult_curve25519', [P, P, P])
extract = native('crypto_kdf_hkdf_sha256_extract', [P, P, C.c_size_t, P, C.c_size_t])
expand = native('crypto_kdf_hkdf_sha256_expand', [P, C.c_size_t, P, C.c_size_t, P])
mac = native('crypto_auth_hmacsha256', [P, P, C.c_ulonglong, P])
aead = native('crypto_aead_xchacha20poly1305_ietf_encrypt',
              [P, P, P, C.c_ulonglong, P, C.c_ulonglong, P, P, P])
buf = C.create_string_buffer
def public(private):
    out = buf(32); assert base(out, buf(private)) == 0
    return out.raw

sp = bytes.fromhex('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a')
rp = bytes.fromhex('5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb')
sk, rk = public(sp), public(rp)
shared = buf(32); assert dh(shared, buf(sp), buf(rk)) == 0
assert shared.raw.hex() == '4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742'
prk = buf(32); assert extract(prk, None, 0, shared, 32) == 0
def hkdf(info, count):
    out = buf(count); info = info.encode('ascii')
    assert expand(out, count, buf(info), len(info), prk) == 0
    return out.raw
def frame(body): return struct.pack('>I', len(body)) + body
def hello(role, nonce):
    return frame(bytes([2 if role == 1 else 1]) + b'FLASH-LAN/2' +
                 struct.pack('>HHB', 2, 1, role) + nonce +
                 struct.pack('>Q', 50 * 1024 * 1024) + b'\x03\x03\x03')
rh = hello(2, bytes(range(32)))
sh = hello(1, bytes(range(32, 64)))
commitment = hashlib.sha256(b'FLASH-LAN/2 commitment\0' + rh + sh + sk).digest()
cf, rf, sf = frame(b'\x03' + commitment), frame(b'\x04' + rk), frame(b'\x05' + sk)
t = hashlib.sha256(b'FLASH-LAN/2 transcript\0' + rh + sh + cf + rf + sf).digest()
th = t.hex()
raw_sas = hkdf('FLASH-LAN/2 sas:' + th, 6)
b = raw_sas
decimals = [1000 + (b[0] << 5 | b[1] >> 3),
            1000 + ((b[1] & 7) << 10 | b[2] << 2 | b[3] >> 6),
            1000 + ((b[3] & 63) << 7 | b[4] >> 1)]
keys = {d: {'key': hkdf('FLASH-LAN/2 key:' + d + ':' + th, 32),
            'prefix': hkdf('FLASH-LAN/2 nonce:' + d + ':' + th, 16)}
        for d in ['S>R', 'R>S']}
confirmations = {}
for role in ['S', 'R']:
    info = 'FLASH-LAN/2 confirm:' + role + ':' + th
    text = ('accept:' + role + ':' + th).encode('ascii')
    key = hkdf(info, 32); tag = buf(32)
    assert mac(tag, buf(text), len(text), buf(key)) == 0
    confirmations[role] = {'input': text.decode('ascii'), 'info': info,
                           'mac': tag.raw.hex(), 'frame': frame(b'\x06' + tag.raw).hex()}
root = Path(__file__).resolve().parents[3]
payload = (root / 'docs/contracts/fixtures/valid-schema2.json').read_bytes()
def record(kind, direction, seq, plaintext):
    k = keys['S>R' if direction == 1 else 'R>S']
    nonce = k['prefix'] + struct.pack('>Q', seq)
    header = struct.pack('>BBQI', kind, direction, seq, len(plaintext) + 16)
    prefix = struct.pack('>I', len(header) + len(plaintext) + 16) + header
    aad = b'FLASH-LAN/2 record\0' + t + prefix
    out = buf(len(plaintext) + 16); length = C.c_ulonglong()
    assert aead(out, C.byref(length), buf(plaintext), len(plaintext), buf(aad), len(aad),
                None, buf(nonce), buf(k['key'])) == 0
    assert length.value == len(plaintext) + 16
    return {'plaintext': plaintext.hex(), 'nonce': nonce.hex(), 'aad': aad.hex(),
            'frame': (prefix + out.raw).hex()}
finish = struct.pack('>Q', len(payload)) + hashlib.sha256(payload).digest()
vector = {
    'status': 'test-only candidate, not release/interoperability approval',
    'private_key_source': 'RFC7748 section 6.1 (publicly known test secrets)',
    'reference': 'Python encoding/hashlib + libsodium 1.0.22 C X25519/HKDF/HMAC/AEAD',
    'opaque_sas_limit': 'fixed-key vectors do not construct vodozemac Sas; randomized full-peer tests cover that API',
    'sender_private': sp.hex(), 'receiver_private': rp.hex(),
    'sender_public': sk.hex(), 'receiver_public': rk.hex(), 'shared_secret': shared.raw.hex(),
    'r_hello': rh.hex(), 's_hello': sh.hex(), 'commitment': commitment.hex(),
    'commitment_frame': cf.hex(), 'r_key_frame': rf.hex(), 's_key_frame': sf.hex(),
    'transcript': th, 'sas_bytes': raw_sas.hex(), 'sas_decimals': decimals,
    'keys': {d: {name: val.hex() for name, val in k.items()} for d, k in keys.items()},
    'confirmations': confirmations,
    'data': record(0x20, 1, 0, payload), 'finish': record(0x21, 1, 1, finish),
    'receipt': record(0x22, 2, 0, finish),
}
text = json.dumps(vector, indent=2, ensure_ascii=False) + '\n'
destination = Path(__file__).with_name('lan-v2.json')
if args.check:
    assert destination.read_text() == text, 'reference vector drift'
    print('Reference vector reproducibility: PASS')
else:
    destination.write_text(text)
    print('Generated fixed RFC7748 candidate vector (test secrets only)')
