import "TransactionScheduler"

pub fun main(addr: Address): [UInt64] {
    return getAuthAccount(addr).borrow<&TransactionScheduler.Container>(from: TransactionScheduler.ContainerStoragePath)!.getIDs()
}