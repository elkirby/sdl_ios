//
//  SDLFileManager.m
//  SmartDeviceLink-iOS
//
//  Created by Joel Fischer on 10/14/15.
//  Copyright © 2015 smartdevicelink. All rights reserved.
//

#import "SDLFileManager.h"

#import "SDLConnectionManagerType.h"
#import "SDLLogMacros.h"
#import "SDLDeleteFileOperation.h"
#import "SDLError.h"
#import "SDLFile.h"
#import "SDLFileWrapper.h"
#import "SDLGlobals.h"
#import "SDLListFilesOperation.h"
#import "SDLManager.h"
#import "SDLNotificationConstants.h"
#import "SDLPutFile.h"
#import "SDLPutFileResponse.h"
#import "SDLStateMachine.h"
#import "SDLUploadFileOperation.h"


NS_ASSUME_NONNULL_BEGIN

typedef NSString SDLFileManagerState;
SDLFileManagerState *const SDLFileManagerStateShutdown = @"Shutdown";
SDLFileManagerState *const SDLFileManagerStateFetchingInitialList = @"FetchingInitialList";
SDLFileManagerState *const SDLFileManagerStateReady = @"Ready";
SDLFileManagerState *const SDLFileManagerStateStartupError = @"StartupError";


#pragma mark - SDLFileManager class

@interface SDLFileManager ()

@property (weak, nonatomic) id<SDLConnectionManagerType> connectionManager;

// Remote state
@property (strong, nonatomic, readwrite) NSMutableSet<SDLFileName *> *mutableRemoteFileNames;
@property (assign, nonatomic, readwrite) NSUInteger bytesAvailable;

// Local state
@property (strong, nonatomic) NSOperationQueue *transactionQueue;
@property (strong, nonatomic) SDLStateMachine *stateMachine;
@property (copy, nonatomic, nullable) SDLFileManagerStartupCompletionHandler startupCompletionHandler;

@end

#pragma mark Constants

NSString * const FileManagerTransactionQueue = @"SDLFileManager Transaction Queue";
const char *_Nullable BackgroundUploadFilesWaitingQueue = "com.sdl.background.uploads.waiting.queue";

@implementation SDLFileManager

#pragma mark - Lifecycle

- (instancetype)initWithConnectionManager:(id<SDLConnectionManagerType>)manager {
    self = [super init];
    if (!self) {
        return nil;
    }

    _connectionManager = manager;
    _bytesAvailable = 0;

    _mutableRemoteFileNames = [NSMutableSet set];
    _transactionQueue = [[NSOperationQueue alloc] init];
    _transactionQueue.name = FileManagerTransactionQueue;
    // FIXME: - add comment below to class description
    // The transaction queue is serial for safety reasons. For example if a developer adds to the queue an upload file RPC and then adds an RPC to delete the same file, bad things can happen if the delete runs before the upload is completed.
    _transactionQueue.maxConcurrentOperationCount = 1;

    _stateMachine = [[SDLStateMachine alloc] initWithTarget:self initialState:SDLFileManagerStateShutdown states:[self.class sdl_stateTransitionDictionary]];

    return self;
}


#pragma mark - Setup / Shutdown

- (void)startWithCompletionHandler:(nullable SDLFileManagerStartupCompletionHandler)handler {
    if ([self.currentState isEqualToString:SDLFileManagerStateShutdown]) {
        self.startupCompletionHandler = handler;
        [self.stateMachine transitionToState:SDLFileManagerStateFetchingInitialList];
    } else {
        // If we already started, just tell the handler we're started.
        handler(YES, nil);
    }
}

- (void)stop {
    [self.stateMachine transitionToState:SDLFileManagerStateShutdown];
}


#pragma mark - Getters

- (NSSet<SDLFileName *> *)remoteFileNames {
    return [NSSet setWithSet:self.mutableRemoteFileNames];
}

- (NSString *)currentState {
    return self.stateMachine.currentState;
}

- (NSArray<__kindof NSOperation *> *)pendingTransactions {
    return self.transactionQueue.operations;
}

- (BOOL)suspended {
    return self.transactionQueue.suspended;
}


#pragma mark Setters

- (void)setSuspended:(BOOL)suspended {
    self.transactionQueue.suspended = suspended;
}


#pragma mark - State

+ (NSDictionary<SDLState *, SDLAllowableStateTransitions *> *)sdl_stateTransitionDictionary {
    return @{
        SDLFileManagerStateShutdown: @[SDLFileManagerStateFetchingInitialList],
        SDLFileManagerStateFetchingInitialList: @[SDLFileManagerStateShutdown, SDLFileManagerStateReady, SDLFileManagerStateStartupError],
        SDLFileManagerStateReady: @[SDLFileManagerStateShutdown],
        SDLFileManagerStateStartupError: @[SDLFileManagerStateShutdown]
    };
}

- (void)didEnterStateStartupError {
    if (self.startupCompletionHandler != nil) {
        self.startupCompletionHandler(NO, [NSError sdl_fileManager_unableToStartError]);
        self.startupCompletionHandler = nil;
    }
}

- (void)didEnterStateShutdown {
    [self.transactionQueue cancelAllOperations];
    [self.mutableRemoteFileNames removeAllObjects];
    [self.class sdl_clearTemporaryFileDirectory];
    self.bytesAvailable = 0;

    self.startupCompletionHandler = nil;
}

- (void)didEnterStateFetchingInitialList {
    __weak typeof(self) weakSelf = self;
    [self sdl_listRemoteFilesWithCompletionHandler:^(BOOL success, NSUInteger bytesAvailable, NSArray<NSString *> *_Nonnull fileNames, NSError *_Nullable error) {
        // If there was an error, we'll pass the error to the startup handler and cancel out
        if (error != nil) {
            [weakSelf.stateMachine transitionToState:SDLFileManagerStateStartupError];
            BLOCK_RETURN;
        }

        // If no error, make sure we're in the ready state
        [weakSelf.stateMachine transitionToState:SDLFileManagerStateReady];
    }];
}

- (void)didEnterStateReady {
    if (self.startupCompletionHandler != nil) {
        self.startupCompletionHandler(YES, nil);
        self.startupCompletionHandler = nil;
    }
}


#pragma mark - Private Listing Remote Files

- (void)sdl_listRemoteFilesWithCompletionHandler:(SDLFileManagerListFilesCompletionHandler)handler {
    __weak typeof(self) weakSelf = self;
    SDLListFilesOperation *listOperation = [[SDLListFilesOperation alloc] initWithConnectionManager:self.connectionManager
                                                                                  completionHandler:^(BOOL success, NSUInteger bytesAvailable, NSArray<NSString *> *_Nonnull fileNames, NSError *_Nullable error) {
                                                                                      if (error != nil || !success) {
                                                                                          handler(success, bytesAvailable, fileNames, error);
                                                                                          BLOCK_RETURN;
                                                                                      }

                                                                                      // If there was no error, set our properties and call back to the startup completion handler
                                                                                      [weakSelf.mutableRemoteFileNames addObjectsFromArray:fileNames];
                                                                                      weakSelf.bytesAvailable = bytesAvailable;

                                                                                      handler(success, bytesAvailable, fileNames, error);
                                                                                  }];

    [self.transactionQueue addOperation:listOperation];
}


#pragma mark - Deleting

- (void)deleteRemoteFileWithName:(SDLFileName *)name completionHandler:(nullable SDLFileManagerDeleteCompletionHandler)handler {
    if ((![self.remoteFileNames containsObject:name]) && (handler != nil)) {
        handler(NO, self.bytesAvailable, [NSError sdl_fileManager_noKnownFileError]);
    }

    __weak typeof(self) weakSelf = self;
    SDLDeleteFileOperation *deleteOperation = [[SDLDeleteFileOperation alloc] initWithFileName:name
                                                                             connectionManager:self.connectionManager
                                                                             completionHandler:^(BOOL success, NSUInteger bytesAvailable, NSError *_Nullable error) {
                                                                                 __strong typeof(weakSelf) strongSelf = weakSelf;

                                                                                 // Mutate self based on the changes
                                                                                 strongSelf.bytesAvailable = bytesAvailable;
                                                                                 if (success) {
                                                                                     [strongSelf.mutableRemoteFileNames removeObject:name];
                                                                                 }

                                                                                 if (handler != nil) {
                                                                                     handler(YES, self.bytesAvailable, nil);
                                                                                 }
                                                                             }];

    [self.transactionQueue addOperation:deleteOperation];
}


#pragma mark - Uploading

- (void)uploadFiles:(NSArray<SDLFile *> *)files completionHandler:(nullable SDLFileManagerMultiUploadCompletionHandler)completionHandler {
    if (files.count == 0) {
        return completionHandler([NSError sdl_fileManager_noFilesError]);
    }

    NSMutableDictionary *failedUploads = [[NSMutableDictionary alloc] init];
    dispatch_group_t uploadFilesTask = dispatch_group_create();

    dispatch_group_enter(uploadFilesTask);
    for (SDLFile *file in files) {
        dispatch_group_enter(uploadFilesTask);
        [self uploadFileAsync:file completionHandler:^(Boolean success, NSString * _Nonnull fileName, NSError * _Nullable error) {
            if (success == false) {
                failedUploads[fileName] = error;
            }

            dispatch_group_leave(uploadFilesTask);
        }];
    }
    dispatch_group_leave(uploadFilesTask);

    dispatch_queue_t waitingQueue = dispatch_queue_create(BackgroundUploadFilesWaitingQueue, DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(waitingQueue, ^{
        dispatch_group_wait(uploadFilesTask, DISPATCH_TIME_FOREVER);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (failedUploads.count > 0) {
                if (completionHandler == nil) {
                    return;
                }
                return completionHandler([NSError sdl_fileManager_unableToUploadError:failedUploads]);
            }

            if (completionHandler == nil) {
                return;
            }
            return completionHandler(nil);
        });
    });
}

// https://stackoverflow.com/questions/16512898/ios-dont-return-from-function-until-multiple-background-threads-complete
- (void)uploadFileAsync:(SDLFile *)file completionHandler:(void (^)(Boolean success, NSString *fileName, NSError * _Nullable error))handler {
    dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(backgroundQueue, ^{
        [self uploadFile:file completionHandler:^(BOOL success, NSUInteger bytesAvailable, NSError * _Nullable error) {
            Boolean uploadSuccess = success;
            NSString *uploadFileName = file.name;
            NSError *uploadError = nil;

            if (error != nil) {
                uploadSuccess = false;
                uploadError = error;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (handler == nil) { return; }
                return handler(uploadSuccess, uploadFileName, uploadError);
            });
        }];
    });
}

//- (void)uploadFiles:(NSArray<SDLFile *> *)files progressHandler:(nullable SDLFileManagerMultiUploadProgressHandler)progressHandler completionHandler:(nullable SDLFileManagerMultiUploadCompletionHandler)completionHandler {
//    // Calculate the total filesize of all files being uploaded
//    NSInteger fileSizeTotal = 0; // In bytes
//    // NSInteger totalBytesUploaded = 0;
//
//    for (SDLFile *file in files) {
//        fileSizeTotal += file.fileSize;
//    }
//
//    // For each file, call [self uploadFile]
//    for (SDLFile *file in files) {
//        [self uploadFile:file completionHandler:^(BOOL success, NSUInteger bytesAvailable, NSError * _Nullable error) {
//            if (progressHandler != nil) {
//                progressHandler(@"abcd", 0.3, true, error);
//            }
//        }];
//    }
//
//    // Wait for all of the file's completion handlers to be called
//    // -> fire off a completion handler when each file comes back
//    // NSError *newError = [[NSError alloc] initWithDomain:SDLErrorDomainFileManager code:sdl_fileManager_unableToUploadError userInfo:nil]; // userInfo is a list of files that could not be uploaded
//    return completionHandler(false);
//}

- (void)uploadFile:(SDLFile *)file completionHandler:(nullable SDLFileManagerUploadCompletionHandler)handler {
    if (file == nil) {
        if (handler != nil) {
            handler(NO, self.bytesAvailable, [NSError sdl_fileManager_unableToUploadError]);
        }
        return;
    }

    // Make sure we are able to send files
    if (![self.currentState isEqualToString:SDLFileManagerStateReady]) {
        if (handler != nil) {
            handler(NO, self.bytesAvailable, [NSError sdl_fileManager_unableToUploadError]);
        }
        return;
    }

    // Check our overwrite settings and error out if it would overwrite
    if (file.overwrite == NO && [self.remoteFileNames containsObject:file.name]) {
        if (handler != nil) {
            handler(NO, self.bytesAvailable, [NSError sdl_fileManager_cannotOverwriteError]);
        }

        return;
    }

    // If we didn't error out over the overwrite, then continue on
    [self sdl_uploadFile:file completionHandler:handler];
}

- (void)sdl_uploadFile:(SDLFile *)file completionHandler:(nullable SDLFileManagerUploadCompletionHandler)handler {
    __block NSString *fileName = file.name;
    __block SDLFileManagerUploadCompletionHandler uploadCompletion = [handler copy];

    __weak typeof(self) weakSelf = self;
    SDLFileWrapper *fileWrapper = [SDLFileWrapper wrapperWithFile:file
                                                completionHandler:^(BOOL success, NSUInteger bytesAvailable, NSError *_Nullable error) {
                                                    [weakSelf.class sdl_deleteTemporaryFile:file.fileURL];

                                                    if (bytesAvailable != 0) {
                                                        weakSelf.bytesAvailable = bytesAvailable;
                                                    }
                                                    if (success) {
                                                        [weakSelf.mutableRemoteFileNames addObject:fileName];
                                                    }
                                                    if (uploadCompletion != nil) {
                                                        uploadCompletion(success, bytesAvailable, error);
                                                    }
                                                }];

    SDLUploadFileOperation *uploadOperation = [[SDLUploadFileOperation alloc] initWithFile:fileWrapper connectionManager:self.connectionManager];

    [self.transactionQueue addOperation:uploadOperation];
}


#pragma mark - Temporary Files

+ (NSURL *)temporaryFileDirectory {
    NSURL *directoryURL = [self.class sdl_temporaryFileDirectoryName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[directoryURL path]]) {
        [[NSFileManager defaultManager] createDirectoryAtURL:directoryURL withIntermediateDirectories:NO attributes:nil error:nil];
    }

    return directoryURL;
}

+ (NSURL *)sdl_temporaryFileDirectoryName {
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"SDL"]];
}

+ (void)sdl_clearTemporaryFileDirectory {
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.class sdl_temporaryFileDirectoryName].absoluteString]) {
        [[NSFileManager defaultManager] removeItemAtURL:[self.class sdl_temporaryFileDirectoryName] error:&error];
    }

    if (error != nil) {
        SDLLogW(@"[Error clearing temporary file directory] %@", error);
    }
}

+ (void)sdl_deleteTemporaryFile:(NSURL *)fileURL {
    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtURL:fileURL error:&error]) {
        SDLLogW(@"[Error clearing temporary file directory] %@ (%@)", error, fileURL);
    }
}

@end


NS_ASSUME_NONNULL_END
