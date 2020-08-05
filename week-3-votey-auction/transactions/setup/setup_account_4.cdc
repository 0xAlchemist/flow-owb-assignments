// This transaction adds an empty Vault
// and Rock Collection to Account 4

// Signer: Account 4 - 0xe03daebed8ca0615

import FungibleToken from 0xee82856bf20e2aa6
import NonFungibleToken from 0xe03daebed8ca0615
import DemoToken from 0x01cf0e2f2f715450
import Rocks from 0x179b6b1cb6755e31

// somefink

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - demo-token.cdc
// Acct 2 - 0x179b6b1cb6755e31 - rocks.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - votey-auction.cdc
// Acct 4 - 0xe03daebed8ca0615 - onflow/NonFungibleToken.cdc

transaction{
    
    prepare(acct: AuthAccount) {
        
        // create a new empty Vault resource
        let vaultA <- DemoToken.createEmptyVault()

        // store the vault in the accout storage
        acct.save<@FungibleToken.Vault>(<-vaultA, to: /storage/DemoTokenVault)

        // create a public Receiver capability to the Vault
        acct.link<&DemoToken.Vault{FungibleToken.Receiver}>(
            /public/DemoTokenReceiver,
            target: /storage/DemoTokenVault
        )

        // create a public Balance capability to the Vault
        acct.link<&DemoToken.Vault{FungibleToken.Balance}>(
            /public/DemoTokenBalance,
            target: /storage/DemoTokenVault
        )

        log("Created a Vault and published the references")

        // create a new empty Rock Collection
        let NFTCollecton <- Rocks.createEmptyCollection()

        // store the Collection in account storage
        acct.save<@NonFungibleToken.Collection>(<-NFTCollecton, to: /storage/RockCollection)

        // create a public CollectionPublic capability to the Rock Collection
        acct.link<&NonFungibleToken.Collection{NonFungibleToken.CollectionPublic}>(
            /public/RockCollection,
            target: /storage/RockCollection
        )


        log("Created a Rock Collection and published the references")

        log("Account 4 is ready to Rock and w00t!")        
    }
}
 