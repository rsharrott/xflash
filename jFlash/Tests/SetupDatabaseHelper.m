//
//  JFlashDatabase.m
//  jFlash
//
//  Created by Rendy Pranata on 20/07/11.
//  Copyright 2011 Long Weekend LLC. All rights reserved.
//

#import "SetupDatabaseHelper.h"

#import "SynthesizeSingleton.h"
#import "LWEFile.h"
#import "LWEDatabase.h"
#import "Constants.h"

#if defined (LWE_JFLASH)
  NSString * const CURRENT_USER_TEST_DATABASE  = @"jFlash.db";
  NSString * const CURRENT_CARD_TEST_DATABASE  = @"jFlash-CARD-2.0.db";
  NSString * const CURRENT_FTS_TEST_DATABASE   = @"jFlash-FTS-2.0.db";
#elif defined (LWE_CFLASH)
  NSString * const CURRENT_USER_TEST_DATABASE  = @"cFlash.db";
  NSString * const CURRENT_CARD_TEST_DATABASE  = @"cFlash-CARD-2.0.db";
  NSString * const CURRENT_FTS_TEST_DATABASE   = @"cFlash-FTS-2.0.db";
#endif

NSString * const kJFlashDatabaseErrorDomain         = @"kJFlashDatabaseErrorDomain";
NSUInteger const kJFlashCannotOpenDatabaseErrorCode   = 999;
NSUInteger const kJFlashCannotCopyDatabaseErrorCode   = 888;
NSUInteger const kJFlashCannotRemoveDatabaseErrorCode = 777;

@interface JFlashDatabase ()
@end

@implementation JFlashDatabase

SYNTHESIZE_SINGLETON_FOR_CLASS(JFlashDatabase);

- (BOOL)setupTestDatabaseAndOpenConnectionWithError:(NSError **)error
{
  //copy it to the user documents folder
  BOOL result = [LWEFile copyFromBundleWithFilename:LWE_CURRENT_USER_DATABASE toDocumentsWithFilename:CURRENT_USER_TEST_DATABASE shouldOverwrite:YES];
  if (!result)
  {
    //Cannot copy database
    NSString *msg = [[NSString alloc] initWithFormat:@"Cannot copy database file from the main bundle to the test dictionary."];
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:msg, NSLocalizedDescriptionKey, nil];
    NSError *theError = [NSError errorWithDomain:kJFlashDatabaseErrorDomain code:kJFlashCannotCopyDatabaseErrorCode userInfo:dict];
    *error = theError;
    
    [msg release];
    return NO;
  }

  //Construct the test database filename
  NSString *pathToDatabase = [LWEFile createDocumentPathWithFilename:CURRENT_USER_TEST_DATABASE];
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];

  //Create the connection for opening the database
  if ([db openDatabase:pathToDatabase])
  {
    return YES;
  }
  else
  {
    // Could not open database!
    NSString *msg = [[NSString alloc] initWithFormat:@"DatabaseFileNotFound.\nLooked for file: %@", pathToDatabase];
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:msg, NSLocalizedDescriptionKey, nil];
    
    NSError *theError = [NSError errorWithDomain:kJFlashDatabaseErrorDomain code:kJFlashCannotOpenDatabaseErrorCode userInfo:dict];
    *error = theError;
    
    [msg release];
    return NO;
  }
}

- (BOOL)setupAttachedDatabase:(NSString*)filename asName:(NSString*)name
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  BOOL returnVal = NO;
  if ([db.dao goodConnection])
  {
    NSString *pathToDatabase = [LWEFile createBundlePathWithFilename:filename];
    returnVal = [db attachDatabase:pathToDatabase withName:name];
  }
  return returnVal;
}

- (BOOL)removeTestDatabaseWithError:(NSError **)error
{
  LWEDatabase *db = [LWEDatabase sharedLWEDatabase];
  BOOL result = [db closeDatabase];
  if (result)
  {
    NSString *testDatabasePath = [LWEFile createDocumentPathWithFilename:CURRENT_USER_TEST_DATABASE];
    result = [LWEFile deleteFile:testDatabasePath];
    if (result)
    {
      return YES;
    }
    else
    {
      NSString *msg = [NSString stringWithFormat:@"Test database cannot be removed from the user documents folder."];
      NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:msg, NSLocalizedDescriptionKey, nil];
      *error = [NSError errorWithDomain:kJFlashDatabaseErrorDomain code:kJFlashCannotRemoveDatabaseErrorCode userInfo:dict];
      return NO;
    }
  }
  else
  {
    NSString *msg = [NSString stringWithFormat:@"Test database cannot be closed for some reason."];
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:msg, NSLocalizedDescriptionKey, nil];
    *error = [NSError errorWithDomain:kJFlashDatabaseErrorDomain code:kJFlashCannotRemoveDatabaseErrorCode userInfo:dict];
    return NO;
  }
}

@end