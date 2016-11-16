/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "MSWrapperExceptionManager.h"
#import "MSCrashes.h"
#import "MSException.h"
#import "MSCrashesInternal.h"

@interface MSWrapperExceptionManager ()

@property MSException *wrapperException;
@property NSMutableDictionary *wrapperExceptionData;
@property NSData *unsavedWrapperExceptionData;
@property CFUUIDRef currentUUIDRef;

+ (MSWrapperExceptionManager*)sharedInstance;
- (BOOL)hasException;
- (MSException*)loadWrapperException:(CFUUIDRef)uuidRef;
- (void)saveWrapperException:(CFUUIDRef)uuidRef;
- (void)deleteWrapperExceptionWithUUID:(CFUUIDRef)uuidRef;
- (void)deleteAllWrapperExceptions;

- (void)saveWrapperExceptionData:(CFUUIDRef)uuidRef;

- (NSData*)loadWrapperExceptionDataWithUUIDString:(NSString*)uuidString;
- (void)deleteWrapperExceptionDataWithUUIDString:(NSString*)uuidString;

+ (NSString*)directoryPath;

+ (NSString*)getFilename:(NSString*)uuidString;
+ (NSString*)getDataFilename:(NSString*)uuidString;
+ (NSString*)getFilenameWithUUIDRef:(CFUUIDRef)uuidRef;
+ (NSString*)getDataFilenameWithUUIDRef:(CFUUIDRef)uuidRef;
+ (void)deleteFile:(NSString*)path;
+ (BOOL)isDataFile:(NSString*)path;
+ (NSString*)uuidRefToString:(CFUUIDRef)uuidRef;
//+ (BOOL)isCurrentUUIDRef:(CFUUIDRef)uuidRef;

@end

static NSString *const datExtension = @"dat";
static NSString *const directoryName = @"wrapper_exceptions";

@implementation MSWrapperExceptionManager : NSObject

+ (NSString*)directoryPath {
  static NSString* directoryPath = nil;

  if (!directoryPath) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    directoryPath = [documentsDirectory stringByAppendingPathComponent:directoryName];
  }

  return directoryPath;
}

+ (NSString*)getFilename:(NSString*)uuidString {
  return [[self directoryPath] stringByAppendingPathComponent:uuidString];
}

+ (NSString*)getDataFilename:(NSString*)uuidString {
  NSString *filename = [MSWrapperExceptionManager getFilename:uuidString];
  return [filename stringByAppendingPathExtension:datExtension];
}

+ (NSString*)getFilenameWithUUIDRef:(CFUUIDRef)uuidRef {
  NSString *uuidString = [MSWrapperExceptionManager uuidRefToString:uuidRef];
  return [MSWrapperExceptionManager getFilename:uuidString];
}

+ (NSString*)getDataFilenameWithUUIDRef:(CFUUIDRef)uuidRef {
  NSString *uuidString = [MSWrapperExceptionManager uuidRefToString:uuidRef];
  return [MSWrapperExceptionManager getDataFilename:uuidString];
}

+ (BOOL) isDataFile:(NSString*)path {
  return path ? [path hasSuffix:[@"" stringByAppendingPathExtension:datExtension]] : false;
}

#pragma mark - Public methods

+ (BOOL)hasException {
  return [[self sharedInstance] hasException];
}

+ (void)setWrapperException:(MSException *)wrapperException {
  [self sharedInstance].wrapperException = wrapperException;
}

+ (void)saveWrapperExceptionData:(CFUUIDRef)uuidRef {
  [[self sharedInstance] saveWrapperExceptionData:uuidRef];
}

+ (NSData*)loadWrapperExceptionDataWithUUIDString:(NSString*)uuidString {
  return [[self sharedInstance] loadWrapperExceptionDataWithUUIDString:uuidString];
}

+ (MSException*)loadWrapperException:(CFUUIDRef)uuidRef {
  return [[self sharedInstance] loadWrapperException:uuidRef];
}

+ (void)saveWrapperException:(CFUUIDRef)uuidRef {
  [[self sharedInstance] saveWrapperException:uuidRef];
}

+ (void)setWrapperExceptionData:(NSData *)data {
  [self sharedInstance].unsavedWrapperExceptionData = data;
}

+ (void)deleteWrapperExceptionWithUUID:(CFUUIDRef)uuidRef {
  [[self sharedInstance] deleteWrapperExceptionWithUUID:uuidRef];
}

+ (void)deleteAllWrapperExceptions {
  [[self sharedInstance] deleteAllWrapperExceptions];
}

+ (void)deleteWrapperExceptionDataWithUUIDString:(NSString*)uuidString {
  [[self sharedInstance] deleteWrapperExceptionDataWithUUIDString:uuidString];
}
+ (void)deleteAllWrapperExceptionData {
  [[self sharedInstance] deleteAllWrapperExceptionData];
}

#pragma mark - Private methods

- (instancetype)init {
  if ((self = [super init])) {

    _unsavedWrapperExceptionData = nil;
    _wrapperException = nil;
    _wrapperExceptionData = [[NSMutableDictionary alloc] init];
    _currentUUIDRef = nil;

    // Create the directory if it doesn't exist
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    NSString *directoryPath = [MSWrapperExceptionManager directoryPath];

    if (![defaultManager fileExistsAtPath:directoryPath]) {
      NSError *error = nil;
      [defaultManager createDirectoryAtPath:directoryPath
                withIntermediateDirectories:NO
                                 attributes:nil
                                      error:&error];
      if (error) {
        MSLogError([MSCrashes getLoggerTag], @"Failed to create directory %@: %@",
                   directoryPath, error.localizedDescription);
      }
    }
  }
  
  return self;
}

+ (instancetype)sharedInstance {
  static MSWrapperExceptionManager *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (BOOL)hasException {
  return _wrapperException != nil;
}

- (MSException*)loadWrapperException:(CFUUIDRef)uuidRef {
  if (_wrapperException && CFEqual(_currentUUIDRef, uuidRef)) {
    return _wrapperException;
  }

  NSString *filename = [MSWrapperExceptionManager getFilenameWithUUIDRef:uuidRef];
  MSException *loadedException = [NSKeyedUnarchiver unarchiveObjectWithFile:filename];

  if (!loadedException) {
    MSLogError([MSCrashes getLoggerTag], @"Could not load wrapper exception from file %@", filename);
    return nil;
  }

  _wrapperException = loadedException;
  _currentUUIDRef = uuidRef;

  return _wrapperException;
}

- (void)saveWrapperException:(CFUUIDRef)uuidRef {
  NSString *filename = [MSWrapperExceptionManager getFilenameWithUUIDRef:uuidRef];
  [self saveWrapperExceptionData:uuidRef];
  BOOL success = [NSKeyedArchiver archiveRootObject:_wrapperException toFile:filename];
  if (!success) {
    MSLogError([MSCrashes getLoggerTag], @"Failed to save file %@", filename);
  }
}

- (void)deleteWrapperExceptionWithUUID:(CFUUIDRef)uuidRef {
  NSString *path = [MSWrapperExceptionManager getFilenameWithUUIDRef:uuidRef];
  [MSWrapperExceptionManager deleteFile:path];

  if (CFEqual(_currentUUIDRef, uuidRef)) {
    _currentUUIDRef = nil;
    _wrapperException = nil;
  }
}

- (void)deleteAllWrapperExceptions {
  _currentUUIDRef = nil;
  _wrapperException = nil;

  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *directoryPath = [MSWrapperExceptionManager directoryPath];

  for (NSString *filePath in [fileManager enumeratorAtPath:directoryPath]) {
    if (![MSWrapperExceptionManager isDataFile:filePath]) {
      NSString *path = [directoryPath stringByAppendingPathComponent:filePath];
      [MSWrapperExceptionManager deleteFile:path];
    }
  }
}

- (void)saveWrapperExceptionData:(CFUUIDRef)uuidRef {
  NSString* dataFilename = [MSWrapperExceptionManager getDataFilenameWithUUIDRef:uuidRef];
  [_unsavedWrapperExceptionData writeToFile:dataFilename atomically:YES];
}

- (NSData*)loadWrapperExceptionDataWithUUIDString:(NSString*)uuidString {
  NSString* dataFilename = [MSWrapperExceptionManager getDataFilename:uuidString];
  NSData *data = [_wrapperExceptionData objectForKey:dataFilename];
  if (data) {
    return data;
  }

  NSError *error = nil;
  data = [NSData dataWithContentsOfFile:dataFilename options:NSDataReadingMappedIfSafe error:&error];
  if (error) {
    MSLogError([MSCrashes getLoggerTag], @"Error loading file %@: %@",
               dataFilename, error.localizedDescription);
  }

  return data;
}

- (void)deleteWrapperExceptionDataWithUUIDString:(NSString*)uuidString {
  NSString* dataFilename = [MSWrapperExceptionManager getDataFilename:uuidString];
  NSData *data = [self loadWrapperExceptionDataWithUUIDString:uuidString];
  if (data) {
    [_wrapperExceptionData setObject:data forKey:dataFilename];
  }
  [MSWrapperExceptionManager deleteFile:dataFilename];
}

- (void)deleteAllWrapperExceptionData {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *directoryPath = [MSWrapperExceptionManager directoryPath];
  for (NSString *filePath in [fileManager enumeratorAtPath:directoryPath]) {
    if ([MSWrapperExceptionManager isDataFile:filePath]) {
      NSString *path = [directoryPath stringByAppendingPathComponent:filePath];
      [MSWrapperExceptionManager deleteFile:path];
    }
  }
}

+ (void)deleteFile:(NSString*)path {
  NSError *error = nil;
  [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
  if (error) {
    MSLogError([MSCrashes getLoggerTag], @"Error deleting file %@: %@",
               path, error.localizedDescription);
  }
}

+ (NSString*)uuidRefToString:(CFUUIDRef)uuidRef {
  if (!uuidRef) {
    return nil;
  }
  CFStringRef uuidStringRef = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
  return (__bridge_transfer NSString*)uuidStringRef;
}

//+ (BOOL)isCurrentUUIDRef:(CFUUIDRef)uuidRef {
//  CFUUIDRef currentUUIDRef = [MSWrapperExceptionManager sharedInstance].currentUUIDRef;
//
//  BOOL currentUUIDRefIsNull = (currentUUIDRef == kCFNull);
//  BOOL uuidRefIsNull = (uuidRef == kCFNull);
//
//  if (currentUUIDRefIsNull && uuidRefIsNull) {
//    return true;
//  }
//  if (currentUUIDRefIsNull || uuidRefIsNull) {
//    return false;
//  }
//
//  // For whatever reason, CF
//  NSString *uuidString = [MSWrapperExceptionManager uuidRefToString:uuidRef];
//  NSString *currentUUIDString = [MSWrapperExceptionManager uuidRefToString:currentUUIDRef];
//
//  return [uuidString isEqualToString:currentUUIDString];
//}

@end
