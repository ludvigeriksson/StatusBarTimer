#import <Preferences/Preferences.h>

@interface StatusBarTimerPrefsListController: PSListController {
}
@end

@implementation StatusBarTimerPrefsListController

-(void)save
{
    [self.view endEditing:YES];
}

- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"StatusBarTimerPrefs" target:self] retain];
	}
	return _specifiers;
}

@end

// vim:ft=objc
