import XCTest
import MEGAData
import MEGADataMock
import MEGADomain
import MEGASwift
import MEGADomainMock

@testable import MEGA

final class AccountRepositoryTests: XCTestCase {
    
    func testCurrentUserHandle() {
        let expectedHandle = HandleEntity.random()
        
        let sut = makeSUT(sdk: MockSdk(myUser: MockUser(handle: expectedHandle)))
        
        XCTAssertEqual(sut.currentUserHandle, expectedHandle)
    }
    
    func testCurrentUser() async {
        let expectedUser = MockUser(handle: .random())
        
        let sut = makeSUT(sdk: MockSdk(myUser: expectedUser))
        
        let currentUser = await sut.currentUser()
        XCTAssertEqual(currentUser, expectedUser.toUserEntity())
    }
    
    func testIsGuest() {
        func assert(
            whenUserEmail email: String,
            isGuestShouldBe expectedIsGuest: Bool,
            line: UInt = #line
        ) {
            let sut = makeSUT(sdk: MockSdk(myUser: MockUser(email: email)))
            
            XCTAssertEqual(sut.isGuest, expectedIsGuest, line: line)
        }
        
        assert(whenUserEmail: "", isGuestShouldBe: true)
        assert(whenUserEmail: "any-email@mega.com", isGuestShouldBe: false)
    }
    
    
    func testIsLoggedIn() {
        XCTAssertTrue(makeSUT(sdk: MockSdk(isLoggedIn: 1)).isLoggedIn())
        XCTAssertFalse(makeSUT(sdk: MockSdk(isLoggedIn: 0)).isLoggedIn())
    }
    
    func testContacts_shouldMapSdkContacts() {
        let userStubOne = MockUser()
        let userStubTwo = MockUser()
        let sut = makeSUT(sdk: MockSdk(
            myContacts: MockUserList(users: [userStubOne, userStubTwo])
        ))
        
        XCTAssertEqual(sut.contacts(), [userStubOne.toUserEntity(), userStubTwo.toUserEntity()])
    }
    
    func testIncomingContactsRequestCount() {
        func assert(
            whenContactRequestCount expectedCount: Int,
            line: UInt = #line
        ) {
            let sut = makeSUT(sdk: MockSdk(
                incomingContactRequestList: MockContactRequestList(
                    contactRequests: Array(repeating: MockContactRequest(), count: expectedCount)
                )
            ))
            
            XCTAssertEqual(sut.incomingContactsRequestsCount(), expectedCount, line: line)
        }
        
        assert(whenContactRequestCount: 0)
        assert(whenContactRequestCount: 1)
        assert(whenContactRequestCount: 5)
        assert(whenContactRequestCount: 10)
    }
    
    func testRelevantUnseenUserAlertsCount() {
        func assert(
            whenAlertsInSDK alerts: [MockUserAlert],
            relevantUnseenUserAlertsCount expectedCount: UInt,
            line: UInt = #line
        ) {
            let sut = makeSUT(sdk: MockSdk(
                userAlertList: MockUserAlertList(alerts: alerts)
            ))
            
            XCTAssertEqual(sut.relevantUnseenUserAlertsCount(), expectedCount, line: line)
        }
        
        assert(whenAlertsInSDK: [], relevantUnseenUserAlertsCount: 0)
        
        assert(
            whenAlertsInSDK: [
                MockUserAlert(isSeen: true, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: false),
                MockUserAlert(isSeen: true, isRelevant: true)
            ],
            relevantUnseenUserAlertsCount: 0
        )
        
        assert(
            whenAlertsInSDK: [
                MockUserAlert(isSeen: false, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: true)
            ],
            relevantUnseenUserAlertsCount: 3
        )
        
        assert(
            whenAlertsInSDK: [
                MockUserAlert(isSeen: true, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: false),
                MockUserAlert(isSeen: false, isRelevant: true),
                MockUserAlert(isSeen: true, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: true)
            ],
            relevantUnseenUserAlertsCount: 3
        )
    }
    
    func testTotalNodesCount() {
        func assert(
            whenNodesCount expectedCount: Int,
            line: UInt = #line
        ) {
            let sut = makeSUT(sdk: MockSdk(
                nodes: Array(repeating: MockNode(handle: .invalidHandle), count: expectedCount)
            ))
            
            XCTAssertEqual(sut.totalNodesCount(), UInt(expectedCount), line: line)
        }
        
        assert(whenNodesCount: 0)
        assert(whenNodesCount: 1)
        assert(whenNodesCount: 5)
        assert(whenNodesCount: 10)
    }
    
    func testAccountDetails_whenFails_shouldThrowGenericError() async {
        let expectedError = MockError.failingError
        let sut = makeSUT(
            sdk: MockSdk(accountDetails: { sdk, delegate in
                delegate.onRequestFinish?(sdk, request: MockRequest(handle: 1), error: expectedError)
            })
        )
        
        await XCTAssertThrowsError(try await sut.accountDetails()) { errorThrown in
            XCTAssertEqual(errorThrown as? AccountDetailsErrorEntity, .generic)
        }
    }
    
    func testUpgradeSecurity_whenApiOk_shouldNotThrow() async {
        let apiOk = MockError(errorType: .apiOk)
        let sut = makeSUT(
            sdk: MockSdk(upgradeSecurity: { sdk, delegate in
                delegate.onRequestFinish?(sdk, request: MockRequest(handle: 1), error: apiOk)
            })
        )
        
        await XCTAssertNoThrow(try await sut.upgradeSecurity())
    }
    
    func testUpgradeSecurity_whenFails_shouldThrowGenericError() async {
        let expectedError = MockError.failingError
        let sut = makeSUT(
            sdk: MockSdk(upgradeSecurity: { sdk, delegate in
                delegate.onRequestFinish?(sdk, request: MockRequest(handle: 1), error: expectedError)
            })
        )
        
        await XCTAssertThrowsError(try await sut.upgradeSecurity()) { errorThrown in
            XCTAssertEqual(errorThrown as? AccountErrorEntity, .generic)
        }
    }
    
    // MARK: - Helpers
    
    private func makeSUT(sdk: MEGASdk) -> AccountRepository {
        AccountRepository(
            sdk: sdk,
            currentUserSource: CurrentUserSource(sdk: sdk)
        )
    }
}
