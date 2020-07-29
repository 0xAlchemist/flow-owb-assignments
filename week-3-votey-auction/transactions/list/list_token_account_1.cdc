// This transaction creates a new Sale Collection object,
// lists an NFT for sale, puts it in account storage,
// and creates a public capability to the sale so that others can buy the token.

// Signer - Account 1 - 0x01cf0e2f2f715450

import NonFungibleToken from 0xe03daebed8ca0615
import FungibleToken from 0xee82856bf20e2aa6
import Marketplace from 0xf3fcd2c1a78f5eee

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - w00tcoin.cdc
// Acct 2 - 0x179b6b1cb6755e31 - rocks.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - marketplace.cdc
// Acct 4 - 0xe03daebed8ca0615 - onflow/NonFungibleToken.cdc

transaction {
    prepare(account: AuthAccount) {

        // borrow a reference to the signer's Vault
        let receiver = account.borrow<&{FungibleToken.Receiver}>(from: /storage/W00tCoinVault)
                              ?? panic("Unable to borrow a reference to the owner's vault")

        // create a new sale object     
        // initializing it with the reference to the owner's Vault
        let sale <- Marketplace.createSaleCollection(ownerVault: receiver)

        // borrow a reference to the NFT collection in storage
        let collectionRef = account.borrow<&NonFungibleToken.Collection>(from: /storage/RockCollection) 
                              ?? panic("Unable to borrow a reference to the NFT collection")

        // withdraw the NFT from the collection that you want to sell
        // and move it into the transaction's context
        let NFT <- collectionRef.withdraw(withdrawID: UInt64(1))

        // list the token for sale by moving it into the sale resource
        sale.listForSale(token: <-NFT, price: UFix64(10))

        // store the sale resource in the account for storage
        account.save(<-sale, to: /storage/NFTSale)

        // create a public capability to the sale so that others
        // can call it's methods
        account.link<&Marketplace.SaleCollection{Marketplace.SalePublic}>(
            /public/NFTSale,
            target: /storage/NFTSale
        )

        log("Sale created for account 1. Selling 1 NFT for 10 BrewCoins.")
    }
}
 