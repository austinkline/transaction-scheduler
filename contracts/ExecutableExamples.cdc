import "TransactionScheduler"
import "FungibleToken"

pub contract ExecutableExamples {
    pub event BasicExecuted(id: UInt64, message: String)

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

    pub resource BasicExecutable: TransactionScheduler.Executable {
        access(self) let message: String

        pub fun execute() {
            emit BasicExecuted(id: self.uuid, message: self.message)
        }

        init(message: String) {
            self.message = message
        }
    }

    pub fun createBasicExecutable(message: String): @BasicExecutable {
        return <- create BasicExecutable(message: message)
    }

    pub fun createTokenTransferExecutable(
        tokens: @FungibleToken.Vault,
        destinaton: Capability<&{FungibleToken.Receiver}>
    ): @TokenTransferExecutable {
        return <- create TokenTransferExecutable(tokens: <-tokens, destinaton: destinaton)
    }
}