import XCTest
@testable import MEGA
import MEGADomainMock
import MEGADomain

final class SendFeedbackViewModelTests: XCTestCase {

    func test_getFeedback_notEmpty() async {
        let currentUser = UserEntity(email: "test@mega.co.nz")
        let mockUseCase = MockAccountUseCase(currentUser: currentUser)
        let sut = SendFeedbackViewModel(accountUseCase: mockUseCase)
        
        let feedbackEntity = await sut.getFeedback()
        XCTAssertFalse(feedbackEntity.toEmail.isEmpty)
        XCTAssertFalse(feedbackEntity.subject.isEmpty)
        XCTAssertFalse(feedbackEntity.messageBody.isEmpty)
        XCTAssertFalse(feedbackEntity.logsFileName.isEmpty)
    }
    
    func test_getFeedback_correctRecipient() async {
        let mockUseCase = MockAccountUseCase()
        let sut = SendFeedbackViewModel(accountUseCase: mockUseCase)
        
        let feedbackEntity = await sut.getFeedback()
        XCTAssertEqual(feedbackEntity.toEmail, "iosfeedback@mega.nz")
    }
    
    func test_getFeedback_correctSubject() async {
        let mockUseCase = MockAccountUseCase()
        let sut = SendFeedbackViewModel(accountUseCase: mockUseCase)
        
        let feedbackEntity = await sut.getFeedback()
        XCTAssertTrue(feedbackEntity.subject.hasPrefix("Feedback "))
    }
}
