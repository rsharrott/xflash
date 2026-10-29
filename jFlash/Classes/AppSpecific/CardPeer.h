#import "Card.h"

@class Tag;

/** Peer object to retrieve & handle Card objects */
@interface CardPeer : NSObject

//! Factory methods for getting a card
+ (Card *) blankCardWithId:(NSInteger)cardId;
+ (Card *) blankCard;

//! Card methods
+ (Card*) retrieveCardByPK:(NSInteger)cardId;

//! Six arrays of card-id NSNumbers, one per study level. A full Card is loaded later, for the card on screen.
+ (NSMutableArray*) retrieveCardsSortedByLevelForTag:(Tag *)tag;
//! Card ids for a set's word list, in link-table order. A row is loaded when it is shown.
+ (NSArray*) retrieveCardIdsForTag:(Tag *)tag;
//! Blank cards (id only). Search uses these for its starred-set cache.
+ (NSArray*) retrieveFaultedCardsForTag:(Tag *)tag;
//! The card to show for an id stored on a study set. A missing row comes back as a blank card.
+ (Card *) hydratedCardWithId:(NSInteger)cardId;

//! Example sentences
+ (NSArray*) retrieveCardSetForExampleSentenceId:(NSInteger)sentenceID;

//! Search methods
+ (BOOL) keywordIsReading:(NSString *)keyword;
+ (BOOL) keywordIsHeadword:(NSString *)keyword;
+ (NSArray*) searchCardsForKeyword:(NSString *)keyword;
@end