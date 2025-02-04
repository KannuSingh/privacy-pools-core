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
      processooor: getAddress("0x7359Ca02A152f8F466dc9A4cB3ad1ED62792F46A"),
      scope: BigInt("12345") as Hash,
      data: keccak256("0x123")
    };
    expect(service.calculateContext(withdrawal)).toStrictEqual(
      "0x127096bf8b62b2dea071de6617ca1893e1194d06ca4fb3bd3987f27c5c7c7352",
    );
  });

  it("calculates returns a scalar field bounded value", () => {
    const withdrawal: Withdrawal = {
      processooor: privateKeyToAccount(generatePrivateKey()).address,
      scope: BigInt(keccak256(generatePrivateKey())) as Hash,
      data: keccak256(generatePrivateKey()),
    };
    const result = service.calculateContext(withdrawal);
    expect(BigInt(result) % SNARK_SCALAR_FIELD).toStrictEqual(BigInt(result));
  });
});
