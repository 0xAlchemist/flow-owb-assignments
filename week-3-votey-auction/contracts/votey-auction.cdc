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

        // The block number at the start of the auction
        pub var auctionStartBlock: UInt64

        // The last block number the updateAuction function was executed on
        pub var lastCheckedBlock: UInt64

        // The length of an auction in blocks
        pub var auctionLengthInBlocks: UInt64

        // The amount of blocks remaining in the current auction
        pub var blocksRemainingInAuction: UInt64

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
        access(contract) let bidVault: @FungibleToken.Vault

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
            self.auctionStartBlock = UInt64(0)
            self.lastCheckedBlock = self.auctionStartBlock
            self.auctionLengthInBlocks = UInt64(3600)
            self.blocksRemainingInAuction = self.auctionLengthInBlocks
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

        // issueBallot returns a new AuctionBallot resource to the calling context
        pub fun issueBallot(): @AuctionBallot {
            
            // create the new AuctionBallot
            let ballot <- create AuctionBallot(auctionRef: &self as &AuctionCollection)
            
            // add the AuctionBallot id to the auctionBallots dictionary with a nil value
            self.auctionBallots[ballot.id] = nil
            
            emit NewBallotIssued(auctionCollectionID: self.id, ballotID: ballot.id)

            return <- ballot
        }

        // castVote casts a vote using the provided AuctionBallot, sets the auctionBallots
        // key to the selected value and then destroys the used AuctionBallot resource
        pub fun castVote(ballot: @AuctionBallot, tokenID: UInt64) {
            
            // vote for the provided tokenID
            ballot.vote(tokenID: tokenID)

            // update the vote count for the token in the auctionQueueVotes dictionary
            self.auctionQueueVotes[tokenID] = self.auctionQueueVotes[tokenID]! + UInt64(1)

            // record the vote selection in the auctionBallots dictionary
            self.auctionBallots[ballot.id] = tokenID

            // destroy the AuctionBallot
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

        // getQueueVotes returns the auctionQueueVotes dictionary
        pub fun getQueueVotes(): {UInt64: UInt64} {
            return self.auctionQueueVotes
        }

        // getHighestVoteTokenID returns the tokenID with the highest vote count
        // or nil if there are no recorded votes
        pub fun getHighestVoteTokenID(): UInt64? {
            var tokenID: UInt64? = nil
            var highestCount: UInt64 = 0
            
            var counter: UInt64 = 0

            while counter < UInt64(self.auctionQueueVotes.keys.length) {
                if self.auctionQueueVotes[counter]! > highestCount {
                    highestCount = self.auctionQueueVotes[counter]
                                        ?? panic("auction queue is out of sync...")
                    tokenID = self.auctionQueueVotes.keys[counter]
                }
            }

            return tokenID
        }

        // getLowestQueuedTokenID returns the lowest ID value
        // in the auctionQueue
        pub fun getLowestQueuedTokenID(): UInt64 {
            var lowestID: UInt64 = self.auctionQueue.keys[0]
            
            for id in self.auctionQueue.keys {
                if id < lowestID {
                    lowestID = id
                }
            }

            return lowestID
        }

        // getNextTokenID returns the ID of the next token available for auction
        pub fun getNextTokenID(): UInt64 {
            let highestVotes = self.getHighestVoteTokenID()
            let lowestTokenID = self.getLowestQueuedTokenID()
            var nextTokenID: UInt64 = 0

            if highestVotes != nil {
                nextTokenID = highestVotes!
            } else {
                nextTokenID = lowestTokenID
            }

            return nextTokenID
        }

        // startAuction starts the auction
        pub fun startAuction(auctionID: UInt64) {
            
            // get the current Block data
            let currentBlock = getCurrentBlock()

            // set the auction start block to the current block height
            self.auctionStartBlock = currentBlock.height

            // set the current auction to 'active'
            VoteyAuction.activeAuctions[auctionID] = true

            // while the current auction is 'active'...
            while VoteyAuction.activeAuctions[auctionID] == true {
                
                // ... update the auction data
                self.updateAuction(currentBlockHeight: currentBlock.height)
                
            }
        }

        // updateAuction updates the auction state every time it receives a new block count
        pub fun updateAuction(currentBlockHeight: UInt64) {
            
            // if the current block was not already checked
            if currentBlockHeight != self.lastCheckedBlock {
                // ... set the remaining block count
                self.blocksRemainingInAuction = (self.auctionStartBlock + self.auctionLengthInBlocks) - currentBlockHeight

                // if there are no more blocks remaining in the auction...
                if self.blocksRemainingInAuction == UInt64(0) {
                    // ... settle the auction
                    self.settleAuction()

                }

            }
            
            // update the last checked block to the current block height
            self.lastCheckedBlock = currentBlockHeight
        }

        pub fun settleAuction() {

            // if there are more NFTs in the auction queue...
            if self.auctionQueue.keys.length > 0 {
                
                // get the next token ID
                let nextTokenID = self.getNextTokenID()
                
                // get the completed auction item and replace it with the next token from the queue
                let purchasedNFT <- self.currentAuctionItem[0] <- self.auctionQueue.remove(key: nextTokenID)!

                // send the completed auction item to the highest bidder
                self.recipientNFTReceiverRef.deposit(token: <-purchasedNFT)

                // set the start block for the new auction to the current block
                self.auctionStartBlock = getCurrentBlock().height

                // reset the auction's remaining block count
                self.blocksRemainingInAuction = self.auctionLengthInBlocks

            } else {

                // send the NFT to the highest bidder
                let purchasedNFT <- self.currentAuctionItem.remove(at: 0)
                self.recipientNFTReceiverRef.deposit(token: <-purchasedNFT)
                
            }

            // send the bid tokens to the NFT seller
            let bidBalance <- self.bidVault.withdraw(amount: self.bidVault.balance)
            self.recipientFTReceiverRef.deposit(from: <-bidBalance)

        }

        // endAuction deactivates the auction and stops the updateAuction loop
        pub fun endAuction(auctionID: UInt64) {
            VoteyAuction.activeAuctions[auctionID] = false
        }

        // withdrawTokenFromQueue gives the owner the opportunity to remove a sale from the auction queue
        // BEFORE the token is up for auction
        pub fun withdrawTokenFromQueue(tokenID: UInt64): @NonFungibleToken.NFT {
            // remove the price
            self.auctionQueuePrices.remove(key: tokenID)

            // remove the votes
            self.auctionQueueVotes.remove(key: tokenID)

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

    // An AuctionBallot is minted to each bidder. They are used to
    // cast votes for the next available NFT from the auction queue.
    // The NFT with the highest vote count will be next up for auction.
    pub resource AuctionBallot {

         // an ID used to track the ballot
         pub let id: UInt64
         
         // a reference to the AuctionCollections the Ballot belongs to
         pub let auctionRef: &AuctionCollection

         // a dictionary containing token IDs from the AuctionCollection's
         // auctionQueue and a boolean value to track the selection
         pub var selection: {UInt64: Bool}
    
         init(auctionRef: &AuctionCollection) {
            self.auctionRef = auctionRef
            self.id = UInt64(self.auctionRef.auctionBallots.keys.length)
            self.selection = {}
         }

         // vote allows the ballot holder to make a selection 
         // from the auctionQueue
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

        return <- auctionCollection
    }

    init() {
        self.activeAuctions = {}
    }
}
 