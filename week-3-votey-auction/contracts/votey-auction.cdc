// VoteyAuction.cdc
//
// The VoteyAuction contract is a sample implementation of an NFT VoteyAuction on Flow.
//
// This contract allows users to put their NFTs up for sale. Other users
// can purchase these NFTs with fungible tokens.
//
import FungibleToken from 0xee82856bf20e2aa6
import NonFungibleToken from 0xe03daebed8ca0615

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - w00tcoin.cdc
// Acct 2 - 0x179b6b1cb6755e31 - rocks.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - votey-auction.cdc
// Acct 4 - 0xe03daebed8ca0615 - onflow/NonFungibleToken.cdc
//

pub contract VoteyAuction {

    pub var activeAuctions: {UInt64: Bool}

    // Event that is emitted when a new NFT is added to the auction collection
    pub event TokenAddedToAuctionQueue(id: UInt64, price: UFix64)

    // Event that is emitted when a NFT receives a vote
    pub event VoteSubmitted(id: UInt64, voteCount: UInt64)

    // Event that is emitted when a new NFT is up for auction
    pub event NewAuctionStarted(id: UInt64, startPrice: UFix64)

    // Event that is emitted when the price of the NFT that is currently up for auction changes
    pub event AuctionPriceChanged(id: UInt64, newPrice: UFix64)

    // Event that is emitted when a new AuctionBallot is issued
    pub event NewBallotIssued(auctionCollectionID: UInt64, ballotID: UInt64)
    
    // Event that is emitted when the start price of an NFT in the auction queue changes
    pub event StartPriceChanged(id: UInt64, newPrice: UFix64)

    // Event that is emitted when a token is purchased
    pub event TokenPurchased(id: UInt64, price: UFix64)

    // Event that is emitted when a seller withdraws their token from the auction collection
    pub event TokenWithdrawn(id: UInt64)

    // Interface that users will publish for their Auction collection
    // that only exposes the methods that are supposed to be public
    pub resource interface AuctionPublic {
        pub fun bid(
            bidTokens: @FungibleToken.Vault,
            recipientNFTReceiverRef: &AnyResource{NonFungibleToken.Receiver},
            recipientFTReceiverRef: &AnyResource{FungibleToken.Receiver}
        )
        pub fun queueIDPrice(tokenID: UInt64): UFix64?
        pub fun queueIDVotes(tokenID: UInt64): UInt64?
        pub fun getQueueIDs(): [UInt64]
        pub fun getQueueVotes(): {UInt64: UInt64}
    }

    // AuctionCollection
    //
    // NFT Collection object that allows a user to put their NFT up for sale
    // where others can send fungible tokens to purchase it
    //
    pub resource AuctionCollection: AuctionPublic {

        // The Auction collection ID
        pub var id: UInt64

        // Dictionary of the NFTs that the user is putting up for sale
        pub var currentAuctionItem: @[NonFungibleToken.NFT]

        // The price of the current NFT
        pub var currentPrice: UFix64

        // The minimum bid increment
        pub var minimumBid: UFix64

        // The FungibleToken Receiver for the current recipient
        // - used to return the balance from the bidVault if the price is outbid
        pub var recipientFTReceiverRef: &AnyResource{FungibleToken.Receiver}

        // The NFT Receiver for the current recipient
        // - used to deposit the NFT to the auction winner
        pub var recipientNFTReceiverRef: &AnyResource{NonFungibleToken.Receiver}

        // Dictionairy of NFTs coming up for auction
        pub var auctionQueue: @{UInt64: NonFungibleToken.NFT}
        
        // Dictionary of prices for each NFT in the auction queue by ID
        pub var auctionQueuePrices: {UInt64: UFix64}

        // Dictionary of votes for each NFT in the auction queue by ID
        pub var auctionQueueVotes: {UInt64: UInt64}

        // Dictionary of active AuctionBallot IDs and their selected token
        pub var auctionBallots: {UInt64: UInt64}

        // The fungible token vault of the owner of this sale.
        // When someone buys a token, this resource can deposit
        // tokens into their account.
        access(account) let ownerVault: &AnyResource{FungibleToken.Receiver}

        // Vault that holds the tokens for the current bid
        access(contract) var bidVault: @FungibleToken.Vault

        init(
            ownerVault: &AnyResource{FungibleToken.Receiver},
            bidVault: @FungibleToken.Vault,
            tempFTVault: &AnyResource{FungibleToken.Receiver},
            tempNFTVault: &AnyResource{NonFungibleToken.Receiver}
        ) {
            self.id = UInt64(VoteyAuction.activeAuctions.values.length)
            self.currentAuctionItem <- []
            self.currentPrice = UFix64(0)
            self.minimumBid = UFix64(0.05)
            self.recipientFTReceiverRef = tempFTVault
            self.recipientNFTReceiverRef = tempNFTVault
            self.auctionQueue <- {}
            self.auctionQueuePrices = {}
            self.auctionQueueVotes = {}
            self.auctionBallots = {}
            self.ownerVault = ownerVault
            self.bidVault <- bidVault
        }

        // purchase lets a user send tokens to purchase an NFT that is for sale
        pub fun bid(
            bidTokens: @FungibleToken.Vault,
            recipientNFTReceiverRef: &AnyResource{NonFungibleToken.Receiver},
            recipientFTReceiverRef: &AnyResource{FungibleToken.Receiver}
        ) {
            
            pre {
                self.currentAuctionItem.length != 0 && self.currentPrice != nil:
                    "No token is up for auction!"
                bidTokens.balance >= (self.currentPrice + self.minimumBid):
                    "Not enough tokens to bid on the NFT!"
            }

            // withdraw the tokens from the bidVault
            let oldBalance <- self.bidVault.withdraw(amount: self.bidVault.balance)
            
            // return them to the previous bidder
            self.recipientFTReceiverRef.deposit(from: <-oldBalance)

            // get th ebid amount before the resource is moved  
            let bidAmount = bidTokens.balance
            
            // deposit the purchasing tokens into the contract's bidVault
            self.bidVault.deposit(from: <-bidTokens)

            // store the recipient's FT receiver reference
            self.recipientFTReceiverRef = recipientFTReceiverRef

            // store the recipient's NFT receiver reference
            self.recipientNFTReceiverRef = recipientNFTReceiverRef
            
            emit AuctionPriceChanged(id: self.currentAuctionItem[0].id, newPrice: bidAmount)
        }

        pub fun issueBallot(): @AuctionBallot {
            
            let ballot <- create AuctionBallot(auctionRef: &self as &AuctionCollection)

            self.auctionBallots[ballot.id] = nil
            
            emit NewBallotIssued(auctionCollectionID: self.id, ballotID: ballot.id)

            return <- ballot
        }

        pub fun castVote(ballot: @AuctionBallot, tokenID: UInt64) {

            ballot.vote(tokenID: tokenID)

            self.auctionQueueVotes[tokenID] = self.auctionQueueVotes[tokenID]! + UInt64(1)

            destroy ballot
        }

        // queueIDPrice returns the start price of a specific token in the auction queue
        pub fun queueIDPrice(tokenID: UInt64): UFix64? {
            return self.auctionQueuePrices[tokenID]
        }

        // queueIDVotes returns the votes for a specific token in the auction queue
        pub fun queueIDVotes(tokenID: UInt64): UInt64? {
            return self.auctionQueueVotes[tokenID]
        }

        // getQueueIDs returns an array of all token IDs that are for sale
        pub fun getQueueIDs(): [UInt64] {
            return self.auctionQueue.keys
        }

        pub fun getQueueVotes(): {UInt64: UInt64} {
            return self.auctionQueueVotes
        }

        // withdrawTokenFromQueue gives the owner the opportunity to remove a sale from the auction queue
        // BEFORE the token is up for auction
        pub fun withdrawTokenFromQueue(tokenID: UInt64): @NonFungibleToken.NFT {
            // remove the price
            self.auctionQueuePrices.remove(key: tokenID)

            //remove and return the token
            let token <- self.auctionQueue.remove(key: tokenID) ?? panic("Missing NFT")
            return <-token
        }

        // addToQueue lists an NFT for auction by adding it to the queue
        pub fun addTokenToQueue(token: @NonFungibleToken.NFT, startPrice: UFix64) {
            // store the token ID
            let id = token.id

            // store the price in the price array
            self.auctionQueuePrices[id] = startPrice

            self.auctionQueueVotes[id] = UInt64(0)
            
            // put the NFT into the forSale dictionary
            let oldToken <- self.auctionQueue[id] <- token
            destroy oldToken

            emit TokenAddedToAuctionQueue(id: id, price: startPrice)
        }

        // changePrice changes the price of a token that is currently for sale
        pub fun changeStartPrice(tokenID: UInt64, newPrice: UFix64) {
            self.auctionQueuePrices[tokenID] = newPrice

            emit StartPriceChanged(id: tokenID, newPrice: newPrice)
        }

        destroy() {
            destroy self.currentAuctionItem
            destroy self.auctionQueue
            destroy self.bidVault
        }
    }

    pub resource AuctionBallot {

         pub let id: UInt64
         
         pub let auctionRef: &AuctionCollection

         pub var selection: {UInt64: Bool}
    
         init(auctionRef: &AuctionCollection) {
            self.auctionRef = auctionRef
            self.id = UInt64(self.auctionRef.auctionBallots.keys.length)
            self.selection = {}
         }

         pub fun vote(tokenID: UInt64) {
            pre {
                self.auctionRef.auctionQueue[tokenID] != nil:
                "Can't vote for a token that doesn't exist"
            }
            self.selection[tokenID] = true
         }
    }

    // createAuctionCollection returns a new collection resource to the caller
    pub fun createAuctionCollection(
        ownerVault: &AnyResource{FungibleToken.Receiver},
        bidVault: @FungibleToken.Vault,
        tempFTReceiverRef: &AnyResource{FungibleToken.Receiver},
        tempNFTReceiverRef: &AnyResource{NonFungibleToken.Receiver}
    ): @AuctionCollection {

        let auctionCollection <- create AuctionCollection(
            ownerVault: ownerVault, 
            bidVault: <-bidVault, 
            tempFTVault: tempFTReceiverRef, 
            tempNFTVault: tempNFTReceiverRef
        )
        
        self.activeAuctions[auctionCollection.id] = true

        return <- auctionCollection
    }

    init() {
        self.activeAuctions = {}
    }
}
 