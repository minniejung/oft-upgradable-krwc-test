import 'dotenv/config'
import '@nomicfoundation/hardhat-chai-matchers'
import '@nomiclabs/hardhat-ethers'
import 'hardhat-deploy'
import '@layerzerolabs/devtools-evm-hardhat'
import '@layerzerolabs/test-devtools-evm-hardhat'
import '@openzeppelin/hardhat-upgrades'

import { HardhatUserConfig } from 'hardhat/config'

const PRIVATE_KEY = process.env.PRIVATE_KEY
const accounts = PRIVATE_KEY ? [PRIVATE_KEY] : []

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: '0.8.20',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: '0.8.22', // for OZ v5 modules
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
        },
        ganache: {
            url: 'http://127.0.0.1:8545',
            accounts,
        },
        kaia: {
            url: process.env.RPC_URL_KAIA || 'https://rpc.kaia-testnet.kairoslabs.dev',
            chainId: 1001,
            accounts,
        },
        sepolia: {
            url: process.env.RPC_URL_SEPOLIA || 'https://rpc2.sepolia.org',
            chainId: 11155111,
            accounts,
        },
        mainnet: {
            url: process.env.RPC_URL_MAINNET || 'https://rpc.ankr.com/eth',
            chainId: 1,
            accounts,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
    },
}

export default config
