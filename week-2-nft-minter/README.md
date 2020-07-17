# Week 2 Assignment | NFT Minter

Stones are a simple NFT for experimenting with Cadence.

The contract uses the NonFungibleToken standard from
https://github.com/onflow/flow-nft/contracts/ and
includes a method that sets the NFT metaData "type"
to a type of stone based on the current block height

# Setting Up

## Flow Playground

Playground link is not working due to an error with getCurrentBlock(), but the code can be found
at: https://play.onflow.org/0634e572-cd43-4d5c-95f8-3dde5a17f370

## VS Code Setup

Clone the git repo:
```git clone https://github.com/0xAlchemist/flow-owb-assignments```

Open the project folder:
```code ./flow-owb-assignments/week-2-nft-minter```

Deploy the onflow/NonFungibleToken.cdc contract to Account 1 (0x01cf0e2f2f715450)

Deploy the stones.cdc contract to Account 2 (0x179b6b1cb6755e31)

Mint approximately 20 NFTs with Account 2 
- Manually click "submit transaction with account 0x179b6b1cb6755e31"
- One NFT is minted with each click
- Each transaction increases the block height (important for this example)
- Check the console to see the token types being minted

Run the read_token_references.cdc script to see the NFT data

# Minting Rocks

## Rock Types

1. Coal
2. Jet
3. Pyrite
4. Diamond

The setRockType method uses the current block height to
select a value from a dictionary of rock types.

That rock type is then returned to the calling context
where it is used by the NFTMinter to create a new NFT

```
// setRockType takes the block height as an agrument and
// uses some simple math to pick a rock type for the asset.
// The rock type is returned to the calling context as a string.
access(self) fun setRockType(blockHeight: UInt64): String {
    let rockTypes = {
        1: "coal",
        2: "jet",
        3: "pyrite",
        4: "diamond"
    }
    
    // Set the initial rock type to 1 - most common
    var rockType = rockTypes[1]

    // If the block height is divisible by 5...
    if (blockHeight % UInt64(5) == UInt64(0)) {
        // .. change the rock type to '2' - uncommon
        rockType = rockTypes[2]
    }
    
    // If the block height is divisible by 10...
    if (blockHeight % UInt64(10) == UInt64(0)) {
        // .. change the rock type to '3' - rare
        rockType = rockTypes[3]
    }
    
    // If the block height is divisible by 15...
    if (blockHeight % UInt64(15) == UInt64(0)) {
        // .. change the rock type to '4' - rarest
        rockType = rockTypes[4]
    }

    // log the rock type to the console
    log("New stone minted:")
    log(rockType)

    return rockType 
        ?? panic("Unable to return a rock type!")
}
```

## Minting Method

The mintNFT method creates a new NFT with the rock type
returned from setRockType.

That new NFT is deposited into the recipient's collection
and the total supply is increased

```
// mintNFT mints a new NFT with a new ID and deposits it into the recipients 
// Collection using their Collection reference
pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}) {

    // get the current block
    let currentBlock = getCurrentBlock()

    // use the current block height to set the rock type
    let rockType = self.setRockType(blockHeight: currentBlock.height)

    // Create a new NFT
    var newNFT <- create NFT(initID: Stones.totalSupply, rockType: rockType)

    // Deposit it in the recipient's Collection using their reference
    recipient.deposit(token: <-newNFT)

    // Update the total supply count
    Stones.totalSupply = Stones.totalSupply + UInt64(1)
}
```