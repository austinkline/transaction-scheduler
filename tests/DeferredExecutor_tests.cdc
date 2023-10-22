import Test
import "test_helpers.cdc"

pub let adminAccount = blockchain.createAccount()
pub let accounts: {String: Test.Account} = {}

pub let flowTokenStoragePath = StoragePath(identifier: "flowTokenVault")!

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