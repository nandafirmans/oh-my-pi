import { expect, it } from "bun:test";
import * as fs from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";

const repoRoot = path.resolve(import.meta.dir, "..");

it("Termux test launcher isolates state and leaves the existing omp launcher intact", async () => {
	const dir = await fs.mkdtemp(path.join(os.tmpdir(), "omp-termux-launch-"));
	try {
		const stateRoot = path.join(dir, "state");
		const capture = path.join(dir, "environment.json");
		const oldOmp = path.join(dir, "omp");
		await Bun.write(oldOmp, "working installation sentinel\n");
		// This shell boundary captures the final Bun launch without loading the CLI.
		const fakeBun = path.join(dir, "bun");
		await Bun.write(
			fakeBun,
			`#!/bin/sh
if [ "$1" = -e ]; then exec "$OMP_REAL_BUN" "$@"; fi
exec "$OMP_REAL_BUN" -e 'await Bun.write(process.env.OMP_CAPTURE, JSON.stringify({ env: process.env, args: process.argv.slice(1), cwd: process.cwd() }));' -- "$@"
`,
		);
		await fs.chmod(fakeBun, 0o755);
		const proc = Bun.spawn(["sh", path.join(repoRoot, "scripts/termux-run.sh"), "--version"], {
			cwd: dir,
			env: {
				...process.env,
				PATH: `${dir}${path.delimiter}${process.env.PATH}`,
				OMP_REAL_BUN: process.execPath,
				OMP_CAPTURE: capture,
				OMP_TERMUX_TEST_HOME: stateRoot,
				PI_CONFIG_DIR: ".omp",
				PI_CODING_AGENT_DIR: path.join(os.homedir(), ".omp/agent"),
				PI_NATIVES_DIR: path.join(os.homedir(), ".omp/natives"),
				OMP_PROFILE: "production",
				XDG_DATA_HOME: path.join(dir, "production-xdg"),
			},
			stdout: "pipe",
			stderr: "pipe",
		});
		expect(await proc.exited).toBe(0);
		const observed = await Bun.file(capture).json();
		expect(path.resolve(os.homedir(), observed.env.PI_CONFIG_DIR)).toBe(path.join(stateRoot, "config"));
		expect(observed.env.PI_CODING_AGENT_DIR).toBe(path.join(stateRoot, "config/agent"));
		expect(observed.env.PI_NATIVES_DIR).toBe(path.join(stateRoot, "natives"));
		expect(observed.env.XDG_DATA_HOME).toBe(path.join(stateRoot, "xdg/data"));
		expect(observed.env.OMP_PROFILE).toBe("default");
		expect(observed.cwd).toBe(path.join(stateRoot, "launch"));
		expect(observed.env.OMP_LAUNCH_CWD).toBe(dir);
		expect(observed.args).toContain("--version");
		expect(await Bun.file(oldOmp).text()).toBe("working installation sentinel\n");
	} finally {
		await fs.rm(dir, { recursive: true, force: true });
	}
});

it.skipIf(process.platform === "android")(
	"Termux build refuses a Linux host before installing dependencies",
	async () => {
		const proc = Bun.spawn(["sh", path.join(repoRoot, "scripts/termux-build.sh")], {
			env: { ...process.env, PATH: `${path.dirname(process.execPath)}${path.delimiter}${process.env.PATH}` },
			stdout: "pipe",
			stderr: "pipe",
		});
		expect(await proc.exited).toBe(1);
		expect(await new Response(proc.stderr).text()).toContain("requires native Android/arm64 Bun");
	},
);
