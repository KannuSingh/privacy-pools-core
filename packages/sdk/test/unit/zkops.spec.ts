import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CircuitsMock, binariesMock } from "../mocks/index.js";
import { ZkOps } from "../../src/zkops.js";
import * as snarkjs from "snarkjs";

vi.mock("snarkjs");

describe("ZkOps", () => {
  let circuits: CircuitsMock;
  let zkOps: ZkOps;

  beforeEach(() => {
    circuits = new CircuitsMock();
    zkOps = new ZkOps(circuits);
  });
  afterEach(() => {
    vi.clearAllMocks();
  });

  describe("constructor", () => {
    it("should set circuits", () => {
      expect(zkOps.circuits).toStrictEqual(circuits);
    });
  });

  describe("proveCommitment", () => {
    it("should use Circuits binaries and delegate to snarkjs prover", async () => {
      snarkjs.groth16.fullProve = vi.fn().mockResolvedValue("PROOF");
      const signals = { signal_1: "1" };
      const handleInitializationSpy = vi.spyOn(
        circuits,
        "_handleInitialization",
      );
      const downloadArtifactsSpy = vi
        .spyOn(circuits, "downloadArtifacts")
        .mockResolvedValue(binariesMock);
      expect(await zkOps.proveCommitment(signals)).toStrictEqual("PROOF");
      expect(downloadArtifactsSpy).toHaveBeenCalledOnce();
      expect(downloadArtifactsSpy).toHaveBeenCalledWith("latest");
      expect(handleInitializationSpy).toHaveBeenCalledTimes(2);
      expect(snarkjs.groth16.fullProve).toHaveBeenCalledWith(
        signals,
        binariesMock.commitment.wasm,
        binariesMock.commitment.zkey,
      );
    });
  });
});
