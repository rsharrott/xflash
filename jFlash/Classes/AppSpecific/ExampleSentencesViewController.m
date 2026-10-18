//
//  ExampleSentencesViewController.m
//  jFlash
//
//  Created by シャロット ロス on 6/5/10.
//  Copyright 2010 LONG WEEKEND INC.. All rights reserved.
//

#import "ExampleSentencesViewController.h"

// Hack that I need this
#import "CardViewController.h"

#import "ExampleSentencePeer.h"
#import "NSURL+LWEUtilities.h"
#import "AddTagViewController.h"
#import "jFlashAppDelegate.h"
#import <AVFoundation/AVFoundation.h>

#define SHOW_BUTTON_TITLE NSLocalizedString(@"Read",@"ReadButton")
#define CLOSE_BUTTON_TITLE NSLocalizedString(@"Close",@"CloseButton")
#define ADD_BUTTON_TITLE NSLocalizedString(@"Add",@"AddButton")

@interface ExampleSentencesViewController ()
{
  AVSpeechSynthesizer *_speechSynthesizer;
  NSMutableDictionary *_sentenceTexts; // sentenceId (string) → sentenceJa
}
- (void)_showAddToSetWithCardID:(NSString *)cardID;
- (void)_showCardsForSentences:(NSString *)sentenceIDStr isOpen:(BOOL)isOpen webView:(WKWebView *)webView;
- (NSString *)_generateCardCompositionStringWithSentenceId:(NSInteger)sentenceId;
- (AVSpeechSynthesisVoice *)_bestJapaneseVoice;
@end

@implementation ExampleSentencesViewController
@synthesize sentencesWebView;
@synthesize sampleDecomposition;

#pragma mark - UIView subclass methods

- (id)initWithExamplesPlugin:(Plugin *)plugin
{
  if ((self = [super init]))
  {
    LWE_ASSERT_EXC([plugin.pluginId isEqualToString:EXAMPLE_DB_KEY], @"This class only knows how to deal with EXAMPLE_DB_KEY plugin");
    self.sampleDecomposition = [NSMutableDictionary dictionary];
    _speechSynthesizer = [[AVSpeechSynthesizer alloc] init];
    _sentenceTexts = [[NSMutableDictionary alloc] init];
    
    // What version of the example sentence plugin are we using?  If 1.1, it's old.
#if defined (LWE_JFLASH)
    _useOldPluginMethods = [plugin.version isEqualToString:@"1.1"];
    // I want to know if someone updated their example sentence version
#endif
    if (_useOldPluginMethods)
    {
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_pluginDidInstall:) name:LWEPluginDidInstall object:nil];
    }
	}
	return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
  [super viewDidLoad];
  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  WKWebView *wv = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
  [config release];
  wv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  wv.navigationDelegate = self;
  wv.opaque = NO;
  wv.backgroundColor = [UIColor clearColor];
  wv.scrollView.bounces = NO;
  [self.view addSubview:wv];
  self.sentencesWebView = wv;
  [wv release];
}


#pragma mark - Private

/**
 * Callback for when a plugin is installed.  
 * If it's the example sentence DB, update the version
 * of this controller so we know which methods to use
 * (1.1 or 1.2)
 */
- (void) _pluginDidInstall:(NSNotification*)aNotification
{
  Plugin *installedPlugin = (Plugin *)aNotification.object;
  if ([installedPlugin.pluginId isEqualToString:EXAMPLE_DB_KEY] && ![installedPlugin.version isEqualToString:@"1.1"])
  {
    _useOldPluginMethods = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LWEPluginDidInstall object:nil];
  }
}


#pragma mark - Core Methods

//* setup the example sentences view with information from the datasource
- (void) setupWithCard:(Card *)card
{
#if defined(LWE_JFLASH)
  // 2026 design: big yellow headword, kana with muted romaji, and each sentence on its own
  // translucent panel (Japanese, then English, then the Read / speak pills).
  NSArray *readingParts = [card.reading componentsSeparatedByString:@" - "];
  NSString *kanaPart = [readingParts count] > 0 ? [readingParts objectAtIndex:0] : @"";
  NSString *romajiPart = [readingParts count] > 1 ? [readingParts objectAtIndex:1] : @"";
  NSMutableString *sentencesHTML = [[NSMutableString alloc] initWithFormat:
    @"<div class='exHeader'><h2 class='headwordLabel'>%@</h2><div class='readingLabel'>%@ <span class='romaji'>%@</span></div></div>"
    @"<div class='exTitle'>%@</div><ol>",
    card.headword, kanaPart, romajiPart, NSLocalizedString(@"Example sentences", @"ExampleSentences.Title")];
#else
  NSMutableString *sentencesHTML = [[NSMutableString alloc] initWithFormat:@"<div class='readingLabel'>%@</div><h2 class='headwordLabel'>%@</h2><ol>",card.reading,card.headword];
#endif

  [_sentenceTexts removeAllObjects];

  // Get all sentences out - extract this
  NSMutableArray *sentences = [ExampleSentencePeer getExampleSentencesByCardId:card.cardId];
  for (ExampleSentence *sentence in sentences)
  {
    NSString *sentenceIdStr = [NSString stringWithFormat:@"%d", sentence.sentenceId];
    [_sentenceTexts setObject:sentence.sentenceJa forKey:sentenceIdStr];

    NSString *speakSVG = @"<svg xmlns='http://www.w3.org/2000/svg' width='14' height='14' viewBox='0 0 24 24' fill='white' style='vertical-align:middle'><path d='M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z'/></svg>";
    NSString *speakLink = [NSString stringWithFormat:@"<a href='http://xflash.com/%@?id=%d'><span class='button'>%@</span></a>",
      SPEAK_SENTENCE, sentence.sentenceId, speakSVG];

#if defined(LWE_JFLASH)
    // The studied word is highlighted inside the sentence (when it appears as written).
    NSString *ja = sentence.sentenceJa ?: @"";
    if ([card.headword length] > 0)
    {
      ja = [ja stringByReplacingOccurrencesOfString:card.headword
                                         withString:[NSString stringWithFormat:@"<span class='hl'>%@</span>", card.headword]];
    }
    [sentencesHTML appendFormat:@"<li><div class='ja'>%@</div><div class='en'>%@</div>", ja, sentence.sentenceEn];
    if (_useOldPluginMethods == NO)
    {
      [sentencesHTML appendFormat:@"<div class='showWordsDiv'><a id='anchor%d' href='http://xflash.com/%@?id=%d&open=0'><span class='button'>%@</span></a> %@</div>",
        sentence.sentenceId, TOKENIZE_SAMPLE_SENTENCE, sentence.sentenceId, SHOW_BUTTON_TITLE, speakLink];
      [sentencesHTML appendFormat:@"<div id='detailedCards%d'></div>", sentence.sentenceId];
    }
    else
    {
      [sentencesHTML appendFormat:@"<div class='showWordsDiv'>%@</div>", speakLink];
    }
    [sentencesHTML appendString:@"</li>"];
#else
    [sentencesHTML appendFormat:@"<li>"];
    if (_useOldPluginMethods == NO)
    {
      [sentencesHTML appendFormat:@"<div class='showWordsDiv'><a id='anchor%d' href='http://xflash.com/%@?id=%d&open=0'><span class='button'>%@</span></a> %@</div>",
        sentence.sentenceId, TOKENIZE_SAMPLE_SENTENCE, sentence.sentenceId, SHOW_BUTTON_TITLE, speakLink];
    }
    else
    {
      [sentencesHTML appendFormat:@"<div class='showWordsDiv'>%@</div>", speakLink];
    }
    [sentencesHTML appendFormat:@"%@<br />", sentence.sentenceJa];

    if (_useOldPluginMethods == NO)
    {
      [sentencesHTML appendFormat:@"<div id='detailedCards%d'></div>", sentence.sentenceId];
    }
    [sentencesHTML appendFormat:@"<div class='lowlight'>%@</div></li>", sentence.sentenceEn];
#endif
  }
  [sentencesHTML appendFormat:@"</ol>"];
  
  if ([self.sampleDecomposition count] > 0)
  {
    [self.sampleDecomposition removeAllObjects];
  }

  // Replace the CSS & the sentences to create the full HTML string
  NSString *cssHeader = [[ThemeManager sharedThemeManager] currentThemeCSS];
  NSString *html = [LWESentencesHTML stringByReplacingOccurrencesOfString:@"##THEMECSS##" withString:cssHeader];
  html = [html stringByReplacingOccurrencesOfString:@"##EXAMPLES##" withString:sentencesHTML];
  [self.sentencesWebView loadHTMLString:html baseURL:nil];

  [sentencesHTML release];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
  NSURLRequest *request = navigationAction.request;
  NSString *url = [[request URL] relativePath];

  if (url == nil || [url isEqualToString:@"about:blank"])
  {
    decisionHandler(WKNavigationActionPolicyAllow);
    return;
  }

  NSDictionary *dict = [[request URL] queryStrings];

  NSRange slashPosition = [url rangeOfString:@"/"];
  if (slashPosition.location != NSNotFound)
  {
    url = [url substringFromIndex:slashPosition.location+1];
  }

  if ([url isEqualToString:TOKENIZE_SAMPLE_SENTENCE])
  {
    BOOL isOpen = [[dict objectForKey:@"open"] isEqualToString:@"1"];
    [self _showCardsForSentences:[dict objectForKey:@"id"] isOpen:isOpen webView:webView];
  }
  else if ([url isEqualToString:ADD_CARD_TO_SET])
  {
    [self _showAddToSetWithCardID:[dict objectForKey:@"id"]];
  }
  else if ([url isEqualToString:SPEAK_SENTENCE])
  {
    NSString *sentenceId = [dict objectForKey:@"id"];
    NSString *text = [_sentenceTexts objectForKey:sentenceId];
    if (text.length > 0)
    {
      [_speechSynthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
      AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:text];
      utterance.voice = [self _bestJapaneseVoice];
      utterance.rate = 0.4f;
      [_speechSynthesizer speakUtterance:utterance];
    }
  }

  decisionHandler(WKNavigationActionPolicyCancel);
}

- (void)_showAddToSetWithCardID:(NSString *)cardID
{
	AddTagViewController *tmpVC = [[AddTagViewController alloc] initWithCard:[CardPeer retrieveCardByPK:[cardID intValue]]];

	// Set up DONE button
	UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"AddTagViewController.NavDoneButtonTitle") 
																style:UIBarButtonItemStyleBordered 
															   target:tmpVC
															   action:@selector(dismissModalViewControllerAnimated:)];

	tmpVC.navigationItem.leftBarButtonItem = doneBtn;
	NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:tmpVC, @"controller", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:LWEShouldShowModal object:self userInfo:dict];
	
	[doneBtn release];
	[tmpVC release];
	[dict release];
}

- (void)_showCardsForSentences:(NSString *)sentenceIDStr isOpen:(BOOL)isOpen webView:(WKWebView *)webView
{
	NSString *js = nil;
	if (isOpen)
	{
		//Close the expanded div. Return back the status of the expaned button
		js = [NSString stringWithFormat:@"document.getElementById('detailedCards%@').innerHTML = ''; ",sentenceIDStr];
		js = [js stringByAppendingFormat:@"document.getElementById('anchor%@').firstChild.innerHTML = '%@'; ",sentenceIDStr,SHOW_BUTTON_TITLE];
		js = [js stringByAppendingFormat:@"document.getElementById('anchor%@').href = 'http://xflash.com/%@?id=%@&open=0'; ",sentenceIDStr,TOKENIZE_SAMPLE_SENTENCE,sentenceIDStr];
		[webView evaluateJavaScript:js completionHandler:nil];
	}
	else
	{
		//expand the sample sentence.
		//Try to look at the dictionary representative of the example decomposition in the memory, if its null, populate a new one,
		//if its not. it just takes the sample decomposition out from it.
		NSString *cardHTML = [self.sampleDecomposition objectForKey:sentenceIDStr];
		if (cardHTML == nil)
		{
      cardHTML = [self _generateCardCompositionStringWithSentenceId:[sentenceIDStr intValue]];
			[self.sampleDecomposition setObject:cardHTML forKey:sentenceIDStr];
		}
		
		//First, put the tokenized sample sentence to the detailedcard-"id" blank div.
		//then tries to change the anchor value, and the href query string. 
		js = [NSString stringWithFormat:@"document.getElementById('detailedCards%@').innerHTML = \"%@\";",sentenceIDStr,cardHTML];
		js = [js stringByAppendingFormat:@"document.getElementById('anchor%@').firstChild.innerHTML = '%@';",sentenceIDStr,CLOSE_BUTTON_TITLE];
		js = [js stringByAppendingFormat:@"document.getElementById('anchor%@').href = 'http://xflash.com/%@?id=%@&open=1';",sentenceIDStr,TOKENIZE_SAMPLE_SENTENCE,sentenceIDStr];
		
		[webView evaluateJavaScript:js completionHandler:nil];
	}
}

- (NSString *)_generateCardCompositionStringWithSentenceId:(NSInteger)sentenceId
{
  NSArray *arrayOfCards = [CardPeer retrieveCardSetForExampleSentenceId:sentenceId];
  NSMutableString *cardHTML = [NSMutableString string];
  [cardHTML appendString: @"<table class='ExpandedSentencesTable' cellpadding='5'>"];

  NSString *lastHeadword = nil;
  for (Card *c in arrayOfCards)
  {
    [cardHTML appendString:@"<tr class='HeadwordRow'>"];
    
    // This block keeps us from showing the same headword over and over when it just has multiple meanings
    NSString *cardHeadword = [c headwordIgnoringMode:YES];
    if ([cardHeadword isEqualToString:lastHeadword] == NO)
    {
      [cardHTML appendFormat:@"<td class='HeadwordCell'>%@</td>",cardHeadword]; 
      lastHeadword = cardHeadword;
    }
    else 
    {
      [cardHTML appendString:@"<td class='HeadwordCell'></td>"]; 
    }
    
    [cardHTML appendFormat:@"<td class='ContentCell'>%@</td><td><a href='http://xflash.com/%@?id=%d' class='AddToSetAnchor'><span class='button'>%@</span></a></td>",c.reading,ADD_CARD_TO_SET,c.cardId,ADD_BUTTON_TITLE];
    [cardHTML appendString:@"</tr>"];
  }
  
  [cardHTML appendString:@"</table>"];
  return (NSString *)cardHTML;
}

- (AVSpeechSynthesisVoice *)_bestJapaneseVoice
{
  AVSpeechSynthesisVoice *enhanced = nil;
  for (AVSpeechSynthesisVoice *v in [AVSpeechSynthesisVoice speechVoices]) {
    if (![v.language isEqualToString:@"ja-JP"]) continue;
    if (@available(iOS 16.0, *)) {
      if (v.quality == AVSpeechSynthesisVoiceQualityPremium) return v;
    }
    if (v.quality == AVSpeechSynthesisVoiceQualityEnhanced) enhanced = v;
  }
  return enhanced ?: [AVSpeechSynthesisVoice voiceWithLanguage:@"ja-JP"];
}

#pragma mark - Class Plumbing

- (void)viewDidUnload
{
  [super viewDidUnload];
  self.sentencesWebView = nil;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:LWEPluginDidInstall object:nil];
  [sentencesWebView release];
  [sampleDecomposition release];
  [_speechSynthesizer release];
  [_sentenceTexts release];
  [super dealloc];
}

@end

NSString * const TOKENIZE_SAMPLE_SENTENCE = @"0";
NSString * const ADD_CARD_TO_SET = @"1";
NSString * const SPEAK_SENTENCE = @"speak";

NSString * const LWESentencesHTML = @""
"<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Transitional//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd'>"
"<html><head><meta http-equiv='Content-Type' content='text/html; charset=utf-8' />"
"<meta name='viewport' content='width=device-width, initial-scale=1.0' />"
"<style>"
#if defined(LWE_JFLASH)
// 2026 design (Japanese in a Flash).  Text colours keep at least 4.5:1 on the card red / dark panels.
"body{ background-color:transparent; margin:0; padding:22px 20px 28px 20px; box-sizing:border-box; width:100%; text-align:left; font-size:17px; font-family:'Helvetica Neue','Hiragino Sans',Helvetica,sans-serif; color:#fff; -webkit-text-size-adjust:none; } "
".exHeader{ margin:0 4px 22px 4px; } "
".headwordLabel{ font-size:2.35em; font-weight:800; line-height:1.1; letter-spacing:-0.5px; color:#FFD60A; margin:0 0 6px 0; } "
".readingLabel{ font-size:1.05em; font-weight:500; color:#fff; margin:0; } "
".romaji{ color:rgba(255,255,255,0.88); margin-left:6px; } "
".exTitle{ font-size:0.76em; font-weight:700; letter-spacing:1.2px; text-transform:uppercase; color:rgba(255,255,255,0.88); margin:0 4px 10px 4px; } "
"ol{ list-style:none; margin:0; padding:0; } "
"li{ background:rgba(0,0,0,0.14); border-radius:20px; padding:16px 18px 14px 18px; margin:0 0 12px 0; overflow:hidden; } "
".ja{ font-size:1.06em; font-weight:600; line-height:1.5; color:#fff; } "
".hl{ color:#FFD60A; } "
".en{ font-size:0.92em; font-weight:400; line-height:1.4; color:rgba(255,255,255,0.88); margin-top:6px; } "
".showWordsDiv{ margin-top:12px; } "
".button{ display:inline-block; font-size:0.8em; font-weight:600; line-height:1; color:#fff; background:rgba(0,0,0,0.2); border-radius:14px; padding:7px 13px; margin-right:6px; vertical-align:middle; } "
".button svg{ display:block; } "
"dfn{ font-style:normal; font-weight:600; color:#3a2a00; font-size:0.72em; background-color:#FFD60A; border-radius:6px; padding:2px 6px; margin:0 4px 0 0; display:inline-block; } "
"#container{ display:block; width:100%; text-align:left; } "
".ExpandedSentencesTable{ width:100%; border-collapse:collapse; margin:12px 0 2px 0; } "
".ExpandedSentencesTable td{ border-top:1px solid rgba(255,255,255,0.18); padding:9px 4px; vertical-align:middle; } "
".HeadwordCell{ font-size:1em; font-weight:700; color:#FFD60A; width:30%; } "
".ContentCell{ font-size:0.88em; color:rgba(255,255,255,0.9); } "
".AddToSetAnchor{ float:right; } "
" a{ text-decoration:none; -webkit-tap-highlight-color:transparent; } "
#else
"body{ background-color: transparent; margin:0; padding: 0 10px; box-sizing:border-box; width:100%; text-align:left; line-height:21px; font-size:16px; font-weight:bold; font-family:Helvetica,sanserif; color:#fff; } "
"dfn{ text-shadow:none; font-weight:normal; color:#000; position:relative; top:-1px; font-family:verdana; font-size:10.5px; background-color:#C79810; line-height:10.5px; margin:4px 4px 0px 0px; height:14px; padding:2px 3px; -webkit-border-radius:4px; border:1px solid #F9F7ED; display:inline-block;} "
".button{ font-size:14px; margin:2px 0px 2px 0px; padding: 2px 4px 3px 4px; display: inline; background: #777; border: none; color: #fff; font-weight: bold; border-radius: 3px; -moz-border-radius: 3px; -webkit-border-radius: 3px; background: rgba(0,0,0,0.3);} "
".showWordsDiv { float: right; margin: 0px 0px 9px 9px; }"
"#container{ display:block; width:100%; text-align:left; } "
"ol{ color:white; text-align:left; width:100%; box-sizing:border-box; margin:0px; padding-left:0px; list-style-position:inside; } "
"li{ color:white; margin:0px; margin-bottom:17px; line-height:17px; } "
".lowlight {display:inline-block; margin-top:3px;color:#181818;text-shadow:none;font-weight:normal;} "
".readingLabel {font-size:14px;font-weight:bold; margin:3px 0px 0px 0px;} "
".headwordLabel {font-size:19px; margin:0px 0px 9px 0px;color:yellow;} "
".ExpandedSentencesTable { width:100%; border-collapse:collapse; margin: 10px 0px 5px 0px; } "
".AddToSetAnchor { float:right; } "
".ExpandedSentencesTable td { border-bottom:1px solid #CCC; border-collapse:collapse; border-top:1px solid #CCC } "
".HeadwordRow { height: 45px; } "
".HeadwordCell { vertical-align:middle; border-right:none; font-size:15px; width:100px; } "
".ContentCell { vertical-align:middle; border-left:none; font-size:14px; } "
" a {text-decoration: none; } "
#endif
"##THEMECSS##</style></head>"
"<body><div id='container'>"
"##EXAMPLES##"
"</div></body></html>";
