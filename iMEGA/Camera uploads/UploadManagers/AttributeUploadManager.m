
#import "AttributeUploadManager.h"
#import "NSFileManager+MNZCategory.h"
#import "NSURL+CameraUpload.h"
#import "ThumbnailUploadOperation.h"
#import "PreviewUploadOperation.h"
#import "CoordinatesUploadOperation.h"
#import "CameraUploadManager.h"
#import "NSString+MNZCategory.h"
#import "NSError+CameraUpload.h"
@import CoreLocation;

static NSString * const AttributesDirectoryName = @"Attributes";

static const NSInteger CoordinatesConcurrentUploadCount = 2;
static const NSInteger ThumbnailConcurrentUploadCount = 50;

typedef NS_ENUM(NSInteger, PreviewConcurrentUploadCount) {
    PreviewConcurrentUploadCountWhenThumbnailsAreDone = 3,
    PreviewConcurrentUploadCountWhenThumbnailsAreUploading = 1
};

@interface AttributeUploadManager ()

@property (strong, nonatomic) NSOperationQueue *thumbnailUploadOperationQueue;
@property (strong, nonatomic) NSOperationQueue *previewUploadOperationQueue;
@property (strong, nonatomic) NSOperationQueue *coordinatesUploadOperationQueue;
@property (strong, nonatomic) NSOperationQueue *attributeScanQueue;

@end

@implementation AttributeUploadManager

+ (instancetype)shared {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _thumbnailUploadOperationQueue = [[NSOperationQueue alloc] init];
        _thumbnailUploadOperationQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        _thumbnailUploadOperationQueue.maxConcurrentOperationCount = ThumbnailConcurrentUploadCount;
        _thumbnailUploadOperationQueue.name = @"thumbnailUploadOperationQueue";
        [_thumbnailUploadOperationQueue addObserver:self forKeyPath:NSStringFromSelector(@selector(operationCount)) options:0 context:NULL];
        
        _previewUploadOperationQueue = [[NSOperationQueue alloc] init];
        _previewUploadOperationQueue.qualityOfService = NSQualityOfServiceBackground;
        _previewUploadOperationQueue.name = @"previewUploadOperationQueue";
        _previewUploadOperationQueue.maxConcurrentOperationCount = PreviewConcurrentUploadCountWhenThumbnailsAreUploading;
        
        _coordinatesUploadOperationQueue = [[NSOperationQueue alloc] init];
        _coordinatesUploadOperationQueue.qualityOfService = NSQualityOfServiceUtility;
        _coordinatesUploadOperationQueue.maxConcurrentOperationCount = CoordinatesConcurrentUploadCount;
        _coordinatesUploadOperationQueue.name = @"coordinatesUploadOperationQueue";
        
        _attributeScanQueue = [[NSOperationQueue alloc] init];
        _attributeScanQueue.name = @"attributeScanQueue";
        _attributeScanQueue.qualityOfService = NSQualityOfServiceBackground;
        _attributeScanQueue.maxConcurrentOperationCount = 1;
    }
    return self;
}

#pragma mark - thumbnail operation count KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(operationCount))] && object == self.thumbnailUploadOperationQueue) {
        NSInteger previewConcurrentCount;
        NSUInteger thumbnailsCount = self.thumbnailUploadOperationQueue.operationCount;
        if (thumbnailsCount == 0) {
            previewConcurrentCount = PreviewConcurrentUploadCountWhenThumbnailsAreDone;
        } else {
            previewConcurrentCount = PreviewConcurrentUploadCountWhenThumbnailsAreUploading;
        }
        
        if (self.previewUploadOperationQueue.maxConcurrentOperationCount != previewConcurrentCount) {
            self.previewUploadOperationQueue.maxConcurrentOperationCount = previewConcurrentCount;
        }
        
        MEGALogDebug(@"[Camera Upload] thumbnail count %lu, preview count %lu, preview concurrent count %li, coordinates count %lu", (unsigned long)thumbnailsCount, (unsigned long)self.previewUploadOperationQueue.operationCount, (long)previewConcurrentCount, (unsigned long)self.coordinatesUploadOperationQueue.operationCount);
    }
}

#pragma mark - upload preview and thumbnail files

- (AssetLocalAttribute *)saveAttributesForUploadInfo:(AssetUploadInfo *)uploadInfo error:(NSError **)error {
    NSURL *attributeDirectoryURL = [self nodeAttributesDirectoryURLByLocalIdentifier:uploadInfo.savedLocalIdentifier];
    [NSFileManager.defaultManager removeItemIfExistsAtURL:attributeDirectoryURL];
    [NSFileManager.defaultManager createDirectoryAtURL:attributeDirectoryURL withIntermediateDirectories:YES attributes:nil error:error];
    if (error != NULL && *error != nil) {
        return nil;
    }
    
    AssetLocalAttribute *attribute = [[AssetLocalAttribute alloc] initWithAttributeDirectoryURL:attributeDirectoryURL];
    [uploadInfo.fingerprint writeToURL:attribute.fingerprintURL atomically:YES encoding:NSUTF8StringEncoding error:error];
    if (error != NULL && *error != nil) {
        return nil;
    }
    
    if (uploadInfo.location) {
        if (![NSKeyedArchiver archiveRootObject:uploadInfo.location toFile:attribute.locationURL.path]) {
            if (error != NULL) {
                *error = [NSError mnz_cameraUploadCanNotArchiveLocationError];
            }
            return nil;
        }
    }
    
    [NSFileManager.defaultManager copyItemAtURL:uploadInfo.thumbnailURL toURL:attribute.thumbnailURL error:error];
    if (error != NULL && *error != nil) {
        return nil;
    }
    
    [NSFileManager.defaultManager copyItemAtURL:uploadInfo.previewURL toURL:attribute.previewURL error:error];
    if (error != NULL && *error != nil) {
        return nil;
    }
    
    return attribute;
}

- (void)uploadLocalAttribute:(AssetLocalAttribute *)attribute forNode:(MEGANode *)node {
    if (attribute.hasSavedThumbnail) {
        if (![self hasPendingAttributeOperationForNode:node inQueue:self.thumbnailUploadOperationQueue]) {
            MEGALogDebug(@"[Camera Upload] queue up thumbnail upload for %@ at %@", node.name, attribute.thumbnailURL);
            [self.thumbnailUploadOperationQueue addOperation:[[ThumbnailUploadOperation alloc] initWithAttributeURL:attribute.thumbnailURL node:node]];
        }
    } else {
        MEGALogError(@"[Camera Upload] No thumbnail file found for node %@ in %@", node.name, attribute.thumbnailURL);
    }
    
    if (attribute.hasSavedPreview) {
        if (![self hasPendingAttributeOperationForNode:node inQueue:self.previewUploadOperationQueue]) {
            MEGALogDebug(@"[Camera Upload] queue up preview upload for %@ at %@", node.name, attribute.previewURL);
            [self.previewUploadOperationQueue addOperation:[[PreviewUploadOperation alloc] initWithAttributeURL:attribute.previewURL node:node]];
        }
    } else {
        MEGALogError(@"[Camera Upload] No preview file found for node %@ in %@", node.name, attribute.previewURL);
    }
    
    if (attribute.hasSavedLocation && ![self hasPendingAttributeOperationForNode:node inQueue:self.coordinatesUploadOperationQueue]) {
        MEGALogDebug(@"[Camera Upload] queue up coordinates upload for %@ at %@", node.name, attribute.locationURL);
        [self.coordinatesUploadOperationQueue addOperation:[[CoordinatesUploadOperation alloc] initWithAttributeURL:attribute.locationURL node:node]];
    }
}

#pragma mark - attributes scan and retry

- (void)scanLocalAttributeFilesAndRetryUploadIfNeeded {
    MEGALogDebug(@"[Camera Upload] scan local attribute files and retry upload");
    if (!(MEGASdkManager.sharedMEGASdk.isLoggedIn && CameraUploadManager.shared.isNodeTreeCurrent)) {
        return;
    }
    
    if (![NSFileManager.defaultManager fileExistsAtPath:[self attributeDirectoryURL].path]) {
        return;
    }
    
    [MEGASdkManager.sharedMEGASdk retryPendingConnections];
    
    [self.attributeScanQueue addOperationWithBlock:^{
        NSError *error;
        NSArray<NSURL *> *attributeDirectoryURLs = [NSFileManager.defaultManager contentsOfDirectoryAtURL:[self attributeDirectoryURL] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
        if (error) {
            MEGALogError(@"[Camera Upload] error when to scan local attributes %@", error);
            return;
        }
        
        for (NSURL *URL in attributeDirectoryURLs) {
            [self scanAttributeDirectoryURL:URL];
        }
    }];
}

- (void)scanAttributeDirectoryURL:(NSURL *)URL {
    AssetLocalAttribute *attribute = [[AssetLocalAttribute alloc] initWithAttributeDirectoryURL:URL];
    MEGANode *node = [MEGASdkManager.sharedMEGASdk nodeForFingerprint:attribute.savedFingerprint];
    if (node == nil) {
        MEGALogDebug(@"[Camera Upload] no node can be created from %@ for %@", attribute.savedFingerprint, URL.lastPathComponent);
        return;
    }
    
    [self retryUploadLocalAttribute:attribute forNode:node];
}

- (void)retryUploadLocalAttribute:(AssetLocalAttribute *)attribute forNode:(MEGANode *)node {
    if (attribute.hasSavedThumbnail) {
        if ([node hasThumbnail]) {
            [attribute.thumbnailURL mnz_cacheThumbnailForNode:node];
        } else if (![self hasPendingAttributeOperationForNode:node inQueue:self.thumbnailUploadOperationQueue]) {
            MEGALogDebug(@"[Camera Upload] retry thumbnail upload for %@ in %@", node.name, attribute.attributeDirectoryURL.lastPathComponent);
            [self.thumbnailUploadOperationQueue addOperation:[[ThumbnailUploadOperation alloc] initWithAttributeURL:attribute.thumbnailURL node:node]];
        }
    }
    
    if (attribute.hasSavedPreview) {
        if ([node hasPreview]) {
            [attribute.previewURL mnz_cachePreviewForNode:node];
        } else if (![self hasPendingAttributeOperationForNode:node inQueue:self.previewUploadOperationQueue]) {
            MEGALogDebug(@"[Camera Upload] retry preview upload for %@ in %@", node.name, attribute.attributeDirectoryURL.lastPathComponent);
            [self.previewUploadOperationQueue addOperation:[[PreviewUploadOperation alloc] initWithAttributeURL:attribute.previewURL node:node]];
        }
    }
    
    if (attribute.hasSavedLocation) {
        if (node.latitude && node.longitude) {
            [NSFileManager.defaultManager removeItemIfExistsAtURL:attribute.locationURL];
        } else if (![self hasPendingAttributeOperationForNode:node inQueue:self.coordinatesUploadOperationQueue]) {
            MEGALogDebug(@"[Camera Upload] retry coordinates upload for %@ in %@", node.name, attribute.attributeDirectoryURL.lastPathComponent);
            [self.coordinatesUploadOperationQueue addOperation:[[CoordinatesUploadOperation alloc] initWithAttributeURL:attribute.locationURL node:node]];
        }
    }
}

#pragma mark - pending operations check

- (BOOL)hasPendingAttributeOperationForNode:(MEGANode *)node inQueue:(NSOperationQueue *)queue {
    BOOL hasPendingOperation = NO;
    
    for (NSOperation *operation in queue.operations) {
        if ([operation isKindOfClass:[AttributeUploadOperation class]]) {
            if ([(AttributeUploadOperation *)operation node].handle == node.handle) {
                hasPendingOperation = YES;
                MEGALogDebug(@"[Camera Upload] found pending operation for %@ in %@", node.name, queue);
                break;
            }
        }
    }
    
    return hasPendingOperation;
}

#pragma mark - data collation

- (void)collateLocalAttributes {
    NSArray<NSURL *> *attributeDirectoryURLs = [NSFileManager.defaultManager contentsOfDirectoryAtURL:[self attributeDirectoryURL] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    for (NSURL *URL in attributeDirectoryURLs) {
        AssetLocalAttribute *localAttribute = [[AssetLocalAttribute alloc] initWithAttributeDirectoryURL:URL];
        if (!localAttribute.hasSavedAttributes) {
            [NSFileManager.defaultManager removeItemIfExistsAtURL:URL];
        }
    }
}

#pragma mark - Utils

- (NSURL *)attributeDirectoryURL {
    return [NSURL.mnz_cameraUploadURL URLByAppendingPathComponent:AttributesDirectoryName isDirectory:YES];
}

- (NSURL *)nodeAttributesDirectoryURLByLocalIdentifier:(NSString *)identifier {
    return [[self attributeDirectoryURL] URLByAppendingPathComponent:identifier.mnz_stringByRemovingInvalidFileCharacters];
}

@end
