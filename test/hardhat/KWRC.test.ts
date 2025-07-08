import { expect } from 'chai'
import { Contract, ContractFactory } from 'ethers'
import { deployments, ethers } from 'hardhat'

import type { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'

// TODO : check all the any types

describe('KWRC Test', function () {
    let KWRC: ContractFactory
    let EndpointV2Mock: ContractFactory
    let MockFeeManager: ContractFactory
    let endpoint: Contract
    let kwrc: Contract
    let feeManager: Contract
    let owner: SignerWithAddress
    let admin: SignerWithAddress
    let delegate: SignerWithAddress
    let userA: SignerWithAddress
    let userB: SignerWithAddress

    const initialBalance = ethers.utils.parseEther('1000')
    const feeRate = 100 // 1%

    before(async function () {
        // Get signers
        const signers = await ethers.getSigners()
        ;[owner, admin, delegate, userA, userB] = signers

        // Get the artifact for EndpointV2Mock from LayerZero devtools
        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2Mock')
        EndpointV2Mock = new ethers.ContractFactory(
            EndpointV2MockArtifact.abi,
            EndpointV2MockArtifact.bytecode,
            owner as any
        )

        // Deploy the mock endpoint
        endpoint = await EndpointV2Mock.deploy(1) // 1 = mock endpoint ID
        await endpoint.deployed()

        // Deploy mock fee manager
        MockFeeManager = await ethers.getContractFactory('MockFeeManager')
        feeManager = await MockFeeManager.deploy()
        await feeManager.deployed()

        // Get KWRC contract factory
        KWRC = await ethers.getContractFactory('KWRC')
    })

    beforeEach(async function () {
        // Create transfer limits for testing
        const transferLimits = [
            {
                dstEid: 2,
                maxDailyTransferAmount: ethers.utils.parseEther('10000'),
                singleTransferUpperLimit: ethers.utils.parseEther('1000'),
                singleTransferLowerLimit: ethers.utils.parseEther('0.1'),
                dailyTransferAmountPerAddress: ethers.utils.parseEther('500'),
                dailyTransferAttemptPerAddress: 10,
            },
        ]

        // Deploy KWRC with the mock endpoint address
        kwrc = await KWRC.deploy(
            'KRW Coin',
            'KWRC',
            endpoint.address, // Use the mock endpoint
            delegate.address,
            feeManager.address,
            feeRate,
            transferLimits,
            admin.address,
            owner.address
        )
        await kwrc.deployed()

        // Mint initial tokens to users
        await kwrc.connect(admin as any).mint(userA.address, initialBalance)
        await kwrc.connect(admin as any).mint(userB.address, initialBalance)
    })

    describe('Constructor', function () {
        it('Should set correct initial values', async function () {
            expect(await kwrc.owner()).to.equal(owner.address)
            expect(await kwrc.feeRate()).to.equal(feeRate)
            expect(await kwrc.feeManager()).to.equal(feeManager.address)
            expect(await kwrc.balanceOf(userA.address)).to.equal(initialBalance)
            expect(await kwrc.balanceOf(userB.address)).to.equal(initialBalance)
        })

        it('Should set correct roles', async function () {
            expect(await kwrc.hasRole(await kwrc.DEFAULT_ADMIN_ROLE(), admin.address)).to.be.true
            expect(await kwrc.hasRole(await kwrc.ADMIN_ROLE(), admin.address)).to.be.true
            expect(await kwrc.hasRole(await kwrc.MINTER_ROLE(), admin.address)).to.be.true
        })
    })

    describe('Transfer with Fee', function () {
        it('Should transfer tokens with fee deduction', async function () {
            const transferAmount = ethers.utils.parseEther('100')
            const expectedFee = transferAmount.mul(feeRate).div(10000) // 1 ether
            const expectedNetAmount = transferAmount.sub(expectedFee)

            const balanceBefore = await kwrc.balanceOf(userA.address)

            await kwrc.connect(userA as any).transfer(userB.address, transferAmount)

            expect(await kwrc.balanceOf(userA.address)).to.equal(balanceBefore.sub(transferAmount))
            expect(await kwrc.balanceOf(userB.address)).to.equal(initialBalance.add(expectedNetAmount))
        })

        it('Should handle transfer without fee manager', async function () {
            // Deploy KWRC without fee manager
            const transferLimits: any[] = []
            const kwrcNoFee = await KWRC.deploy(
                'No Fee KWRC',
                'NFKWRC',
                endpoint.address,
                delegate.address,
                ethers.constants.AddressZero, // No fee manager
                0, // No fee rate
                transferLimits,
                admin.address,
                owner.address
            )
            await kwrcNoFee.deployed()

            await kwrcNoFee.connect(admin as any).mint(userA.address, ethers.utils.parseEther('100'))

            const transferAmount = ethers.utils.parseEther('50')
            await kwrcNoFee.connect(userA as any).transfer(userB.address, transferAmount)

            expect(await kwrcNoFee.balanceOf(userB.address)).to.equal(transferAmount)
        })
    })

    describe('Transfer Limits', function () {
        it('Should enforce single transfer upper limit', async function () {
            const transferAmount = ethers.utils.parseEther('1000') // At the upper limit

            await kwrc.connect(userA as any).transfer(userB.address, transferAmount)
            const overLimit = ethers.utils.parseEther('1001')

            // Try to transfer more than the limit
            await expect(kwrc.connect(userA as any).transfer(userB.address, overLimit)).to.be.reverted
        })

        it('Should enforce daily transfer amount limit', async function () {
            const transferAmount = ethers.utils.parseEther('300')

            // First transfer should succeed
            await kwrc.connect(userA as any).transfer(userB.address, transferAmount)

            // Second transfer that exceeds daily limit should fail
            await expect(kwrc.connect(userA as any).transfer(userB.address, ethers.utils.parseEther('250'))).to.be
                .reverted
        })

        it('Should enforce daily transfer attempt limit', async function () {
            const transferAmount = ethers.utils.parseEther('10')

            // Make 10 transfers (at the limit)
            for (let i = 0; i < 10; i++) {
                await kwrc.connect(userA as any).transfer(userB.address, transferAmount)
            }

            // 11th transfer should fail
            await expect(kwrc.connect(userA as any).transfer(userB.address, transferAmount)).to.be.reverted
        })

        it('Should enforce single transfer lower limit', async function () {
            const smallAmount = ethers.utils.parseEther('0.05') // Below lower limit

            await expect(kwrc.connect(userA as any).transfer(userB.address, smallAmount)).to.be.reverted
        })
    })

    describe('Access Control', function () {
        it('Should allow admin to mint', async function () {
            const mintAmount = ethers.utils.parseEther('100')

            await kwrc.connect(admin as any).mint(userA.address, mintAmount)
            expect(await kwrc.balanceOf(userA.address)).to.equal(initialBalance.add(mintAmount))
        })

        it('Should prevent non-admin from minting', async function () {
            const mintAmount = ethers.utils.parseEther('100')

            await expect(kwrc.connect(userA as any).mint(userB.address, mintAmount)).to.be.reverted
        })

        it('Should allow admin to burn', async function () {
            const burnAmount = ethers.utils.parseEther('10')

            await kwrc.connect(admin as any).burn(userA.address, burnAmount)
            expect(await kwrc.balanceOf(userA.address)).to.equal(initialBalance.sub(burnAmount))
        })

        it('Should prevent non-admin from burning', async function () {
            const burnAmount = ethers.utils.parseEther('10')

            await expect(kwrc.connect(userA as any).burn(userB.address, burnAmount)).to.be.reverted
        })
    })

    describe('Fee Management', function () {
        it('Should allow owner to update fee rate', async function () {
            const newFeeRate = 200 // 2%

            await kwrc.connect(owner as any).setFeeRate(newFeeRate)
            expect(await kwrc.feeRate()).to.equal(newFeeRate)
        })

        it('Should prevent non-owner from updating fee rate', async function () {
            const newFeeRate = 300

            await expect(kwrc.connect(userA as any).setFeeRate(newFeeRate)).to.be.reverted
        })

        it('Should allow owner to update fee manager', async function () {
            const newFeeManager = ethers.Wallet.createRandom().address

            await kwrc.connect(owner as any).setFeeManager(newFeeManager)
            expect(await kwrc.feeManager()).to.equal(newFeeManager)
        })

        it('Should prevent non-owner from updating fee manager', async function () {
            const newFeeManager = ethers.Wallet.createRandom().address

            await expect(kwrc.connect(userA as any).setFeeManager(newFeeManager)).to.be.reverted
        })
    })

    describe('Transfer Validation', function () {
        it('Should prevent transfer to zero address', async function () {
            await expect(
                kwrc.connect(userA as any).transfer(ethers.constants.AddressZero, ethers.utils.parseEther('10'))
            ).to.be.revertedWith('KWRC: transfer to the zero address')
        })
    })

    describe('LayerZero Integration', function () {
        it('Should have correct endpoint address', async function () {
            expect(await kwrc.endpoint()).to.equal(endpoint.address)
        })

        it('Should have correct delegate set', async function () {
            // The delegate should be set in the endpoint
            expect(await endpoint.delegate()).to.equal(delegate.address)
        })
    })
})
