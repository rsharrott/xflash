//
//  DownloadManager.m
//  jFlash
//
//  Created by Mark Makdad on 12/9/11.
//  Copyright (c) 2011 Long Weekend LLC. All rights reserved.
//

#import "DownloadManager.h"

#import "jFlashAppDelegate.h"
#import "LWEPackageDownloader.h"
#import "ModalTaskViewController.h"

@interface DownloadManager ()
- (void) _showDownloaderModal:(NSNotification*)aNotification;
@end

@implementation DownloadManager

@synthesize modalTaskViewController, baseViewController, pluginManager;
@synthesize tabIconTimer, tabIconImages, tabIconIndex;

#pragma mark - Class Plumbing

- (id) init
{
  self = [super init];
  if (self)
  {
    // Register listener to pop up downloader modal for search FTS download & ex sentence download
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_showDownloaderModal:) name:LWEShouldShowDownloadModal object:nil];
  }
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [tabIconTimer release];
  [tabIconImages release];
  [baseViewController release];
  [modalTaskViewController release];
  [pluginManager release];

  [super dealloc];
}

#pragma mark - LWEPackageDownloaderDelegate Methods

- (void) packageDownloaderStarted:(LWEPackageDownloader *)packageDownloader
{
  [self startTabAnimation];
}

- (void) packageDownloaderFinished:(LWEPackageDownloader *)packageDownloader
{
  [self stopTabAnimation];
  if (self.baseViewController.presentedViewController && (self.baseViewController.presentedViewController == self.modalTaskViewController))
  {
    [self.modalTaskViewController dismissViewControllerAnimated:YES completion:nil];
  }
  self.modalTaskViewController = nil;
}

- (void) unpackageFinished:(LWEPackage*)package
{
  NSError *error = nil;
  Plugin *plugin = [package.userInfo objectForKey:@"plugin"];
  [self.pluginManager installPlugin:plugin error:&error];
}

- (void) unpackageFailed:(LWEPackage*)package withError:(NSError*)error
{
  // Don't alert the user if they cancelled/it timed out due to backgrounding
  if (error.code != ASIRequestTimedOutErrorType && error.code != ASIRequestCancelledErrorType)
  {
    [LWEUIAlertView notificationAlertWithTitle:NSLocalizedString(@"Problem Installing Update",@"PluginError.AlertMsgTitle") message:error.localizedDescription];
  }
}

#pragma mark - Tab Image Animation

- (void) startTabAnimation
{
  // Starting twice must not orphan the first (repeating) timer
  LWE_STOP_TIMER(self.tabIconTimer);
  self.tabIconTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(tabIconTimerDidFire:) userInfo:nil repeats:YES];
  self.tabIconImages = [DownloadManager _turningGearImages];
  self.tabIconIndex = 0;
}

/**
 * Frames for the Settings tab while a download runs: the gearshape SF Symbol (the same symbol as the
 * tab's normal icon) drawn at 0, 15 and 30 degrees, so the gear appears to turn.  Template images,
 * so the tab bar tints them like any other tab icon.
 */
+ (NSArray *) _turningGearImages
{
  UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
  UIImage *gear = [UIImage systemImageNamed:@"gearshape" withConfiguration:cfg];
  if (gear == nil)
  {
    return [NSArray array];
  }
  CGSize gearSize = gear.size;
  CGFloat side = ceilf(MAX(gearSize.width, gearSize.height));
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)];
  NSMutableArray *frames = [NSMutableArray arrayWithCapacity:3];
  for (NSInteger step = 0; step < 3; step++)
  {
    CGFloat angle = (CGFloat)(step * 15.0 * M_PI / 180.0);
    UIImage *frame = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
      CGContextRef context = ctx.CGContext;
      CGContextTranslateCTM(context, side / 2.0, side / 2.0);
      CGContextRotateCTM(context, angle);
      [gear drawInRect:CGRectMake(-gearSize.width / 2.0, -gearSize.height / 2.0, gearSize.width, gearSize.height)];
    }];
    [frames addObject:[frame imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
  }
  [renderer release];
  return frames;
}

- (void) stopTabAnimation
{
  LWE_STOP_TIMER(self.tabIconTimer);
  
  // Return the icon back to the way it was.
  jFlashAppDelegate *appDelegate = (jFlashAppDelegate *)[[UIApplication sharedApplication] delegate];
  UIViewController *vc = [appDelegate.tabBarController.viewControllers objectAtIndex:SETTINGS_VIEW_CONTROLLER_TAB_INDEX];
  vc.tabBarItem.image = [UIImage systemImageNamed:@"gearshape"];
  vc.tabBarItem.selectedImage = [UIImage systemImageNamed:@"gearshape.fill"];
}

- (void) tabIconTimerDidFire:(NSTimer *)timer
{
  jFlashAppDelegate *appDelegate = (jFlashAppDelegate *)[[UIApplication sharedApplication] delegate];
  UIViewController *vc = [appDelegate.tabBarController.viewControllers objectAtIndex:SETTINGS_VIEW_CONTROLLER_TAB_INDEX];
  if ([self.tabIconImages count] == 0)
  {
    return;
  }
  UIImage *frame = [self.tabIconImages objectAtIndex:self.tabIconIndex];
  // Same frame when the Settings tab is selected, so the animation also shows there
  vc.tabBarItem.image = frame;
  vc.tabBarItem.selectedImage = frame;
  
  self.tabIconIndex++;
  if (self.tabIconIndex == [self.tabIconImages count])
  {
    self.tabIconIndex = 0;
  }
}

#pragma mark -

- (BOOL) pluginIsDownloading
{
  return (self.modalTaskViewController != nil);
}

/**
 * Pops up a modal over the screen when the user needs to download something
 * Relies on showModalWithViewController:useNavController:
 */
- (void) _showDownloaderModal:(NSNotification*)aNotification
{
  // Remote plugins are switched off (no server), so there is nothing to download
  if ([PluginManager remotePluginsEnabled] == NO || aNotification.object == nil)
  {
    return;
  }

  // Already showing!  Don't do it again.
  if (self.baseViewController.presentedViewController != nil)
  {
    return;
  }
  
  // If the user tries to re-lauch while we are downloading, just re-launch that modal.
  if ([self pluginIsDownloading])
  {
    [self.baseViewController presentViewController:self.modalTaskViewController animated:YES completion:nil];
    return;
  }
  
  Plugin *thePlugin = (Plugin *)aNotification.object;
  LWE_ASSERT_EXC(thePlugin, @"This method can't be called with a nil plugin.");
  
  // Instantiate downloader with jFlash download URL & destination filename
  //TODO: iPad customization here
  ModalTaskViewController *dlViewController = [[ModalTaskViewController alloc] initWithNibName:@"ModalTaskView" bundle:nil];
  dlViewController.title = NSLocalizedString(@"Get Update",@"ModalTaskViewController_Update.NavBarTitle");
  dlViewController.webViewContent = thePlugin.htmlString;
  
  // Get path information
  LWEPackageDownloader *packageDownloader = [[[LWEPackageDownloader alloc] initWithDownloaderDelegate:self] autorelease];
  packageDownloader.progressDelegate = dlViewController;
  [packageDownloader queuePackage:[thePlugin downloadPackage]];
  dlViewController.taskHandler = packageDownloader;

  UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:dlViewController];
  [dlViewController release];
  
  [self.baseViewController presentViewController:navController animated:YES completion:nil];
  self.modalTaskViewController = navController;
  [navController release];
}

@end
