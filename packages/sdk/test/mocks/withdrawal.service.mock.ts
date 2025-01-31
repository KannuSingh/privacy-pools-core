import { Withdrawal, WithdrawalService } from "../../src/index.js";

export class WithdrawalServiceMock extends WithdrawalService {
  override calculateContext(withdrawal: Withdrawal): string {
    return super.calculateContext(withdrawal);
  }
}
