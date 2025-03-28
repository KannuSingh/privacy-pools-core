import { Ajv, JSONSchemaType } from "ajv";
import { QuotetBody } from "../../interfaces/relayer/quote.js";

// AJV schema for validation
const ajv = new Ajv();

const quoteSchema: JSONSchemaType<QuotetBody> = {
  type: "object",
  properties: {
    withdrawal: {
      type: "object",
      properties: {
        processooor: { type: "string" },
        data: { type: "string", pattern: "0x[0-9a-fA-F]+" },
      },
      required: ["processooor", "data"],
    },
    scope: { type: "string" },
    chainId: { type: ["string", "number"] },
    balance: { type: ["string", "number"] },
  },
  required: ["withdrawal", "scope", "chainId", "balance"],
} as const;

export const validateQuoteBody = ajv.compile(quoteSchema);
