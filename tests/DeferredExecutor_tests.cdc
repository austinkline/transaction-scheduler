import Test
import "test_helpers.cdc"

pub let adminAccount = blockchain.createAccount()
pub let accounts: {String: Test.Account} = {}

pub let flowTokenStoragePath = /storage/flowTokenVault
pub let exampleTokenStoragePath = /storage/exampleTokenVault

pub fun testImports() {
    let res = scriptExecutor("test_imports.cdc", [])! as! Bool
    assert(res, message: "import test failed")
}

pub fun testSetupContainer() {
    let tmp = blockchain.createAccount()
    setupContainer(tmp)

    let isSetup = scriptExecutor("has_container.cdc", [tmp.address])! as! Bool
    Test.assert(isSetup, message: "Container not found")
}

pub fun testCreateJob() {
    let creator = blockchain.createAccount()
    let executor = blockchain.createAccount()
    let receiver = blockchain.createAccount()

    setupContainer(creator)
    setupExampleToken(creator)
    mintExampleTokens(creator, amount: 10.0)

    let creatorBalance = getTokenBalance(creator, path: flowTokenStoragePath)

    let transferAmount = 1.0
    let bounty = 1.0

    createTokenTransferJob(acct: creator, transferAmount: transferAmount, bounty: bounty, receiverAddr: receiver.address, runAfter: nil, expiresOn: nil, runnableBy: nil)

    let jobIDs = getJobIDs(creator)
    let job = jobIDs[0]

    compareJobDetails(acct: creator, jobID: job, bounty: bounty, runAfter: nil, paymentType: getExampleTokenIdentifier(), expiresOn: nil, runnableBy: nil, hasRun: false)
}

pub fun testExecuteJob() {
    let creator = blockchain.createAccount()
    let receiver = blockchain.createAccount()
    let executor = blockchain.createAccount()

    setupContainer(creator)
    setupExampleToken(creator)
    mintExampleTokens(creator, amount: 10.0)

    setupExampleToken(receiver)
    setupExampleToken(executor)

    let creatorBalance = getTokenBalance(creator, path: flowTokenStoragePath)

    let transferAmount = 1.0
    let bounty = 1.0

    createTokenTransferJob(acct: creator, transferAmount: transferAmount, bounty: bounty, receiverAddr: receiver.address, runAfter: nil, expiresOn: nil, runnableBy: nil)

    let receiverBalanceBefore = getTokenBalance(receiver, path: exampleTokenStoragePath)

    let jobID = getJobIDs(creator)[0]
    executeJob(executor: executor, creator: creator, jobID: jobID)

    let receiverBalanceAfter = getTokenBalance(receiver, path: exampleTokenStoragePath)

    Test.assert(receiverBalanceBefore + transferAmount == receiverBalanceAfter, message: "incorrect example token balance after job execution")

    // verify that the job has been deleted
    let jobs = getJobIDs(creator)
    Test.assert(jobs.length == 0, message: "unexpected number of jobs in creator account")
}

pub fun testCancelJob() {
    let creator = blockchain.createAccount()
    let receiver = blockchain.createAccount()
    setupContainer(creator)
    setupExampleToken(creator)
    mintExampleTokens(creator, amount: 10.0)
    let transferAmount = 1.0
    let bounty = 1.0

    createTokenTransferJob(acct: creator, transferAmount: transferAmount, bounty: bounty, receiverAddr: receiver.address, runAfter: nil, expiresOn: nil, runnableBy: nil)
    let jobID = getJobIDs(creator)[0]

    let beforeCancelBalance = getTokenBalance(creator, path: exampleTokenStoragePath)

    // Cancel the job, make sure it isn't there anymore
    cancelJob(creator: creator, jobID: jobID)
    
    let jobIDs = getJobIDs(creator)
    Test.assertEqual(0, jobIDs.length)

    let afterCancelBalance = getTokenBalance(creator, path: exampleTokenStoragePath)

    Test.assert(beforeCancelBalance + bounty == afterCancelBalance, message: "unexpected balance after job cancellation")
}

pub fun testRunJobTooSoon() {
    let creator = blockchain.createAccount()
    let receiver = blockchain.createAccount()
    let executor = blockchain.createAccount()

    setupContainer(creator)
    setupExampleToken(creator)
    mintExampleTokens(creator, amount: 10.0)

    setupExampleToken(receiver)
    setupExampleToken(executor)

    let creatorBalance = getTokenBalance(creator, path: flowTokenStoragePath)

    let transferAmount = 1.0
    let bounty = 1.0
    let runAfter = 1918919404 as UInt64 // job cannot be run until 22nd October, 2030

    createTokenTransferJob(acct: creator, transferAmount: transferAmount, bounty: bounty, receiverAddr: receiver.address, runAfter: runAfter, expiresOn: nil, runnableBy: nil)

    let jobID = getJobIDs(creator)[0]
    let expectedErrorMessage = "job cannot be run yet"
    expectJobExecutionFailure(executor: executor, creator: creator, jobID: jobID, failureMessageContains: expectedErrorMessage, failureMessageType: ErrorType.TX_PRE)
}

pub fun testCreateExpiredJob() {
    let creator = blockchain.createAccount()
    let receiver = blockchain.createAccount()

    setupContainer(creator)
    setupExampleToken(creator)
    mintExampleTokens(creator, amount: 10.0)

    let transferAmount = 1.0
    let bounty = 1.0
    let runAfter = nil
    let expiresOn: UInt64 = 0

    expectCreateTokenTransferJobFailure(
        acct: creator,
        transferAmount:transferAmount,
        bounty: bounty,
        receiverAddr: receiver.address,
        runAfter: runAfter,
        expiresOn: expiresOn,
        runnableBy: nil,
        failureMessageContains: "expiration must be after current block's timestamp",
        failureMessageType: ErrorType.TX_PRE
    )
}

pub fun testRunExpiredJob() {
    let creator = blockchain.createAccount()
    let receiver = blockchain.createAccount()
    let executor = blockchain.createAccount()

    setupContainer(creator)
    setupExampleToken(creator)
    mintExampleTokens(creator, amount: 10.0)

    setupExampleToken(receiver)
    setupExampleToken(executor)

    let creatorBalance = getTokenBalance(creator, path: flowTokenStoragePath)

    let transferAmount = 1.0
    let bounty = 1.0
    let runAfter = nil
    
    let currentTimestamp = getTimestamp()
    let expiresOn = currentTimestamp + 2

    createTokenTransferJob(acct: creator, transferAmount: transferAmount, bounty: bounty, receiverAddr: receiver.address, runAfter: runAfter, expiresOn: expiresOn, runnableBy: nil)

    waitUntilTimestamp(timestamp: expiresOn + 1)

    let jobID = getJobIDs(creator)[0]

    // we should not be able to execute the job
    let expectedErrorMessage = "job has expired"
    expectJobExecutionFailure(executor: executor, creator: creator, jobID: jobID, failureMessageContains: expectedErrorMessage, failureMessageType: ErrorType.TX_PRE)
}

pub fun testExecuteJobWrongIdentity() {
    let creator = blockchain.createAccount()
    let receiver = blockchain.createAccount()
    let executor = blockchain.createAccount()

    setupContainer(creator)
    setupExampleToken(creator)
    mintExampleTokens(creator, amount: 10.0)

    setupExampleToken(receiver)
    setupExampleToken(executor)

    let creatorBalance = getTokenBalance(creator, path: flowTokenStoragePath)

    let transferAmount = 1.0
    let bounty = 1.0
    let runAfter = nil

    createTokenTransferJob(acct: creator, transferAmount: transferAmount, bounty: bounty, receiverAddr: receiver.address, runAfter: runAfter, expiresOn: nil, runnableBy: receiver.address)

    let jobID = getJobIDs(creator)[0]
    let expectedErrorMessage = "job cannot be run by given identity"
    expectJobExecutionFailure(executor: executor, creator: creator, jobID: jobID, failureMessageContains: expectedErrorMessage, failureMessageType: ErrorType.TX_PRE)
}

pub fun testDestroyContainer() {
    let creator = blockchain.createAccount()
    let receiver = blockchain.createAccount()
    let executor = blockchain.createAccount()

    setupContainer(creator)
    setupExampleToken(creator)
    mintExampleTokens(creator, amount: 10.0)

    setupExampleToken(receiver)
    setupExampleToken(executor)

    let creatorBalance = getTokenBalance(creator, path: flowTokenStoragePath)

    let transferAmount = 1.0
    let bounty = 1.0
    let runAfter = nil

    createTokenTransferJob(acct: creator, transferAmount: transferAmount, bounty: bounty, receiverAddr: receiver.address, runAfter: runAfter, expiresOn: nil, runnableBy: receiver.address)
    destroyContainer(acct: creator)
}

pub fun destroyContainer(acct: Test.Account) {
    txExecutor("destroy_container.cdc", [acct], [], nil, nil)
}

pub fun expectJobExecutionFailure(executor: Test.Account, creator: Test.Account, jobID: UInt64, failureMessageContains: String, failureMessageType: ErrorType) {
    txExecutor("execute_job.cdc", [executor], [creator.address, jobID], failureMessageContains, failureMessageType)
}

pub fun cancelJob(creator: Test.Account, jobID: UInt64) {
    txExecutor("cancel_job.cdc", [creator], [jobID], nil, nil)
}

pub fun executeJob(executor: Test.Account, creator: Test.Account, jobID: UInt64) {
    txExecutor("execute_job.cdc", [executor], [creator.address, jobID], nil, nil)
}

pub fun expectCreateTokenTransferJobFailure(
    acct: Test.Account,
    transferAmount: UFix64,
    bounty: UFix64,
    receiverAddr: Address,
    runAfter: UInt64?,
    expiresOn: UInt64?,
    runnableBy: Address?,
    failureMessageContains: String,
    failureMessageType: ErrorType
) {
    let args = [transferAmount, bounty, receiverAddr, runAfter, expiresOn, runnableBy]
    txExecutor("create_token_transfer_executable.cdc", [acct], args, failureMessageContains, failureMessageType)
}

pub fun createTokenTransferJob(
    acct: Test.Account,
    transferAmount: UFix64,
    bounty: UFix64,
    receiverAddr: Address,
    runAfter: UInt64?,
    expiresOn: UInt64?,
    runnableBy: Address?
) {
    let args = [transferAmount, bounty, receiverAddr, runAfter, expiresOn, runnableBy]
    txExecutor("create_token_transfer_executable.cdc", [acct], args, nil, nil)
}

pub fun setupContainer(_ acct: Test.Account) {
    txExecutor("initialize_container.cdc", [acct], [], nil, nil)
}

pub fun mintExampleTokens(_ acct: Test.Account, amount: UFix64) {
    txExecutor("helper/mint_example_tokens.cdc", [adminAccount], [acct.address, amount], nil, nil)
}

pub fun setupExampleToken(_ acct: Test.Account) {
    txExecutor("helper/setup_example_token.cdc", [acct], [], nil, nil)
}

pub fun getTokenBalance(_ acct: Test.Account, path: StoragePath): UFix64 {
    return scriptExecutor("get_token_balance.cdc", [acct.address, path])! as! UFix64
}

pub fun getJobIDs(_ acct: Test.Account): [UInt64] {
    return scriptExecutor("get_job_ids.cdc", [acct.address])! as! [UInt64]
}

pub fun getExampleTokenIdentifier(): String {
    let addr = adminAccount.address.toString()
    return "A.".concat(adminAccount.address.toString().slice(from: 2, upTo: addr.length)).concat("ExampleToken.Vault")
}

pub fun compareJobDetails(
    acct: Test.Account,
    jobID: UInt64,
    bounty: UFix64,
    runAfter: UInt64?,
    paymentType: String,
    expiresOn: UInt64?,
    runnableBy: Address?,
    hasRun: Bool
) {
    let args = [acct.address, jobID, bounty, runAfter, paymentType, expiresOn, runnableBy, hasRun]
    scriptExecutor("verify_job_details.cdc", args)
}

pub fun getTimestamp(): UInt64 {
    return scriptExecutor("get_current_timestamp.cdc", [])! as! UInt64
}

pub fun waitUntilTimestamp(timestamp: UInt64) {
    var current: UInt64 = getTimestamp()
    while current < timestamp {
        current = getTimestamp()

        // advance the blockchain time by submitting a heartbeat transaction
        txExecutor("helper/heartbeat.cdc", [adminAccount], [], nil, nil)
    }
}

pub fun setup() {
    accounts["DeferredExecutor"] = adminAccount
    accounts["ExecutableExamples"] = adminAccount
    accounts["ExampleToken"] = adminAccount

    blockchain.useConfiguration(Test.Configuration({
        "DeferredExecutor": adminAccount.address,
        "ExecutableExamples": adminAccount.address,
        "ExampleToken": adminAccount.address
    }))

    deploy("DeferredExecutor", adminAccount, "../contracts/DeferredExecutor.cdc")
    deploy("ExecutableExamples", adminAccount, "../contracts/ExecutableExamples.cdc")
    deploy("ExampleToken", adminAccount, "../contracts/helper/ExampleToken.cdc")
}