//
//  ExampleSentencesViewController.h
//  jFlash
//
//  Created by シャロット ロス on 6/5/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "Card.h"
#import "Plugin.h"

// Strings used as fake URL paths in WKWebView links to intercept button taps.
extern NSString * const TOKENIZE_SAMPLE_SENTENCE;
extern NSString * const ADD_CARD_TO_SET;
extern NSString * const SPEAK_SENTENCE;

// The HTML template we show the example sentences in.
extern NSString * const LWESentencesHTML;

@interface ExampleSentencesViewController : UIViewController <WKNavigationDelegate>
{
  BOOL _useOldPluginMethods;
}

- (id) initWithExamplesPlugin:(Plugin *)plugin;

//! LWESentencesHTML (unit tests reach it through the class: app symbols aren't exported to the test bundle)
+ (NSString *) sentencesHTMLTemplate;
//! The reading + Add cells of one word row in an expanded sentence (`addTitle` is localized by the caller).
//! The Add cell has class 'AddCell', so its button never wraps (ja 追加 must not break into 追 / 加).
+ (NSString *) wordCellsHTMLWithReading:(NSString *)reading cardId:(NSInteger)cardId addTitle:(NSString *)addTitle;
- (void) setupWithCard:(Card*)card;

@property (retain) NSMutableDictionary *sampleDecomposition;
@property (nonatomic, retain) WKWebView *sentencesWebView;

@end