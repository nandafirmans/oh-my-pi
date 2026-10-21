#!/bin/sh
# Run this checkout using separate state; never replace the installed omp command.
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
# Deliberately override existing OMP directory variables: a test must never
# share production credentials, sessions, native caches, or launcher state.
state_root=${OMP_TERMUX_TEST_HOME:-"$repo_root/.termux-test"}
case "$state_root" in
    /*) ;;
    *) echo 'OMP_TERMUX_TEST_HOME must be an absolute path.' >&2; exit 1 ;;
esac
# PI_CONFIG_DIR is relative to HOME in the shared directory resolver.
PI_CONFIG_DIR=$(bun -e 'import * as path from "node:path"; import * as os from "node:os"; process.stdout.write(path.relative(os.homedir(), process.argv[1]));' "$state_root/config")
PI_CODING_AGENT_DIR="$state_root/config/agent"
PI_NATIVES_DIR="$state_root/natives"
OMP_DEV_LAUNCH_DIR="$state_root/launch"
export PI_CONFIG_DIR PI_CODING_AGENT_DIR PI_NATIVES_DIR OMP_DEV_LAUNCH_DIR
XDG_CONFIG_HOME="$state_root/xdg/config"
XDG_DATA_HOME="$state_root/xdg/data"
XDG_STATE_HOME="$state_root/xdg/state"
XDG_CACHE_HOME="$state_root/xdg/cache"
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
# Avoid inheriting a production profile, including a profile selected in cwd.
OMP_PROFILE=default
PI_PROFILE=default
export OMP_PROFILE PI_PROFILE
exec sh "$repo_root/packages/coding-agent/scripts/omp" "$@"
