//! Isolated build/ABI probe. NOT a pairing protocol or a production LAN adapter.
//! No sockets, discovery, file access, backup data, persistent keys or UI hooks.
use std::{ffi::{c_char, c_int, c_void, CStr}, panic::catch_unwind};
use vodozemac::sas::Sas;

unsafe extern "C" {
    fn sodium_init() -> c_int;
    fn sodium_version_string() -> *const c_char;
    fn randombytes_buf(buf: *mut c_void, len: usize);
    fn sodium_memzero(buf: *mut c_void, len: usize);
    fn crypto_aead_xchacha20poly1305_ietf_encrypt(
        c: *mut u8, clen: *mut u64, m: *const u8, mlen: u64,
        ad: *const u8, adlen: u64, nsec: *const u8, nonce: *const u8, key: *const u8,
    ) -> c_int;
    fn crypto_aead_xchacha20poly1305_ietf_decrypt(
        m: *mut u8, mlen: *mut u64, nsec: *mut u8, c: *const u8, clen: u64,
        ad: *const u8, adlen: u64, nonce: *const u8, key: *const u8,
    ) -> c_int;
}

struct Key([u8; 32]);
impl Drop for Key {
    fn drop(&mut self) {
        // SAFETY: the allocation remains live and writable for all 32 bytes.
        unsafe { sodium_memzero(self.0.as_mut_ptr().cast(), self.0.len()) };
    }
}

fn probe() -> Result<(), i32> {
    // SAFETY: libsodium exposes a process-lifetime NUL-terminated version string.
    unsafe {
        if sodium_init() < 0 { return Err(1); }
        if CStr::from_ptr(sodium_version_string()).to_bytes() != b"1.0.22" {
            return Err(2);
        }
    }
    // This is the upstream primitive API smoke test, deliberately NOT an
    // authenticated key exchange. No Flash transcript or protocol is defined here.
    let alice = Sas::new();
    let bob = Sas::new();
    let ap = alice.public_key();
    let bp = bob.public_key();
    let alice = alice.diffie_hellman(bp).map_err(|_| 3)?;
    let bob = bob.diffie_hellman(ap).map_err(|_| 3)?;
    const INFO: &str = "FLASH-LAN-BUILD-PROBE/1 (not a wire protocol)";
    if alice.bytes(INFO).decimals() != bob.bytes(INFO).decimals() { return Err(4); }
    let mac = alice.calculate_mac("synthetic build probe", INFO);
    bob.verify_mac("synthetic build probe", INFO, &mac).map_err(|_| 5)?;
    if bob.verify_mac("changed probe", INFO, &mac).is_ok() { return Err(6); }

    let mut key = Key([0; 32]);
    let mut nonce = [0; 24];
    let message = b"fictional probe: contains no backup";
    let aad = b"probe aad";
    let mut ciphertext = vec![0; message.len() + 16];
    let mut plain = vec![0; message.len()];
    let mut len = 0;
    // SAFETY: all buffers have the documented lengths, no overlap, key=32,
    // nonce=24, ciphertext=message+16. Null nsec is required by libsodium.
    unsafe {
        randombytes_buf(key.0.as_mut_ptr().cast(), key.0.len());
        randombytes_buf(nonce.as_mut_ptr().cast(), nonce.len());
        if crypto_aead_xchacha20poly1305_ietf_encrypt(
            ciphertext.as_mut_ptr(), &mut len, message.as_ptr(), message.len() as u64,
            aad.as_ptr(), aad.len() as u64, std::ptr::null(), nonce.as_ptr(), key.0.as_ptr(),
        ) != 0 || len != ciphertext.len() as u64 { return Err(7); }
        if crypto_aead_xchacha20poly1305_ietf_decrypt(
            plain.as_mut_ptr(), &mut len, std::ptr::null_mut(), ciphertext.as_ptr(),
            ciphertext.len() as u64, aad.as_ptr(), aad.len() as u64, nonce.as_ptr(), key.0.as_ptr(),
        ) != 0 || len != message.len() as u64 || plain != message { return Err(8); }
        ciphertext[0] ^= 1;
        if crypto_aead_xchacha20poly1305_ietf_decrypt(
            plain.as_mut_ptr(), &mut len, std::ptr::null_mut(), ciphertext.as_ptr(),
            ciphertext.len() as u64, aad.as_ptr(), aad.len() as u64, nonce.as_ptr(), key.0.as_ptr(),
        ) == 0 { return Err(9); }
        sodium_memzero(key.0.as_mut_ptr().cast(), key.0.len());
    }
    if key.0 != [0; 32] { return Err(10); }
    Ok(())
}

/// ABI 1; returns 0 on success, 1..10 for a failed probe, 100 for a caught panic.
/// The probe never returns keys, SAS values, exception text or user data.
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_probe_run() -> i32 {
    match catch_unwind(probe) {
        Ok(Ok(())) => 0,
        Ok(Err(code)) => code,
        Err(_) => 100,
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn upstream_primitives_and_c_abi() {
        assert_eq!(super::flash_lan_probe_run(), 0);
    }

    #[test]
    fn sas_rejects_noncontributory_and_malformed_public_keys() {
        use vodozemac::{sas::Sas, Curve25519PublicKey};
        assert!(Sas::new().diffie_hellman(Curve25519PublicKey::from_bytes([0; 32])).is_err());
        assert!(Sas::new().diffie_hellman_with_raw("not a public key").is_err());
    }

    #[test]
    fn sas_info_and_mac_contexts_are_distinct() {
        use vodozemac::sas::Sas;
        let a = Sas::new();
        let b = Sas::new();
        let ap = a.public_key();
        let bp = b.public_key();
        let a = a.diffie_hellman(bp).unwrap();
        let b = b.diffie_hellman(ap).unwrap();
        let tag = a.calculate_mac("synthetic acceptance", "probe sender");
        assert!(b.verify_mac("synthetic acceptance", "probe receiver", &tag).is_err());
        assert!(b.verify_mac("synthetic acceptance", "probe sender", &tag).is_ok());
        assert_ne!(a.bytes("probe session 1"), b.bytes("probe session 2"));
    }

    #[test]
    fn ffi_probe_is_reentrant() {
        let threads: Vec<_> = (0..4).map(|_| std::thread::spawn(|| super::flash_lan_probe_run())).collect();
        for thread in threads {
            assert_eq!(thread.join().unwrap(), 0);
        }
    }
}
