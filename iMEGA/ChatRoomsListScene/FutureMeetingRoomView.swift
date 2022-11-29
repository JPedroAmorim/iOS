
import SwiftUI

@available(iOS 14.0, *)
struct FutureMeetingRoomView: View {
    @ObservedObject var viewModel: FutureMeetingRoomViewModel
    
    private enum Constants {
        static let viewHeight: CGFloat = 65
        static let avatarViewSize = CGSize(width: 28, height: 28)
    }

    var body: some View {
        HStack(spacing: 0) {
            if let avatarViewModel = viewModel.chatRoomAvatarViewModel {
                ChatRoomAvatarView(
                    viewModel: avatarViewModel,
                    size: Constants.avatarViewSize
                )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.title)
                    .font(.subheadline)
                
                Text(viewModel.time)
                    .foregroundColor(Color(Colors.Chat.Listing.meetingTimeTextColor.color))
                    .font(.caption)
            }
        }
        .frame(height: Constants.viewHeight)
    }
}
