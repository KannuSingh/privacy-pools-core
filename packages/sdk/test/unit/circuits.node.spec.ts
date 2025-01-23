import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { fs, vol } from "memfs";
import { Circuits } from "../../src/circuits/index.js";
import { FetchArtifact } from "../../src/internal.js";
import { CircuitsMock } from "../mocks/index.js";

vi.mock("node:fs/promises");

const ARTIFACT_DIR = "/dist/node/artifacts";
const WASM_PATH = `${ARTIFACT_DIR}/withdraw.wasm`;

class CircuitsMockNode extends CircuitsMock {
  override baseUrl: string = `file://${ARTIFACT_DIR}`;
}

describe("Circuits for Node", () => {
  let circuits: Circuits;
  afterEach(() => {
    vi.clearAllMocks();
  });

  beforeEach(() => {
    vol.reset();
    fs.mkdirSync(ARTIFACT_DIR, { recursive: true });
    fs.writeFileSync(WASM_PATH, "somedata");
    circuits = new CircuitsMockNode();
  });

  it("virtual file exists", () => {
    expect(fs.existsSync(WASM_PATH)).toStrictEqual(true);
    expect(fs.existsSync("non_existent_file")).toStrictEqual(false);
  });

  it("throws a FetchArtifact exception if artifact is not found in filesystem", async () => {
    expect(async () => {
      return await circuits._fetchVersionedArtifact(
        "artifacts/artifact_not_here.wasm",
      );
    }).rejects.toThrowError(FetchArtifact);
  });

  it("loads artifact if it exists on filesystem", async () => {
    expect(
      circuits._fetchVersionedArtifact("artifacts/withdraw.wasm"),
    ).resolves.toBeInstanceOf(Uint8Array);
  });
});
