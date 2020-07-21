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

    // Call the getRockTypeCount method on the collection reference to return 
    // a dictionary of rock type options and the total amount of minted NFTs of that type 
    let rockTypeCount = collectionRef.getRockTypeCount()
    log(rockTypeCount)
}
 