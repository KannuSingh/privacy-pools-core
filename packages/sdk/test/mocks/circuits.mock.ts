import { vi } from "vitest";
import {
  Binaries,
  CircuitArtifacts,
  VersionString,
} from "../../src/circuits/circuits.interface.js";
import { Circuits } from "../../src/circuits/index.js";

export const binariesMock: Binaries = {
  withdraw: vi.fn() as any as CircuitArtifacts, // eslint-disable-line @typescript-eslint/no-explicit-any
  merkleTree: vi.fn() as any as CircuitArtifacts, // eslint-disable-line @typescript-eslint/no-explicit-any
  commitment: vi.fn() as any as CircuitArtifacts, // eslint-disable-line @typescript-eslint/no-explicit-any
};

export class CircuitsMock extends Circuits {
  override _initialize(binaries: Binaries, version: VersionString) {
    super._initialize(binaries, version);
  }

  override async _handleInitialization(version: VersionString) {
    await super._handleInitialization(version);
  }

  get introspectInitialized(): boolean {
    return this.initialized;
  }

  get introspectVersion(): string {
    return this.version;
  }

  get introspectBinaries(): { [key: string]: CircuitArtifacts } {
    return this.binaries;
  }
}
