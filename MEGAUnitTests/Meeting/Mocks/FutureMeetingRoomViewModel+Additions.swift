@testable import MEGA
import MEGADomain
import MEGADomainMock

extension FutureMeetingRoomViewModel {
    convenience init(
        scheduledMeeting: ScheduledMeetingEntity = ScheduledMeetingEntity(),
        nextOccurrenceDate: Date = Date(),
        router: ChatRoomsListRouting = MockChatRoomsListRouter(),
        chatRoomUseCase: ChatRoomUseCaseProtocol = MockChatRoomUseCase(),
        chatRoomUserUseCase: ChatRoomUserUseCaseProtocol = MockChatRoomUserUseCase(),
        userImageUseCase: UserImageUseCaseProtocol = MockUserImageUseCase(),
        chatUseCase: ChatUseCaseProtocol = MockChatUseCase(),
        accountUseCase: AccountUseCaseProtocol = MockAccountUseCase(),
        callUseCase: CallUseCaseProtocol = MockCallUseCase(),
        audioSessionUseCase: AudioSessionUseCaseProtocol = MockAudioSessionUseCase(),
        scheduledMeetingUseCase: ScheduledMeetingUseCaseProtocol = MockScheduledMeetingUseCase(),
        megaHandleUseCase: MEGAHandleUseCaseProtocol = MockMEGAHandleUseCase(),
        chatNotificationControl: ChatNotificationControl = ChatNotificationControl(delegate: MockPushNotificationControl()),
        isTesting: Bool = true
    ) {
        self.init(
            scheduledMeeting: scheduledMeeting,
            nextOccurrenceDate: nextOccurrenceDate,
            router: router,
            chatRoomUseCase: chatRoomUseCase,
            chatRoomUserUseCase: chatRoomUserUseCase,
            userImageUseCase: userImageUseCase,
            chatUseCase: chatUseCase,
            accountUseCase: accountUseCase,
            callUseCase: callUseCase,
            audioSessionUseCase: audioSessionUseCase,
            scheduledMeetingUseCase: scheduledMeetingUseCase,
            megaHandleUseCase: megaHandleUseCase,
            chatNotificationControl: chatNotificationControl
        )
    }
}

private final class MockPushNotificationControl: PushNotificationControlProtocol {}
