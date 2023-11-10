import "FungibleToken"

/*
TransactionScheduler is a contract to allow any account to request an action be run for them in
exchange for a bounty.
*/
pub contract TransactionScheduler {
    pub let ContainerStoragePath: StoragePath
    pub let ContainerPublicPath: PublicPath

    pub event JobCreated(address: Address, id: UInt64, details: Details)
    pub event JobCompleted(address: Address, id: UInt64, bounty: UFix64, paymentIdentifier: String, run: Bool, runBy: Address?)

    pub struct Details {
        pub let bounty: UFix64
        pub let runAfter: UInt64?
        pub let paymentType: Type
        pub let expiresOn: UInt64?
        pub let runnableBy: Address?
        pub var hasRun: Bool

        init(bounty: UFix64, runAfter: UInt64?, paymentType: Type, expiresOn: UInt64?, runnableBy: Address?, hasRun: Bool) {
            self.bounty = bounty
            self.runAfter = runAfter
            self.paymentType = paymentType
            self.expiresOn = expiresOn
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

    pub resource interface JobPublic {
        pub fun getDetails(): Details
    }

    /*
    Job is the main resource of TransactionScheduler. It wraps an executable which will be executed when a job
    is run. A job can only be run once, and can restric when it can be run, for how long it is able to be run, and
    who is able to run it.

    Once a job has been run, its bounty is returned.
    */
    pub resource Job: JobPublic {
        access(contract) let details: Details
        access(self) let executable: @{Executable}
        access(self) let payment: @FungibleToken.Vault

        /*
        run - Executes this job's Executable, returns payment, and sets this job to run.
        Once run, a job cannot be run again.

        A job will fail to be run if:
            - Its executable fails (TransactionScheduler is not in control of this!)
            - The job has expired (current timestamp is greater than job.details.expiresOn)
            - The job cannot be run yet (current timestamp is less than job.details.runAfter)
            - The job has already been run

        Returns: A FungibleToken Vault with a balance equal to the job.details.bounty
        */
        access(contract) fun run(): @FungibleToken.Vault {
            pre {
                !self.details.hasRun: "cannot run a job multiple times"
                self.details.expiresOn == nil || self.details.expiresOn! >= UInt64(getCurrentBlock().timestamp): "job has expired"
                self.details.runAfter == nil || self.details.runAfter! < UInt64(getCurrentBlock().timestamp): "job cannot be run yet"
            }

            post {
                self.details.bounty == result.balance: "returned vault balance is not equal to the job's bounty"
            }

            let payment <- self.payment.withdraw(amount: self.payment.balance)

            self.executable.execute()
            self.details.setHasRun()
            return <- payment
        }

        pub fun cancel(): @FungibleToken.Vault {
            pre {
                !self.details.hasRun: "cannot cancel a job that's already been run"
            }

            return <- self.payment.withdraw(amount: self.payment.balance)
        }

        pub fun getDetails(): Details {
            return self.details
        }

        init(
            executable: @{Executable},
            payment: @FungibleToken.Vault,
            runAfter: UInt64?,
            expiresOn: UInt64?,
            runnableBy: Address?
        ) {
            pre {
                expiresOn == nil || expiresOn! > UInt64(getCurrentBlock().timestamp): "expiration must be after current block's timestamp"
            }

            self.details = Details(
                bounty: payment.balance,
                runAfter: runAfter,
                paymentType: payment.getType(),
                expiresOn: expiresOn,
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
        pub fun borrowJob(id: UInt64): &Job{JobPublic}?
        pub fun runJob(jobID: UInt64, identity: &{Identity}): @FungibleToken.Vault
        pub fun getIDs(): [UInt64]
    }

    // empty resource to borrow with so that we can restrict who is able to run a job
    pub resource interface Identity {}

    pub resource Container: ContainerPublic, Identity {
        pub let jobs: @{UInt64: Job}

        pub fun borrowJob(id: UInt64): &Job{JobPublic}? {
            return &self.jobs[id] as &Job{JobPublic}?
        }

        pub fun getIDs(): [UInt64] {
            return self.jobs.keys
        }

        // cancelJob
        // Removes the specified job from this container. The creator of the job might not
        // want a job to be executed anymore, and should 
        pub fun cancelJob(jobID: UInt64): @FungibleToken.Vault {
            let job <- self.jobs.remove(key: jobID)
                ?? panic("job not found")

            let tokens <- job.cancel()

            emit JobCompleted(address: self.owner!.address, id: jobID, bounty: job.details.bounty, paymentIdentifier: job.details.paymentType.identifier, run: job.details.hasRun, runBy: nil)
            destroy job

            return <- tokens
        }

        pub fun runJob(jobID: UInt64, identity: &{Identity}): @FungibleToken.Vault {
            let job <- self.jobs.remove(key: jobID)
                ?? panic("job not found")
            let tokens <- job.run()

            let details = job.getDetails()
            let runner = identity.owner!.address

            assert(details.runnableBy == nil || details.runnableBy! == runner, message: "job cannot be run by given identity")

            emit JobCompleted(address: self.owner!.address, id: jobID, bounty: details.bounty, paymentIdentifier: tokens.getType().identifier, run: job.details.hasRun, runBy: runner)
            destroy job


            return <- tokens
        }

        /*
        createJob
        The main entry point for those who wish to creates jobs to be executed. It accepts:
            - executable: A resource implementing the Executable interface. exeutable.Execute() is the function that will be run on job execution
            - payment: The bounty offered for running this job
            - runAfter: An optional unix timestamp which must be passed in order for the job to be runnable
            - expiresOn: A unix timestamp after which the job cannot be run anymore
            - runnableBy: An optional address dictating who is permitted to run this job
        */
        pub fun createJob(
            executable: @{Executable},
            payment: @FungibleToken.Vault,
            runAfter: UInt64?,
            expiresOn: UInt64?,
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

    pub fun createContainer(): @Container {
        return <- create Container()
    }

    init() {
        let baseIdentifier = "TransactionScheduler_".concat(self.account.address.toString())
        let containerIdentifier = baseIdentifier.concat("_Container")
        self.ContainerPublicPath = PublicPath(identifier: containerIdentifier)!
        self.ContainerStoragePath = StoragePath(identifier: containerIdentifier)!

        let runnerIdentifier = baseIdentifier.concat("_Runner")
    }
}