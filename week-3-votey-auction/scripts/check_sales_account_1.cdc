// This script prints the NFTs that account 1 has for sale.

import Marketplace from 0xf3fcd2c1a78f5eee

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - w00tcoin.cdc
// Acct 2 - 0x179b6b1cb6755e31 - rocks.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - marketplace.cdc
// Acct 4 - 0xe03daebed8ca0615 - onflow/NonFungibleToken.cdc

pub fun main() {
    // get the public account object for account 1
    let account1 = getAccount(0x01cf0e2f2f715450)

    // find the public Sale Collection capability
    let account1SaleRef = account1.getCapability(/public/NFTSale)!
                                  .borrow<&{Marketplace.SalePublic}>()
                                  ?? panic("unable to borrow a reference to the sale collection for account 1")

    // Log the NFTs that are for sale
    log("Account 1 NFTs for sale")
    log(account1SaleRef.getIDs())
    log("Price of NFT 1")
    log(account1SaleRef.idPrice(tokenID: 1))
}
