// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
// Test-only fixed secret injection. No deterministic constructor exists in the C ABI.
use super::*;
use serde_json::Value;
use sha2::Sha256;

fn vector() -> Value { serde_json::from_str(include_str!("../../vectors/lan-v2.json")).unwrap() }
fn hex(s: &str) -> Vec<u8> {
    assert_eq!(s.len() % 2, 0);
    (0..s.len()).step_by(2).map(|i| u8::from_str_radix(&s[i..i+2], 16).unwrap()).collect()
}
fn b(v: &Value, name: &str) -> Vec<u8> { hex(v[name].as_str().unwrap()) }
fn setup(v: &Value, role: Role, state: State) -> Session {
    let mut session = Session::new(role, 0, 120_000).unwrap();
    let (tx, rx) = if role == Role::Sender { ("S>R", "R>S") } else { ("R>S", "S>R") };
    session.output.clear(); session.state = state;
    session.transcript.copy_from_slice(&b(v, "transcript"));
    session.keys = Some(Keys {
        tx: Zeroizing::new(b(&v["keys"][tx], "key")), rx: Zeroizing::new(b(&v["keys"][rx], "key")),
        tx_nonce: Zeroizing::new(b(&v["keys"][tx], "prefix")), rx_nonce: Zeroizing::new(b(&v["keys"][rx], "prefix")),
    });
    session
}

#[test]
fn fixed_rfc7748_secret_matches_independent_c_reference() {
    let v = vector();
    let private: [u8; 32] = b(&v, "sender_private").try_into().unwrap();
    let secret = vodozemac::Curve25519SecretKey::from_slice(&private);
    let public = Curve25519PublicKey::from(&secret);
    assert_eq!(public.as_bytes().as_slice(), b(&v, "sender_public"));
    let peer = Curve25519PublicKey::from_slice(&b(&v, "receiver_public")).unwrap();
    let shared = secret.diffie_hellman(&peer).unwrap();
    assert_eq!(shared.as_bytes().as_slice(), b(&v, "shared_secret"));
}
#[test]
fn exact_commitment_transcript_and_hello_bytes_match_reference() {
    let v = vector();
    let r = b(&v, "r_hello"); let s = b(&v, "s_hello");
    assert_eq!(wire::read_hello(&r, Role::Receiver).unwrap(), MAX_BACKUP);
    assert_eq!(wire::read_hello(&s, Role::Sender).unwrap(), MAX_BACKUP);
    assert_eq!(wire::commitment(&r, &s, &b(&v, "sender_public")).as_slice(), b(&v, "commitment"));
    assert_eq!(wire::transcript(&r, &s, &b(&v, "commitment_frame"), &b(&v, "r_key_frame"), &b(&v, "s_key_frame")).as_slice(), b(&v, "transcript"));
}
#[test]
fn rust_hkdf_and_hmac_match_independent_libsodium_reference() {
    use hmac::{Hmac, KeyInit, Mac};
    let v = vector(); let shared = b(&v, "shared_secret");
    let hkdf = hkdf::Hkdf::<Sha256>::new(None, &shared);
    let derive = |info: &str, count: usize| {
        let mut out = vec![0; count]; hkdf.expand(info.as_bytes(), &mut out).unwrap(); out
    };
    let t = v["transcript"].as_str().unwrap();
    assert_eq!(derive(&format!("FLASH-LAN/2 sas:{t}"), 6), b(&v, "sas_bytes"));
    for direction in ["S>R", "R>S"] {
        assert_eq!(derive(&format!("FLASH-LAN/2 key:{direction}:{t}"), 32), b(&v["keys"][direction], "key"));
        assert_eq!(derive(&format!("FLASH-LAN/2 nonce:{direction}:{t}"), 16), b(&v["keys"][direction], "prefix"));
    }
    for role in ["S", "R"] {
        let c = &v["confirmations"][role];
        let key = derive(c["info"].as_str().unwrap(), 32);
        let mut mac = <Hmac<Sha256> as KeyInit>::new_from_slice(&key).unwrap();
        mac.update(c["input"].as_str().unwrap().as_bytes());
        assert_eq!(mac.finalize().into_bytes().as_slice(), b(c, "mac"));
    }
}
#[test]
fn exact_records_and_authenticated_receipt_match_reference_encoder() {
    let v = vector();
    let mut s = setup(&v, Role::Sender, State::ReadyToSend);
    let mut r = setup(&v, Role::Receiver, State::Receiving);
    let payload = b(&v["data"], "plaintext");
    s.provide_backup(&payload, 0).unwrap();
    for name in ["data", "finish"] {
        let frame = s.take_output(0).unwrap().unwrap();
        assert_eq!(frame, b(&v[name], "frame"));
        for byte in frame { r.receive(&[byte], 0).unwrap(); }
    }
    assert_eq!(r.received_backup(), Some(payload.as_slice()));
    r.validated(true, 0).unwrap();
    let receipt = r.take_output(0).unwrap().unwrap();
    assert_eq!(receipt, b(&v["receipt"], "frame"));
    s.receive(&receipt, 0).unwrap(); assert_eq!(s.state(), State::Done);
}
#[test]
fn exhausted_counter_closes_instead_of_reusing_a_nonce() {
    let v = vector();
    let mut s = setup(&v, Role::Sender, State::ReadyToSend);
    s.provide_backup(b"{}", 0).unwrap(); s.tx_sequence = u64::MAX;
    assert_eq!(s.take_output(0), Err(Error::Size));
    assert_eq!(s.state(), State::Failed); assert!(s.keys.is_none()); assert!(s.payload.is_empty());
}
#[test]
fn receiver_rejects_authenticated_but_invalid_utf8_before_preview() {
    let v = vector();
    let mut s = setup(&v, Role::Sender, State::ReadyToSend);
    let mut r = setup(&v, Role::Receiver, State::Receiving);
    s.provide_backup(b"{}", 0).unwrap();
    // Deliberately malicious authenticated peer, injected in tests only.
    s.payload[0] = 0xff; s.digest = crypto::hash(&s.payload);
    r.receive(&s.take_output(0).unwrap().unwrap(), 0).unwrap();
    assert_eq!(r.receive(&s.take_output(0).unwrap().unwrap(), 0), Err(Error::Malformed));
    assert!(r.received_backup().is_none());
}

#[test]
fn authenticated_wrong_receipt_digest_is_not_delivery() {
    let v = vector();
    let mut s = setup(&v, Role::Sender, State::ReadyToSend);
    let mut r = setup(&v, Role::Receiver, State::Receiving);
    s.provide_backup(b"{}", 0).unwrap();
    r.receive(&s.take_output(0).unwrap().unwrap(), 0).unwrap();
    r.receive(&s.take_output(0).unwrap().unwrap(), 0).unwrap();
    let mut wrong = 2u64.to_be_bytes().to_vec(); wrong.extend_from_slice(&[0; 32]);
    let receipt = r.encrypt_record(0x22, &wrong).unwrap();
    assert_eq!(s.receive(&receipt, 0), Err(Error::Authentication));
    assert_eq!(s.state(), State::Failed);
}

#[test]
fn extra_authenticated_data_during_strict_validation_clears_pending_preview() {
    let v = vector();
    let mut s = setup(&v, Role::Sender, State::ReadyToSend);
    let mut r = setup(&v, Role::Receiver, State::Receiving);
    s.provide_backup(b"{}", 0).unwrap();
    r.receive(&s.take_output(0).unwrap().unwrap(), 0).unwrap();
    r.receive(&s.take_output(0).unwrap().unwrap(), 0).unwrap();
    assert_eq!(r.state(), State::Validate);
    let extra = s.encrypt_record(0x20, b"{}").unwrap();
    assert_eq!(r.receive(&extra, 0), Err(Error::State));
    assert!(r.received_backup().is_none());
}
