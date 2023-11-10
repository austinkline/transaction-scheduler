import "TransactionScheduler"
import "FungibleToken"
import "ExampleToken"

transaction(addr: Address, jobID: UInt64) {
    prepare(acct: AuthAccount) {
        if acct.borrow<&AnyResource>(from: TransactionScheduler.ContainerStoragePath) == nil {
            let container <- TransactionScheduler.createContainer()
            acct.save(<-container, to: TransactionScheduler.ContainerStoragePath)
        }

        if !acct.getCapability<&TransactionScheduler.Container{TransactionScheduler.ContainerPublic}>(TransactionScheduler.ContainerPublicPath).check() {
            acct.unlink(TransactionScheduler.ContainerPublicPath)
            acct.link<&TransactionScheduler.Container{TransactionScheduler.ContainerPublic}>(TransactionScheduler.ContainerPublicPath, target: TransactionScheduler.ContainerStoragePath)
        }

        let identity = acct.borrow<&{TransactionScheduler.Identity}>(from: TransactionScheduler.ContainerStoragePath)!

        let cap = getAccount(addr).getCapability<&TransactionScheduler.Container{TransactionScheduler.ContainerPublic}>(TransactionScheduler.ContainerPublicPath)
        let container = cap.borrow() ?? panic("job container not found")
        let tokens <- container.runJob(jobID: jobID, identity: identity)

        let vault = acct.borrow<&{FungibleToken.Receiver}>(from: ExampleToken.VaultStoragePath)
            ?? panic("example token vault not found")
        vault.deposit(from: <-tokens)
    }
}