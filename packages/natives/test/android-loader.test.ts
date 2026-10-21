import { describe, expect, it } from "bun:test";
import * as path from "node:path";
import { hostTargetName } from "../../../scripts/bazel-natives";
import { resolveLocalHostAddon } from "../../../scripts/host-detect";
import { initLoaderContext } from "../native/loader-state.js";

describe("Android Bionic addon selection", () => {
	it("loads the local Android addon without Linux or x64 candidates on an x64 build host", () => {
		const host = { platform: "android", arch: "arm64", avx2: true, musl: false };
		const nativeDir = "/data/data/com.termux/files/home/omp-test/packages/natives/native";
		const context = initLoaderContext({ ...host, nativeDir, isCompiledBinary: false });
		const built = resolveLocalHostAddon(host);
		expect(context.candidates).toEqual([
			path.join(nativeDir, built.filename),
			path.join(path.dirname(process.execPath), built.filename),
		]);
		expect(context.selectedVariant).toBeNull();
		expect(context.stageFromNodeModules).toBe(false);
		expect(context.leafPackageDir).toBeNull();
		expect(hostTargetName(host)).toBe("android-arm64");
	});

	it("rejects unsupported Android architectures before choosing a Linux build target", () => {
		expect(() => hostTargetName({ platform: "android", arch: "x64", avx2: false, musl: false })).toThrow(
			"No pi_natives addon target",
		);
	});
});
