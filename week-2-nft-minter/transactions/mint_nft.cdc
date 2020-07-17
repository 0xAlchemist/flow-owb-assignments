// This script uses the NFTMinter resource to mint a new NFT
// It must be run with the account that has the minter resource
// stored in /storage/NFTMinter

import NonFungibleToken from 0x01cf0e2f2f715450
import Stones from 0x179b6b1cb6755e31

transaction {

    // local variable for storing the Minter reference
    let minter: &Stones.NFTMinter

    prepare(signer: AuthAccount) {

        // borrow a reference to the NFTMinter resource in storage
        self.minter = signer.borrow<&Stones.NFTMinter>(from: /storage/StoneMinter)
                        ?? panic("Could not borrow a reference to the NFT minter")
    }

    execute {
        // Get the public account object for the recipient
        let recipient = getAccount(0x179b6b1cb6755e31)

        // Borrow the recipient's public NFT Collection reference
        let receiver = recipient
                        .getCapability(/public/StoneCollection)!
                        .borrow<&{NonFungibleToken.CollectionPublic}>()
                        ?? panic("Could not borrow a reference to the Stone collection")

        // Mint the NFT and deposit it to the recipient's collection
        self.minter.mintNFT(recipient: receiver)
    }
}