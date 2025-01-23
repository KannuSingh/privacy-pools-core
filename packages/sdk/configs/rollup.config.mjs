import path from "path";
import commonjs from "@rollup/plugin-commonjs";
import { nodeResolve } from "@rollup/plugin-node-resolve";
import typescript from "@rollup/plugin-typescript";
import json from "@rollup/plugin-json";
import inject from "@rollup/plugin-inject";
import { dts } from "rollup-plugin-dts";

const rootOutDir = "dist"
const outDirNode = path.join(rootOutDir, "node");
const outDirBrowser = path.join(rootOutDir, "esm");

const typescriptConfig = {
  tsconfig: path.resolve(`./tsconfig.build.json`),
  exclude: ["**/*spec.ts"],
  outputToFilesystem: false,
}

export default [

  {
    input: "src/index.ts",
    output: [
      {
        dir: outDirBrowser,
        format: "esm",
        sourcemap: true,
        entryFileNames: "[name].mjs"
      },
    ],
    plugins: [
      nodeResolve({
        exportConditions: ["umd"],
        browser: true,
        preferBuiltins: true,
      }),
      commonjs({ requireReturnsDefault: "auto" }),
      json(),
      typescript({
        ...typescriptConfig,
        declaration: false,
        noEmit: true,
      }),
    ],
  },

  {
    input: "src/index.ts",
    output: [
      {
        dir: outDirNode,
        format: "esm",
        sourcemap: true,
        entryFileNames: "[name].mjs"
      },
    ],
    plugins: [
      nodeResolve({
        exportConditions: ["node"],
        browser: false,
        preferBuiltins: true,
      }),
      commonjs({ requireReturnsDefault: "auto" }),
      inject({
        __filename: path.resolve("src/filename.helper.js"),
        __dirname: path.resolve("src/dirname.helper.js")
      }),
      json(),
      typescript({
        ...typescriptConfig,
        declaration: false,
        noEmit: true,
      }),
    ],
  },

  {
    input: "src/index.ts",
    output: [
      {
        dir: path.join(rootOutDir, "types"),
        sourcemap: true,
      },
    ],
    plugins: [
      nodeResolve({
        exportConditions: ["node"],
        browser: false,
        preferBuiltins: true,
      }),
      commonjs({ requireReturnsDefault: "auto" }),
      json(),
      typescript({
        ...typescriptConfig,
        declaration: true,
        declarationDir: path.join(rootOutDir, "types"),
        emitDeclarationOnly: true,
      }),
    ],
  },

  {
    input: path.join(rootOutDir, "types", "src", "index.d.ts"),
    output: [{ file: path.join(rootOutDir, "index.d.mts"), format: "esm" }],
    plugins: [dts()],
  }

];

