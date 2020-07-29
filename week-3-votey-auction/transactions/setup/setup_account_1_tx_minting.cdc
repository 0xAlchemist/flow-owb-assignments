// This transaction mints tokens for Accounts 1 and 2 using
// the minter stored on Account 1.

// Signer: Account 1 - 0x01cf0e2f2f715450

import FungibleToken from 0xee82856bf20e2aa6
import W00tCoin from 0x01cf0e2f2f715450

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - w00tcoin.cdc
// Acct 2 - 0x179b6b1cb6755e31 - rocks.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - marketplace.cdc
// Acct 4 - 0xe03daebed8ca0615 - onflow/NonFungibleToken.cdc

transaction {

    // public Vault reciever references for both accounts
    let acct1Ref: &AnyResource{FungibleToken.Receiver}
    let acct2Ref: &AnyResource{FungibleToken.Receiver}

    // reference to the W00tCoin administrator
    let adminRef: &W00tCoin.Administrator
    let minterRef: &W00tCoin.Minter
    
    prepare(acct: AuthAccount) {
        // get the public object for Account 2
        let account2 = getAccount(0x179b6b1cb6755e31)

        // retreive the public vault references for both accounts
        self.acct1Ref = acct.getCapability(/public/W00tCoinReceiver)!
                        .borrow<&{FungibleToken.Receiver}>()
                        ?? panic("Could not borrow owner's vault reference")
                        
        self.acct2Ref = account2.getCapability(/public/W00tCoinReceiver)!
                        .borrow<&{FungibleToken.Receiver}>()
                        ?? panic("Could not borrow Account 2's vault reference")
        
        // borrow a reference to the Administrator resource in Account 2
        self.adminRef = acct.borrow<&W00tCoin.Administrator>(from: /storage/W00tCoinAdmin)
                            ?? panic("Signer is not the token admin!")
        
        // create a new minter and store it in account storage
        let minter <-self.adminRef.createNewMinter(allowedAmount: UFix64(100))
        acct.save<@W00tCoin.Minter>(<-minter, to: /storage/W00tCoinMinter)

        // create a capability for the new minter
        let minterRef = acct.link<&W00tCoin.Minter>(
            /public/W00tCoinMinter,
            target: /storage/W00tCoinMinter
        )

        // get the stored Minter reference from account 2
        self.minterRef = acct.borrow<&W00tCoin.Minter>(from: /storage/W00tCoinMinter)
            ?? panic("Could not borrow owner's vault minter reference")
    }

    execute {
        // mint tokens for both accounts
        self.acct1Ref.deposit(from: <-self.minterRef.mintTokens(amount: UFix64(40)))
        self.acct2Ref.deposit(from: <-self.minterRef.mintTokens(amount: UFix64(20)))

        log("Minted new W00tCoins for accounts 1 and 2")
    }
}
 