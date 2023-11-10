import "FungibleToken"
import "FlowToken"

pub contract CoinFlipUnsafe {
    pub fun play(tokens: @FungibleToken.Vault, call: String): @FungibleToken.Vault? {
        pre {
            call == "heads" || call == "tails": "can only call heads or tails!"
            tokens.balance == 1.0: "must bet one token to play"
            tokens.getType() == Type<@FlowToken.Vault>(): "can only bet flow tokens"
        }

        let bet <- tokens.withdraw(amount: tokens.balance)
        destroy tokens

        let rand = revertibleRandom()
        let coinFlipRes = rand % 2 == 0 ? "heads" : "tails"

        // caller won
        if coinFlipRes == call {
            let prize <- CoinFlipUnsafe.account.borrow<&{FungibleToken.Provider}>(from: /storage/flowTokenVault)!.withdraw(amount: 1.0)
            prize.deposit(from: <-bet)
            return <-prize
        } else {
            // caller lost
            CoinFlipUnsafe.account.borrow<&{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!.deposit(from: <-bet)
        }

        return nil
    }
}

