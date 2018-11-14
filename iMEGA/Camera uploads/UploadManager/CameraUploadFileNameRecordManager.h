
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CameraUploadFileNameRecordManager : NSObject

+ (instancetype)shared;

/**
 Generate a local unique file name for a given asset local identifier and proposed file name. Under the hood, we have a serial queue to handle fetchfing local upload file name records from local core data db, generating local unique file name base on a binary search algorithm, and saving the new local unique file name to local core data db.
 
 @discussion This is an on-demand pattern to resovle local unique file name issue. An unique name won't be generated unless an asset starts its upload process.
 
 This method is designed for thread safe to make sure it generates unique local file name.

 @param identifier local identifier of an photo or video asset.
 @param proposedFileName a proposed file name generated by other features
 @return a local unique file name which usually a name by appending "_%d" after proposed file name. It defaults to proposedFileName if there is no same name found in local record.
 */
- (NSString *)localUniqueFileNameForAssetLocalIdentifier:(NSString *)identifier proposedFileName:(NSString *)proposedFileName;

@end

NS_ASSUME_NONNULL_END
