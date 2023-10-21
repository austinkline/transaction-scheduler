import Test
import "test_helpers.cdc"

pub let adminAccount = blockchain.createAccount()
pub let accounts: {String: Test.Account} = {}

pub fun testImports() {
    let res = scriptExecutor("test_imports.cdc", [])! as! Bool
    assert(res, message: "import test failed")
}

pub fun setup() {
    accounts["DeferredExecutor"] = adminAccount
    accounts["ExecutableExamples"] = adminAccount

    blockchain.useConfiguration(Test.Configuration({
        "DeferredExecutor": adminAccount.address,
        "ExecutableExamples": adminAccount.address
    }))

    deploy("DeferredExecutor", adminAccount, "../contracts/DeferredExecutor.cdc")
    deploy("ExecutableExamples", adminAccount, "../contracts/ExecutableExamples.cdc")
}