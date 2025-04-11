import { Router } from "express";
import {
  relayerDetailsHandler,
  relayRequestHandler,
} from "../handlers/index.js";
import { validateDetailsMiddleware, validateRelayRequestMiddleware } from "../middlewares/relayer/request.js";

// Router setup
const relayerRouter = Router();
relayerRouter.get("/details", [
  validateDetailsMiddleware,
  relayerDetailsHandler
]);

relayerRouter.post("/request", [
  validateRelayRequestMiddleware,
  relayRequestHandler,
]);

export { relayerRouter };
