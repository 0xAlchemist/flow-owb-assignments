// This transaction loops through an array
// of NFT ids, borrows a reference to the NFT
// and logs it out

import NonFungibleToken from 0x01cf0e2f2f715450
import Stones from 0x179b6b1cb6755e31

pub fun main() {
    // Get the NFT holder's public account object
    let acct = getAccount(0x179b6b1cb6755e31)
    
    // Borrow a reference to the NFT holder's public collection capability
    let collectionRef = acct.getCapability(/public/StoneCollection)!.borrow<&{Stones.PublicCollectionMethods}>()
                            ?? panic("Unable to borrow capability from public collection")

    // Call the getRockTypes method on the collection reference to return 
    // a dictionary of NFT IDs and rock types
    let stoneIDs = collectionRef.getIDs()

    // for each id in the array...
    for stoneID in stoneIDs {

        // ... get the Stone NFT reference
        let stoneRef = collectionRef.borrowStone(id: stoneID)
            ?? panic("No stone at this ID")

        // ... get the NFT rock type
        let rockType = stoneRef.getRockType()

        // ... log the Stone id and rock type as a dictionary for formatting
        log({stoneID: rockType})
    }
}
 