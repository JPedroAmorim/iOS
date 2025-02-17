import XCTest
@testable import MEGA
import MEGADomain
import MEGADomainMock

final class FutureMeetingRoomViewModelTests: XCTestCase {
    
    private let router = MockChatRoomsListRouter()
    private let chatUseCase = MockChatUseCase()
    private let chatRoomUseCase = MockChatRoomUseCase(chatRoomEntity: ChatRoomEntity(chatId: 100))
    private let callUseCase = MockCallUseCase(call: CallEntity(chatId: 100, callId: 1))
    
    func testComputedProperty_title() {
        let title = "Meeting Title"
        let scheduledMeeting = ScheduledMeetingEntity(title: title)
        let viewModel = FutureMeetingRoomViewModel(scheduledMeeting: scheduledMeeting)
        XCTAssert(viewModel.title == title)
    }
    
    func testComputedProperty_time() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let startDate = dateFormatter.date(from: "2015-04-01T11:42:00") else {
            return
        }

        let endDate = startDate.advanced(by: 3600)
        
        let scheduledMeeting = ScheduledMeetingEntity(startDate: startDate, endDate: endDate)
        let viewModel = FutureMeetingRoomViewModel(scheduledMeeting: scheduledMeeting)
        XCTAssertTrue(viewModel.time == "11:42 AM - 12:42 PM" || viewModel.time == "11:42 - 12:42")
    }
    
    func testComputedProperty_unreadChatsCount() {
        let unreadMessagesCount = 10
        let chatRoomEntity = ChatRoomEntity(unreadCount: unreadMessagesCount)
        let chatRoomUseCase = MockChatRoomUseCase(chatRoomEntity: chatRoomEntity)
        let viewModel = FutureMeetingRoomViewModel(chatRoomUseCase: chatRoomUseCase)
        XCTAssertTrue(viewModel.unreadCountString == "\(unreadMessagesCount)")
    }
    
    func testComputedProperty_noUnreadChatsCount() {
        let viewModel = FutureMeetingRoomViewModel()
        XCTAssertTrue(viewModel.unreadCountString.isEmpty)
    }
    
    func testComputedProperty_noLastMessageTimestampAvailable() {
        let viewModel = FutureMeetingRoomViewModel()
        XCTAssertTrue(viewModel.lastMessageTimestamp == nil)
    }
    
    func testComputedProperty_lastMessageTimestampToday() {
        guard let date = Calendar
            .autoupdatingCurrent
            .date(bySettingHour: 0, minute: 1, second: 0, of: Date()) else {
            return
        }
        
        let chatListItem = ChatListItemEntity(lastMessageDate: date)
        let chatUseCase = MockChatUseCase(items: [chatListItem])
        let viewModel = FutureMeetingRoomViewModel(chatUseCase: chatUseCase)
        XCTAssertTrue(viewModel.lastMessageTimestamp == "00:01")
    }
    
    func testComputedProperty_lastMessageYesterday() {
        guard let today = Calendar
            .autoupdatingCurrent
            .date(bySettingHour: 0, minute: 1, second: 0, of: Date()),
              let yesterday = Calendar
            .autoupdatingCurrent
            .date(byAdding: .day, value: -1, to: today) else {
            return
        }
        
        let chatListItem = ChatListItemEntity(lastMessageDate: yesterday)
        let chatUseCase = MockChatUseCase(items: [chatListItem])
        let viewModel = FutureMeetingRoomViewModel(chatUseCase: chatUseCase)
        XCTAssertTrue(viewModel.lastMessageTimestamp == DateFormatter.fromTemplate("EEE").localisedString(from: yesterday))
    }
    
    func testComputedProperty_lastMessageReceivedSixDaysBack() {
        guard let today = Calendar
            .autoupdatingCurrent
            .date(bySettingHour: 0, minute: 1, second: 0, of: Date()),
              let pastDate = Calendar
            .autoupdatingCurrent
            .date(byAdding: .day, value: -6, to: today) else {
            return
        }
        
        let chatListItem = ChatListItemEntity(lastMessageDate: pastDate)
        let chatUseCase = MockChatUseCase(items: [chatListItem])
        let viewModel = FutureMeetingRoomViewModel(chatUseCase: chatUseCase)
        XCTAssertTrue(viewModel.lastMessageTimestamp == DateFormatter.fromTemplate("EEE").localisedString(from: pastDate))
    }
    
    func testComputedProperty_lastMessageTimestampReceivedSevenDaysBack() {
        guard let today = Calendar
            .autoupdatingCurrent
            .date(bySettingHour: 0, minute: 1, second: 0, of: Date()),
              let pastDate = Calendar
            .autoupdatingCurrent
            .date(byAdding: .day, value: -7, to: today) else {
            return
        }
        
        let chatListItem = ChatListItemEntity(lastMessageDate: pastDate)
        let chatUseCase = MockChatUseCase(items: [chatListItem])
        let viewModel = FutureMeetingRoomViewModel(chatUseCase: chatUseCase)
        XCTAssertTrue(viewModel.lastMessageTimestamp == DateFormatter.fromTemplate("ddyyMM").localisedString(from: pastDate))
    }
    
    func testComputedProperty_lastMessageTimestampReceivedMoreThanSevenDaysBack() {
        guard let today = Calendar
            .autoupdatingCurrent
            .date(bySettingHour: 0, minute: 1, second: 0, of: Date()),
              let pastDate = Calendar
            .autoupdatingCurrent
            .date(byAdding: .day, value: -10, to: today) else {
            return
        }
        
        let chatListItem = ChatListItemEntity(lastMessageDate: pastDate)
        let chatUseCase = MockChatUseCase(items: [chatListItem])
        let viewModel = FutureMeetingRoomViewModel(chatUseCase: chatUseCase)
        XCTAssertTrue(viewModel.lastMessageTimestamp == DateFormatter.fromTemplate("ddyyMM").localisedString(from: pastDate))
    }
    
    func testStartOrJoinCallActionTapped_startCall() {
        chatUseCase.isCallActive = false
        callUseCase.callCompletion = .success(callUseCase.call)
        
        let viewModel = FutureMeetingRoomViewModel(router: router, chatRoomUseCase: chatRoomUseCase, chatUseCase: chatUseCase, callUseCase: callUseCase)

        viewModel.startOrJoinCall()
        
        XCTAssertTrue(router.openCallView_calledTimes == 1)
    }
    
    func testStartOrJoinCallActionTapped_startCallError() {
        chatUseCase.isCallActive = false
        callUseCase.callCompletion = .failure(.generic)
        
        let viewModel = FutureMeetingRoomViewModel(router: router, chatRoomUseCase: chatRoomUseCase, chatUseCase: chatUseCase, callUseCase: callUseCase)

        viewModel.startOrJoinCall()
        
        XCTAssertTrue(router.showCallError_calledTimes == 1)
    }
    
    func testStartOrJoinCallActionTapped_startCallTooManyParticipants() {
        chatUseCase.isCallActive = false
        callUseCase.callCompletion = .failure(.tooManyParticipants)
        
        let viewModel = FutureMeetingRoomViewModel(router: router, chatRoomUseCase: chatRoomUseCase, chatUseCase: chatUseCase, callUseCase: callUseCase)

        viewModel.startOrJoinCall()
        
        XCTAssertTrue(router.showCallError_calledTimes == 1)
    }
    
    func testStartOrJoinCallActionTapped_joinCall() {
        chatUseCase.isCallActive = true
        callUseCase.callCompletion = .success(callUseCase.call)
        
        let viewModel = FutureMeetingRoomViewModel(router: router, chatRoomUseCase: chatRoomUseCase, chatUseCase: chatUseCase, callUseCase: callUseCase)

        viewModel.startOrJoinCall()
        
        XCTAssertTrue(router.openCallView_calledTimes == 1)
    }
    
    func testStartOrJoinCallActionTapped_joinCallError() {
        chatUseCase.isCallActive = true
        callUseCase.callCompletion = .failure(.generic)
        
        let viewModel = FutureMeetingRoomViewModel(router: router, chatRoomUseCase: chatRoomUseCase, chatUseCase: chatUseCase, callUseCase: callUseCase)

        viewModel.startOrJoinCall()
        
        XCTAssertTrue(router.showCallError_calledTimes == 1)
    }
    
    func testStartOrJoinCallActionTapped_joinCallTooManyParticipants() {
        chatUseCase.isCallActive = true
        callUseCase.callCompletion = .failure(.tooManyParticipants)
        
        let viewModel = FutureMeetingRoomViewModel(router: router, chatRoomUseCase: chatRoomUseCase, chatUseCase: chatUseCase, callUseCase: callUseCase)

        viewModel.startOrJoinCall()
        
        XCTAssertTrue(router.showCallError_calledTimes == 1)
    }
}
