#!/bin/bash

CIRCUITS=("merkleTree" "commitment" "withdraw")
BUILD_DIR="../circuits/build"
DEST_DIR="./dist/node/artifacts"

mkdir -p "$DEST_DIR"
for circuit in "${CIRCUITS[@]}"
do
  cp "$BUILD_DIR/$circuit/groth16_pkey.zkey" "$DEST_DIR/${circuit}.zkey"
  cp "$BUILD_DIR/$circuit/groth16_vkey.json" "$DEST_DIR/${circuit}.vkey"
  cp "$BUILD_DIR/$circuit/${circuit}_js/${circuit}.wasm" "$DEST_DIR/"
done
