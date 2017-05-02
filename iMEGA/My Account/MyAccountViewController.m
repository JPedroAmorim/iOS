#import "MyAccountViewController.h"

#import "UIImage+GKContact.h"
#import "SVProgressHUD.h"

#import "UIImageView+MNZCategory.h"
#import "NSString+MNZCategory.h"

#import "MEGASdkManager.h"
#import "MEGAReachabilityManager.h"
#import "Helper.h"

#import "MEGAUser+MNZCategory.h"

#import "UsageViewController.h"
#import "SettingsTableViewController.h"

@interface MyAccountViewController () <MEGARequestDelegate, MEGAChatRequestDelegate> {
    BOOL isAccountDetailsAvailable;
    
    NSNumber *localSize;
    NSNumber *cloudDriveSize;
    NSNumber *rubbishBinSize;
    NSNumber *incomingSharesSize;
    NSNumber *usedStorage;
    NSNumber *maxStorage;
    
    NSByteCountFormatter *byteCountFormatter;
}

@property (weak, nonatomic) IBOutlet UIBarButtonItem *editBarButtonItem;

@property (weak, nonatomic) IBOutlet UIButton *usageButton;
@property (weak, nonatomic) IBOutlet UILabel *usageLabel;

@property (weak, nonatomic) IBOutlet UIImageView *userAvatarImageView;

@property (weak, nonatomic) IBOutlet UIButton *settingsButton;
@property (weak, nonatomic) IBOutlet UILabel *settingsLabel;

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *emailLabel;

@property (weak, nonatomic) IBOutlet UILabel *localLabel;
@property (weak, nonatomic) IBOutlet UILabel *localUsedSpaceLabel;

@property (weak, nonatomic) IBOutlet UILabel *usedLabel;
@property (weak, nonatomic) IBOutlet UILabel *usedSpaceLabel;

@property (weak, nonatomic) IBOutlet UILabel *availableLabel;
@property (weak, nonatomic) IBOutlet UILabel *availableSpaceLabel;

@property (weak, nonatomic) IBOutlet UILabel *accountTypeLabel;

@property (weak, nonatomic) IBOutlet UIView *freeView;
@property (weak, nonatomic) IBOutlet UILabel *freeStatusLabel;
@property (weak, nonatomic) IBOutlet UIButton *upgradeToProButton;

@property (weak, nonatomic) IBOutlet UIView *proView;
@property (weak, nonatomic) IBOutlet UILabel *proStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *proExpiryDateLabel;

@property (weak, nonatomic) IBOutlet UIImageView *logoutButtonTopImageView;
@property (weak, nonatomic) IBOutlet UIButton *logoutButton;
@property (weak, nonatomic) IBOutlet UIImageView *logoutButtonBottomImageView;

@property (nonatomic) MEGAAccountType megaAccountType;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *usedLabelTopLayoutConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *accountTypeLabelTopLayoutConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *freeViewTopLayoutConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *upgradeAccountTopLayoutConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *proViewTopLayoutConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *logoutButtonTopLayoutConstraint;

@end

@implementation MyAccountViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.userAvatarImageView.layer.cornerRadius = self.userAvatarImageView.frame.size.width/2;
    self.userAvatarImageView.layer.masksToBounds = YES;
    
    [self.navigationItem setTitle:AMLocalizedString(@"myAccount", @"Title of the app section where you can see your account details")];
    
    self.editBarButtonItem.title = AMLocalizedString(@"edit", @"Caption of a button to edit the files that are selected");
    self.navigationItem.rightBarButtonItem = nil;
    
    [self.usageLabel setText:AMLocalizedString(@"usage", nil)];
    [self.settingsLabel setText:AMLocalizedString(@"settingsTitle", nil)];
    
    [self.localLabel setText:AMLocalizedString(@"localLabel", @"Local")];
    [self.usedLabel setText:AMLocalizedString(@"usedSpaceLabel", @"Used")];
    [self.availableLabel setText:AMLocalizedString(@"availableLabel", @"Available")];
    
    NSString *accountTypeString = [AMLocalizedString(@"accountType", @"title of the My Account screen") stringByReplacingOccurrencesOfString:@":" withString:@""];
    self.accountTypeLabel.text = accountTypeString;
    
    [self.freeStatusLabel setText:AMLocalizedString(@"free", nil)];
    [self.upgradeToProButton setTitle:AMLocalizedString(@"upgradeAccount", nil) forState:UIControlStateNormal];
    
    [self.logoutButton setTitle:AMLocalizedString(@"logoutLabel", @"Title of the button which logs out from your account.") forState:UIControlStateNormal];
    
    isAccountDetailsAvailable = NO;
    byteCountFormatter = [[NSByteCountFormatter alloc] init];
    [byteCountFormatter setCountStyle:NSByteCountFormatterCountStyleMemory];
    
    if ([[UIDevice currentDevice] iPhone4X]) {
        self.usedLabelTopLayoutConstraint.constant = 8.0f;
        self.accountTypeLabelTopLayoutConstraint.constant = 9.0f;
        self.freeViewTopLayoutConstraint.constant = 8.0f;
        self.upgradeAccountTopLayoutConstraint.constant = 8.0f;
        self.proViewTopLayoutConstraint.constant = 8.0f;
        self.logoutButtonTopLayoutConstraint.constant = 0.0f;
        self.logoutButtonTopImageView.backgroundColor = nil;
        self.logoutButtonBottomImageView.backgroundColor = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    long long thumbsSize = [Helper sizeOfFolderAtPath:[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"thumbnailsV3"]];
    long long previewsSize = [Helper sizeOfFolderAtPath:[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"previewsV3"]];
    long long offlineSize = [Helper sizeOfFolderAtPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
    
    localSize = [NSNumber numberWithLongLong:(thumbsSize + previewsSize + offlineSize)];
    
    NSString *stringFromByteCount = [byteCountFormatter stringFromByteCount:[localSize longLongValue]];
    [_localUsedSpaceLabel setAttributedText:[self textForSizeLabels:stringFromByteCount]];
    
    [[MEGASdkManager sharedMEGASdk] getAccountDetailsWithDelegate:self];
    
    [self setUserAvatar];
    
    self.nameLabel.text = [[[MEGASdkManager sharedMEGASdk] myUser] mnz_fullName];
    self.emailLabel.text = [[MEGASdkManager sharedMEGASdk] myEmail];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - Private

- (void)setUserAvatar {
    MEGAUser *myUser = [[MEGASdkManager sharedMEGASdk] myUser];
    [self.userAvatarImageView mnz_setImageForUserHandle:myUser.handle];
}

- (NSMutableAttributedString *)textForSizeLabels:(NSString *)stringFromByteCount {
    
    NSMutableAttributedString *firstPartMutableAttributedString;
    NSMutableAttributedString *secondPartMutableAttributedString;
    
    NSArray *componentsSeparatedByStringArray = [stringFromByteCount componentsSeparatedByString:@" "];
    NSString *firstPartString = [NSString mnz_stringWithoutUnitOfComponents:componentsSeparatedByStringArray];
    NSRange firstPartRange;
    
    NSArray *stringComponentsArray = [firstPartString componentsSeparatedByString:@","];
    NSString *secondPartString;
    if ([stringComponentsArray count] > 1) {
        NSString *integerPartString = [stringComponentsArray objectAtIndex:0];
        NSString *fractionalPartString = [stringComponentsArray objectAtIndex:1];
        firstPartMutableAttributedString = [[NSMutableAttributedString alloc] initWithString:integerPartString];
        firstPartRange = [integerPartString rangeOfString:integerPartString];
        secondPartString = [NSString stringWithFormat:@".%@ %@", fractionalPartString, [NSString mnz_stringWithoutCountOfComponents:componentsSeparatedByStringArray]];
    } else {
        firstPartMutableAttributedString = [[NSMutableAttributedString alloc] initWithString:firstPartString];
        firstPartRange = [firstPartString rangeOfString:firstPartString];
        secondPartString = [NSString stringWithFormat:@" %@", [NSString mnz_stringWithoutCountOfComponents:componentsSeparatedByStringArray]];
    }
    NSRange secondPartRange = [secondPartString rangeOfString:secondPartString];
    secondPartMutableAttributedString = [[NSMutableAttributedString alloc] initWithString:secondPartString];
    
    [firstPartMutableAttributedString addAttribute:NSFontAttributeName
                                             value:[UIFont mnz_SFUIRegularWithSize:20.0f]
                                             range:firstPartRange];
    
    [secondPartMutableAttributedString addAttribute:NSFontAttributeName
                                              value:[UIFont mnz_SFUIRegularWithSize:12.0f]
                                              range:secondPartRange];
    
    [firstPartMutableAttributedString appendAttributedString:secondPartMutableAttributedString];
    
    return firstPartMutableAttributedString;
}

#pragma mark - IBActions

- (IBAction)editTouchUpInside:(UIBarButtonItem *)sender {
    //TODO: Change Name / Change Avatar / Remove Avatar
}

- (IBAction)logoutTouchUpInside:(UIButton *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        [[MEGASdkManager sharedMEGASdk] logoutWithDelegate:self];
    }
}

- (IBAction)usageTouchUpInside:(UIButton *)sender {
    
    if (isAccountDetailsAvailable) {
        NSArray *sizesArray = @[cloudDriveSize, rubbishBinSize, incomingSharesSize, usedStorage, maxStorage];
        
        UsageViewController *usageVC = [[UIStoryboard storyboardWithName:@"MyAccount" bundle:nil] instantiateViewControllerWithIdentifier:@"UsageViewControllerID"];
        [self.navigationController pushViewController:usageVC animated:YES];
        
        [usageVC setSizesArray:sizesArray];
    }
}

- (IBAction)settingsTouchUpInside:(UIButton *)sender {
    [Helper changeToViewController:[SettingsTableViewController class] onTabBarController:self.tabBarController];
}

#pragma mark - MEGARequestDelegate

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if ([error type]) {
        return;
    }
    
    switch ([request type]) {
        case MEGARequestTypeGetAttrUser: {
            if (request.file) {
                [self setUserAvatar];
            }
            break;
        }
            
        case MEGARequestTypeAccountDetails: {
            self.megaAccountType = [[request megaAccountDetails] type];
            
            cloudDriveSize = [[request megaAccountDetails] storageUsedForHandle:[[[MEGASdkManager sharedMEGASdk] rootNode] handle]];
            rubbishBinSize = [[request megaAccountDetails] storageUsedForHandle:[[[MEGASdkManager sharedMEGASdk] rubbishNode] handle]];
            
            MEGANodeList *incomingShares = [[MEGASdkManager sharedMEGASdk] inShares];
            NSUInteger count = [incomingShares.size unsignedIntegerValue];
            long long incomingSharesSizeLongLong = 0;
            for (NSUInteger i = 0; i < count; i++) {
                MEGANode *node = [incomingShares nodeAtIndex:i];
                incomingSharesSizeLongLong += [[[MEGASdkManager sharedMEGASdk] sizeForNode:node] longLongValue];
            }
            incomingSharesSize = [NSNumber numberWithLongLong:incomingSharesSizeLongLong];
            
            usedStorage = [request.megaAccountDetails storageUsed];
            maxStorage = [request.megaAccountDetails storageMax];
            
            NSString *usedStorageString = [byteCountFormatter stringFromByteCount:[usedStorage longLongValue]];
            long long availableStorage = maxStorage.longLongValue - usedStorage.longLongValue;
            NSString *availableStorageString = [byteCountFormatter stringFromByteCount:(availableStorage < 0) ? 0 : availableStorage];
            
            [_usedSpaceLabel setAttributedText:[self textForSizeLabels:usedStorageString]];
            [_availableSpaceLabel setAttributedText:[self textForSizeLabels:availableStorageString]];
            
            NSString *expiresString;
            if ([request.megaAccountDetails type]) {
                [_freeView setHidden:YES];
                [_proView setHidden:NO];
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                [formatter setDateFormat:@"yyyy'-'MM'-'dd'"];
                NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
                [formatter setLocale:locale];
                NSDate *expireDate = [[NSDate alloc] initWithTimeIntervalSince1970:[request.megaAccountDetails proExpiration]];
                
                expiresString = [NSString stringWithFormat:AMLocalizedString(@"expiresOn", @"(Expires on %@)"), [formatter stringFromDate:expireDate]];
            } else {
                [_proView setHidden:YES];
                [_freeView setHidden:NO];
            }
            
            switch ([request.megaAccountDetails type]) {
                case MEGAAccountTypeFree: {
                    break;
                }
                    
                case MEGAAccountTypeLite: {
                    [_proStatusLabel setText:[NSString stringWithFormat:@"PRO LITE"]];
                    [_proExpiryDateLabel setText:[NSString stringWithFormat:@"%@", expiresString]];
                    break;
                }
                    
                case MEGAAccountTypeProI: {
                    [_proStatusLabel setText:[NSString stringWithFormat:@"PRO I"]];
                    [_proExpiryDateLabel setText:[NSString stringWithFormat:@"%@", expiresString]];
                    break;
                }
                    
                case MEGAAccountTypeProII: {
                    [_proStatusLabel setText:[NSString stringWithFormat:@"PRO II"]];
                    [_proExpiryDateLabel setText:[NSString stringWithFormat:@"%@", expiresString]];
                    break;
                }
                    
                case MEGAAccountTypeProIII: {
                    [_proStatusLabel setText:[NSString stringWithFormat:@"PRO III"]];
                    [_proExpiryDateLabel setText:[NSString stringWithFormat:@"%@", expiresString]];
                    break;
                }
                    
                default:
                    break;
            }
            
            isAccountDetailsAvailable = YES;
            
            break;
        }
            
        default:
            break;
    }
}

@end
