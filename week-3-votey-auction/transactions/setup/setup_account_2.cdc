// This transaction adds an empty Vault to Account 2
// and mints an NFT with id=1 that is deposited into
// the NFT collection on Account 1.

// Signer: Account 2 - 0xf3fcd2c1a78f5eee

import FungibleToken from 0xee82856bf20e2aa6
import NonFungibleToken from 0xe03daebed8ca0615
import W00tCoin from 0x01cf0e2f2f715450
import Rocks from 0x179b6b1cb6755e31

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - w00tcoin.cdc
// Acct 2 - 0x179b6b1cb6755e31 - rocks.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - marketplace.cdc
// Acct 4 - 0xe03daebed8ca0615 - onflow/NonFungibleToken.cdc

transaction{

    // private reference to this account's minter resource
    let minterRef: &Rocks.NFTMinter
    
    prepare(acct: AuthAccount) {
        
        // create a new empty Vault resource
        let vaultA <- W00tCoin.createEmptyVault()

        // store the vault in the accout storage
        acct.save<@FungibleToken.Vault>(<-vaultA, to: /storage/W00tCoinVault)

        // create a public Receiver capability to the Vault
        acct.link<&W00tCoin.Vault{FungibleToken.Receiver}>(
            /public/W00tCoinReceiver,
            target: /storage/W00tCoinVault
        )

        // create a public Balance capability to the Vault
        acct.link<&W00tCoin.Vault{FungibleToken.Balance}>(
            /public/W00tCoinBalance,
            target: /storage/W00tCoinVault
        )

        log("Created a Vault and published the references")

        // borrow a reference to the NFTMinter in storage
        self.minterRef = acct.borrow<&Rocks.NFTMinter>(from: /storage/RockMinter)
            ?? panic("Could not borrow owner's vault minter reference")
        
    }

    execute {
        // Get the recipient's public account object
        let recipient = getAccount(0x01cf0e2f2f715450)

        // get the collection reference for the receiver
        // getting the public capability and borrowing the reference from it
        let receiverRef = recipient.getCapability(/public/RockCollection)!
                                   .borrow<&{NonFungibleToken.CollectionPublic}>()
                                   ?? panic("unable to borrow nft receiver reference")

        // mint an NFT and deposit it in the receiver's collection
        self.minterRef.mintNFT(recipient: receiverRef)

        log("New NFT minted for account 1")
    }
}
 