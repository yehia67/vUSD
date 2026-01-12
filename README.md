## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Environment Setup

1. Copy `.env.example` to `.env`:
   ```shell
   cp .env.example .env
   ```
2. Fill in the required values:
   - `RPC_URL` – Base Sepolia RPC endpoint (e.g., Alchemy/Infura)
   - `PRIVATE_KEY` – Deployer private key (0x-prefixed)
   - `ETHERSCAN_API_KEY` – Basescan/Etherscan API key for contract verification

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```


### Deploy & Verify (Base Sepolia)

```shell
forge script script/DeployVUSD.s.sol:DeployVUSD \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --verifier etherscan \
  --verifier-url "https://api.etherscan.io/v2/api?chainid=84532" \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Deployed Contracts (Base Sepolia)

- Mock vETH: [0xAeD88bFC17C1700291FD8d59c155a377e79E16F7](https://sepolia.basescan.org/address/0xAeD88bFC17C1700291FD8d59c155a377e79E16F7)
- Mock vDOT: [0x135078823F9FaA95BB1761e02F4BE1D20fB56328](https://sepolia.basescan.org/address/0x135078823F9FaA95BB1761e02F4BE1D20fB56328)
- vUSD: [0xa873aafC84eef54Aee3c0b1705DEd9CB35Fb6715](https://sepolia.basescan.org/address/0xa873aafC84eef54Aee3c0b1705DEd9CB35Fb6715)

## Project Progress & Task Dashboard

Development tasks and feature progress are tracked publicly using GitHub Projects:

https://github.com/users/yehia67/projects/5
### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
