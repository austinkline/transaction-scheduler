// Helper functions. All of the following were taken from
// https://github.com/onflow/Offers/blob/fd380659f0836e5ce401aa99a2975166b2da5cb0/lib/cadence/test/Offers.cdc
// - deploy
// - scriptExecutor
// - txExecutor
// - getErrorMessagePointer

import Test

pub fun deployAll() {
    deploy("ExampleToken", "../contracts/helper/ExampleToken.cdc", [])
    deploy("TransactionScheduler", "../contracts/TransactionScheduler.cdc", [])
    deploy("ExecutableExamples", "../contracts/ExecutableExamples.cdc", [])
}

pub fun deploy(_ name: String, _ path: String, _ arguments: [AnyStruct]) {
    let err = Test.deployContract(name: name, path: path, arguments: arguments)
    Test.expect(err, Test.beNil()) 
}

pub fun scriptExecutor(_ scriptName: String, _ arguments: [AnyStruct]): AnyStruct? {
    let scriptCode = loadCode(scriptName, "scripts")
    let scriptResult = Test.executeScript(scriptCode, arguments)

    if let failureError = scriptResult.error {
        panic(
            "Failed to execute the script because -:  ".concat(failureError.message)
        )
    }

    return scriptResult.returnValue
}

pub fun txExecutor(_ txName: String, _ signers: [Test.Account], _ arguments: [AnyStruct], _ expectedError: String?, _ expectedErrorType: ErrorType?): Bool {
    let txCode = loadCode(txName, "transactions")

    let authorizers: [Address] = []
    for signer in signers {
        authorizers.append(signer.address)
    }

    let tx = Test.Transaction(
        code: txCode,
        authorizers: authorizers,
        signers: signers,
        arguments: arguments,
    )

    let txResult = Test.executeTransaction(tx)
    if let err = txResult.error {
        if let expectedErrorMessage = expectedError {
            let ptr = getErrorMessagePointer(errorType: expectedErrorType!)
            let errMessage = err.message
            let hasEmittedCorrectMessage = contains(errMessage, expectedErrorMessage)
            let failureMessage = "Expecting - "
                .concat(expectedErrorMessage)
                .concat("\n")
                .concat("But received - ")
                .concat(err.message)
            assert(hasEmittedCorrectMessage, message: failureMessage)
            return true
        }
        panic(err.message)
    } else {
        if let expectedErrorMessage = expectedError {
            panic("Expecting error - ".concat(expectedErrorMessage).concat(". While no error triggered"))
        }
    }

    return txResult.status == Test.ResultStatus.succeeded
}

pub fun loadCode(_ fileName: String, _ baseDirectory: String): String {
    return Test.readFile("../".concat(baseDirectory).concat("/").concat(fileName))
}

pub enum ErrorType: UInt8 {
    pub case TX_PANIC
    pub case TX_ASSERT
    pub case TX_PRE
}

pub fun getErrorMessagePointer(errorType: ErrorType): Int {
    switch errorType {
        case ErrorType.TX_PANIC: return 159
        case ErrorType.TX_ASSERT: return 170
        case ErrorType.TX_PRE: return 174
        default: panic("Invalid error type")
    }

    return 0
}

// Copied functions from flow-utils so we can assert on error conditions
// https://github.com/green-goo-dao/flow-utils/blob/main/cadence/contracts/StringUtils.cdc
pub fun contains(_ s: String, _ substr: String): Bool {
    if let index = index(s, substr, 0) {
        return true
    }
    return false
}

// https://github.com/green-goo-dao/flow-utils/blob/main/cadence/contracts/StringUtils.cdc
pub fun index(_ s: String, _ substr: String, _ startIndex: Int): Int? {
    for i in range(startIndex, s.length - substr.length + 1) {
        if s[i] == substr[0] && s.slice(from: i, upTo: i + substr.length) == substr {
            return i
        }
    }
    return nil
}

// https://github.com/green-goo-dao/flow-utils/blob/main/cadence/contracts/ArrayUtils.cdc
pub fun rangeFunc(_ start: Int, _ end: Int, _ f: ((Int): Void)) {
    var current = start
    while current < end {
        f(current)
        current = current + 1
    }
}

pub fun range(_ start: Int, _ end: Int): [Int] {
    let res: [Int] = []
    rangeFunc(start, end, fun (i: Int) {
        res.append(i)
    })
    return res
}
