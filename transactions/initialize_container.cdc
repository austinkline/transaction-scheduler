import "DeferredExecutor"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&AnyResource>(from: DeferredExecutor.ContainerStoragePath) == nil {
            let container <- DeferredExecutor.createContainer()
            acct.save(<-container, to: DeferredExecutor.ContainerStoragePath)
        }

        if !acct.getCapability<&DeferredExecutor.Container{DeferredExecutor.ContainerPublic}>(DeferredExecutor.ContainerPublicPath).check() {
            acct.unlink(DeferredExecutor.ContainerPublicPath)
            acct.link<&DeferredExecutor.Container{DeferredExecutor.ContainerPublic}>(DeferredExecutor.ContainerPublicPath, target: DeferredExecutor.ContainerStoragePath)
        }
    }
}