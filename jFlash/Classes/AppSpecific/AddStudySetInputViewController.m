//
//  AddStudySetInputViewController.m
//  jFlash
//
//  Created by シャロット ロス on 7/2/09.
//  Copyright 2009 LONG WEEKEND INC. All rights reserved.
//

#import "AddStudySetInputViewController.h"
#import "TagPeer.h"
#import <QuartzCore/QuartzCore.h>

@implementation AddStudySetInputViewController

@synthesize owner, defaultCard, setNameTextfield, tag;

// REVIEW: Ross I have been putting more of these notifications into the model, it's been working well
// for decoupling the tag content changes code.  By putting it there you also get the same functioality
// for free with any other code that adds sets (well, I think the only other one is the backup mgr, but).
NSString * const kSetWasAddedOrUpdated = @"setAddedToView";

/**
 * Custom initializer for AddStudySet modal
 * \param cardId If not 0, this cardId will be added to the membership of the newly-created Tag
 * \param groupOwnerId Specifies which group this Tag will belong to.  For top-level, this is zero.
 */
- (id) initWithDefaultCard:(Card *)card inGroup:(Group *)group
{
  // TODO: iPad customization!
  if ((self = [super initWithNibName:@"AddStudySetView" bundle:nil]))
  {
    self.defaultCard = card;
    self.owner = group;
  }
  return self;
}

/**
 * Custom init for preexisting studyset to update the info
 */
- (id) initWithTag:(Tag*)aTag
{
  if ((self = [super initWithNibName:@"AddStudySetView" bundle:nil]))
  {
    self.tag = aTag;
  }
  return self;
}


- (void)viewDidLoad
{
  [super viewDidLoad];
  self.title = NSLocalizedString(@"Create Study Set",@"AddStudySetInputViewController.NavBarTitle");
  
  UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(save)];
  self.navigationItem.rightBarButtonItem = doneButton;
  [doneButton release];
    
  self.view.backgroundColor = [[ThemeManager sharedThemeManager] backgroundColor];
  
  if ([self isModal])
  {
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismiss)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    [cancelButton release];
  }
  
  if (self.tag)
  {
    self.title = NSLocalizedString(@"Update Study Set",@"AddStudySetInputViewController.NavBarTitle");
    self.setNameTextfield.text = [tag tagName];
  }
    
  [self.setNameTextfield becomeFirstResponder];
}


- (void)viewWillAppear: (BOOL)animated
{
  [super viewWillAppear:animated];
  self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
}

/**
 * Determines if this viewController was loaded modally or not
 * \return Yes if modally presented. No if not
 */
- (BOOL)isModal 
{ 
  NSArray *viewControllers = [[self navigationController] viewControllers];
  UIViewController *rootViewController = [viewControllers objectAtIndex:0];    
  return rootViewController == self;
}

- (void)dismiss
{
  [self dismissViewControllerAnimated:YES completion:nil];
  [self.navigationController popViewControllerAnimated:YES];
}

- (void)save
{
  // Is it whitespace only?
  if ([[self.setNameTextfield.text stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString:@""])
  {
    [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Please Tap a Name", "")
                                       message:NSLocalizedString(@"We need to call your new set something.  Please tap a name and press 'Save'.", "")];
    return;
  }
  
  if (self.tag == nil)
  {
    // Create the tag & subscribe the card to it
    Tag *newTag = [TagPeer createTagNamed:self.setNameTextfield.text inGroup:self.owner withDescription:nil];
    if (self.defaultCard)
    {
      [TagPeer subscribeCard:self.defaultCard toTag:newTag];
    }
  }
  else
  {
    self.tag.tagName = self.setNameTextfield.text;
    [self.tag save];
  }
    
  [self dismiss];
  [[NSNotificationCenter defaultCenter] postNotificationName:kSetWasAddedOrUpdated object:self];
}

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField 
{
  if (theTextField == self.setNameTextfield && [theTextField.text length] == 0)
  {
    [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Enter Set Name",@"AddStudySetInputViewController.AlertViewTitle")
                                       message:NSLocalizedString(@"Please enter a new set name or click 'Cancel'.",@"AddStudySetInputViewController.AlertViewMessage")];
    return NO;
  }
  else if (theTextField == self.setNameTextfield)
  {
    return NO;
  }
  return YES;
}

- (void) dealloc
{
  [owner release];
  [defaultCard release];
  [setNameTextfield release];
  [tag release];
  [super dealloc];
}

@end