//
//  Tag.h
//  jFlash
//
//  Created by Paul Chapman on 5/6/09.
//  Copyright 2009 LONG WEEKEND INC. All rights reserved.
//

#import "Constants.h"
#import "Card.h"
#import "CardPeer.h"
#import "FMResultSet.h"
#import "LWEFile.h"
#import "LWEDatabase.h"

extern NSString * const kTagErrorDomain;
extern NSUInteger const kAllBuriedAndHiddenError;
extern NSUInteger const kLWETagUnknownError;

extern NSInteger const kLWEUninitializedTagId;
extern NSInteger const kLWEUnseenCardLevel;
extern NSInteger const kLWELearnedCardLevel;

//! Japanese built-in names, jFlash only.  cFlash always returns NO.
//! Pass nil to clear the test override and follow the app language.
BOOL LWEBuiltInCatalogUsesJapanese(void);
void LWESetBuiltInCatalogLanguageOverride(NSString *languageOrNil);

@interface Tag : NSObject

- (void) hydrateWithResultSet:(FMResultSet*)rs;
- (void) hydrate;
- (void) save;

//! Factory method that returns the starred words tag
+ (Tag *) starredWordsTag;

//! Factory method for an unitialized tag that only has its ID set
+ (Tag *) blankTagWithId:(NSInteger)tagId;

//! Returns YES if the user is allowed to edit this tag (either description or the contents)
- (BOOL) isEditable;

- (void) populateCardIds;
- (void) moveCard:(Card*) card toLevel:(NSInteger) nextLevel;
- (void) recacheCardCountForEachLevel;
- (void) freezeCardIds;
- (NSMutableArray *) thawCardIds;
- (void) removeCardFromActiveSet:(Card *)card;
- (void) addCardToActiveSet:(Card *)card;
- (NSMutableArray *) flattenCardArrays;
- (NSInteger) seenCardCount;
- (NSInteger) groupId;

//! Is the tag deletable by the user?
@property (nonatomic) NSInteger tagEditable;
@property (nonatomic, retain) NSString *tagName;
@property (nonatomic, retain) NSString *tagDescription;
//! Japanese catalog columns.  Nil on cFlash and on any set without a translation.
@property (nonatomic, retain) NSString *tagNameJa;
@property (nonatomic, retain) NSString *tagDescriptionJa;

//! Name to show.  Japanese for a built-in set when the app language is Japanese.
//! A user-created set always returns tagName.
- (NSString *)displayName;
//! Description to show, under the same rule as displayName.
- (NSString *)displayDescription;
//! Six arrays of card-id NSNumbers, one per study level (0 unseen through 5 learned).
@property (nonatomic, retain) NSMutableArray *cardsByLevel;
//! Every card id in the set, sorted by card id, for browse mode.
@property (nonatomic, retain) NSMutableArray *flattenedCardIdArray;
@property (nonatomic, retain) NSMutableArray *cardLevelCounts;
@property (nonatomic) NSInteger tagId;
@property (nonatomic) NSInteger currentIndex;

//! Returns YES if this Tag is not actually a Tag, but a shell of a tag.  If so, call -hydrate
@property (readonly) BOOL isFault;

//! Current count of Card objects in the Tag
@property NSInteger cardCount;

@end