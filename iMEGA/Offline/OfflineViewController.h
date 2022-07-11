#import <UIKit/UIKit.h>

@class MEGAQLPreviewController, MOOfflineNode, ContextMenuManager;

typedef NS_ENUM(NSUInteger, OfflineViewControllerFlavor) {
    AccountScreen = 0,
    HomeScreen,
};

NS_ASSUME_NONNULL_BEGIN

static NSString *documentProviderLog = @"MEGAiOS.docExt.log";
static NSString *fileProviderLog = @"MEGAiOS.fileExt.log";
static NSString *shareExtensionLog = @"MEGAiOS.shareExt.log";
static NSString *notificationServiceExtensionLog = @"MEGAiOS.NSE.log";

@interface OfflineViewController : UIViewController

@property (nonatomic, strong, nullable) NSIndexPath *peekIndexPath;

@property (nonatomic, assign) BOOL allItemsSelected;
@property (nonatomic, strong, nullable) NSString *previewDocumentPath;

@property (nonatomic, strong, nullable) NSMutableArray *selectedItems;
@property (nonatomic, strong, nullable) NSMutableArray *offlineSortedItems;
@property (nonatomic, strong, nullable) NSMutableArray *offlineSortedFileItems;
@property (nonatomic, strong, nullable) NSMutableArray *searchItemsArray;
@property (nonatomic, strong, nullable) UISearchController *searchController;
@property (nonatomic, assign) OfflineViewControllerFlavor flavor;
@property (nonatomic, readonly) NSString *currentOfflinePath;
@property (nonatomic, strong, nullable) NSString *folderPathFromOffline;

@property (nonatomic, strong, nullable) ContextMenuManager * contextMenuManager;
@property (nonatomic, strong) UIBarButtonItem *contextBarButtonItem;
@property (nonatomic, strong) NSString *logsPath;

- (nullable NSDictionary *)itemAtIndexPath:(NSIndexPath *)indexPath;
- (void)updateNavigationBarTitle;
- (BOOL)removeOfflineNodeCell:(NSString *)itemPath;
- (void)setViewEditing:(BOOL)editing;
- (void)itemTapped:(NSString *)name atIndexPath:(NSIndexPath *)indexPath;
- (void)enableButtonsBySelectedItems;
- (void)showInfoFilePath:(NSString *)itemPath at:(nullable NSIndexPath *)indexPath from:(UIButton *)sender;
- (void)showRemoveAlertWithConfirmAction:(void (^)(void))confirmAction andCancelAction:(nullable void (^)(void))cancelAction;
- (void)setEditMode:(BOOL)editMode;
- (void)openFileFromWidgetWith:(NSString *)path;
- (NSString *)folderPathFromOffline:(NSString *)absolutePath folder:(NSString *)folderName;

- (void)changeViewModePreference;
- (void)changeEditingModeStatus;
- (void)nodesSortTypeHasChanged;
@end

NS_ASSUME_NONNULL_END
