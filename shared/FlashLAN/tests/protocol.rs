// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
use flash_lan::{Error, Role, Session, State, MAX_RECORD};

fn pair() -> (Session, Session) {
    let mut s = Session::new(Role::Sender, 0, 120_000).unwrap();
    let mut r = Session::new(Role::Receiver, 0, 120_000).unwrap();
    pump(&mut r, &mut s, 1);
    pump(&mut s, &mut r, 1);
    pump(&mut r, &mut s, 1);
    pump(&mut s, &mut r, 1);
    assert_eq!(s.state(), State::Confirm); assert_eq!(r.state(), State::Confirm);
    assert_eq!(s.sas(), r.sas());
    (s, r)
}
fn pump(from: &mut Session, to: &mut Session, chunk_size: usize) {
    while let Some(frame) = from.take_output(0).unwrap() {
        for chunk in frame.chunks(chunk_size) { to.receive(chunk, 0).unwrap(); }
        from.wrote(0).unwrap();
    }
}
fn ready() -> (Session, Session) {
    let (mut s, mut r) = pair();
    s.accept(0).unwrap(); r.accept(0).unwrap();
    pump(&mut s, &mut r, 7); pump(&mut r, &mut s, 17);
    assert_eq!(s.state(), State::ReadyToSend); assert_eq!(r.state(), State::Receiving);
    (s, r)
}

#[test]
fn split_every_byte_then_receive_validate_and_authenticated_receipt() {
    let (mut s, mut r) = ready();
    let bytes = b"{\"fictional\":true}";
    s.provide_backup(bytes, 0).unwrap();
    pump(&mut s, &mut r, 1);
    assert_eq!(r.state(), State::Validate);
    assert_eq!(r.received_backup(), Some(bytes.as_slice()));
    assert_eq!(s.state(), State::WaitReceipt);
    assert!(r.take_output(0).unwrap().is_none());
    r.validated(true, 0).unwrap();
    pump(&mut r, &mut s, 1);
    assert_eq!(s.state(), State::Done);
    assert_eq!(r.received_backup(), Some(bytes.as_slice()));
}
#[test]
fn no_backup_before_both_local_and_peer_acceptance() {
    let (mut s, mut r) = pair();
    assert_eq!(s.provide_backup(b"secret", 0), Err(Error::State));
    s.accept(0).unwrap();
    pump(&mut s, &mut r, 1);
    assert_eq!(s.state(), State::WaitPeer);
    assert_eq!(r.state(), State::Confirm);
    assert_eq!(s.provide_backup(b"secret", 0), Err(Error::State));
    assert!(s.take_output(0).unwrap().is_none());
    r.accept(0).unwrap(); pump(&mut r, &mut s, 1);
    assert_eq!(s.state(), State::ReadyToSend);
}
#[test]
fn full_payload_is_absent_from_wire_and_large_backup_is_chunked() {
    let (mut s, mut r) = ready();
    let data = vec![b'q'; MAX_RECORD * 2 + 17];
    s.provide_backup(&data, 0).unwrap();
    let mut records = 0;
    while let Some(frame) = s.take_output(0).unwrap() {
        assert!(frame.len() <= MAX_RECORD + 34);
        assert!(!frame.windows(64).any(|w| w == &data[..64]));
        r.receive(&frame, 0).unwrap(); records += 1;
    }
    assert_eq!(records, 4); // three data records and authenticated finish
    assert_eq!(r.received_backup(), Some(data.as_slice()));
}
#[test]
fn tampered_record_releases_no_preview_and_wipes_assembly() {
    let (mut s, mut r) = ready();
    s.provide_backup(b"fictional backup", 0).unwrap();
    let mut frame = s.take_output(0).unwrap().unwrap();
    *frame.last_mut().unwrap() ^= 1;
    assert_eq!(r.receive(&frame, 0), Err(Error::Authentication));
    assert_eq!(r.state(), State::Failed); assert!(r.received_backup().is_none());
}
#[test]
fn duplicate_and_gap_sequences_fail_closed() {
    for duplicate in [false, true] {
        let (mut s, mut r) = ready();
        s.provide_backup(&vec![9; MAX_RECORD + 1], 0).unwrap();
        let first = s.take_output(0).unwrap().unwrap();
        let second = s.take_output(0).unwrap().unwrap();
        if duplicate {
            r.receive(&first, 0).unwrap();
            assert!(r.receive(&first, 0).is_err());
        } else { assert!(r.receive(&second, 0).is_err()); }
        assert_eq!(r.state(), State::Failed); assert!(r.received_backup().is_none());
    }
}
#[test]
fn reflected_and_foreign_session_records_are_rejected() {
    let (mut s, mut r) = ready();
    let (_, mut other) = ready();
    s.provide_backup(b"fictional", 0).unwrap();
    let frame = s.take_output(0).unwrap().unwrap();
    assert!(other.receive(&frame, 0).is_err());
    let mut reflected = frame.clone(); reflected[5] = 2;
    assert!(r.receive(&reflected, 0).is_err());
}
#[test]
fn eof_and_dropped_receipt_never_report_sender_success() {
    let (mut s, mut r) = ready();
    s.provide_backup(b"fictional", 0).unwrap(); pump(&mut s, &mut r, 100);
    r.validated(true, 0).unwrap();
    assert_eq!(s.state(), State::WaitReceipt);
    assert_eq!(s.disconnected(), Err(Error::Peer)); assert_eq!(s.state(), State::Failed);
}
#[test]
fn strict_parser_rejection_has_no_receipt() {
    let (mut s, mut r) = ready();
    s.provide_backup(b"not JSON", 0).unwrap(); pump(&mut s, &mut r, 4);
    assert_eq!(r.validated(false, 0), Err(Error::Malformed));
    assert!(r.received_backup().is_none()); assert_eq!(s.state(), State::WaitReceipt);
}
#[test]
fn commitment_tampering_is_detected_before_codes_or_payload() {
    let mut s = Session::new(Role::Sender, 0, 120_000).unwrap();
    let mut r = Session::new(Role::Receiver, 0, 120_000).unwrap();
    pump(&mut r, &mut s, 100);
    r.receive(&s.take_output(0).unwrap().unwrap(), 0).unwrap();
    let mut commitment = s.take_output(0).unwrap().unwrap(); commitment[5] ^= 1;
    r.receive(&commitment, 0).unwrap(); pump(&mut r, &mut s, 100);
    assert_eq!(r.receive(&s.take_output(0).unwrap().unwrap(), 0), Err(Error::Authentication));
    assert!(r.sas().is_none()); assert!(r.received_backup().is_none());
}
#[test]
fn acceptance_mac_cannot_be_reflected_or_replayed() {
    let (mut s, mut r) = pair();
    s.accept(0).unwrap();
    let mac = s.take_output(0).unwrap().unwrap();
    assert_eq!(s.receive(&mac, 0), Err(Error::Authentication));
    let (mut s2, _) = pair();
    assert_eq!(s2.receive(&mac, 0), Err(Error::Authentication));
    // Legitimate peer MAC can arrive before local user acceptance.
    r.receive(&mac, 0).unwrap();
    assert_eq!(r.state(), State::Confirm);
}
#[test]
fn session_nonce_changes_codes_and_transcript() {
    let (a, _) = pair(); let (b, _) = pair();
    assert_ne!(a.sas(), b.sas());
}
#[test]
fn cancel_and_timeouts_clear_sensitive_results_and_never_restart() {
    let (mut s, mut r) = ready();
    s.provide_backup(b"fictional", 0).unwrap(); pump(&mut s, &mut r, 100);
    r.cancel();
    assert!(r.received_backup().is_none());
    assert_eq!(r.tick(1), Err(Error::Canceled));
    assert_eq!(s.tick(10_000), Err(Error::Timeout));
    assert_eq!(s.state(), State::Failed);
}
#[test]
fn comparison_is_bounded_but_does_not_require_network_chatter() {
    let (mut s, _) = pair();
    assert!(s.tick(59_999).is_ok());
    assert_eq!(s.tick(60_000), Err(Error::Timeout)); assert!(s.sas().is_none());
}
#[test]
fn absolute_opening_deadline_is_not_extended_by_slow_drip() {
    let mut s = Session::new(Role::Sender, 0, 12).unwrap();
    let mut r = Session::new(Role::Receiver, 0, 120_000).unwrap();
    let hello = r.take_output(0).unwrap().unwrap();
    for t in 1..12 { s.receive(&hello[t as usize - 1..t as usize], t).unwrap(); }
    assert_eq!(s.tick(12), Err(Error::Timeout));
}
#[test]
fn malformed_untrusted_error_never_becomes_success() {
    let mut s = Session::new(Role::Sender, 0, 120_000).unwrap();
    assert!(s.receive(b"ERR PIN\n", 0).is_err()); assert_eq!(s.state(), State::Failed);
}
#[test]
fn coalesced_hello_and_commitment_preserve_order() {
    let mut s = Session::new(Role::Sender, 0, 120_000).unwrap();
    let mut r = Session::new(Role::Receiver, 0, 120_000).unwrap();
    pump(&mut r, &mut s, 100);
    let mut combined = s.take_output(0).unwrap().unwrap();
    combined.extend_from_slice(&s.take_output(0).unwrap().unwrap());
    r.receive(&combined, 0).unwrap();
    assert_eq!(r.state(), State::WaitSKey);
}

#[test]
fn oversized_prefix_is_rejected_without_waiting_for_body() {
    let mut s = Session::new(Role::Sender, 0, 120_000).unwrap();
    assert_eq!(s.receive(&u32::MAX.to_be_bytes(), 0), Err(Error::Size));
    assert_eq!(s.state(), State::Failed);
}

#[test]
fn oversized_backup_is_rejected_before_any_body_record() {
    let (mut s, _) = ready();
    assert_eq!(s.provide_backup(&vec![0; flash_lan::MAX_BACKUP + 1], 0), Err(Error::Size));
    assert_eq!(s.state(), State::Failed);
}

#[test]
fn invalid_utf8_is_rejected_without_lossy_platform_decoding() {
    let (mut s, _) = ready();
    assert_eq!(s.provide_backup(&[0xff, 0xfe], 0), Err(Error::Malformed));
    assert_eq!(s.state(), State::Failed);
}
