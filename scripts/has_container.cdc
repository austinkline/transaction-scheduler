import "DeferredExecutor"

pub fun main(addr: Address): Bool {
    let acct = getAccount(addr)
    return acct.getCapability<&DeferredExecutor.Container{DeferredExecutor.ContainerPublic}>(DeferredExecutor.ContainerPublicPath).check()
}