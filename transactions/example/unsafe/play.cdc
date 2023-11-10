import "CoinFlipUnsafe"
import "FungibleToken"

transaction {
    prepare(acct: AuthAccount) {
        let vault 
            = acct.borrow<&{FungibleToken.Provider, FungibleToken.Receiver}>(from: /storage/flowTokenVault)!
        let tokens <- vault.withdraw(amount: 1.0)
        let winnings <- CoinFlipUnsafe.play(tokens: <-tokens, call: "heads")
            ?? panic("do not permit losing")
        vault.deposit(from: <-winnings)
    }
}




