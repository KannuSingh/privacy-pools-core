import {
  Circuits,
  PrivacyPoolSDK,
  WithdrawalPayload,
  WithdrawalProof,
} from "@privacy-pool-core/sdk";

export class SdkProvider {
  private sdk: PrivacyPoolSDK;
  constructor() {
    this.sdk = new PrivacyPoolSDK(new Circuits());
  }
  async verifyWithdrawal(withdrawalPayload: WithdrawalProof) {
    return await this.sdk.verifyWithdrawal(withdrawalPayload);
  }
  async broadcastWithdrawal(
    _withdrawalPayload: WithdrawalPayload, // eslint-disable-line @typescript-eslint/no-unused-vars
    _brodacastDetails: { privateKey: string; rpcUrl: string }, // eslint-disable-line @typescript-eslint/no-unused-vars
  ): Promise<{ hash: string }> {
    return {
      hash: "0x",
    };
  }
}
