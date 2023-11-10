import "TransactionScheduler"
import "FungibleToken"
import "FlowToken"

pub contract CoinFlipSafe {
    // ...

    pub let bets: @{UInt64: Bet}

    pub fun toss(tokens: @FungibleToken.Vault, call: String, receiver: Capability<&{FungibleToken.Receiver}>) {
        let bet <- create Bet(tokens: <-tokens, call: call, receiver: receiver)

        let uuid = bet.uuid

        destroy CoinFlipSafe.bets.insert(key: uuid, <-bet)

        let executable <- create TossExecutable(betID: uuid)
        CoinFlipSafe.account.borrow<&TransactionScheduler.Container>(from: TransactionScheduler.ContainerStoragePath)!.schedule(
            executable: <- executable,
            payment: <-FlowToken.createEmptyVault(),
            runAfter: nil,
            expiresOn: nil,
            runnableBy: nil
        )
    }

    pub resource TossExecutable: TransactionScheduler.Executable {
        pub let betID: UInt64

        pub fun execute() {
            CoinFlipSafe.betCallback(self.betID)
        }

        init(betID: UInt64) {
            self.betID = betID
        }
    }

    pub resource Bet {
        pub let tokens: @FungibleToken.Vault
        pub let call: String
        pub let receiver: Capability<&{FungibleToken.Receiver}>

        init( tokens: @FungibleToken.Vault, call: String, receiver: Capability<&{FungibleToken.Receiver}> ) {
            pre {
                call == "heads" || call == "tails": "can only call heads or tails!"
                tokens.balance == 1.0: "must bet one token to play"
                tokens.getType() == Type<@FlowToken.Vault>(): "can only bet flow tokens"
            }
            self.tokens <- tokens
            self.call = call
            self.receiver = receiver
        }

        destroy () {
            destroy self.tokens
        }
    }

    access(contract) fun betCallback(_ betID: UInt64) {
        let bet <- CoinFlipSafe.bets.remove(key: betID) ?? panic("bet not found")
        let tokens <- bet.tokens.withdraw(amount: bet.tokens.balance)

        let rand = revertibleRandom()
        let coinFlipRes = rand % 2 == 0 ? "heads" : "tails"

        // caller won
        if coinFlipRes == bet.call {
            let prize <- CoinFlipSafe.account.borrow<&{FungibleToken.Provider}>(from: /storage/flowTokenVault)!.withdraw(amount: 1.0)
            prize.deposit(from: <-tokens)

            bet.receiver.borrow()!.deposit(from: <-prize)            
        } else {
            // caller lost
            CoinFlipSafe.account.borrow<&{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!.deposit(from: <-tokens)
        }

        
        destroy bet
    }


    init() {
        self.bets <- {}
    }
}