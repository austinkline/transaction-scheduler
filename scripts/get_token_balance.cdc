import "FungibleToken"

pub fun main(addr: Address, path: StoragePath): UFix64 {
    return getAuthAccount(addr).borrow<&{FungibleToken.Balance}>(from: path)!.balance
}