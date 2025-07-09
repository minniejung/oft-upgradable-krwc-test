import { ethers } from 'hardhat'

async function main() {
    const FeeManager = await ethers.getContractFactory('FeeManager')
    const lpReceiver = '<LP_RECEIVER_ADDRESS>'
    const treasuryReceiver = '<TREASURY_RECEIVER_ADDRESS>'

    const feeManager = await FeeManager.deploy()
    await feeManager.deployed()

    await feeManager.initialize(lpReceiver, treasuryReceiver)
    console.log('FeeManager deployed to:', feeManager.address)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
