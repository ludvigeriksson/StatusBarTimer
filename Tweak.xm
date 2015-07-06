static NSString *path = @"/var/mobile/Library/Preferences/com.ludvigeriksson.statusbartimer.stopwatch.plist";

// SpringBoard variables
static NSString *separator = @"-"; // Default separator
static BOOL alwaysShowMinutes = NO;
static NSString *dateFormat;
static NSTimeInterval timeToAppend;

// Timer variables
static BOOL enabledForTimer = YES;
static NSDate *timerEndDate = nil;

// Stopwatch variables
static BOOL enabledForStopwatch = YES;
static NSDate *stopwatchStartDate = nil;


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
    if (timerEndDate != nil && enabledForTimer) {
        timeToAppend = [timerEndDate timeIntervalSinceDate:[NSDate date]];
        if (timeToAppend < 0) timeToAppend = 0;
    } else {
        timeToAppend = 0;
    }

    if (timeToAppend == 0 && stopwatchStartDate != nil && enabledForStopwatch) {
        timeToAppend = [[NSDate date] timeIntervalSinceDate:stopwatchStartDate];
    }

    // Append the timer to the clock text

    NSString *append = (timeToAppend > 0) ? [NSString stringWithFormat:@" '%@ %@'", separator, stringFromTime(timeToAppend)] : @"";
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


%group Stopwatch

%hook StopWatchViewController

-(void)setMode:(int)mode { 
    %orig; 

    if (mode == 2) {
        // Timer started or resumed
        double currentInterval = MSHookIvar<double>(self, "_currentInterval");

        NSDictionary *dict = @{ @"currentInterval" : @(currentInterval) };
        [dict writeToFile:path atomically:NO];

        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.ludvigeriksson.statusbartimer/stopwatchstarted"), (__bridge const void *)(self), nil, TRUE);
    } else {
        // Timer stopped or reset
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.ludvigeriksson.statusbartimer/stopwatchstopped"), (__bridge const void *)(self), nil, TRUE);
    }
}

%end

%end // group Stopwatch

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
    if (CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("SBTAlwaysShowMinutes"), CFSTR("com.ludvigeriksson.statusbartimerprefs")))) {
        alwaysShowMinutes = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("SBTAlwaysShowMinutes"), CFSTR("com.ludvigeriksson.statusbartimerprefs"))) boolValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("SBTSeparator"), CFSTR("com.ludvigeriksson.statusbartimerprefs")))) {
        separator = (id)CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("SBTSeparator"), CFSTR("com.ludvigeriksson.statusbartimerprefs")));
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("SBTEnableForTimer"), CFSTR("com.ludvigeriksson.statusbartimerprefs")))) {
        enabledForTimer = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("SBTEnableForTimer"), CFSTR("com.ludvigeriksson.statusbartimerprefs"))) boolValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("SBTEnableForStopwatch"), CFSTR("com.ludvigeriksson.statusbartimerprefs")))) {
        enabledForStopwatch = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("SBTEnableForStopwatch"), CFSTR("com.ludvigeriksson.statusbartimerprefs"))) boolValue];
    }
}

// Gets called when the time format of the phone changes
static void changeTimeFormat() {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateStyle:NSDateFormatterNoStyle];
    [df setTimeStyle:NSDateFormatterShortStyle];
    dateFormat = df.dateFormat;
}

static void stopwatchStarted() {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    stopwatchStartDate = [NSDate dateWithTimeIntervalSinceNow:-[dict[@"currentInterval"] doubleValue]];
    NSLog(@"Setting stopwatchStartDate to: %@", stopwatchStartDate);
}

static void stopwatchStopped() {
    stopwatchStartDate = nil;
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

            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)stopwatchStarted, CFSTR("com.ludvigeriksson.statusbartimer/stopwatchstarted"), NULL, CFNotificationSuspensionBehaviorCoalesce);
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)stopwatchStopped, CFSTR("com.ludvigeriksson.statusbartimer/stopwatchstopped"), NULL, CFNotificationSuspensionBehaviorCoalesce);
        }
        if ([bundleIdentifier isEqualToString:@"com.apple.mobiletimer"]) {
            %init(Stopwatch);
        }
    }
}

