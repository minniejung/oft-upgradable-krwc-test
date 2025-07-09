import { expect } from 'chai'
import { ethers, upgrades } from 'hardhat'

describe('KRWC (Ganache Test)', function () {
    let krwc: any
    let owner: any
    let addr1: any

    beforeEach(async function () {
        ;[owner, addr1] = await ethers.getSigners()

        const MockCompliance = await ethers.getContractFactory('MockComplianceModule')
        const mockCompliance = await MockCompliance.deploy()
        await mockCompliance.deployed()

        console.log('MockCompliance deployed to:', mockCompliance.address)

        const KRWC = await ethers.getContractFactory('KRWC')
        krwc = await upgrades.deployProxy(KRWC, ['KRWC', 'KRWC', mockCompliance.address], {
            initializer: 'initialize',
        })
        await krwc.waitForDeployment()
    })

    it('should mint tokens to a compliant user', async function () {
        await krwc.grantRole(await krwc.MINTER_ROLE(), owner.address)
        await krwc.mint(addr1.address, 1000)
        expect(await krwc.balanceOf(addr1.address)).to.equal(1000)
    })

    it('should not allow transfer if sender is not compliant', async function () {
        const tx = krwc.connect(addr1).transfer(owner.address, 100)
        await expect(tx).to.be.revertedWith('KRWC: sender not compliant')
    })

    it('should pause and unpause transfers', async function () {
        await krwc.grantRole(await krwc.OPERATOR_ROLE(), owner.address)
        await krwc.pause()
        expect(await krwc.isPaused()).to.equal(true)

        await krwc.unpause()
        expect(await krwc.isPaused()).to.equal(false)
    })
})
