#!/bin/sh
# Build only this checkout. Never install Bun, link omp, or touch a global install.
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$repo_root"

if [ "$(bun -p 'process.platform + "-" + process.arch')" != android-arm64 ]; then
    echo 'This build requires native Android/arm64 Bun (not a glibc Linux binary).' >&2
    exit 1
fi
for tool in cargo rustc clang cmake ninja pkg-config; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Missing build prerequisite: $tool (see docs/termux.md)" >&2
        exit 1
    fi
done
case "$(rustc -vV)" in
    *"host: aarch64-linux-android"*) ;;
    *) echo 'Rust must be a native aarch64-linux-android toolchain.' >&2; exit 1 ;;
esac
# Known Android-active nightly gates: xutf (SIMD/statement attributes) and
# vendored brush_core (process_setsid). Keep stable opt-in explicit and scoped.
case "$(rustc --version)" in
    *-nightly*|*-dev*) ;;
    *)
        for unstable_crate in xutf brush_core; do
            case ",${RUSTC_BOOTSTRAP:-}," in
                ,1,|*,"$unstable_crate",*) ;;
                *)
                    echo 'xutf and brush_core require nightly Rust. For an experimental stable-Termux build, run:' >&2
                    echo '  RUSTC_BOOTSTRAP=xutf,brush_core sh scripts/termux-build.sh' >&2
                    echo 'This opts only the named crates out of stable feature guarantees; see docs/termux.md.' >&2
                    exit 1
                    ;;
            esac
        done
        ;;
esac
case "${CARGO_BUILD_TARGET:-aarch64-linux-android}" in
    aarch64-linux-android) ;;
    *) echo 'Unset the non-Android CARGO_BUILD_TARGET for this native build.' >&2; exit 1 ;;
esac
if ! pkg-config --exists opus; then
    echo 'Missing system libopus: install the Termux libopus package.' >&2
    exit 1
fi
# The existing LD_PRELOAD syscall helper is inherited unchanged by children.
CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS:-1}
CMAKE_BUILD_PARALLEL_LEVEL=${CMAKE_BUILD_PARALLEL_LEVEL:-1}
OMP_NATIVE_BUILD_BACKEND=cargo
export CARGO_BUILD_JOBS CMAKE_BUILD_PARALLEL_LEVEL OMP_NATIVE_BUILD_BACKEND

# Keep dependency files inside this checkout. Symlink-backed installs resolve
# react-dom from Bun's global cache, where its react/scheduler siblings are absent.
# Force reinstall also repairs a previous symlink-backed attempt without deleting
# the shared cache or changing global installs. Keep lifecycle hooks disabled.
bun install --frozen-lockfile --ignore-scripts --backend=copyfile --force
bun run gen:tool-views
bun run build:native
printf '%s\n' 'Built this checkout. Test it with: sh scripts/termux-run.sh --version'
