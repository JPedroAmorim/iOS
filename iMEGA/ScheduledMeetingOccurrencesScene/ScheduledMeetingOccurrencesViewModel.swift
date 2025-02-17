import MEGADomain

final class ScheduledMeetingOccurrencesViewModel: ObservableObject {
    private let scheduledMeeting: ScheduledMeetingEntity
    private let scheduledMeetingUseCase: ScheduledMeetingUseCaseProtocol
    let chatRoomAvatarViewModel: ChatRoomAvatarViewModel?
    
    private var occurrences: [ScheduledMeetingOccurrenceEntity] = []
    private var lastOccurrenceDate = Date()
    
    @Published var title: String
    @Published var subtitle: String?
    @Published var displayOccurrences: [ScheduleMeetingOccurence] = []
    @Published private(set) var primaryAvatar: UIImage?
    @Published private(set) var secondaryAvatar: UIImage?
    @Published var seeMoreOccurrencesVisible: Bool = true

    private let maxOccurrencesBatchCount = 20
    
    init(scheduledMeeting: ScheduledMeetingEntity,
         scheduledMeetingUseCase: ScheduledMeetingUseCaseProtocol,
         chatRoomAvatarViewModel: ChatRoomAvatarViewModel?) {
        self.scheduledMeeting = scheduledMeeting
        self.scheduledMeetingUseCase = scheduledMeetingUseCase
        self.chatRoomAvatarViewModel = chatRoomAvatarViewModel
        
        self.title = scheduledMeeting.title
        self.primaryAvatar = chatRoomAvatarViewModel?.primaryAvatar
        self.secondaryAvatar = chatRoomAvatarViewModel?.secondaryAvatar
        updateSubtitle()
        fetchOccurrences()
    }

    // MARK: - Public
    func seeMoreTapped() {
        fetchOccurrences()
    }

    // MARK: - Private
    private func updateSubtitle() {
        switch scheduledMeeting.rules.frequency {
        case .invalid:
            MEGALogError("A recurring meeting must have frequency")
        case .daily:
            subtitle = Strings.Localizable.Meetings.Scheduled.Recurring.Frequency.daily
        case .weekly:
            subtitle = Strings.Localizable.Meetings.Scheduled.Recurring.Frequency.weekly
        case .monthly:
            subtitle = Strings.Localizable.Meetings.Scheduled.Recurring.Frequency.monthly
        }
    }
    
    private func fetchOccurrences() {
        Task {
            do {
                var newOccurrences = try await scheduledMeetingUseCase.scheduledMeetingOccurrencesByChat(chatId: scheduledMeeting.chatId, since: lastOccurrenceDate)
                populateOccurrences(&newOccurrences)
            } catch {
                MEGALogError("Error fetching occurrences for scheduled meeting: \(scheduledMeeting.title)")
            }
        }
    }
    
    private func populateOccurrences(_ newOccurrences: inout [ScheduledMeetingOccurrenceEntity]) {
        if newOccurrences.count < maxOccurrencesBatchCount {
            DispatchQueue.main.async {
                self.seeMoreOccurrencesVisible = false
            }
        }
        lastOccurrenceDate = newOccurrences.last?.startDate ?? Date()

        let filteredOccurrences = newOccurrences.filter { !$0.cancelled }
        occurrences.append(contentsOf: filteredOccurrences)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, d MMM"
        let timeFormatter = DateFormatter.timeShort()
        
        let newDisplayOccurrences = filteredOccurrences.map {
            ScheduleMeetingOccurence(
                id: UUID().uuidString,
                date: dateFormatter.localisedString(from: $0.startDate),
                title: scheduledMeeting.title,
                time: timeFormatter.localisedString(from: $0.startDate) + " - " + timeFormatter.localisedString(from: $0.endDate))
        }
        DispatchQueue.main.async {
            self.displayOccurrences.append(contentsOf: newDisplayOccurrences)
        }
    }
}
