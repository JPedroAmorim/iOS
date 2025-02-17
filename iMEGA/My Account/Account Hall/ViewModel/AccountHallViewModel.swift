import Foundation
import MEGAPresentation
import MEGADomain
import MEGAData

enum AccountHallAction: ActionType {
    case onViewAppear
    case didTapUpgradeButton
}

final class AccountHallViewModel: ViewModelType, ObservableObject {
    
    enum Command: CommandType, Equatable {
        case reload
    }
    
    var invokeCommand: ((Command) -> Void)?
    var incomingContactRequestsCount = 0
    var relevantUnseenUserAlertsCount: UInt = 0
    
    private var accountDetails: AccountDetailsEntity?
    @Published private(set) var currentPlanName: String = ""
    
    private let accountHallUsecase: AccountHallUseCaseProtocol
    
    // MARK: - Init
    
    init(accountHallUsecase: AccountHallUseCaseProtocol) {
        self.accountHallUsecase = accountHallUsecase
    }
    
    // MARK: - Dispatch actions
    
    func dispatch(_ action: AccountHallAction) {
        switch action {
        case .onViewAppear:
            fetchAccountDetails()
            fetchCounts()
        case .didTapUpgradeButton:
            showUpgradeAccountPlanView()
        }
    }
    
    // MARK: - Private
    
    private func fetchAccountDetails() {
        Task {
            do {
                accountDetails = try await accountHallUsecase.accountDetails()
                await setCurrentPlanName(accountDetails?.proLevel)
            } catch {
                MEGALogError("[Account Hall] Error loading account details. Error: \(error)")
            }
        }
    }
    
    private func fetchCounts() {
        Task {
            incomingContactRequestsCount = await accountHallUsecase.incomingContactsRequestsCount()
            relevantUnseenUserAlertsCount = await accountHallUsecase.relevantUnseenUserAlertsCount()
            
            await reloadContent()
        }
    }
    
    @MainActor
    private func reloadContent() {
        invokeCommand?(.reload)
    }
    
    @MainActor
    private func setCurrentPlanName(_ plan: AccountTypeEntity?) {
        currentPlanName = plan?.toAccountTypeDisplayName() ?? ""
    }
    
    private func showUpgradeAccountPlanView() {
        guard let accountDetails else { return }
        let upgradePlanRouter = UpgradeAccountPlanRouter(presenter: UIApplication.mnz_presentingViewController(),
                                                         accountDetails: accountDetails)
        upgradePlanRouter.start()
    }
}
