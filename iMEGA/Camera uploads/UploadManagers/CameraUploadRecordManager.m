
#import "CameraUploadRecordManager.h"
#import "MEGAStore.h"
#import "MOAssetUploadErrorPerLaunch+CoreDataClass.h"
#import "MOAssetUploadErrorPerLogin+CoreDataClass.h"
#import "LocalFileNameGenerator.h"
#import "SavedIdentifierParser.h"

static const NSUInteger MaximumUploadRetryPerLaunchCount = 20;
static const NSUInteger MaximumUploadRetryPerLoginCount = 800;

@interface CameraUploadRecordManager ()

@property (strong, nonatomic, nullable) NSManagedObjectContext *backgroundContext;
@property (strong, nonatomic) LocalFileNameGenerator *fileNameCoordinator;
@property (strong, nonatomic) dispatch_queue_t serialQueueForContext;
@property (strong, nonatomic) dispatch_queue_t serialQueueForFileCoordinator;

@end

@implementation CameraUploadRecordManager

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
        _serialQueueForContext = dispatch_queue_create("nz.mega.cameraUpload.recordManager.context", DISPATCH_QUEUE_SERIAL);
        _serialQueueForFileCoordinator = dispatch_queue_create("nz.mega.cameraUpload.recordManager.coordinator", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

- (LocalFileNameGenerator *)fileNameCoordinator {
    if (_fileNameCoordinator) {
        return _fileNameCoordinator;
    }
    
    dispatch_sync(self.serialQueueForFileCoordinator, ^{
        if (self->_fileNameCoordinator == nil) {
            self->_fileNameCoordinator = [[LocalFileNameGenerator alloc] initWithBackgroundContext:self.backgroundContext];
        }
    });
    
    return _fileNameCoordinator;
}

- (NSManagedObjectContext *)backgroundContext {
    if (_backgroundContext) {
        return _backgroundContext;
    }

    dispatch_sync(self.serialQueueForContext, ^{
        if (self->_backgroundContext == nil) {
            self->_backgroundContext = [MEGAStore.shareInstance newBackgroundContext];
        }
    });
    
    return _backgroundContext;
}

- (void)resetDataContext {
    [self.backgroundContext performBlockAndWait:^{
        [self.backgroundContext reset];
    }];
    self.backgroundContext = nil;
    self.fileNameCoordinator = nil;
}

#pragma mark - access properties of record

- (NSString *)savedIdentifierInRecord:(MOAssetUploadRecord *)record {
    __block NSString *identifier;
    [self.backgroundContext performBlockAndWait:^{
        identifier = record.localIdentifier;
    }];
    
    return identifier;
}

#pragma mark - fetch records

- (CameraAssetUploadStatus)uploadStatusForIdentifier:(NSString *)identifier {
    MOAssetUploadRecord *record = [[self fetchUploadRecordsByIdentifier:identifier shouldPrefetchErrorRecords:NO error:nil] firstObject];
    __block CameraAssetUploadStatus status = CameraAssetUploadStatusUnknown;
    if (record != nil) {
        [self.backgroundContext performBlockAndWait:^{
            status = (CameraAssetUploadStatus)[record.status integerValue];
        }];
    }
    
    return status;
}

- (NSArray<MOAssetUploadRecord *> *)fetchUploadRecordsByIdentifier:(NSString *)identifier shouldPrefetchErrorRecords:(BOOL)prefetchErrorRecords error:(NSError *__autoreleasing  _Nullable *)error {
    NSFetchRequest *request = MOAssetUploadRecord.fetchRequest;
    request.predicate = [NSPredicate predicateWithFormat:@"localIdentifier == %@", identifier];
    if (prefetchErrorRecords) {
        [request setRelationshipKeyPathsForPrefetching:@[@"errorPerLaunch", @"errorPerLogin"]];
    }
    
    return [self fetchUploadRecordsByFetchRequest:request error:error];
}

- (NSArray<MOAssetUploadRecord *> *)queueUpUploadRecordsByStatuses:(NSArray<NSNumber *> *)statuses fetchLimit:(NSUInteger)fetchLimit mediaType:(PHAssetMediaType)mediaType error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    __block NSArray<MOAssetUploadRecord *> *records = @[];
    __block NSError *coreDataError = nil;
    [self.backgroundContext performBlockAndWait:^{
        NSFetchRequest *request = MOAssetUploadRecord.fetchRequest;
        request.fetchLimit = fetchLimit;
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(status IN %@) AND (mediaType == %@)", statuses, @(mediaType)];
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, [self predicateByFilterAssetUploadRecordError]]];
        [request setRelationshipKeyPathsForPrefetching:@[@"errorPerLaunch", @"errorPerLogin", @"fileNameRecord"]];
        records = [self.backgroundContext executeFetchRequest:request error:&coreDataError];
        
        for (MOAssetUploadRecord *record in records) {
            record.status = @(CameraAssetUploadStatusQueuedUp);
        }
    }];
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return records;
}

- (NSArray<MOAssetUploadRecord *> *)fetchAllUploadRecords:(NSError * _Nullable __autoreleasing * _Nullable)error {
    return [self fetchUploadRecordsByFetchRequest:MOAssetUploadRecord.fetchRequest error:error];
}

- (NSArray<MOAssetUploadRecord *> *)fetchUploadRecordsByStatuses:(NSArray<NSNumber *> *)statuses error:(NSError * _Nullable __autoreleasing *)error {
    NSFetchRequest *request = MOAssetUploadRecord.fetchRequest;
    request.predicate = [NSPredicate predicateWithFormat:@"status IN %@", statuses];
    return [self fetchUploadRecordsByFetchRequest:request error:error];
}

- (NSArray<MOAssetUploadRecord *> *)fetchUploadRecordsByMediaTypes:(NSArray<NSNumber *> *)mediaTypes includeAdditionalMediaSubtypes:(BOOL)includeAdditionalMediaSubtypes error:(NSError * _Nullable __autoreleasing *)error {
    NSFetchRequest *request = MOAssetUploadRecord.fetchRequest;
    NSPredicate *mediaTypePredicate = [NSPredicate predicateWithFormat:@"mediaType IN %@", mediaTypes];
    if (includeAdditionalMediaSubtypes) {
        request.predicate = mediaTypePredicate;
    } else {
        NSPredicate *additionalSubtypePredicate = [NSPredicate predicateWithFormat:@"additionalMediaSubtype == nil"];
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[mediaTypePredicate, additionalSubtypePredicate]];
    }
    
    return [self fetchUploadRecordsByFetchRequest:request error:error];
}

- (NSArray<MOAssetUploadRecord *> *)fetchUploadRecordsByFetchRequest:(NSFetchRequest *)request error:(NSError * _Nullable __autoreleasing *)error {
    __block NSArray<MOAssetUploadRecord *> *records = @[];
    __block NSError *coreDataError = nil;
    [self.backgroundContext performBlockAndWait:^{
        records = [self.backgroundContext executeFetchRequest:request error:&coreDataError];
    }];
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return records;
}

#pragma mark - fetch upload counts

- (NSUInteger)uploadDoneRecordsCountByMediaTypes:(NSArray<NSNumber *> *)mediaTypes error:(NSError * _Nullable __autoreleasing *)error {
    NSFetchRequest *request = MOAssetUploadRecord.fetchRequest;
    request.predicate = [NSPredicate predicateWithFormat:@"(status == %@) AND (mediaType IN %@)", @(CameraAssetUploadStatusDone), mediaTypes];
    return [self countForFetchRequest:request error:error];
}

- (NSUInteger)totalRecordsCountByMediaTypes:(NSArray<NSNumber *> *)mediaTypes error:(NSError * _Nullable __autoreleasing *)error {
    NSFetchRequest *request = MOAssetUploadRecord.fetchRequest;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaType IN %@", mediaTypes];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, [self predicateByFilterAssetUploadRecordError]]];
    return [self countForFetchRequest:request error:error];
}

- (NSUInteger)pendingRecordsCountByMediaTypes:(NSArray<NSNumber *> *)mediaTypes error:(NSError * _Nullable __autoreleasing *)error {
    NSFetchRequest *request = MOAssetUploadRecord.fetchRequest;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(status <> %@) AND (mediaType IN %@)", @(CameraAssetUploadStatusDone), mediaTypes];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, [self predicateByFilterAssetUploadRecordError]]];
    return [self countForFetchRequest:request error:error];
}

- (NSUInteger)uploadingRecordsCountWithError:(NSError * _Nullable __autoreleasing *)error {
    NSFetchRequest *request = MOAssetUploadRecord.fetchRequest;
    request.predicate = [NSPredicate predicateWithFormat:@"status == %@", @(CameraAssetUploadStatusUploading)];
    return [self countForFetchRequest:request error:error];
}

- (NSUInteger)countForFetchRequest:(NSFetchRequest *)request error:(NSError * _Nullable __autoreleasing *)error {
    __block NSUInteger count = 0;
    __block NSError *coreDataError = nil;
    [self.backgroundContext performBlockAndWait:^{
        count = [self.backgroundContext countForFetchRequest:request error:&coreDataError];
    }];
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return count;
}

#pragma mark - save records

- (BOOL)saveChangesIfNeededWithError:(NSError *__autoreleasing  _Nullable *)error {
    __block NSError *coreDataError = nil;
    [self.backgroundContext performBlockAndWait:^{
        if (self.backgroundContext.hasChanges) {
            [self.backgroundContext save:&coreDataError];
        }
    }];
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return coreDataError == nil;
}

- (BOOL)saveInitialUploadRecordsByAssetFetchResult:(PHFetchResult<PHAsset *> *)result error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    __block NSError *coreDataError = nil;
    if (result.count > 0) {
        [self.backgroundContext performBlockAndWait:^{
            for (PHAsset *asset in result) {
                [self createUploadRecordFromAsset:asset];
            }
            
            [self.backgroundContext save:&coreDataError];
        }];
    }
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return coreDataError == nil;
}

#pragma mark - create records

- (void)createUploadRecordsIfNeededByAssets:(NSArray<PHAsset *> *)assets {
    if (assets.count > 0) {
        [self.backgroundContext performBlockAndWait:^{
            for (PHAsset *asset in assets) {
                if ([self fetchUploadRecordsByIdentifier:asset.localIdentifier shouldPrefetchErrorRecords:NO error:nil].count == 0) {
                    [self createUploadRecordFromAsset:asset];
                }
            }
        }];
    }
}

- (void)createAdditionalRecordsIfNeededForRecords:(NSArray<MOAssetUploadRecord *> *)uploadRecords withMediaSubtype:(PHAssetMediaSubtype)subtype {
    [self.backgroundContext performBlockAndWait:^{
        SavedIdentifierParser *parser = [[SavedIdentifierParser alloc] init];
        for (MOAssetUploadRecord *record in uploadRecords) {
            if (record.additionalMediaSubtype) {
                continue;
            }
            
            NSString *savedIdentifier = [parser savedIdentifierForLocalIdentifier:record.localIdentifier mediaSubtype:subtype];
            if ([self fetchUploadRecordsByIdentifier:savedIdentifier shouldPrefetchErrorRecords:NO error:nil].count == 0) {
                MOAssetUploadRecord *subtypeRecord = [NSEntityDescription insertNewObjectForEntityForName:@"AssetUploadRecord" inManagedObjectContext:self.backgroundContext];
                subtypeRecord.localIdentifier = savedIdentifier;
                subtypeRecord.status = @(CameraAssetUploadStatusNotStarted);
                subtypeRecord.creationDate = record.creationDate;
                subtypeRecord.mediaType = record.mediaType;
                subtypeRecord.additionalMediaSubtype = @(subtype);
            }
        }
    }];
}

#pragma mark - update records

- (BOOL)updateUploadRecordByLocalIdentifier:(NSString *)identifier withStatus:(CameraAssetUploadStatus)status error:(NSError *__autoreleasing  _Nullable *)error {
    __block NSError *coreDataError = nil;
    NSArray *records = [self fetchUploadRecordsByIdentifier:identifier shouldPrefetchErrorRecords:YES error:&coreDataError];
    for (MOAssetUploadRecord *record in records) {
        [self updateUploadRecord:record withStatus:status error:&coreDataError];
    }
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return coreDataError == nil;
}

- (BOOL)updateUploadRecord:(MOAssetUploadRecord *)record withStatus:(CameraAssetUploadStatus)status error:(NSError *__autoreleasing  _Nullable *)error {
    __block NSError *coreDataError = nil;
    [self.backgroundContext performBlockAndWait:^{
        record.status = @(status);
        if (status == CameraAssetUploadStatusFailed) {
            if (record.errorPerLaunch == nil) {
                record.errorPerLaunch = [self createErrorRecordPerLaunchForLocalIdentifier:record.localIdentifier];
            }
            record.errorPerLaunch.errorCount = @(record.errorPerLaunch.errorCount.unsignedIntegerValue + 1);
            
            if (record.errorPerLogin == nil) {
                record.errorPerLogin = [self createErrorRecordPerLoginForLocalIdentifier:record.localIdentifier];
            }
            record.errorPerLogin.errorCount = @(record.errorPerLogin.errorCount.unsignedIntegerValue + 1);
        } else if (status == CameraAssetUploadStatusDone) {
            MOAssetUploadErrorPerLaunch *errorPerLaunch = [record errorPerLaunch];
            if (errorPerLaunch) {
                [self.backgroundContext deleteObject:errorPerLaunch];
            }
            
            MOAssetUploadErrorPerLogin *errorPerLogin = [record errorPerLogin];
            if (errorPerLogin) {
                [self.backgroundContext deleteObject:errorPerLogin];
            }
        }
        
        [self.backgroundContext save:&coreDataError];
    }];
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return coreDataError == nil;
}

#pragma mark - delete records

- (BOOL)deleteAllUploadRecordsWithError:(NSError * _Nullable __autoreleasing * _Nullable)error {
    __block NSError *coreDataError = nil;
    [self.backgroundContext performBlockAndWait:^{
        NSFetchRequest *request = MOAssetUploadRecord.fetchRequest;
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
        [self.backgroundContext executeRequest:deleteRequest error:&coreDataError];
    }];
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return coreDataError == nil;
}

- (BOOL)deleteUploadRecord:(MOAssetUploadRecord *)record error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    __block NSError *coreDataError = nil;
    [self.backgroundContext performBlockAndWait:^{
        [self.backgroundContext deleteObject:record];
        [self.backgroundContext save:&coreDataError];
    }];
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return coreDataError == nil;
}

- (BOOL)deleteUploadRecordsByLocalIdentifiers:(NSArray<NSString *> *)identifiers error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    __block NSError *coreDataError = nil;
    if (identifiers.count > 0) {
        [self.backgroundContext performBlockAndWait:^{
            NSFetchRequest *request = MOAssetUploadRecord.fetchRequest;
            request.predicate = [NSPredicate predicateWithFormat:@"localIdentifier IN %@", identifiers];
            NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
            [self.backgroundContext executeRequest:deleteRequest error:&coreDataError];
            
        }];
    }
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return coreDataError == nil;
}

#pragma mark - error record management

- (BOOL)deleteAllErrorRecordsPerLaunchWithError:(NSError * _Nullable __autoreleasing * _Nullable)error {
    __block NSError *coreDataError = nil;
    [self.backgroundContext performBlockAndWait:^{
        NSFetchRequest *request = MOAssetUploadErrorPerLaunch.fetchRequest;
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
        [self.backgroundContext executeRequest:deleteRequest error:&coreDataError];
    }];
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return coreDataError == nil;
}

#pragma mark - helper methods

- (MOAssetUploadRecord *)createUploadRecordFromAsset:(PHAsset *)asset {
    if (asset.localIdentifier.length == 0) {
        return nil;
    }
    
    MOAssetUploadRecord *record = [NSEntityDescription insertNewObjectForEntityForName:@"AssetUploadRecord" inManagedObjectContext:self.backgroundContext];
    record.localIdentifier = asset.localIdentifier;
    record.status = @(CameraAssetUploadStatusNotStarted);
    record.creationDate = asset.creationDate;
    record.mediaType = @(asset.mediaType);
    
    return record;
}

- (MOAssetUploadErrorPerLaunch *)createErrorRecordPerLaunchForLocalIdentifier:(NSString *)identifier {
    MOAssetUploadErrorPerLaunch *errorPerLaunch = [NSEntityDescription insertNewObjectForEntityForName:@"AssetUploadErrorPerLaunch" inManagedObjectContext:self.backgroundContext];
    errorPerLaunch.localIdentifier = identifier;
    errorPerLaunch.errorCount = @(0);
    return errorPerLaunch;
}

- (MOAssetUploadErrorPerLogin *)createErrorRecordPerLoginForLocalIdentifier:(NSString *)identifier {
    MOAssetUploadErrorPerLogin *errorPerLogin = [NSEntityDescription insertNewObjectForEntityForName:@"AssetUploadErrorPerLogin" inManagedObjectContext:self.backgroundContext];
    errorPerLogin.localIdentifier = identifier;
    errorPerLogin.errorCount = @(0);
    return errorPerLogin;
}

- (NSPredicate *)predicateByFilterAssetUploadRecordError {
    NSPredicate *errorPerLaunch = [NSPredicate predicateWithFormat:@"(errorPerLaunch == %@) OR (errorPerLaunch.errorCount <= %@)", NSNull.null, @(MaximumUploadRetryPerLaunchCount)];
    NSPredicate *errorPerLogin = [NSPredicate predicateWithFormat:@"(errorPerLogin == %@) OR (errorPerLogin.errorCount <= %@)", NSNull.null, @(MaximumUploadRetryPerLoginCount)];
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[errorPerLaunch, errorPerLogin]];
}

@end
