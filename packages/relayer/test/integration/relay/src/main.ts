import { Hash, Withdrawal } from "@0xbow/privacy-pools-core-sdk";
import { encodeAbiParameters, getAddress, Hex } from "viem";
import { request } from "./api-test.js";
import { anvilChain, pool } from "./chain.js";
import { ENTRYPOINT_ADDRESS } from "./constants.js";
import { deposit, proveWithdrawal } from "./create-withdrawal.js";

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

  const scope = await pool.read.SCOPE() as Hash;
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
    chainId: anvilChain.id,
    withdrawal,
    publicSignals,
    proof,
  };

  await request(requestBody);
})();
