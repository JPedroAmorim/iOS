import MEGASdk

public final class MockShareList: MEGAShareList {
    private let shares: [MEGAShare]
    
    public init(shares: [MEGAShare] = []) {
        self.shares = shares
        super.init()
    }
    
    public override var size: NSNumber! {
        NSNumber(value: shares.count)
    }
    
    public override func share(at index: Int) -> MEGAShare! {
        shares[index]
    }
}
