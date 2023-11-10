# Transaction Scheduler

[![codecov](https://codecov.io/gh/austinkline/transaction-scheduler/graph/badge.svg?token=M62XXCBLXK)](https://codecov.io/gh/austinkline/transaction-scheduler)

This contract is the base layer of a system that lets transactions queue other pieces of work to be executed by anyone else at a later date.
Creators of Jobs must implement a resource of their own which implements the `Executable` interface, and submit a bounty in exchange for the job
being run by another party. Whoever runs the job successfully will receive the bounty.

## Why?

There are many forms of products which want to allow separating actions into two steps. For example, maybe you want to
implement a coin flip game, but don't want someone to be able to force the outcome by doing their coinflip, then reverting their
transaction if they didn't guess the coinflip correctly.

```cadence
import "CoinFlip"
import "FungibleToken"

transaction {
    prepare(acct: AuthAccount) {
        let receiver = acct.borrow<&{FungibleToken.Receiver, FungibleToken.Balance}>(from: /storage/flowTokenVault)
        let provider = acct.borrow<&{FungibleToken.Provider}>(from: /storage/flowTokenVault)

        let balanceBefore = receiver.balance

        let bet <- provider.withdraw(amount: 1.0)
        CoinFlip.toss(bet: <-bet, call: "heads", rewardReceiver: receiver)

        let balanceAfter = receiver.balance

        assert(balanceAfter > balanceBefore, message: "would have lost the coinflip")
    }
}
```

In the above example, a hypothetical game which lets you bet on the outcome of a cointoss, then force its result if you do not win.
With transaction scheduling, the Coinflip game could schedule the actual toss to happen in a separate transaction. By taking this approach, 
the CoinFlip game can prevent the previous example entirely. It might look something like the following:

```cadence
import "CoinFlip"
import "FungibleToken"

transaction {
    prepare(acct: AuthAccount) {
        let receiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)

        let balance = acct.borrow<&{FungibleToken.Balance}>(from: /storage/flowTokenVault)
        let provider = acct.borrow<&{FungibleToken.Provider}>(from: /storage/flowTokenVault)

        let balanceBefore = balance.balance

        let tokens <- provider.withdraw(amount: 1.0)
        CoinFlip.toss(tokens: <-tokens, call: "heads", rewardReceiver: receiver)

        let balanceAfter = balance.balance

        assert(balanceAfter > balanceBefore, message: "would have lost the coinflip")
    }
}

// CoinFlip.cdc
import "TransactionScheduler"

pub contract CoinFlip {
    // ...

    pub let bets: @{UInt64: Bet}

    pub fun toss(tokens: @FungibleToken.Vault, call: String, receiver: Capability<&{FungibleToken.Receiver}>) {
        let bet <- create Bet(tokens: <-tokens, call: call, receiver: receiver)

        let uuid = bet.uuid

        destroy CoinFlip.bets.insert(key: uuid, value: <-bet)

        let executable <- create TossExecutable(betID: uuid)
        CoinFlip.account.borrow<&TransactionScheduler.Container>(from: TransactionScheduler.ContainerStoragePath)!.createJob(
            executable: <- executable
            // ...
        )
    }

    pub resource Bet {
        tokens: @FungibleToken.Vault
        call: String
        receiver: Capability<&{FungibleToken.Receiver}>

        init( ... ) {
            // ...
        }
    }

    pub resource TossExecutable: TransactionScheduler.Executable {
        pub let betID: UInt64

        pub fun execute() {
            betCallback(self.betID)
        }

        init(betID: UInt64) {
            self.betID = betID
        }
    }

    pub fun betCallback(betID: UInt64) {
        // do the coinflip here
    }


    init() { ... }
}
```