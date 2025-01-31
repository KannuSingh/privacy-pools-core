import { getAddress, hexToBytes, keccak256 } from "viem/utils";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { Hash, Withdrawal } from "../../src/types/index.js";
import { CircuitsMock } from "../mocks/index.js";
import { WithdrawalServiceMock } from "../mocks/withdrawal.service.mock.js";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { SNARK_SCALAR_FIELD } from "../../src/internal.js";

describe("WithdrawalService", () => {
  let service: WithdrawalServiceMock;
  let circuits: CircuitsMock;

  beforeEach(() => {
    circuits = new CircuitsMock();
    service = new WithdrawalServiceMock(circuits);
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("calculates the context correctly", () => {
    const withdrawal: Withdrawal = {
      procesooor: getAddress("0x7359Ca02A152f8F466dc9A4cB3ad1ED62792F46A"),
      scope: BigInt("12345") as Hash,
      data: Uint8Array.from((new TextEncoder()).encode("This is some binary data")),
    };
    expect(service.calculateContext(withdrawal)).toStrictEqual("0x302394f42f14aa47c0f84c2e6c325aa17866f8c28cd3243fa08df47b88262be8");
  })

  it("calculates returns a scalar field bounded value", () => {
    const withdrawal: Withdrawal = {
      procesooor: privateKeyToAccount(generatePrivateKey()).address,
      scope: BigInt(keccak256(generatePrivateKey())) as Hash,
      data: hexToBytes(keccak256(generatePrivateKey())),
    };
    const result = service.calculateContext(withdrawal);
    expect(BigInt(result) % SNARK_SCALAR_FIELD).toStrictEqual(BigInt(result));
  })

})
