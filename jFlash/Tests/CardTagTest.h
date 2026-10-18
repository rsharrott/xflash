//
//  CardTagTest.h
//  jFlash
//
//  Created by Rendy Pranata on 19/07/11.
//  Copyright 2011 Long Weekend LLC. All rights reserved.
//
//  See Also: http://developer.apple.com/iphone/library/documentation/Xcode/Conceptual/iphone_development/135-Unit_Testing_Applications/unit_testing_applications.html

//  Application unit tests contain unit test code that must be injected into an application to run correctly.
//  Define USE_APPLICATION_UNIT_TEST to 0 if the unit test code is designed to be linked into an independent test executable.

#define USE_APPLICATION_UNIT_TEST 1

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
//#import "application_headers" as required


@interface CardTagTest : XCTestCase 
{
  Tag *tag_;
}

- (void)testProbabilityOfUnseenWhenMoreSeenThanPoolSize;
- (void)testProbabilityOfUnseenStaysInRange;
- (void)testPickCardLevelPicksSeenCardsAndNeverAnEmptyLevel;
- (void)testFrequencySliderMoreOftenMeansMoreNewCards;
- (void)testCalculateNextCardLevelWithError;
- (void) testUpdateLevelCounts;
- (void)testAddThenRemoveCardsFromStudySet;
- (void)testRecordCorrectFromLevel2MovesCardToLevel3;
- (void)testRecordCorrectFromLevel3MovesCardToLevel4;
- (void)testRecordWrongFromLevel0MovesCardToLevel1;
- (void)testRecordWrongFromLevel5MovesCardToLevel1;
@end