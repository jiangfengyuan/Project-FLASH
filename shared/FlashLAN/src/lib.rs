// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
//! Isolated FLASH-LAN/2 candidate. Application enablement requires separate gates.
mod crypto;
mod wire;
mod session;
mod ffi;
pub use session::{Session, State};

pub const MAX_BACKUP: usize = 50 * 1024 * 1024;
pub const MAX_RECORD: usize = 64 * 1024;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Role { Sender = 1, Receiver = 2 }
impl Role {
    fn peer(self) -> Self { match self { Self::Sender => Self::Receiver, Self::Receiver => Self::Sender } }
    fn label(self) -> &'static str { match self { Self::Sender => "S", Self::Receiver => "R" } }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(i32)]
pub enum Error {
    State = 1, Malformed = 2, Incompatible = 3, Authentication = 4,
    Size = 5, Timeout = 6, Canceled = 7, Crypto = 8, Peer = 9,
}
pub type Result<T> = std::result::Result<T, Error>;
