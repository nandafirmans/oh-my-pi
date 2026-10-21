use std::env;

fn main() {
	if env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("android") {
		// Native Termux supplies libopus built against Bionic. Desktop
		// builds retain opus/opusic-sys and its bundled codec.
		println!("cargo:rustc-link-lib=dylib=opus");
	}
}
