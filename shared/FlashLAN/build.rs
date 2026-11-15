use std::{env, path::Path};
fn main() {
    println!("cargo:rerun-if-env-changed=FLASH_SODIUM_LIB_DIR");
    let dir = env::var("FLASH_SODIUM_LIB_DIR").expect("set FLASH_SODIUM_LIB_DIR for libsodium 1.0.22");
    assert!(Path::new(&dir).join("libsodium.a").is_file());
    println!("cargo:rustc-link-search=native={dir}");
    println!("cargo:rustc-link-lib=static=sodium");
}
