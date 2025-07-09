import fs from 'fs'
import path from 'path'

// No Addressable in ethers v5 types
type AddressLike = string

const basePath = __dirname
const base = path.join(basePath, '../')

const makeFile = async (location: string, destination: string, address: AddressLike) => {
    try {
        const destinationPath = path.join(base, destination)
        console.log('Generating ABI file at:', destinationPath)

        const json = fs.readFileSync(path.join(base, location), {
            encoding: 'utf-8',
        })

        fs.writeFileSync(destinationPath, makeData(json, address))
    } catch (e) {
        console.error('❌ Failed to generate ABI file:', e)
    }
}

const makeData = (json: string, address: AddressLike) => {
    const abi = JSON.parse(json).abi

    return JSON.stringify(
        {
            abi,
            address: address.toString(),
        },
        null,
        2 // pretty-printed
    )
}

export const makeAbi = async (contract: string, address: AddressLike) => {
    await makeFile(`/artifacts/contracts/${contract}.sol/${contract}.json`, `/abis/${contract}.json`, address)
}
