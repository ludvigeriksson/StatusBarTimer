// SpringBoard variables
static NSString *separator = @"-"; // Default separator
static BOOL alwaysShowMinutes = NO;
static NSDate *timerEndDate;
static NSTimeInterval timeLeft;
static NSString *dateFormat;

// Helper functions
static void changeTimeFormat();
static NSString *stringFromTime(double interval);


%group SpringBoardHooks

%hook SBLockScreenTimerView

-(void)setEndDate:(id)date {
    timerEndDate = date;
    %orig;
}

%end

%hook SBStatusBarStateAggregator

- (void)_updateTimeItems {

    // Calculate time left based on timer end date
    if (timerEndDate) {
        timeLeft = [timerEndDate timeIntervalSinceDate:[NSDate date]];
        if (timeLeft < 0) timeLeft = 0;
    } else {
        timeLeft = 0;
    }

    // Append the timer to the clock text

    NSString *append = (timeLeft > 0) ? [NSString stringWithFormat:@" '%@ %@'", separator, stringFromTime(timeLeft)] : @"";
    NSString *newDateFormat = [dateFormat stringByAppendingString:append];

    NSDateFormatter* timeItemDateFormatter = MSHookIvar<NSDateFormatter*>(self, "_timeItemDateFormatter");
    [timeItemDateFormatter setDateFormat:newDateFormat];

    %orig;
}

// Set the update interval for the time in the status bar to 1 second
-(void)_restartTimeItemTimer {
    %orig;

    // Original fire date is next minute

    NSTimer *timeItemTimer = MSHookIvar<NSTimer*>(self, "_timeItemTimer");
    [timeItemTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:1]];
}

%end

%end // group SpringBoard


// Format the time left
static NSString *stringFromTime(double interval) {
    long time    = round(interval);
    long seconds = time % 60;
    long minutes = (time / 60) % 60;
    long hours   = (time / 3600);
    if (hours) {
        return [NSString stringWithFormat:@"%02lu:%02lu:%02lu", hours, minutes, seconds];
    } else if (minutes || alwaysShowMinutes) {
        return [NSString stringWithFormat:@"%02lu:%02lu", minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%02lu", seconds];
    }
}

// Gets called when separator changes in settings
static void loadPrefs() {
    CFPreferencesAppSynchronize(CFSTR("com.ludvigeriksson.statusbartimerprefs"));
    if (CFPreferencesCopyAppValue(CFSTR("SBTAlwaysShowMinutes"), CFSTR("com.ludvigeriksson.statusbartimerprefs"))) {
        alwaysShowMinutes = [(id)CFPreferencesCopyAppValue(CFSTR("SBTAlwaysShowMinutes"), CFSTR("com.ludvigeriksson.statusbartimerprefs")) boolValue];
    }
    if (CFPreferencesCopyAppValue(CFSTR("SBTSeparator"), CFSTR("com.ludvigeriksson.statusbartimerprefs"))) {
        separator = (id)CFPreferencesCopyAppValue(CFSTR("SBTSeparator"), CFSTR("com.ludvigeriksson.statusbartimerprefs"));
    }
}

// Gets called when the time format of the phone changes
static void changeTimeFormat() {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateStyle:NSDateFormatterNoStyle];
    [df setTimeStyle:NSDateFormatterShortStyle];
    dateFormat = df.dateFormat;
}

// Subscribe to notifications when tweak is loaded
%ctor {
    NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
    if ([bundleIdentifier length]) {
        if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            %init(SpringBoardHooks);
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, CFSTR("com.ludvigeriksson.statusbartimerprefs/settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)changeTimeFormat, CFSTR("UIApplicationSignificantTimeChangeNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);        
            loadPrefs();
            changeTimeFormat();
        }
    }
}