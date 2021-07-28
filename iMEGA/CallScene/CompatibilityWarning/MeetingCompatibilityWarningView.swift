

final class MeetingCompatibilityWarningView: UIView {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    
    var buttonTappedHandler: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        clipsToBounds = true
        layer.cornerRadius = 16.0
        label.text = NSLocalizedString("meetings.incompatibility.warningMessage", comment: "")
        button.setTitle(NSLocalizedString("ok", comment: ""), for: .normal)
    }
    
    @IBAction func buttonPressed(_ sender: UIButton) {
        buttonTappedHandler?()
    }
}
