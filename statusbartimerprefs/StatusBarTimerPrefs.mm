#import <Preferences/Preferences.h>

@interface StatusBarTimerPrefsListController: PSListController {
}
@end

@implementation StatusBarTimerPrefsListController

- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"StatusBarTimerPrefs" target:self] retain];
	}
	return _specifiers;
}

- (void)contactMe {
	NSURL *url = [NSURL URLWithString:@"mailto:ludvigeriksson@icloud.com?subject=StatusBarTimer"];
	[[UIApplication sharedApplication] openURL:url];
}

- (void)donate {
	NSURL *url = [NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=ludvigeriksson%40icloud%2ecom&lc=SE&item_name=Donation%20to%20Ludvig%20Eriksson&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHosted"];
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