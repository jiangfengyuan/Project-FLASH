// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
use crate::{Error, Result, Role, Session, MAX_BACKUP};
use std::{collections::HashMap, panic::{catch_unwind, AssertUnwindSafe}, sync::{Mutex, OnceLock, atomic::{AtomicU64, Ordering}}};

struct Handle { session: Session, pending: Option<Vec<u8>> }
static HANDLES: OnceLock<Mutex<HashMap<u64, Handle>>> = OnceLock::new();
static NEXT: AtomicU64 = AtomicU64::new(1);
fn handles() -> &'static Mutex<HashMap<u64, Handle>> { HANDLES.get_or_init(|| Mutex::new(HashMap::new())) }
fn call(id: u64, action: impl FnOnce(&mut Handle) -> Result<i64>) -> i64 {
    match catch_unwind(AssertUnwindSafe(|| {
        let mut map = handles().lock().unwrap_or_else(|e| e.into_inner());
        let h = map.get_mut(&id).ok_or(Error::State)?;
        let result = action(h);
        if h.session.state() == crate::State::Failed { h.pending = None; }
        result
    })) {
        Ok(Ok(value)) => value,
        Ok(Err(error)) => -(error as i64),
        Err(_) => {
            handles().lock().unwrap_or_else(|e| e.into_inner()).remove(&id);
            -100
        }
    }
}
unsafe fn bytes<'a>(ptr: *const u8, len: usize) -> Result<&'a [u8]> {
    if len > MAX_BACKUP || (len > 0 && ptr.is_null()) { return Err(Error::Size); }
    if len == 0 { return Ok(&[]); }
    // SAFETY: valid caller-owned readable memory is the C ABI's precondition.
    Ok(unsafe { std::slice::from_raw_parts(ptr, len) })
}

#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_new(role: u8, now_ms: u64, remaining_ms: u64) -> u64 {
    catch_unwind(AssertUnwindSafe(|| {
        let role = match role { 1 => Role::Sender, 2 => Role::Receiver, _ => return 0 };
        let Ok(session) = Session::new(role, now_ms, remaining_ms) else { return 0 };
        let Ok(id) = NEXT.try_update(Ordering::Relaxed, Ordering::Relaxed, |v| v.checked_add(1)) else { return 0 };
        handles().lock().unwrap_or_else(|e| e.into_inner()).insert(id, Handle { session, pending: None });
        id
    })).unwrap_or(0)
}
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_free(id: u64) {
    let _ = catch_unwind(|| { handles().lock().unwrap_or_else(|e| e.into_inner()).remove(&id); });
}
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_state(id: u64) -> i64 { call(id, |h| Ok(h.session.state() as i64)) }
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_error(id: u64) -> i64 { call(id, |h| Ok(h.session.error().map_or(0, |e| e as i64))) }
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_tick(id: u64, now: u64) -> i64 { call(id, |h| h.session.tick(now).map(|_| 0)) }
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_wrote(id: u64, now: u64) -> i64 { call(id, |h| h.session.wrote(now).map(|_| 0)) }
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_accept(id: u64, now: u64) -> i64 { call(id, |h| h.session.accept(now).map(|_| 0)) }
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_cancel(id: u64) -> i64 { call(id, |h| { h.session.cancel(); h.pending = None; Ok(0) }) }
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_disconnected(id: u64) -> i64 { call(id, |h| h.session.disconnected().map(|_| 0)) }

#[unsafe(no_mangle)]
pub unsafe extern "C" fn flash_lan_receive(id: u64, ptr: *const u8, len: usize, now: u64) -> i64 {
    call(id, |h| h.session.receive(unsafe { bytes(ptr, len)? }, now).map(|_| 0))
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn flash_lan_provide(id: u64, ptr: *const u8, len: usize, now: u64) -> i64 {
    call(id, |h| h.session.provide_backup(unsafe { bytes(ptr, len)? }, now).map(|_| 0))
}
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_output_len(id: u64, now: u64) -> i64 {
    call(id, |h| {
        h.session.tick(now)?;
        if h.pending.is_none() { h.pending = h.session.take_output(now)?; }
        Ok(h.pending.as_ref().map_or(0, |b| b.len() as i64))
    })
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn flash_lan_copy_output(id: u64, out: *mut u8, capacity: usize) -> i64 {
    call(id, |h| {
        let Some(packet) = h.pending.as_ref() else { return Ok(0) };
        if out.is_null() || capacity < packet.len() { return Err(Error::Size); }
        let len = packet.len();
        // SAFETY: caller guarantees a writable buffer of at least capacity bytes.
        unsafe { std::ptr::copy_nonoverlapping(packet.as_ptr(), out, len) };
        h.pending = None;
        Ok(len as i64)
    })
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn flash_lan_sas(id: u64, out_three: *mut u16) -> i64 {
    call(id, |h| {
        let sas = h.session.sas().ok_or(Error::State)?;
        if out_three.is_null() { return Err(Error::Size); }
        // SAFETY: caller guarantees three writable, aligned u16 elements.
        unsafe { std::ptr::copy_nonoverlapping(sas.as_ptr(), out_three, 3) };
        Ok(0)
    })
}
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_received_len(id: u64) -> i64 {
    call(id, |h| h.session.received_backup().map(|b| b.len() as i64).ok_or(Error::State))
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn flash_lan_copy_received(id: u64, out: *mut u8, capacity: usize) -> i64 {
    call(id, |h| {
        let bytes = h.session.received_backup().ok_or(Error::State)?;
        if out.is_null() || capacity < bytes.len() { return Err(Error::Size); }
        unsafe { std::ptr::copy_nonoverlapping(bytes.as_ptr(), out, bytes.len()) };
        Ok(bytes.len() as i64)
    })
}
#[unsafe(no_mangle)]
pub extern "C" fn flash_lan_validated(id: u64, valid: u8, now: u64) -> i64 {
    call(id, |h| {
        if valid > 1 { return Err(Error::Malformed); }
        h.session.validated(valid == 1, now).map(|_| 0)
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn stale_and_invalid_handles_do_not_affect_new_sessions() {
        let old = flash_lan_new(1, 0, 120_000);
        assert!(old > 0); flash_lan_free(old);
        let new = flash_lan_new(1, 0, 120_000);
        assert_ne!(old, new);
        assert!(flash_lan_cancel(old) < 0);
        assert_eq!(flash_lan_state(new), crate::State::WaitRHello as i64);
        flash_lan_free(new); flash_lan_free(new);
    }
    #[test]
    fn output_size_query_never_consumes_or_regenerates_a_frame() {
        let id = flash_lan_new(2, 0, 120_000);
        let length = flash_lan_output_len(id, 0);
        assert_eq!(length, 64); assert_eq!(flash_lan_output_len(id, 0), length);
        let mut frame = vec![0; length as usize];
        assert_eq!(unsafe { flash_lan_copy_output(id, frame.as_mut_ptr(), frame.len()) }, length);
        assert_eq!(flash_lan_output_len(id, 0), 0);
        flash_lan_free(id);
    }
    #[test]
    fn a_small_caller_buffer_does_not_drop_a_pending_record() {
        let id = flash_lan_new(2, 0, 120_000);
        assert_eq!(flash_lan_output_len(id, 0), 64);
        let mut small = [0; 8];
        assert_eq!(unsafe { flash_lan_copy_output(id, small.as_mut_ptr(), small.len()) }, -(Error::Size as i64));
        assert_eq!(flash_lan_output_len(id, 0), 64);
        let mut full = [0; 64];
        assert_eq!(unsafe { flash_lan_copy_output(id, full.as_mut_ptr(), full.len()) }, 64);
        flash_lan_free(id);
    }
}
