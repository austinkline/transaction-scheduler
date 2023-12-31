import "TransactionScheduler"
import "FungibleToken"

pub contract ExecutableExamples {
    pub resource TokenTransferExecutable: TransactionScheduler.Executable {
        access(self) var tokens: @FungibleToken.Vault
        pub let destinaton: Capability<&{FungibleToken.Receiver}>

        pub fun execute() {
            let receiver = self.destinaton.borrow() ?? panic("receiver not valid")
            receiver.deposit(from: <-self.tokens.withdraw(amount: self.tokens.balance))
        }

        init(
            tokens: @FungibleToken.Vault,
            destinaton: Capability<&{FungibleToken.Receiver}>
        ) {
            self.tokens <- tokens
            self.destinaton = destinaton
        }

        destroy () {
            destroy self.tokens
        }
    }

    pub fun createTokenTransferExecutable(
        tokens: @FungibleToken.Vault,
        destinaton: Capability<&{FungibleToken.Receiver}>
    ): @TokenTransferExecutable {
        return <- create TokenTransferExecutable(tokens: <-tokens, destinaton: destinaton)
    }
}