import "TransactionScheduler"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&AnyResource>(from: TransactionScheduler.ContainerStoragePath) == nil {
            let container <- TransactionScheduler.createContainer()
            acct.save(<-container, to: TransactionScheduler.ContainerStoragePath)
        }

        if !acct.getCapability<&TransactionScheduler.Container{TransactionScheduler.ContainerPublic}>(TransactionScheduler.ContainerPublicPath).check() {
            acct.unlink(TransactionScheduler.ContainerPublicPath)
            acct.link<&TransactionScheduler.Container{TransactionScheduler.ContainerPublic}>(TransactionScheduler.ContainerPublicPath, target: TransactionScheduler.ContainerStoragePath)
        }
    }
}