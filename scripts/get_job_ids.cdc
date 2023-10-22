import "DeferredExecutor"

pub fun main(addr: Address): [UInt64] {
    return getAuthAccount(addr).borrow<&DeferredExecutor.Container>(from: DeferredExecutor.ContainerStoragePath)!.getIDs()
}