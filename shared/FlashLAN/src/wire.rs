// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
use crate::{crypto, Error, Result, Role, MAX_BACKUP, MAX_RECORD};

pub const MAX_BODY: usize = 14 + MAX_RECORD + 16;
pub fn frame(body: &[u8]) -> Vec<u8> {
    let mut output = Vec::with_capacity(body.len() + 4);
    output.extend_from_slice(&(body.len() as u32).to_be_bytes());
    output.extend_from_slice(body);
    output
}
pub fn message(kind: u8, bytes: &[u8]) -> Vec<u8> {
    let mut body = vec![kind];
    body.extend_from_slice(bytes);
    frame(&body)
}
pub fn hello(role: Role) -> Vec<u8> {
    let mut body = vec![if role == Role::Sender { 2 } else { 1 }];
    body.extend_from_slice(b"FLASH-LAN/2");
    body.extend_from_slice(&2u16.to_be_bytes());
    body.extend_from_slice(&1u16.to_be_bytes());
    body.push(role as u8);
    body.extend_from_slice(&crypto::random_nonce());
    body.extend_from_slice(&(MAX_BACKUP as u64).to_be_bytes());
    body.extend_from_slice(&[3, 3, 3]);
    frame(&body)
}
pub fn read_hello(frame: &[u8], role: Role) -> Result<usize> {
    if frame.len() != 64 || frame[4] != if role == Role::Sender { 2 } else { 1 } {
        return Err(Error::Malformed);
    }
    let body = &frame[5..];
    if &body[..11] != b"FLASH-LAN/2" || &body[11..15] != [0, 2, 0, 1] || body[15] != role as u8 || body[56..59] != [3, 3, 3] {
        return Err(Error::Incompatible);
    }
    let size = u64::from_be_bytes(body[48..56].try_into().map_err(|_| Error::Malformed)?);
    if size == 0 || size > MAX_BACKUP as u64 { return Err(Error::Size); }
    Ok(size as usize)
}
pub fn commitment(r: &[u8], s: &[u8], key: &[u8]) -> [u8; 32] {
    let mut bytes = b"FLASH-LAN/2 commitment\0".to_vec();
    bytes.extend_from_slice(r); bytes.extend_from_slice(s); bytes.extend_from_slice(key);
    crypto::hash(&bytes)
}
pub fn transcript(r: &[u8], s: &[u8], commit: &[u8], rk: &[u8], sk: &[u8]) -> [u8; 32] {
    let mut bytes = b"FLASH-LAN/2 transcript\0".to_vec();
    for frame in [r, s, commit, rk, sk] { bytes.extend_from_slice(frame); }
    crypto::hash(&bytes)
}
pub fn nonce(prefix: &[u8], sequence: u64) -> Result<[u8; 24]> {
    if prefix.len() != 16 { return Err(Error::Crypto); }
    let mut nonce = [0; 24];
    nonce[..16].copy_from_slice(prefix);
    nonce[16..].copy_from_slice(&sequence.to_be_bytes());
    Ok(nonce)
}
