// Stones are a simple NFT for experimenting with Cadence.
// The contract uses the NonFungibleToken standard from
// https://github.com/onflow/flow-nft/contracts/ and
// includes a method that sets the NFT metaData "type"
// to a type of stone based on the current block height

// Flow Playground (Not Working with Block.height)
// https://play.onflow.org/0634e572-cd43-4d5c-95f8-3dde5a17f370

import NonFungibleToken from 0x01cf0e2f2f715450

// VS Code | Emulator Account Setup
//
// Acct 1 - 0x01cf0e2f2f715450 - NonFungibleToken.cdc
// Acct 2 - 0x179b6b1cb6755e31 - stones.cdc
//
pub contract Stones: NonFungibleToken {

    // totalSupply of Stones NFTs
    pub var totalSupply: UInt64

    // The event that emits when the contract has been initialized
    pub event ContractInitialized()

    // Event that emits when a stone has been withdrawn from a collection
    pub event Withdraw(id: UInt64, from: Address?)

    // Event that emits when a stone has been deposited to a collection
    pub event Deposit(id: UInt64, to: Address?)

    // The stone NFT resource
    pub resource NFT: NonFungibleToken.INFT {
        
        // the stone's ID
        pub let id: UInt64

        // a dictionary for storing the stone's meta data
        pub var metaData: {String: String}

        init(initID: UInt64, rockType: String) {
            
            // Set the initial ID
            self.id = initID

            // Set the rock type to the provided value
            self.metaData = {
                "type": rockType
            }
        }

        // getRockType returns the rock type as a string
        pub fun getRockType(): String {
            return self.metaData["rockType"]
                ?? panic("Stone has no rock type!")
        }
    }

    // Collection is a resource that contains the stone NFTs and provides secure methods for the deposit,
    // withdrawal and management of the stones in the collection
    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with a 'UInt64' ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the Collection and provides it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes an NFT and adds it to the collections dictionary
        // adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @Stones.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty Collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {

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
    }

    init() {
        // initialize the totalSupply
        self.totalSupply = 0

        // create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: /storage/StoneCollection)

        // create a public capability for the Collection
        self.account.link<&{NonFungibleToken.CollectionPublic}>(
            /public/StoneCollection,
            target: /storage/StoneCollection
        )

        // create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: /storage/StoneMinter)

        emit ContractInitialized()
    }
}
 