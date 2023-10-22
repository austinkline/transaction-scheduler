import "DeferredExecutor"
import "ExampleToken"

transaction(jobID: UInt64) {
    prepare(acct: AuthAccount) {
        let container = acct.borrow<&DeferredExecutor.Container>(from: DeferredExecutor.ContainerStoragePath)
            ?? panic("container not found")
        
        let returnedPayment <- container.cancelJob(jobID: jobID)
        acct.borrow<&ExampleToken.Vault>(from: ExampleToken.VaultStoragePath)!.deposit(from: <- returnedPayment)
    }
}