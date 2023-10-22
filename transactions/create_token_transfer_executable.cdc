import "DeferredExecutor"
import "ExecutableExamples"
import "FungibleToken"
import "ExampleToken"

transaction(
    transferAmount: UFix64,
    bounty: UFix64,
    receiverAddr: Address,
    runAfter: UInt64?,
    expiresOn: UInt64?,
    runnableBy: Address?
) {
    let container: &DeferredExecutor.Container
    let executable: @{DeferredExecutor.Executable}
    let bounty: @FungibleToken.Vault

    prepare(acct: AuthAccount) {
        if acct.borrow<&AnyResource>(from: DeferredExecutor.ContainerStoragePath) == nil {
            let container <- DeferredExecutor.createContainer()
            acct.save(<-container, to: DeferredExecutor.ContainerStoragePath)
        }

        if !acct.getCapability<&DeferredExecutor.Container{DeferredExecutor.ContainerPublic}>(DeferredExecutor.ContainerPublicPath).check() {
            acct.unlink(DeferredExecutor.ContainerPublicPath)
            acct.link<&DeferredExecutor.Container{DeferredExecutor.ContainerPublic}>(DeferredExecutor.ContainerPublicPath, target: DeferredExecutor.ContainerStoragePath)
        }

        self.container = acct.borrow<&DeferredExecutor.Container>(from: DeferredExecutor.ContainerStoragePath)
            ?? panic("container not found")

        let etVault = acct.borrow<&{FungibleToken.Provider}>(from: ExampleToken.VaultStoragePath)
            ?? panic("vault not found")
        let vaultToTransfer <- etVault.withdraw(amount: transferAmount)

        let receiver = getAccount(receiverAddr).getCapability<&{FungibleToken.Receiver}>(ExampleToken.ReceiverPublicPath)

        self.executable <- ExecutableExamples.createTokenTransferExecutable(
            tokens: <-vaultToTransfer,
            destinaton: receiver
        )

        self.bounty <- etVault.withdraw(amount: bounty)
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