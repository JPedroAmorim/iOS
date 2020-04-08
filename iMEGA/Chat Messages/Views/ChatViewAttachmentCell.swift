import MessageKit

protocol AttachmentCellDataSource {
    var title: String { get }
    var subtitle: String { get }
    func set(imageView: UIImageView)
}

class ChatViewAttachmentCell: MessageContentCell {

    open var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    public lazy var titleLabel: UILabel = {
        let titleLabel = UILabel(frame: CGRect.zero)
        titleLabel.font = UIFont.mnz_SFUIMedium(withSize: 14)
        titleLabel.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        return titleLabel
    }()

    public lazy var detailLabel: UILabel = {
        let detailLabel = UILabel(frame: CGRect.zero)
        detailLabel.font = UIFont.mnz_SFUIRegular(withSize: 12)
        detailLabel.textColor = #colorLiteral(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        detailLabel.lineBreakMode = .byTruncatingMiddle
        return detailLabel
    }()

    // MARK: - Methods

    /// Responsible for setting up the constraints of the cell's subviews.
    open func setupConstraints() {
        imageView.autoSetDimensions(to: CGSize(width: 40, height: 40))
        imageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        imageView.autoPinEdge(toSuperviewEdge: .leading, withInset: 10)

        titleLabel.autoPinEdge(.leading, to: .trailing, of: imageView, withOffset: 10)
        titleLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: 10)
        titleLabel.autoSetDimension(.height, toSize: 18)
        titleLabel.autoAlignAxis(.horizontal, toSameAxisOf: messageContainerView, withOffset: -8)

        detailLabel.autoPinEdge(.leading, to: .trailing, of: imageView, withOffset: 10)
        detailLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: 10)
        detailLabel.autoSetDimension(.height, toSize: 18)
        detailLabel.autoAlignAxis(.horizontal, toSameAxisOf: messageContainerView, withOffset: 8)
    }

    open override func setupSubviews() {
        super.setupSubviews()
        messageContainerView.addSubview(imageView)
        messageContainerView.addSubview(titleLabel)
        messageContainerView.addSubview(detailLabel)
        setupConstraints()
    }
    
    var attachment: AttachmentCellDataSource! {
        didSet {
            configureUI()
        }
    }
    
    private func configureUI() {
        titleLabel.text = attachment.title
        detailLabel.text = attachment.subtitle
        attachment.set(imageView: imageView)
    }
    
    override func configure(with message: MessageType, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)
        
        guard let chatMessage = message as? ChatMessage else {
            return
        }
        
        self.attachment = chatMessage
    }
    
    func sizeThatFits() -> CGSize {
        titleLabel.sizeToFit()
        detailLabel.sizeToFit()
        
        let width = 75 + max(titleLabel.bounds.width, detailLabel.bounds.width)
        return CGSize(width: width, height: 80)
    }
}

open class ChatViewAttachmentCellCalculator: MessageSizeCalculator {
    
    let chatViewAttachmentCell = ChatViewAttachmentCell()
    
    public override init(layout: MessagesCollectionViewFlowLayout? = nil) {
        super.init(layout: layout)
        configureAccessoryView()
    }

    open override func messageContainerSize(for message: MessageType) -> CGSize {
       guard let chatMessage = message as? ChatMessage else {
            fatalError("ChatViewAttachmentCellCalculator: wrong type message passed.")
        }
        
        let maxWidth = messageContainerMaxWidth(for: message)
        
        chatViewAttachmentCell.attachment = chatMessage
        let size = chatViewAttachmentCell.sizeThatFits()
        
        return CGSize(width: min(size.width, maxWidth), height: size.height)
    }
}
