// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IState {
  error OnlyEntrypoint();
  error PoolIsDead();
  error NullifierAlreadySpent();
}
