import "DeferredExecutor"
import "FungibleToken"

pub contract ExecutableExamples {
    pub resource TokenTransferExecutable: DeferredExecutor.Executable {
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
}