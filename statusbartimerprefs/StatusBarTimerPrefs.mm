#import <Preferences/Preferences.h>

@interface StatusBarTimerPrefsListController: PSListController {
	UIView *alert;
	UIView *shadow;
}
@end

@implementation StatusBarTimerPrefsListController

- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"StatusBarTimerPrefs" target:self] retain];
	}
	return _specifiers;
}

- (void)openWebsite {
	NSURL *url = [NSURL URLWithString:@"http://ludvigeriksson.com"];
	[[UIApplication sharedApplication] openURL:url];
}

- (void)contact {
	NSURL *url = [NSURL URLWithString:@"mailto:ludvigeriksson@icloud.com?subject=StatusBarTimer"];
	[[UIApplication sharedApplication] openURL:url];
}

- (void)donatePayPal {
	NSURL *url = [NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=ludvigeriksson%40icloud%2ecom&lc=US&item_name=Donation%20to%20Ludvig%20Eriksson&no_note=0&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHostedGuest"];
	[[UIApplication sharedApplication] openURL:url];
}

@end

@interface StatusBarTimerTextCell : PSEditableTableCell
- (BOOL)textFieldShouldReturn:(UITextField *)textField;
@end

@implementation StatusBarTimerTextCell
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}
@end

// vim:ft=objc
