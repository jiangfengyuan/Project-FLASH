// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
use crate::{Error, Result};
use sha2::{Digest, Sha256};
use std::ffi::{c_int, c_char, c_void, CStr};
use zeroize::Zeroizing;

unsafe extern "C" {
    fn sodium_init() -> c_int;
    fn sodium_version_string() -> *const c_char;
    fn randombytes_buf(buf: *mut c_void, len: usize);
    fn sodium_memcmp(a: *const c_void, b: *const c_void, len: usize) -> c_int;
    fn crypto_aead_xchacha20poly1305_ietf_encrypt(
        c: *mut u8, clen: *mut u64, m: *const u8, mlen: u64,
        ad: *const u8, adlen: u64, nsec: *const u8, nonce: *const u8, key: *const u8,
    ) -> c_int;
    fn crypto_aead_xchacha20poly1305_ietf_decrypt(
        m: *mut u8, mlen: *mut u64, nsec: *mut u8, c: *const u8, clen: u64,
        ad: *const u8, adlen: u64, nonce: *const u8, key: *const u8,
    ) -> c_int;
}

pub fn initialize() -> Result<()> {
    // SAFETY: libsodium's init is thread-safe; version is a static C string.
    unsafe {
        if sodium_init() < 0 || CStr::from_ptr(sodium_version_string()).to_bytes() != b"1.0.22" {
            return Err(Error::Crypto);
        }
    }
    Ok(())
}
pub fn random_nonce() -> [u8; 32] {
    let mut nonce = [0; 32];
    // SAFETY: nonce is a live writable buffer of the specified length.
    unsafe { randombytes_buf(nonce.as_mut_ptr().cast(), nonce.len()) };
    nonce
}
pub fn hash(bytes: &[u8]) -> [u8; 32] { Sha256::digest(bytes).into() }
pub fn hex(bytes: &[u8]) -> String { bytes.iter().map(|b| format!("{b:02x}")).collect() }
pub fn equal(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && unsafe { sodium_memcmp(a.as_ptr().cast(), b.as_ptr().cast(), a.len()) == 0 }
}

pub fn seal(key: &[u8], nonce: &[u8; 24], aad: &[u8], plaintext: &[u8]) -> Result<Vec<u8>> {
    if key.len() != 32 || plaintext.len() > crate::MAX_RECORD { return Err(Error::Size); }
    let mut output = vec![0; plaintext.len() + 16];
    let mut length = 0;
    // SAFETY: sizes checked; disjoint buffers; combined ciphertext has room for tag.
    let code = unsafe { crypto_aead_xchacha20poly1305_ietf_encrypt(
        output.as_mut_ptr(), &mut length, plaintext.as_ptr(), plaintext.len() as u64,
        aad.as_ptr(), aad.len() as u64, std::ptr::null(), nonce.as_ptr(), key.as_ptr(),
    ) };
    if code != 0 || length != output.len() as u64 { return Err(Error::Crypto); }
    Ok(output)
}
pub fn open(key: &[u8], nonce: &[u8; 24], aad: &[u8], ciphertext: &[u8]) -> Result<Zeroizing<Vec<u8>>> {
    if key.len() != 32 || !(16..=crate::MAX_RECORD + 16).contains(&ciphertext.len()) {
        return Err(Error::Size);
    }
    let mut output = Zeroizing::new(vec![0; ciphertext.len() - 16]);
    let mut length = 0;
    // SAFETY: sizes checked, disjoint buffers; null nsec is required by this AEAD.
    let code = unsafe { crypto_aead_xchacha20poly1305_ietf_decrypt(
        output.as_mut_ptr(), &mut length, std::ptr::null_mut(), ciphertext.as_ptr(),
        ciphertext.len() as u64, aad.as_ptr(), aad.len() as u64, nonce.as_ptr(), key.as_ptr(),
    ) };
    if code != 0 || length != output.len() as u64 { return Err(Error::Authentication); }
    Ok(output)
}
