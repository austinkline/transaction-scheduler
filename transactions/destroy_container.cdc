import "TransactionScheduler"

transaction {
    prepare(acct: AuthAccount) {
        destroy <- acct.load<@AnyResource>(from: TransactionScheduler.ContainerStoragePath)
    }
}