// This transaction loops through an array
// of NFT ids, borrows a reference to the NFT
// and logs it out

import NonFungibleToken from 0x01cf0e2f2f715450
import Stones from 0x179b6b1cb6755e31

pub fun main() {
    // Get the NFT holder's public account object
    let acct = getAccount(0x179b6b1cb6755e31)
    
    // Borrow a reference to the NFT holder's public collection capability
    let collectionRef = acct.getCapability(/public/StoneCollection)!.borrow<&{NonFungibleToken.CollectionPublic}>()
                            ?? panic("Unable to borrow capability from public collection")

    // Call the getIDs method to return an array of NFT IDs
    let stones = collectionRef.getIDs()

    // For each NFT id in the array...
    for stone in stones {
        // .. log the reference
        log(collectionRef.borrowNFT(id: stone))

        // NOTE: I'm having trouble figuring out
        // how to read the NFT's metadata or call
        // the getRockType() method. I gather it's
        // because the reference is being passed
        // as a @NonFungibleToken.NFT and not a
        // @Stones.NFT
        //
        // I've left it as-is to conform to the NFT
        // standard, but need to wrap my head around
        // this :)
    }
}