// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
use crate::{crypto, wire, Error, Result, Role, MAX_BACKUP, MAX_RECORD};
use std::collections::VecDeque;
use vodozemac::{sas::{EstablishedSas, Mac, Sas}, Curve25519PublicKey};
use zeroize::{Zeroize, Zeroizing};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(i32)]
pub enum State {
    WaitRHello = 1, WaitSHello, WaitCommitment, WaitRKey, WaitSKey,
    Confirm, WaitPeer, ReadyToSend, Sending, Receiving, Validate,
    WaitReceipt, Done, Failed,
}
struct Keys {
    tx: Zeroizing<Vec<u8>>, rx: Zeroizing<Vec<u8>>,
    tx_nonce: Zeroizing<Vec<u8>>, rx_nonce: Zeroizing<Vec<u8>>,
}

/// One connection only. No network, database, discovery or automatic retry.
/// Caller must serialize events and await each complete socket write.
/// Never derive Debug for this secret-bearing object.
pub struct Session {
    role: Role, state: State, error: Option<Error>,
    now: u64, opening_end: u64, transfer_end: Option<u64>,
    compare_end: Option<u64>, last_io: u64,
    input: Vec<u8>, output: VecDeque<Vec<u8>>,
    rhello: Vec<u8>, shello: Vec<u8>, commitment: Vec<u8>,
    ephemeral: Option<Sas>, established: Option<EstablishedSas>,
    transcript: [u8; 32], sas: [u16; 3], local_accept: bool, peer_accept: bool,
    keys: Option<Keys>, tx_sequence: u64, rx_sequence: u64,
    cap: usize, payload: Zeroizing<Vec<u8>>, sent: usize, total: usize,
    digest: [u8; 32],
}

impl Session {
    pub fn new(role: Role, now_ms: u64, opening_remaining_ms: u64) -> Result<Self> {
        crypto::initialize()?;
        if opening_remaining_ms == 0 || opening_remaining_ms > 120_000 { return Err(Error::Timeout); }
        let hello = wire::hello(role);
        let mut output = VecDeque::new();
        if role == Role::Receiver { output.push_back(hello.clone()); }
        Ok(Self {
            role, state: if role == Role::Sender { State::WaitRHello } else { State::WaitSHello },
            error: None, now: now_ms, opening_end: now_ms.checked_add(opening_remaining_ms).ok_or(Error::Timeout)?,
            transfer_end: None, compare_end: None, last_io: now_ms,
            input: Vec::new(), output,
            rhello: if role == Role::Receiver { hello.clone() } else { Vec::new() },
            shello: if role == Role::Sender { hello } else { Vec::new() },
            commitment: Vec::new(), ephemeral: None, established: None,
            transcript: [0; 32], sas: [0; 3], local_accept: false, peer_accept: false,
            keys: None, tx_sequence: 0, rx_sequence: 0,
            cap: MAX_BACKUP, payload: Zeroizing::new(Vec::new()), sent: 0, total: 0, digest: [0; 32],
        })
    }
    pub fn state(&self) -> State { self.state }
    pub fn error(&self) -> Option<Error> { self.error }
    pub fn sas(&self) -> Option<[u16; 3]> {
        if matches!(self.state, State::Confirm | State::WaitPeer) { Some(self.sas) } else { None }
    }
    fn clear_secrets(&mut self) {
        self.ephemeral = None; self.established = None; self.keys = None;
        self.sas.zeroize(); self.payload.zeroize();
    }
    fn fail<T>(&mut self, error: Error) -> Result<T> {
        self.state = State::Failed; self.error = Some(error);
        self.clear_secrets(); self.input.clear(); self.output.clear();
        Err(error)
    }
    pub fn cancel(&mut self) { let _: Result<()> = self.fail(Error::Canceled); }
    pub fn disconnected(&mut self) -> Result<()> {
        if self.state == State::Done { Ok(()) } else { self.fail(Error::Peer) }
    }
    pub fn tick(&mut self, now_ms: u64) -> Result<()> {
        if self.state == State::Failed { return Err(self.error.unwrap_or(Error::State)); }
        if now_ms < self.now { return self.fail(Error::Timeout); }
        self.now = now_ms;
        if self.state == State::Done { return Ok(()); }
        let deadline = self.transfer_end.unwrap_or(self.opening_end);
        if now_ms >= deadline || now_ms.saturating_sub(self.last_io) >= 10_000 ||
            self.compare_end.is_some_and(|limit| now_ms >= limit) {
            // Human comparison deliberately permits network silence up to 60s.
            if matches!(self.state, State::Confirm | State::WaitPeer) &&
                now_ms < deadline && self.compare_end.is_some_and(|limit| now_ms < limit) {
                return Ok(());
            }
            return self.fail(Error::Timeout);
        }
        Ok(())
    }
    /// Called after an adapter's successful complete write, never on a queued write.
    pub fn wrote(&mut self, now_ms: u64) -> Result<()> {
        self.tick(now_ms)?; self.last_io = now_ms; Ok(())
    }
    /// Incremental bounded parser: never buffers an entire untrusted input chunk.
    pub fn receive(&mut self, mut bytes: &[u8], now_ms: u64) -> Result<()> {
        self.tick(now_ms)?;
        if self.state == State::Done { return self.fail(Error::State); }
        if !bytes.is_empty() { self.last_io = now_ms; }
        while !bytes.is_empty() {
            let needed = if self.input.len() < 4 { 4 } else {
                let len = u32::from_be_bytes(self.input[..4].try_into().map_err(|_| Error::Malformed)?) as usize;
                let max = if self.keys.is_some() { wire::MAX_BODY } else { 60 };
                if len == 0 || len > max { return self.fail(Error::Size); }
                len + 4
            };
            let count = (needed - self.input.len()).min(bytes.len());
            self.input.extend_from_slice(&bytes[..count]); bytes = &bytes[count..];
            if self.input.len() == 4 {
                let length = u32::from_be_bytes(self.input[..4].try_into().map_err(|_| Error::Malformed)?) as usize;
                let cap = if self.keys.is_some() { wire::MAX_BODY } else { 60 };
                if length == 0 || length > cap { return self.fail(Error::Size); }
            }
            if self.input.len() == needed && needed > 4 {
                let packet = std::mem::take(&mut self.input);
                if let Err(error) = self.handle(&packet) { return self.fail(error); }
            }
        }
        Ok(())
    }
    fn handle(&mut self, packet: &[u8]) -> Result<()> {
        match self.state {
            State::WaitRHello => {
                self.cap = wire::read_hello(packet, Role::Receiver)?;
                self.rhello = packet.to_vec();
                let key = Sas::new();
                self.commitment = wire::message(3, &wire::commitment(&self.rhello, &self.shello, key.public_key().as_bytes()));
                self.ephemeral = Some(key);
                self.output.push_back(self.shello.clone()); self.output.push_back(self.commitment.clone());
                self.state = State::WaitRKey;
            }
            State::WaitSHello => {
                self.cap = wire::read_hello(packet, Role::Sender)?;
                self.shello = packet.to_vec(); self.state = State::WaitCommitment;
            }
            State::WaitCommitment => {
                if packet.len() != 37 || packet[4] != 3 { return Err(Error::Malformed); }
                self.commitment = packet.to_vec();
                let key = Sas::new();
                self.output.push_back(wire::message(4, key.public_key().as_bytes()));
                self.ephemeral = Some(key); self.state = State::WaitSKey;
            }
            State::WaitRKey | State::WaitSKey => {
                let expected = if self.role == Role::Sender { 4 } else { 5 };
                if packet.len() != 37 || packet[4] != expected { return Err(Error::Malformed); }
                let key = self.ephemeral.take().ok_or(Error::State)?;
                let own = wire::message(if self.role == Role::Sender { 5 } else { 4 }, key.public_key().as_bytes());
                let raw: [u8; 32] = packet[5..].try_into().map_err(|_| Error::Malformed)?;
                if self.role == Role::Receiver && !crypto::equal(&self.commitment[5..], &wire::commitment(&self.rhello, &self.shello, &raw)) {
                    return Err(Error::Authentication);
                }
                let established = key.diffie_hellman(Curve25519PublicKey::from_bytes(raw)).map_err(|_| Error::Authentication)?;
                let (rkey, skey) = if self.role == Role::Sender { (packet, own.as_slice()) } else { (own.as_slice(), packet) };
                self.transcript = wire::transcript(&self.rhello, &self.shello, &self.commitment, rkey, skey);
                let numbers = established.bytes(&format!("FLASH-LAN/2 sas:{}", crypto::hex(&self.transcript))).decimals();
                self.sas = [numbers.0, numbers.1, numbers.2];
                self.established = Some(established);
                if self.role == Role::Sender { self.output.push_back(own); }
                self.state = State::Confirm;
                self.compare_end = Some(self.now.checked_add(60_000).ok_or(Error::Timeout)?);
            }
            State::Confirm | State::WaitPeer => {
                if packet.len() != 37 || packet[4] != 6 || self.peer_accept { return Err(Error::Malformed); }
                let role = self.role.peer().label(); let t = crypto::hex(&self.transcript);
                self.established.as_ref().ok_or(Error::State)?.verify_mac(
                    &format!("accept:{role}:{t}"), &format!("FLASH-LAN/2 confirm:{role}:{t}"),
                    &Mac::from_slice(&packet[5..]),
                ).map_err(|_| Error::Authentication)?;
                self.peer_accept = true; self.ready()?;
            }
            State::Receiving | State::Validate | State::WaitReceipt => self.record(packet)?,
            _ => return Err(Error::State),
        }
        Ok(())
    }
    pub fn accept(&mut self, now_ms: u64) -> Result<()> {
        self.tick(now_ms)?;
        if self.state != State::Confirm || self.local_accept { return Err(Error::State); }
        let t = crypto::hex(&self.transcript); let role = self.role.label();
        let mac = self.established.as_ref().ok_or(Error::State)?.calculate_mac(
            &format!("accept:{role}:{t}"), &format!("FLASH-LAN/2 confirm:{role}:{t}"),
        );
        self.output.push_back(wire::message(6, mac.as_bytes()));
        self.local_accept = true; self.state = State::WaitPeer;
        if let Err(error) = self.ready() { return self.fail(error); }
        Ok(())
    }
    fn ready(&mut self) -> Result<()> {
        if !self.local_accept || !self.peer_accept { return Ok(()); }
        let sas = self.established.as_ref().ok_or(Error::State)?;
        let t = crypto::hex(&self.transcript);
        let (tx, rx) = if self.role == Role::Sender { ("S>R", "R>S") } else { ("R>S", "S>R") };
        let derive = |purpose: &str, direction: &str, count| -> Result<Zeroizing<Vec<u8>>> {
            Ok(Zeroizing::new(sas.bytes_raw(&format!("FLASH-LAN/2 {purpose}:{direction}:{t}"), count).map_err(|_| Error::Crypto)?))
        };
        self.keys = Some(Keys { tx: derive("key", tx, 32)?, rx: derive("key", rx, 32)?,
            tx_nonce: derive("nonce", tx, 16)?, rx_nonce: derive("nonce", rx, 16)? });
        self.established = None; self.sas.zeroize(); self.compare_end = None;
        self.transfer_end = Some(self.now.checked_add(120_000).ok_or(Error::Timeout)?);
        self.last_io = self.now;
        self.state = if self.role == Role::Sender { State::ReadyToSend } else { State::Receiving };
        Ok(())
    }
    /// Caller obtains/strictly serializes its snapshot only after ReadyToSend.
    pub fn provide_backup(&mut self, bytes: &[u8], now_ms: u64) -> Result<()> {
        self.tick(now_ms)?;
        if self.state != State::ReadyToSend { return Err(Error::State); }
        if bytes.is_empty() || bytes.len() > self.cap { return self.fail(Error::Size); }
        if std::str::from_utf8(bytes).is_err() { return self.fail(Error::Malformed); }
        self.digest = crypto::hash(bytes); self.total = bytes.len();
        self.payload.extend_from_slice(bytes); self.state = State::Sending;
        Ok(())
    }
    fn encrypt_record(&mut self, kind: u8, bytes: &[u8]) -> Result<Vec<u8>> {
        let keys = self.keys.as_ref().ok_or(Error::State)?;
        let next = self.tx_sequence.checked_add(1).ok_or(Error::Size)?;
        let mut header = vec![kind, self.role as u8];
        header.extend_from_slice(&self.tx_sequence.to_be_bytes());
        header.extend_from_slice(&((bytes.len() + 16) as u32).to_be_bytes());
        let mut prefix = ((header.len() + bytes.len() + 16) as u32).to_be_bytes().to_vec();
        prefix.extend_from_slice(&header);
        let mut aad = b"FLASH-LAN/2 record\0".to_vec();
        aad.extend_from_slice(&self.transcript); aad.extend_from_slice(&prefix);
        let nonce = wire::nonce(&keys.tx_nonce, self.tx_sequence)?;
        let ciphertext = crypto::seal(&keys.tx, &nonce, &aad, bytes)?;
        self.tx_sequence = next; // consumed at creation, never retried with new data
        prefix.extend_from_slice(&ciphertext);
        Ok(prefix)
    }
    /// Produces at most one record; adapter must drain it completely before calling again.
    pub fn take_output(&mut self, now_ms: u64) -> Result<Option<Vec<u8>>> {
        self.tick(now_ms)?;
        match self.next_output() {
            Ok(output) => Ok(output),
            Err(error) => self.fail(error),
        }
    }
    fn next_output(&mut self) -> Result<Option<Vec<u8>>> {
        if let Some(packet) = self.output.pop_front() { return Ok(Some(packet)); }
        if self.state != State::Sending { return Ok(None); }
        let packet = if self.sent < self.payload.len() {
            let end = (self.sent + MAX_RECORD).min(self.payload.len());
            let chunk = Zeroizing::new(self.payload[self.sent..end].to_vec());
            let packet = self.encrypt_record(0x20, &chunk)?;
            self.sent = end; packet
        } else {
            let mut finish = (self.total as u64).to_be_bytes().to_vec();
            finish.extend_from_slice(&self.digest);
            let packet = self.encrypt_record(0x21, &finish)?;
            self.payload.zeroize(); self.state = State::WaitReceipt; packet
        };
        Ok(Some(packet))
    }
    fn record(&mut self, packet: &[u8]) -> Result<()> {
        if packet.len() < 34 || packet[5] != self.role.peer() as u8 { return Err(Error::Malformed); }
        let sequence = u64::from_be_bytes(packet[6..14].try_into().map_err(|_| Error::Malformed)?);
        let length = u32::from_be_bytes(packet[14..18].try_into().map_err(|_| Error::Malformed)?) as usize;
        if sequence != self.rx_sequence || packet.len() != 18 + length { return Err(Error::Authentication); }
        let keys = self.keys.as_ref().ok_or(Error::State)?;
        let mut aad = b"FLASH-LAN/2 record\0".to_vec();
        aad.extend_from_slice(&self.transcript); aad.extend_from_slice(&packet[..18]);
        let plaintext = crypto::open(&keys.rx, &wire::nonce(&keys.rx_nonce, sequence)?, &aad, &packet[18..])?;
        let next = sequence.checked_add(1).ok_or(Error::Size)?;
        match (self.state, packet[4]) {
            (State::Receiving, 0x20) => {
                if plaintext.is_empty() || plaintext.len() > self.cap.saturating_sub(self.payload.len()) { return Err(Error::Size); }
                self.payload.extend_from_slice(&plaintext);
            }
            (State::Receiving, 0x21) => {
                if plaintext.len() != 40 || self.payload.is_empty() { return Err(Error::Malformed); }
                self.total = self.payload.len(); self.digest = crypto::hash(&self.payload);
                if plaintext[..8] != (self.total as u64).to_be_bytes() || !crypto::equal(&plaintext[8..], &self.digest) {
                    return Err(Error::Authentication);
                }
                if std::str::from_utf8(&self.payload).is_err() { return Err(Error::Malformed); }
                self.state = State::Validate;
            }
            (State::WaitReceipt, 0x22) => {
                if plaintext.len() != 40 || plaintext[..8] != (self.total as u64).to_be_bytes() || !crypto::equal(&plaintext[8..], &self.digest) {
                    return Err(Error::Authentication);
                }
                self.state = State::Done; self.clear_secrets();
            }
            (_, 0x23) if plaintext.len() == 2 && [1u16, 2, 3].contains(&u16::from_be_bytes(plaintext[..].try_into().map_err(|_| Error::Malformed)?)) => return Err(Error::Peer),
            _ => return Err(Error::State),
        }
        self.rx_sequence = next;
        Ok(())
    }
    /// Available only after authenticated finish, never an import/commit instruction.
    pub fn received_backup(&self) -> Option<&[u8]> {
        if self.role == Role::Receiver && matches!(self.state, State::Validate | State::Done) { Some(&self.payload) } else { None }
    }
    /// Called by the existing strict backup parser, not by the network peer.
    pub fn validated(&mut self, valid: bool, now_ms: u64) -> Result<()> {
        self.tick(now_ms)?;
        if self.state != State::Validate { return Err(Error::State); }
        if !valid { return self.fail(Error::Malformed); }
        let mut finish = (self.total as u64).to_be_bytes().to_vec(); finish.extend_from_slice(&self.digest);
        let receipt = match self.encrypt_record(0x22, &finish) {
            Ok(packet) => packet,
            Err(error) => return self.fail(error),
        };
        self.output.push_back(receipt); self.state = State::Done;
        self.established = None; self.keys = None; self.sas.zeroize();
        Ok(())
    }
}
impl Drop for Session { fn drop(&mut self) { self.clear_secrets(); } }
