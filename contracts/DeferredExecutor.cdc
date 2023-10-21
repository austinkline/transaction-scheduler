import "FungibleToken"

/*
DeferredExecutor is a contract to allow any account to request an action be run for them in
exchange for a bounty.
*/
pub contract DeferredExecutor {
    pub let ContainerStoragePath: StoragePath
    pub let ContainerPublicPath: PublicPath

    pub event JobCreated(address: Address, id: UInt64, details: Details)
    pub event JobCompleted(address: Address, id: UInt64, bounty: UFix64, paymentIdentifier: String, run: Bool)

    pub struct Details {
        pub let bounty: UFix64
        pub let runAfter: UInt64
        pub let paymentType: Type
        pub let expirationTimestamp: UInt64
        pub let runnableBy: Address?
        pub var hasRun: Bool

        init(bounty: UFix64, runAfter: UInt64, paymentType: Type, expirationTimestamp: UInt64, runnableBy: Address?, hasRun: Bool) {
            self.bounty = bounty
            self.runAfter = runAfter
            self.paymentType = paymentType
            self.expirationTimestamp = expirationTimestamp
            self.runnableBy = runnableBy
            self.hasRun = hasRun
        }

        access(contract) fun setHasRun() {
            self.hasRun = true
        }
    }

    pub resource interface Executable {
        pub fun execute()
    }

    /*
    Job is the main resource of DeferredExecutor. It wraps an executable which will be executed when a job
    is run. A job can only be run once, and can restric when it can be run, for how long it is able to be run, and
    who is able to run it.

    Once a job has been run, its bounty is returned.
    */
    pub resource Job {
        pub let details: Details
        access(self) let executable: @{Executable}
        access(self) let payment: @FungibleToken.Vault

        // set to access(contract) so we can ensure proper cleanup. 
        // use the Runner resource to facilitate running a job
        access(contract) fun run(): @FungibleToken.Vault {
            pre {
                !self.details.hasRun: "cannot run a job multiple times"
                self.details.expirationTimestamp >= UInt64(getCurrentBlock().timestamp): "job has expired"
            }

            let payment <- self.payment.withdraw(amount: self.payment.balance)

            self.executable.execute()
            self.details.setHasRun()
            return <- payment
        }

        pub fun getDetails(): Details {
            return self.details
        }

        init(
            executable: @{Executable},
            payment: @FungibleToken.Vault,
            runAfter: UInt64,
            expiresOn: UInt64,
            runnableBy: Address?
        ) {
            let timestamp = UInt64(getCurrentBlock().timestamp)
            assert(runAfter > timestamp, message: "runAfter must be greater than the current block's timestamp")
            assert(expiresOn > timestamp, message: "expiration must be after current block's timestamp")

            self.details = Details(
                bounty: payment.balance,
                runAfter: runAfter,
                paymentType: payment.getType(),
                expirationTimestamp: expiresOn,
                runnableBy: runnableBy,
                hasRun: false
            )

            self.executable <- executable
            self.payment <- payment
        }

        destroy() {
            destroy self.executable
            destroy self.payment
        }
    }

    pub resource interface ContainerPublic {
        pub fun borrowJob(id: UInt64): &Job?
        pub fun runJob(jobID: UInt64, identity: &{Identity}): @FungibleToken.Vault
    }

    // empty resource to borrow with so that we can restrict who is able to run a job
    pub resource interface Identity {}

    pub resource Container: ContainerPublic {
        pub let jobs: @{UInt64: Job}

        pub fun borrowJob(id: UInt64): &Job? {
            return &self.jobs[id] as &Job?
        }

        pub fun cleanupJob(jobID: UInt64) {
            let job <- self.jobs.remove(key: jobID)
                ?? panic("job not found")
            assert(job.details.hasRun, message: "can only cleanup a job that has been run")

            destroy job
        }

        pub fun runJob(jobID: UInt64, identity: &{Identity}): @FungibleToken.Vault {
            let job <- self.jobs.remove(key: jobID)
                ?? panic("job not found")
            let tokens <- job.run()

            let details = job.getDetails()
            assert(details.runnableBy == nil || details.runnableBy! == identity.owner!.address, message: "job cannot be run by given identity")

            emit JobCompleted(address: self.owner!.address, id: jobID, bounty: details.bounty, paymentIdentifier: tokens.getType().identifier, run: job.details.hasRun)
            destroy job


            return <- tokens
        }

        pub fun addJob(
            executable: @{Executable},
            payment: @FungibleToken.Vault,
            runAfter: UInt64,
            expiresOn: UInt64,
            runnableBy: Address?
        ) {
            let job <- create Job(
                executable: <-executable,
                payment: <-payment,
                runAfter: runAfter,
                expiresOn: expiresOn,
                runnableBy: runnableBy
            )

            emit JobCreated(address: self.owner!.address, id: job.uuid, details: job.details)
            destroy self.jobs.insert(key: job.uuid, <-job)
        }

        init() {
            self.jobs <- {}
        }

        destroy() {
            destroy self.jobs
        }
    }

    init() {
        let baseIdentifier = "DeferredExecutor_".concat(self.account.address.toString())
        let containerIdentifier = baseIdentifier.concat("_Container")
        self.ContainerPublicPath = PublicPath(identifier: containerIdentifier)!
        self.ContainerStoragePath = StoragePath(identifier: containerIdentifier)!

        let runnerIdentifier = baseIdentifier.concat("_Runner")
    }
}