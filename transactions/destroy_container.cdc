import "DeferredExecutor"

transaction {
    prepare(acct: AuthAccount) {
        destroy <- acct.load<@AnyResource>(from: DeferredExecutor.ContainerStoragePath)
    }
}