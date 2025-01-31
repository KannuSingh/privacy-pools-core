import sqlite3 from "sqlite3";
import { open, Database } from "sqlite";

import { WithdrawalPayload } from "@privacy-pool-core/sdk";
import path from "path";
import { SQLITE_DB_PATH } from "../config.js";
import { RelayerDatabase } from "../types/db.types.js";
import { RequestStatus } from "../interfaces/relayer/request.js";

function replacer(key: string, value: unknown) {
  return typeof value === "bigint" ? { $bigint: value.toString() } : value;
}

// TODO
export class SqliteDatabase implements RelayerDatabase {
  readonly dbPath: string;
  private _initialized: boolean = false;
  private db!: Database<sqlite3.Database, sqlite3.Statement>;

  private createTableRequest = `
CREATE TABLE IF NOT EXISTS requests (
    id UUID PRIMARY KEY,
    timestamp INTEGER NOT NULL,
    request JSON,
    status TEXT CHECK(status IN ('BROADCASTED', 'FAILED', 'RECEIVED')) NOT NULL,
    txHash TEXT,
    error TEXT
);
`;

  constructor() {
    this.dbPath = path.resolve(SQLITE_DB_PATH);
  }

  get initialized(): boolean {
    return this._initialized;
  }

  async init() {
    try {
      this.db = await open({
        driver: sqlite3.Database,
        filename: this.dbPath,
      });
      await this.db.run(this.createTableRequest);
    } catch (error) {
      console.log(error);
    }
    this._initialized = true;
    console.log("sqlite db initialized");
  }

  async createNewRequest(
    requestId: string,
    timestamp: number,
    req: WithdrawalPayload,
  ) {
    const strigifiedPayload = JSON.stringify(req, replacer);
    // Store initial request
    await this.db.run(
      `
      INSERT INTO requests (id, timestamp, request, status)
      VALUES (?, ?, ?, ?)
    `,
      [requestId, timestamp, strigifiedPayload, RequestStatus.RECEIVED],
    );
  }

  async updateBroadcastedRequest(requestId: string, txHash: string) {
    // Update database
    await this.db.run(
      `
      UPDATE requests
      SET status = ?, txHash = ?
      WHERE id = ?
    `,
      [RequestStatus.BROADCASTED, txHash, requestId],
    );
  }

  async updateFailedRequest(requestId: string, errorMessage: string) {
    // Update database with error
    await this.db.run(
      `
      UPDATE requests
      SET status = ?, error = ?
      WHERE id = ?
    `,
      [RequestStatus.FAILED, errorMessage, requestId],
    );
  }
}
