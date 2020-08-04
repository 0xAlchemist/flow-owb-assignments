
import NonFungibleToken from 0xe03daebed8ca0615

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - w00tcoin.cdc
// Acct 2 - 0x179b6b1cb6755e31 - rocks.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - marketplace.cdc
// Acct 4 - 0xe03daebed8ca0615 - onflow/NonFungibleToken.cdc
//

pub contract Rocks: NonFungibleToken {

    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64

        // TODO: Needs a rock type (minted with some rarity mechanism)
        pub var metaData: {String: String}

        init(initID: UInt64) {
            self.id = initID
            self.metaData = {}
        }
    }

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
            let token <- token as! @Rocks.NFT

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

        // mintNFT mints a new NFT with a new ID and deposits it into the recipients 
        // Collection using their Collection reference
        pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}) {

            // Create a new NFT
            var newNFT <- create NFT(initID: Rocks.totalSupply + UInt64(1))

            // Deposit it in the recipient's Collection using their reference
            recipient.deposit(token: <-newNFT)

            Rocks.totalSupply = Rocks.totalSupply + UInt64(1)
        }
    }

    init() {
        // initialize the totalSupply
        self.totalSupply = 0

        // create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: /storage/RockCollection)

        // create a public capability for the Collection
        self.account.link<&{NonFungibleToken.CollectionPublic}>(
            /public/RockCollection,
            target: /storage/RockCollection
        )

        // create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: /storage/RockMinter)

        emit ContractInitialized()
    }
}
 