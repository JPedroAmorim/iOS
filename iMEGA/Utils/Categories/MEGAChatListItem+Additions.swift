import Foundation
import MEGADomain

extension MEGAChatListItem {

    var chatRoom: MEGAChatRoom? {
        return MEGASdkManager.sharedMEGAChatSdk().chatRoom(forChatId: chatId)
    }

    var peerCount: UInt {
        return chatRoom?.peerCount ?? 0
    }

    @objc var searchString: String {
        let fullnames = (0..<peerCount).compactMap { MEGASdkManager.sharedMEGAChatSdk().userFullnameFromCache(byUserHandle: chatRoom?.peerHandle(at: $0) ?? MEGAInvalidHandle)}.joined(separator: " ")
        let nicknames = (0..<peerCount).compactMap { nickName(forHandle: chatRoom?.peerHandle(at: $0)) }.joined(separator: " ")
        let emails = (0..<peerCount).compactMap { MEGASdkManager.sharedMEGAChatSdk().userEmailFromCache(byUserHandle: chatRoom?.peerHandle(at: $0) ?? MEGAInvalidHandle) }.joined(separator: " ")
        
        guard let chatRoomTitle = title else {
            return fullnames + " " + nicknames + " " + emails
        }
        
        return chatRoomTitle + " " + fullnames + " " + nicknames + " " + emails
    }
    
    @objc func chatTitle() -> String {
        return chatRoom?.chatTitle() ?? ""
    }
    
    private func nickName(forHandle handle: HandleEntity?) -> String? {
        guard let handle, let backgroundContext = MEGAStore.shareInstance().stack.newBackgroundContext() else { return nil }
        
        var nickname: String?
        
        backgroundContext.performAndWait {
            nickname = MEGAStore.shareInstance().fetchUser(withUserHandle: handle, context: backgroundContext)?.nickname
        }
        
        return nickname
    }
}
