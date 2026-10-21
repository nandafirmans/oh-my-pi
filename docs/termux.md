# Android / Termux source build

This branch ports Android/arm64 support to **official v18.12.5**, commit
`d5cd750e41fede277f9eb933455da92a0738915e` (release checked 2026-10-21).
It is a source port, not a verified Android release binary. Native Android Bun
and native Termux Rust/Clang must produce and load Bionic libraries; Linux/glibc
and Linux/musl addons are not substitutes.

## Build beside the working installation

Keep the existing `omp` installation and its source checkout. Clone this branch
into a **new directory** under Termux's private home, not shared `/sdcard` storage.
Do not run `omp update`, `bun install -g`, `bun link`, `bun run setup`,
`scripts/install.sh`, or `scripts/link-omp.sh` for this trial: those paths may
replace or relink a working installation.

The target already has native Android Bun and a temporary `LD_PRELOAD` helper
for blocked `openat2`/`fchmodat2`. This port does not install/replace Bun, modify
that helper, or persist changes to shell startup files. Leave the working
`LD_PRELOAD` value exported in the build and launch shell; subprocesses inherit
it. Interposition coverage depends on the existing helper and how each caller
issues syscalls; its presence does not prove Rust filesystem operations work.

Install any missing prerequisites using Termux packages:

```sh
pkg install git rust clang make cmake ninja pkg-config libopus
bun --version
bun -p 'process.platform + "-" + process.arch'
rustc -vV
cargo --version
pkg-config --modversion opus
```

Use Bun 1.4 or newer for this workspace. Bun must report `android-arm64` and
Rust's host must be `aarch64-linux-android`. Use Termux's native `rust` package;
do not install a glibc Rust toolchain. If using rustup, it must select a working
native Android toolchain, not automatically download the repository's desktop
nightly targets. The allocation-error hook is disabled only on Android so the
Termux compiler does not need `alloc_error_hook`; desktop builds retain it.
Other dependency minimum Rust versions still apply.

```sh
cd "$HOME"
git clone --branch android/termux-v18.12.5 --single-branch \
  https://github.com/nandafirmans/oh-my-pi.git omp-termux-v18.12.5-test
cd omp-termux-v18.12.5-test
sh scripts/termux-build.sh
```

The helper checks platform and build prerequisites before installing local
workspace dependencies. It runs the frozen Bun install without lifecycle hooks,
explicitly generates tool views, then uses the current local Cargo/N-API build.
It writes dependencies/generated files/build outputs in this checkout; it does
not register or change a global command. Cargo's ordinary shared download cache
is still used. The native build stamps the official package version and probes
loading the addon before reporting success.

Both `CARGO_BUILD_JOBS` and `CMAKE_BUILD_PARALLEL_LEVEL` default to `1` on Android;
explicit settings are respected. The default `local` Cargo profile avoids the
shipping profile's fat LTO. Start with one job on the phone. No Bazel/NDK cross
build is required or selected for an Android host.

## Run without sharing production state

```sh
sh scripts/termux-run.sh --version
sh scripts/termux-run.sh --help
sh scripts/termux-run.sh --smoke-test
sh scripts/termux-run.sh
```

This wrapper launches the source CLI using the existing dev wrapper, with config,
agent/session state, profiles, XDG roots, native cache and launch directory under
`<checkout>/.termux-test/`. `PI_CONFIG_DIR` is computed relative to home, matching
the shared resolver's contract. Existing production directory overrides are
replaced only in the child process. The original working directory is preserved
for tools. The wrapper neither copies production credentials nor changes the
installed `omp` launcher. Authenticate separately for an interactive test.

Set `OMP_TERMUX_TEST_HOME` to another **absolute** path if desired. Do not point
it at production state. Avoid explicit `--profile`/directory flags targeting a
production profile during the trial. Default isolation does not prevent tools
from editing a project you explicitly open; use a disposable project for tests.

The generated addon must be:

```text
packages/natives/native/pi_natives.android-arm64.node
```

Do not rename a Linux addon to that filename. With `llvm-readelf` from Termux's
`binutils`/LLVM tooling, inspect its `NEEDED` entries and confirm there are no
`libc.so.6`/glibc dependencies. Android voice links Termux's `libopus.so`;
PulseAudio is optional (`pkg install pulseaudio`) and uses unversioned Android
sonames. Microphone/speaker access and PulseAudio setup still require device tests.
Text clipboard access is optional and needs both the Termux:API Android app and
`pkg install termux-api` from compatible signing sources. Image clipboard reads
return no image because the Termux:API command interface exposes no image reader.

## What changed from the reference fork

Reference: [PlayWithG/oh-my-pi-termux, termux branch](https://github.com/PlayWithG/oh-my-pi-termux/tree/termux),
head `7abcab434b6e212ca15dc411cb588499cf8f7b2e`, based on
`45e12e5bb758198a920c6070e7e64cb33b21beac`.
All 18 branch-specific commits and their combined diff were inspected.

| Reference commits | Adaptation for v18.12.5 |
| --- | --- |
| `63d675a4ca` Rust/Bionic | Share current `proc_sys` helpers with Android; preserve new thread snapshots and process-exit APIs. Android can fall back from denied/missing pidfds to identity-checked `kill`, while Linux keeps pidfd-only signaling. Zombie-aware procfs polling prevents exit waits hanging. Use the platform temp directory, exclude arboard on Android, support Termux text clipboard read/write, retain panic logs/XDG support. |
| `63d675a4ca` voice | Keep the fork's narrowly scoped mono Opus C ABI adapter against Termux libopus. Official v18.12.5 now uses `opus 0.4`/`opusic-sys`, so the old `audiopus_sys` explanation no longer applies; Android still avoids a bundled CMake/NDK codec build. Reuse PulseAudio/ALSA support with Android sonames and drain timing. |
| `2ad6314faa` loader/packaging | Add Android identity and architecture-aware loader context without losing upstream Windows arm64 support, release stamps, or workspace loading. Android leaf generation requires explicit `--tag android-arm64`; official published target defaults remain unchanged. |
| `8f831f8334`, `aea7eac2d9` source build | Adapt to the current shared local Cargo build backend instead of duplicating it. Reject Android Bazel/cross-target requests, retain host load verification, bound Rust/CMake concurrency. Add separate build/run helpers that never relink the installed command. |
| `5eca1318a5` update | Preserve the official published native-tag set, excluding Android. Source checkouts remain source-managed; no Android release leaf or binary is claimed. |
| `eac04efd1f`, `0e7784d129`, `71190ff62a` runtime/tests/docs | Include Android XDG eligibility and the Android Bun tool-view minifier workaround. Adapt relevant test paths and add focused behavior tests and this guide. |

The old installer's Bun bootstrap/relink logic and fork-specific sync workflows,
repository-agent configuration, broad test rewrites, eval-runner changes and
model-ID sorting changes were not copied. They are not prerequisites for the
native source build described here. Existing upstream fixes (for example portable
shell test shims and `pgrep -q`) were retained rather than reverted.

The Android numeric-PID fallback checks start time before signaling, but cannot
eliminate the race between the check and `kill(2)` without a usable pidfd. Procfs
visibility and process-control permissions remain bounded by Android's sandbox.
Desktop automation, filesystem snapshot backends and other OS features do not
become available merely because the addon loads.

Optional local packaging (not publication or installation):

```sh
bun packages/natives/scripts/gen-npm-packages.ts --tag android-arm64
```

## Verification performed in the Linux workspace

| Check | Result |
| --- | --- |
| Frozen Bun install with scripts disabled | Passed, Bun 1.4.0; lockfile unchanged. |
| Focused Bun behavior tests | Passed: 14 tests across Android loader selection, explicit Android packaging, existing Windows staging/packaging, source-run state isolation, and refusing a non-Android build host. |
| `packages/natives`, `packages/utils`, and `packages/coding-agent` type checks | Passed. |
| Tool-view source-build generator | Passed on Linux. This does not exercise the Android minifier branch. |
| Shell syntax and Rust formatting | Passed. |
| System Opus ABI adapter | Two tests passed on Linux against system libopus: mono frame encode/decode with packet-loss concealment, and invalid sample-rate rejection. Compiled directly with `rustc --test -D warnings`; this is not an Android link test. |
| Cargo manifest metadata with `--locked --no-deps` | Passed; Cargo.lock unchanged. |
| Host `cargo check --locked -p pi-shell` | Blocked in dependencies by invalid metadata/zero-length object artifacts in this environment, including on retry with embedded metadata enabled. No completed Rust workspace check is claimed. |
| Android-target `cargo check --locked --target aarch64-linux-android -p pi-shell` | Blocked: no `aarch64-linux-android-clang` cross compiler here; dependency-artifact failures also occurred. |
| Repository Rust test command `bun run test:rs` | Blocked: `cargo-nextest` is not installed here. The new no-pidfd process regression test has not run. |
| Full addon/CLI/smoke/interactive operation on Android | Not run: no Android device is connected to this workspace. |

To reproduce focused checks:

```sh
bun test packages/natives/test/android-loader.test.ts \
  packages/natives/test/npm-packages.test.ts \
  packages/natives/test/windows-staging.test.ts scripts/termux.test.ts
bun run --cwd=packages/natives check:types
bun run --cwd=packages/utils check:types
bun run --cwd=packages/coding-agent check:types
bun run gen:tool-views
sh -n scripts/termux-build.sh scripts/termux-run.sh
bun run fmt:rs
# With cargo-nextest and the complete native toolchain installed:
bun run test:rs
```

## Still required on the Android device

1. Record Android version, Bun version/platform, Rust host/version, and helper
   configuration. Confirm the old `command -v omp` target before and after the trial.
2. Build from a fresh checkout with the helper exported. Confirm no `EPERM`/`SIGSYS`
   on install, chmod, generated-file writes, temp files or native cache operations.
3. Confirm Bionic `NEEDED` dependencies, stamped-addon load, `--version`, `--help`
   and `--smoke-test`. Confirm no Linux/glibc addon is selected.
4. In a disposable project test file reads/writes, grep/glob, PTY, embedded shell,
   `ps`/`pgrep`/`pidwait`, long-running children, cancellation and descendant cleanup.
   Test an older/restricted pidfd environment and ensure zombies do not hang waits.
5. Run the Rust tests using `bun run test:rs` once cargo-nextest and dependencies
   are available. In particular run the added process fallback and Opus tests.
6. Test clipboard copy/read with Unicode, leading `-` and multiline text, and
   verify missing/denied Termux:API errors are visible. Image paste is unsupported.
7. Test optional PulseAudio microphone/playback, remote latency/drain behavior,
   Opus/WebRTC voice, and permission failures. Building the codec proves none of these.
8. Confirm the working installation still runs normally and production sessions,
   credentials, native caches and profiles were not migrated. Keep using it until
   the device checks pass. To roll back the trial, stop using this checkout; no
   global launcher needs restoration.
