import "TransactionScheduler"
import "ExecutableExamples"
import "FungibleToken"
import "ExampleToken"

transaction(
    bounty: UFix64,
    runAfter: UInt64?,
    expiresOn: UInt64?,
    runnableBy: Address?,
    message: String
) {
    let container: &TransactionScheduler.Container
    let executable: @{TransactionScheduler.Executable}
    let bounty: @FungibleToken.Vault

    prepare(acct: AuthAccount) {
        if acct.borrow<&AnyResource>(from: TransactionScheduler.ContainerStoragePath) == nil {
            let container <- TransactionScheduler.createContainer()
            acct.save(<-container, to: TransactionScheduler.ContainerStoragePath)
        }

        if !acct.getCapability<&TransactionScheduler.Container{TransactionScheduler.ContainerPublic}>(TransactionScheduler.ContainerPublicPath).check() {
            acct.unlink(TransactionScheduler.ContainerPublicPath)
            acct.link<&TransactionScheduler.Container{TransactionScheduler.ContainerPublic}>(TransactionScheduler.ContainerPublicPath, target: TransactionScheduler.ContainerStoragePath)
        }

        self.container = acct.borrow<&TransactionScheduler.Container>(from: TransactionScheduler.ContainerStoragePath)
            ?? panic("container not found")

        let v = acct.borrow<&{FungibleToken.Provider}>(from: ExampleToken.VaultStoragePath)
            ?? panic("vault not found")

        self.executable <- ExecutableExamples.createBasicExecutable(message: message)
        self.bounty <- v.withdraw(amount: bounty)
    }

    execute {
        self.container.createJob(
            executable: <-self.executable,
            payment: <-self.bounty,
            runAfter: runAfter,
            expiresOn: expiresOn,
            runnableBy: runnableBy
        )
    }
}