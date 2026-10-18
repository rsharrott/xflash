//
//  UserDetailsViewController.m
//  jFlash
//
//  Created by paul on 1/2/10.
//  Copyright 2010 LONG WEEKEND INC. All rights reserved.
//

#import "UserDetailsViewController.h"
#import "LWELocalization.h"
#import "UserViewController.h"
#import "UserPeer.h"

@implementation UserDetailsViewController
@synthesize selectedUser, mode, userNicknameTextField, originalUserNickname, commitChangesBtn, activateUserBtn;
@synthesize delegate;

- (id)initWithUserDetails:(User*)aUser
{
  if ((self = [super init]))
  {
    if (aUser)
    {
      self.mode = kUserViewModeEdit;
      self.originalUserNickname = aUser.userNickname;
      self.title = aUser.userNickname;
      self.selectedUser = aUser;
    }
    else
    {
      self.title = NSLocalizedString(@"Add User",@"UserDetailsViewController.NavBarTitle");
      self.mode = kUserViewModeAdd;
      self.selectedUser = [[[User alloc] init] autorelease];
    }
  }
  return self;
}

- (void) viewDidLoad
{
  [super viewDidLoad];
  // Swap the English XIB text for the current language (Interface.strings)
  LWELocalizeInterface(self.view);

  self.view.backgroundColor = [[ThemeManager sharedThemeManager] backgroundColor];

  // Start editing right away
  [self.userNicknameTextField becomeFirstResponder];

  // Hide all the buttons if we are adding a new user
  if (self.mode == kUserViewModeAdd)
  {
    self.commitChangesBtn.hidden = YES;
    self.activateUserBtn.hidden = YES;
  }
  else
  {
    self.userNicknameTextField.text = [self.selectedUser userNickname];
  }
}

- (void)viewWillAppear:(BOOL)animated 
{
  [super viewWillAppear:animated];
	self.navigationController.navigationBar.tintColor = [[ThemeManager sharedThemeManager] currentThemeTintColor];
}

# pragma mark UI Responders

- (IBAction) doActivateUser
{
  // Activate
  if (self.delegate && [self.delegate respondsToSelector:@selector(activateUser:)])
  {
    [self.delegate activateUser:self.selectedUser];
  }
}

// Save user details
- (IBAction) doCommitChanges
{
  self.selectedUser.userNickname = self.userNicknameTextField.text;
  [self.selectedUser save];

  if (self.delegate && [self.delegate respondsToSelector:@selector(userDetailsDidChange:)])
  {
    [self.delegate userDetailsDidChange:self.selectedUser];
  }
}

#pragma mark - UITextFieldDelegate Methods 

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
  if (self.mode == kUserViewModeEdit && textField == self.userNicknameTextField)
  {
    // Hide the "Save" button if the user's input is blank or equal to the old nickname.
    NSString *proposedNewString = [self.userNicknameTextField.text stringByReplacingCharactersInRange:range withString:string];
    BOOL noChanges = [proposedNewString isEqualToString:self.originalUserNickname];
    BOOL noInput = ([proposedNewString length] == 0);
    self.commitChangesBtn.hidden = (noChanges || noInput);
  }
  return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
  self.commitChangesBtn.hidden = YES;
  return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField 
{
  if ([theTextField.text length] == 0)
  {
    [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Enter a Name",@"UserDetailsViewController.EnterNameAlertTitle")
                                       message:NSLocalizedString(@"Please enter a user name or tap back to cancel.",@"UserDetailsViewController.EnterNameAlertMsg")];
    return NO;
  }
  [self doCommitChanges];
  return YES;
}

# pragma mark Other functions

- (void)dealloc 
{
  [originalUserNickname release];
  [selectedUser release];
  [userNicknameTextField release];
  [commitChangesBtn release];
  [activateUserBtn release];
  [super dealloc];
}

@end