import bodyParser from "body-parser";
import express, { NextFunction, Request, Response } from "express";
import {
  errorHandlerMiddleware,
  marshalResponseMiddleware,
  notFoundMiddleware,
} from "./middlewares/index.js";
import { relayerRouter } from "./routes/index.js";

// Initialize the express app
const app = express();

// Middleware functions
const parseJsonMiddleware = bodyParser.json();

// Apply middleware and routes
app.use(parseJsonMiddleware);
app.use(marshalResponseMiddleware);

// ping route
app.use("/ping", (req: Request, res: Response, next: NextFunction) => {
  res.send("pong");
  next();
});

// relayer route
app.use("/relayer", relayerRouter);

// Error and 404 handling
app.use([errorHandlerMiddleware, notFoundMiddleware]);

export { app };
