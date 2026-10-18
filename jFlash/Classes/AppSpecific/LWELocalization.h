//
//  LWELocalization.h
//  xFlash
//
//  Runtime localization for text that lives in XIBs.
//
//  The XIBs aren't split into per-language variants (that would mean one copy of every
//  XIB per language for all 5 targets).  Instead, a view controller calls
//  LWELocalizeInterface(self.view) in -viewDidLoad and every label, button title,
//  text field placeholder, and segment title whose English text is a key in
//  Interface.strings is swapped for the translation.  Text that isn't a key (numbers,
//  card data, set names) is left alone, and a target without Interface.strings simply
//  keeps the English from the XIB, so this is safe to call from shared code.
//
//  Code-only strings use NSLocalizedString / Localizable.strings as usual.
//

#import <UIKit/UIKit.h>

//! Looks up XIB / tab bar text in Interface.strings; returns the English text if there's no entry.
static inline NSString *LWEInterfaceString(NSString *english)
{
  if ([english length] == 0) return english;
  return [[NSBundle mainBundle] localizedStringForKey:english value:english table:@"Interface"];
}

//! Replaces the English XIB text in |view| and all of its subviews with the Interface.strings translation.
static inline void LWELocalizeInterface(UIView *view)
{
  if (view == nil) return;
  if ([view isKindOfClass:[UILabel class]])
  {
    // Only touch labels that have a translation, so attributed text & fonts are otherwise untouched.
    UILabel *label = (UILabel *)view;
    NSString *localized = LWEInterfaceString(label.text);
    if (label.text && [localized isEqualToString:label.text] == NO)
    {
      label.text = localized;
    }
    return;
  }
  else if ([view isKindOfClass:[UIButton class]])
  {
    UIButton *button = (UIButton *)view;
    NSString *title = [button titleForState:UIControlStateNormal];
    NSString *localized = LWEInterfaceString(title);
    if (title && [localized isEqualToString:title] == NO)
    {
      [button setTitle:localized forState:UIControlStateNormal];
    }
    // UIButton's accessibilityLabel getter falls back to the current title when none was set, so
    // writing it back unconditionally would pin VoiceOver to that title (e.g. a button whose title
    // is cleared later).  Only assign when there's a translation for an explicitly set XIB label;
    // with no Interface.strings (cFlash, jFlashJr) nothing changes.
    NSString *axLabel = button.accessibilityLabel;
    NSString *axLocalized = LWEInterfaceString(axLabel);
    if (axLabel && [axLocalized isEqualToString:axLabel] == NO)
    {
      button.accessibilityLabel = axLocalized;
    }
    // The title label is a subview of the button; it's handled via the button state above.
    return;
  }
  else if ([view isKindOfClass:[UITextField class]])
  {
    UITextField *field = (UITextField *)view;
    if (field.placeholder) field.placeholder = LWEInterfaceString(field.placeholder);
    return;
  }
  else if ([view isKindOfClass:[UISegmentedControl class]])
  {
    UISegmentedControl *segments = (UISegmentedControl *)view;
    for (NSUInteger i = 0; i < segments.numberOfSegments; i++)
    {
      NSString *title = [segments titleForSegmentAtIndex:i];
      if (title) [segments setTitle:LWEInterfaceString(title) forSegmentAtIndex:i];
    }
    return;
  }
  else if ([view isKindOfClass:[UISearchBar class]])
  {
    UISearchBar *bar = (UISearchBar *)view;
    if (bar.placeholder) bar.placeholder = LWEInterfaceString(bar.placeholder);
    return;
  }
  for (UIView *subview in view.subviews)
  {
    LWELocalizeInterface(subview);
  }
}
