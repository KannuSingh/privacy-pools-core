import { encodeAbiParameters, getAddress, Hex } from "viem";
import { request } from "./api-test.js";
import { deposit, proveWithdrawal } from "./create-withdrawal.js";
import { Hash, Withdrawal } from "@0xbow/privacy-pools-core-sdk";
import { ENTRYPOINT_ADDRESS } from "./constants.js";

const FeeDataAbi = [
  {
    name: "FeeData",
    type: "tuple",
    components: [
      { name: "recipient", type: "address" },
      { name: "feeRecipient", type: "address" },
      { name: "relayFeeBPS", type: "uint256" },
    ],
  },
];

const recipient = getAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8");
const processooor = ENTRYPOINT_ADDRESS;
const FEE_RECEIVER_ADDRESS = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

async function prove(w: Withdrawal, scope: bigint) {
  return proveWithdrawal(w, scope);
}

async function depositEth() {
  const r = await deposit();
  await r.wait();
  console.log(`Successful deposit, hash := ${r.hash}`);
}

(async () => {
  const scope = BigInt(
    "0x2b85ec3a046efd3b9e0d715cc2f6b08fd973c5831c2cb30b906ec57c4479f455",
  ) as Hash;
  const data = encodeAbiParameters(FeeDataAbi, [
    {
      recipient,
      feeRecipient: FEE_RECEIVER_ADDRESS,
      relayFeeBPS: 1_000n,
    },
  ]) as Hex;

  const withdrawal = { processooor, data };

  await depositEth();

  // prove
  const { proof, publicSignals } = await prove(withdrawal, scope);
  const requestBody = {
    scope: scope.toString(),
    withdrawal,
    publicSignals,
    proof,
  };

  await request(requestBody);
})();
