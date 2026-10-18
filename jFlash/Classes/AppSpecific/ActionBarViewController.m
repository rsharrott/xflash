//
//  ActionBarViewController.m
//  jFlash
//
//  Created by シャロット ロス on 6/4/10.
//  Copyright 2010 LONG WEEKEND INC. All rights reserved.
//

#import "ActionBarViewController.h"
#import "LWEDesignTokens.h"

// Practice-mode answer bar metrics (design Option A)
static const CGFloat kLWEBarPadTop       = 16.0;
static const CGFloat kLWEBarPadSide      = 16.0;
static const CGFloat kLWEBarGap          = 10.0;
static const CGFloat kLWEBarSecondaryH   = 44.0;
static const CGFloat kLWEBarPrimaryH     = 60.0;
static const CGFloat kLWEBarPadBottom    = 14.0;

@interface ActionBarViewController ()
{
  BOOL _isPracticeBar;
  CGFloat _nibHeight;
}
- (void) _reportBadData;
- (void) _setupPracticeBar API_AVAILABLE(ios(15.0));
- (void) _layoutPracticeBar;
- (void) _stylePracticeButton:(UIButton *)btn title:(NSString *)title symbol:(NSString *)symbol
                         fill:(UIColor *)fill ink:(UIColor *)ink font:(UIFont *)font radius:(CGFloat)radius API_AVAILABLE(ios(15.0));
- (void) _applyModernStyle:(UIButton *)btn symbolName:(NSString *)name label:(NSString *)labelText color:(UIColor *)color;
@end

@implementation ActionBarViewController
@synthesize delegate, currentCard;
@synthesize nextCardBtn, prevCardBtn, addBtn, rightBtn, wrongBtn, buryCardBtn;
@synthesize cardMeaningBtnHint, showAnswerBtn;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
  [super viewDidLoad];
  _nibHeight = self.view.bounds.size.height;

  // The practice NIB has right/wrong buttons; the browse NIB has prev/next instead.
  _isPracticeBar = (self.rightBtn != nil && self.wrongBtn != nil);
  if (_isPracticeBar)
  {
    if (@available(iOS 15.0, *)) {
      [self _setupPracticeBar];
      return;
    }
  }
  _isPracticeBar = NO;

  if (@available(iOS 13.0, *)) {
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self _applyModernStyle:self.addBtn      symbolName:@"plus.circle.fill"           label:@"actions" color:[UIColor systemBlueColor]];
    [self _applyModernStyle:self.rightBtn    symbolName:@"checkmark.circle.fill"      label:@"right"   color:[UIColor systemGreenColor]];
    [self _applyModernStyle:self.wrongBtn    symbolName:@"xmark.circle.fill"          label:@"wrong"   color:[UIColor systemRedColor]];
    [self _applyModernStyle:self.buryCardBtn symbolName:@"archivebox.circle.fill"     label:@"bury it" color:[UIColor systemOrangeColor]];
    [self _applyModernStyle:self.prevCardBtn symbolName:@"chevron.left.circle.fill"   label:@"prev"    color:[UIColor systemGrayColor]];
    [self _applyModernStyle:self.nextCardBtn symbolName:@"chevron.right.circle.fill"  label:@"next"    color:[UIColor systemGrayColor]];
  }
}

- (void)_applyModernStyle:(UIButton *)btn symbolName:(NSString *)name label:(NSString *)labelText color:(UIColor *)color
{
  if (!btn) return;
  if (@available(iOS 13.0, *)) {
    UIImage *icon = [UIImage systemImageNamed:name];
    if (icon) {
      UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:44 weight:UIImageSymbolWeightMedium];
      icon = [icon imageByApplyingSymbolConfiguration:config];
    }
    [btn setImage:icon forState:UIControlStateNormal];
    [btn setImage:nil forState:UIControlStateHighlighted];
    [btn setBackgroundImage:nil forState:UIControlStateNormal];
    [btn setBackgroundImage:nil forState:UIControlStateHighlighted];
    [btn setTitle:@"" forState:UIControlStateNormal];
    btn.tintColor = color;
    btn.backgroundColor = [UIColor clearColor];
    btn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 20, 0);

    UILabel *lbl = (UILabel *)[btn viewWithTag:9002];
    if (!lbl) {
      lbl = [[UILabel alloc] init];
      lbl.tag = 9002;
      lbl.textAlignment = NSTextAlignmentCenter;
      lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
      lbl.textColor = [UIColor secondaryLabelColor];
      [btn addSubview:lbl];
      [lbl release];
    }
    lbl.text = labelText;
  }
}

#pragma mark - Practice answer bar (paper panel)

/**
 * Two rows on a paper panel: quieter Actions / Bury on top (always visible), and below
 * them either a full-width dark "Show answer" (before reveal) or Wrong / Right (after).
 * The buttons keep their NIB tags & actions (doCardBtn: via the responder chain,
 * showCardActionSheet), so behaviour is unchanged.
 */
- (void) _setupPracticeBar
{
  self.view.backgroundColor = LWEDesignPaper();
  self.view.layer.cornerRadius = 28.0;
  self.view.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
  if (@available(iOS 13.0, *)) {
    self.view.layer.cornerCurve = kCACornerCurveContinuous;
  }
  self.view.clipsToBounds = YES;

  // The old brush-script "TAP FOR ANSWER" strip is replaced by the Show answer button.
  self.cardMeaningBtnHint.hidden = YES;

  UIFont *secondaryFont = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
  UIFont *primaryFont = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];

  [self _stylePracticeButton:self.addBtn title:NSLocalizedString(@"Actions", @"ActionBar.Actions") symbol:@"plus.circle"
                        fill:LWEDesignPaperButton() ink:LWEDesignInk() font:secondaryFont radius:14];
  self.addBtn.accessibilityLabel = NSLocalizedString(@"Actions", @"ActionBar.Actions");

  [self _stylePracticeButton:self.buryCardBtn title:NSLocalizedString(@"Bury", @"ActionBar.Bury") symbol:@"archivebox"
                        fill:LWEDesignPaperButton() ink:LWEDesignInk() font:secondaryFont radius:14];
  self.buryCardBtn.accessibilityLabel = NSLocalizedString(@"Bury it", @"ActionBar.BuryIt");

  [self _stylePracticeButton:self.wrongBtn title:NSLocalizedString(@"Wrong", @"ActionBar.Wrong") symbol:@"xmark"
                        fill:LWEDesignWrongFill() ink:LWEDesignWrongInk() font:primaryFont radius:18];
  self.wrongBtn.accessibilityLabel = NSLocalizedString(@"Wrong", @"ActionBar.Wrong");

  [self _stylePracticeButton:self.rightBtn title:NSLocalizedString(@"Right", @"ActionBar.Right") symbol:@"checkmark"
                        fill:LWEDesignRightFill() ink:LWEDesignRightInk() font:primaryFont radius:18];
  self.rightBtn.accessibilityLabel = NSLocalizedString(@"Right", @"ActionBar.Right");

  // Show answer: same action as tapping the card (StudyViewController -revealCard via the responder chain)
  UIButton *show = [UIButton buttonWithType:UIButtonTypeCustom];
  [self _stylePracticeButton:show title:NSLocalizedString(@"Show answer", @"ActionBar.ShowAnswer") symbol:nil
                        fill:LWEDesignInk() ink:[UIColor whiteColor] font:primaryFont radius:18];
  show.accessibilityLabel = NSLocalizedString(@"Show answer", @"ActionBar.ShowAnswer");
  [show addTarget:nil action:@selector(revealCard) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:show];
  self.showAnswerBtn = show;
}

- (void) _stylePracticeButton:(UIButton *)btn title:(NSString *)title symbol:(NSString *)symbol
                         fill:(UIColor *)fill ink:(UIColor *)ink font:(UIFont *)font radius:(CGFloat)radius
{
  if (btn == nil) return;
  // Clear the NIB's legacy images
  [btn setImage:nil forState:UIControlStateNormal];
  [btn setImage:nil forState:UIControlStateHighlighted];
  [btn setBackgroundImage:nil forState:UIControlStateNormal];
  [btn setBackgroundImage:nil forState:UIControlStateHighlighted];
  [btn setTitle:nil forState:UIControlStateNormal];
  btn.backgroundColor = [UIColor clearColor];
  btn.autoresizingMask = UIViewAutoresizingNone;

  UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
  config.baseBackgroundColor = fill;
  config.baseForegroundColor = ink;
  config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
  config.background.cornerRadius = radius;
  config.imagePadding = 8.0;
  config.contentInsets = NSDirectionalEdgeInsetsMake(0, 8, 0, 8);
  if (symbol)
  {
    CGFloat pointSize = (radius >= 18) ? 16.0 : 17.0;
    UIImageSymbolWeight weight = (radius >= 18) ? UIImageSymbolWeightBold : UIImageSymbolWeightRegular;
    config.image = [UIImage systemImageNamed:symbol];
    config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
  }
  NSAttributedString *attrTitle = [[[NSAttributedString alloc] initWithString:title
                                                                   attributes:@{ NSFontAttributeName: font }] autorelease];
  config.attributedTitle = [[[NSAttributedString alloc] initWithAttributedString:attrTitle] autorelease];
  btn.configuration = config;
}

- (void) _layoutPracticeBar
{
  CGFloat w = self.view.bounds.size.width;
  if (w <= 0) return;
  CGFloat innerW = w - 2.0 * kLWEBarPadSide;
  CGFloat halfW = floorf((innerW - kLWEBarGap) / 2.0);

  CGFloat y1 = kLWEBarPadTop;
  self.addBtn.frame      = CGRectMake(kLWEBarPadSide, y1, halfW, kLWEBarSecondaryH);
  self.buryCardBtn.frame = CGRectMake(w - kLWEBarPadSide - halfW, y1, halfW, kLWEBarSecondaryH);

  CGFloat y2 = y1 + kLWEBarSecondaryH + kLWEBarGap;
  self.wrongBtn.frame      = CGRectMake(kLWEBarPadSide, y2, halfW, kLWEBarPrimaryH);
  self.rightBtn.frame      = CGRectMake(w - kLWEBarPadSide - halfW, y2, halfW, kLWEBarPrimaryH);
  self.showAnswerBtn.frame = CGRectMake(kLWEBarPadSide, y2, innerW, kLWEBarPrimaryH);
}

- (CGFloat) preferredBarHeight
{
  if (_isPracticeBar)
  {
    return kLWEBarPadTop + kLWEBarSecondaryH + kLWEBarGap + kLWEBarPrimaryH + kLWEBarPadBottom;
  }
  return (_nibHeight > 0) ? _nibHeight : self.view.bounds.size.height;
}

// MMA: 11/14/2011 -- this method appears to be unused...
//Give the delegate a chance to not reveal the card
- (BOOL)_actionBarShouldReveal:(BOOL)reveal
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(actionBarShouldReveal:)])
  {
    reveal = [self.delegate actionBarShouldReveal:self];
  }
  return reveal;
}

#pragma mark - StudyViewControllerDelegate

- (void) studyViewModeDidChange:(StudyViewController*)svc
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(actionBarDidChangeMode:)])
  {
    [self.delegate actionBarDidChangeMode:self];
  }
}

#pragma mark - IBActions

//! IBAction method - shows card action sheet for starred, add to set, fix, and share
- (IBAction) showCardActionSheet
{
  Tag *starredTag = [[CurrentState sharedCurrentState] starredTag];
  NSString *favoriteTitle = [TagPeer card:self.currentCard isMemberOfTag:starredTag]
    ? NSLocalizedString(@"Remove from Starred", @"ActionBarViewController.ActionSheetRemoveFromFavorites")
    : NSLocalizedString(@"Add to Starred",       @"ActionBarViewController.ActionSheetAddToFavorites");

  UIAlertController *sheet = [UIAlertController
    alertControllerWithTitle:NSLocalizedString(@"Card Actions", @"ActionBarViewController.ActionSheetTitle")
                     message:nil
              preferredStyle:UIAlertControllerStyleActionSheet];

  Card *card = self.currentCard;
  Tag  *favTag = starredTag;

  [sheet addAction:[UIAlertAction actionWithTitle:favoriteTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    if ([TagPeer card:card isMemberOfTag:favTag]) {
      NSError *err = nil;
      BOOL removed = [TagPeer cancelMembership:card fromTag:favTag error:&err];
      if (!removed && err.code == kRemoveLastCardOnATagError) {
        [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Last Card in Set", @"AddTagViewController.AlertViewLastCardTitle")
                                           message:[err localizedDescription]];
      }
    } else {
      [TagPeer subscribeCard:card toTag:favTag];
    }
  }]];

  [sheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add to Study Set", @"ActionBarViewController.ActionSheetAddToSet") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    AddTagViewController *tmpVC = [[AddTagViewController alloc] initWithCard:card];
    tmpVC.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]
      initWithTitle:NSLocalizedString(@"Done", @"AddTagViewController.NavDoneButtonTitle")
              style:UIBarButtonItemStyleBordered
             target:tmpVC
             action:@selector(dismissModalViewControllerAnimated:)] autorelease];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:tmpVC, @"controller",
                          [NSNumber numberWithBool:YES], @"useNavController", nil];
    [tmpVC release];
    [[NSNotificationCenter defaultCenter] postNotificationName:LWEShouldShowModal object:self userInfo:info];
  }]];

  [sheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Fix Card", @"ActionBarViewController.ActionSheetReportBadData") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    [self _reportBadData];
  }]];

  [sheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Share This Card", @"Action Sheet Button to post on FB") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    [self shareWord];
  }]];

  [sheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"ActionBarViewController.ActionSheetCancel") style:UIAlertActionStyleCancel handler:nil]];

  // iPad needs a source for the popover anchor
  sheet.popoverPresentationController.sourceView = self.addBtn;
  sheet.popoverPresentationController.sourceRect = self.addBtn.bounds;

  [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - SVC Subcontroller Delegate Implementation

- (void) setupWithCard:(Card *)card
{
  self.currentCard = card;
  LWE_DELEGATE_CALL(@selector(actionBarWillSetup:), self);
  LWE_DELEGATE_CALL(@selector(actionBarDidSetup:), self);
}

- (void) reveal
{
  LWE_DELEGATE_CALL(@selector(actionBarWillReveal:), self);
  LWE_DELEGATE_CALL(@selector(actionBarDidReveal:), self);
}

#pragma mark - MailCompose helper & delegate method

- (void) _reportBadData
{
  if ([MFMailComposeViewController canSendMail]) 
  {
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = self;
    [picker setSubject:@"Bad Data"];
    [picker setToRecipients:[NSArray arrayWithObjects:LWE_BAD_DATA_EMAIL, nil]];
    
    Tag *tmpTag = [[CurrentState sharedCurrentState] activeTag];
    NSString *messageBody = [NSString stringWithFormat:@"How can we make this awesome?\n\n\n\nInfo For Long Weekend:\n\nCard Id: %i\nCard Headword: %@\nCard Meaning: %@\nActive Tag Id: %i\nActive Tag Name: %@", self.currentCard.cardId, self.currentCard.headword, self.currentCard.meaningWithoutMarkup, tmpTag.tagId, tmpTag.tagName];
    
    [picker setMessageBody:messageBody isHTML:NO];
    
    jFlashAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate.tabBarController presentModalViewController:picker animated:YES];
    [picker release];
  }
  else 
  {
    [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Email Not Available", @"emailVM.notAvailable.title")
                                       message:NSLocalizedString(@"Oh no!! We can't send mail right now.", @"emailVM.notAvailable.body")];
    
  }
}

//! Called when dismissing email composer
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
  [controller dismissModalViewControllerAnimated:YES];
}

#pragma mark - UIAlertView delegate methods

- (void) shareWord
{
  // Format: "Headword [reading] meaning"
  NSMutableString *shareText = [NSMutableString stringWithString:self.currentCard.headword];
  NSString *reading = self.currentCard.reading;
  if ([reading length] > 0)
  {
    [shareText appendFormat:@" [%@]", reading];
  }
  NSString *meaning = [self.currentCard meaningWithoutMarkup];
  if ([meaning length] > 0)
  {
    [shareText appendFormat:@" %@", meaning];
  }

  NSMutableArray *sharingItems = [NSMutableArray array];
  [sharingItems addObject:shareText];
  [sharingItems addObject:@"https://itunes.apple.com/us/app/japanese-flash-vocabulary/id367216357?mt=8"];

  UIActivityViewController *activityController = [[[UIActivityViewController alloc] initWithActivityItems:sharingItems applicationActivities:nil] autorelease];
  [self presentViewController:activityController animated:YES completion:nil];
}

#pragma mark - Layout

- (void)distributeButtonsEvenly
{
  if (_isPracticeBar)
  {
    [self _layoutPracticeBar];
    return;
  }
  CGFloat width = self.view.bounds.size.width;
  CGFloat height = self.view.bounds.size.height;
  if (width <= 0 || height <= 0) return;

  NSMutableArray *buttons = [NSMutableArray array];
  if (self.prevCardBtn) [buttons addObject:self.prevCardBtn];
  if (self.addBtn)      [buttons addObject:self.addBtn];
  if (self.rightBtn)    [buttons addObject:self.rightBtn];
  if (self.wrongBtn)    [buttons addObject:self.wrongBtn];
  if (self.buryCardBtn) [buttons addObject:self.buryCardBtn];
  if (self.nextCardBtn) [buttons addObject:self.nextCardBtn];

  if (buttons.count == 0) return;

  CGFloat btnWidth = floorf(width / (CGFloat)buttons.count);
  for (NSUInteger i = 0; i < buttons.count; i++) {
    UIButton *btn = buttons[i];
    CGFloat x = i * btnWidth;
    CGFloat w = (i == buttons.count - 1) ? (width - x) : btnWidth;
    btn.frame = CGRectMake(x, 0, w, height);
  }
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  [self distributeButtonsEvenly];
  if (_isPracticeBar) return;

  if (@available(iOS 13.0, *)) {
    NSMutableArray *btns = [NSMutableArray array];
    if (self.addBtn)      [btns addObject:self.addBtn];
    if (self.rightBtn)    [btns addObject:self.rightBtn];
    if (self.wrongBtn)    [btns addObject:self.wrongBtn];
    if (self.buryCardBtn) [btns addObject:self.buryCardBtn];
    if (self.prevCardBtn) [btns addObject:self.prevCardBtn];
    if (self.nextCardBtn) [btns addObject:self.nextCardBtn];
    for (UIButton *btn in btns) {
      UILabel *lbl = (UILabel *)[btn viewWithTag:9002];
      if (lbl) {
        [lbl sizeToFit];
        CGFloat bW = btn.bounds.size.width;
        CGFloat bH = btn.bounds.size.height;
        lbl.frame = CGRectMake(0, bH - lbl.bounds.size.height - 5, bW, lbl.bounds.size.height);
      }
    }
  }
}

#pragma mark - Class Plumbing

- (void)viewDidUnload
{
	[super viewDidUnload];
	
  self.addBtn = nil;
  self.buryCardBtn = nil;
  self.nextCardBtn = nil;
  self.prevCardBtn = nil;
  self.rightBtn = nil;
  self.wrongBtn = nil;
	self.cardMeaningBtnHint = nil;
  self.showAnswerBtn = nil;
}

- (void)dealloc
{
	[currentCard release];
  [cardMeaningBtnHint release];
  [addBtn release];
  [buryCardBtn release];
  [nextCardBtn release];
  [prevCardBtn release];
  [rightBtn release];
  [wrongBtn release];
  [showAnswerBtn release];
  [super dealloc];
}
@end
