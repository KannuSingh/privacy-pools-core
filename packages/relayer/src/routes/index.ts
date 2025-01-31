import { Router } from "express";
import {
  relayerDetailsHandler,
  relayRequestHandler,
} from "../handlers/index.js";
import { validateRelayRequestMiddleware } from "../middlewares/relayer/request.js";

// Router setup
const relayerRouter = Router();
relayerRouter.get("/details", [relayerDetailsHandler]);

relayerRouter.post("/request", [
  validateRelayRequestMiddleware,
  relayRequestHandler,
]);

export { relayerRouter };
