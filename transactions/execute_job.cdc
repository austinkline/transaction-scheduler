import "DeferredExecutor"
import "FungibleToken"
import "ExampleToken"

transaction(addr: Address, jobID: UInt64) {
    prepare(acct: AuthAccount) {
        if acct.borrow<&AnyResource>(from: DeferredExecutor.ContainerStoragePath) == nil {
            let container <- DeferredExecutor.createContainer()
            acct.save(<-container, to: DeferredExecutor.ContainerStoragePath)
        }

        if !acct.getCapability<&DeferredExecutor.Container{DeferredExecutor.ContainerPublic}>(DeferredExecutor.ContainerPublicPath).check() {
            acct.unlink(DeferredExecutor.ContainerPublicPath)
            acct.link<&DeferredExecutor.Container{DeferredExecutor.ContainerPublic}>(DeferredExecutor.ContainerPublicPath, target: DeferredExecutor.ContainerStoragePath)
        }

        let identity = acct.borrow<&{DeferredExecutor.Identity}>(from: DeferredExecutor.ContainerStoragePath)!

        let cap = getAccount(addr).getCapability<&DeferredExecutor.Container{DeferredExecutor.ContainerPublic}>(DeferredExecutor.ContainerPublicPath)
        let container = cap.borrow() ?? panic("job container not found")
        let tokens <- container.runJob(jobID: jobID, identity: identity)

        let vault = acct.borrow<&{FungibleToken.Receiver}>(from: ExampleToken.VaultStoragePath)
            ?? panic("example token vault not found")
        vault.deposit(from: <-tokens)
    }
}