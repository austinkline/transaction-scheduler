import "TransactionScheduler"

pub fun main(addr: Address): Bool {
    let acct = getAccount(addr)
    return acct.getCapability<&TransactionScheduler.Container{TransactionScheduler.ContainerPublic}>(TransactionScheduler.ContainerPublicPath).check()
}