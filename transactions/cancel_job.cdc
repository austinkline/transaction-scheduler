import "TransactionScheduler"
import "ExampleToken"

transaction(jobID: UInt64) {
    prepare(acct: AuthAccount) {
        let container = acct.borrow<&TransactionScheduler.Container>(from: TransactionScheduler.ContainerStoragePath)
            ?? panic("container not found")
        
        let returnedPayment <- container.cancelJob(jobID: jobID)
        acct.borrow<&ExampleToken.Vault>(from: ExampleToken.VaultStoragePath)!.deposit(from: <- returnedPayment)
    }
}