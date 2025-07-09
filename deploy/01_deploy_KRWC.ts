import { ethers, upgrades } from 'hardhat'

import { makeAbi } from './abiGenerator'

async function main() {
    console.log('Deploying contracts')

    const KRWC = await ethers.getContractFactory('KRWC')
    // const lzEndpoint = '0x...' // 실제 주소
    const complianceModule = '0x...' // 실제 주소

    const proxy = await upgrades.deployProxy(KRWC, ['KRWC', 'KRWC', complianceModule], {
        initializer: 'initialize',
    })

    await proxy.waitForDeployment()

    console.log(`✅ KRWC deployed at >>>>> ${proxy.target}`)

    await makeAbi('KRWC', proxy.target)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
