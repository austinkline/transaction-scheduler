import "DeferredExecutor"

pub fun main(
    addr: Address,
    id: UInt64,
    bounty: UFix64,
    runAfter: UInt64?,
    paymentType: String,
    expiresOn: UInt64?,
    runnableBy: Address?,
    hasRun: Bool
) {
    let acct = getAuthAccount(addr)
    let container = acct.borrow<&DeferredExecutor.Container>(from: DeferredExecutor.ContainerStoragePath)
        ?? panic("container not found")
    let job = container.borrowJob(id: id)
        ?? panic("job not found")
    let details = job.getDetails()

    assert(details.bounty == bounty, message: "bounty not equal to expect value")
    assert(details.runAfter == runAfter, message: "runAfter not equal to expected value")
    assert(details.paymentType.identifier == details.paymentType.identifier, message: "paymentType identifier not equal to expected value")
    assert(details.expiresOn == expiresOn, message: "expiresOn not equal to expected value")
    assert(details.runnableBy == runnableBy, message: "runnableBy not equal to expected value")
    assert(details.hasRun == hasRun, message: "hasRun not equal to expectedValue")
}