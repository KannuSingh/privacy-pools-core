import { Ajv, JSONSchemaType } from "ajv";
import { RelayRequestBody } from "../../interfaces/relayer/request.js";

// AJV schema for validation
const ajv = new Ajv();

const relayRequestSchema: JSONSchemaType<RelayRequestBody> = {
  type: "object",
  properties: {
    withdrawal: {
      type: "object",
      properties: {
        procesooor: { type: "string" },
        scope: { type: "string" },
        data: { type: "string" },
      },
      required: ["procesooor", "scope", "data"],
    },
    publicSignals: {
      type: "array",
      items: { type: "string" },
      minItems: 8,
      maxItems: 8,
    },
    proof: {
      type: "object",
      properties: {
        protocol: { type: "string" },
        curve: { type: "string" },
        pi_a: { type: "array", items: { type: "string" }, minItems: 1 },
        pi_b: {
          type: "array",
          items: {
            type: "array",
            items: { type: "string" },
            minItems: 1,
          },
          minItems: 1,
        },
        pi_c: { type: "array", items: { type: "string" }, minItems: 1 },
      },
      required: ["pi_a", "pi_b", "pi_c"],
    },
  },
  required: ["withdrawal", "proof", "publicSignals"],
} as const;

export const validateRelayRequestBody = ajv.compile(relayRequestSchema);
