// SpringBoard variables
static NSString *separator = @"|"; // Default separator
static BOOL alwaysShowMinutes = NO;
static NSString *oldDateFormat = nil;
static BOOL shouldRestoreDateFormat = NO;
static BOOL shouldSaveDateFormat = YES;
static NSTimeInterval timeToAppend = 0;

// Timer variables
static BOOL enabledForTimer = YES;
static NSDate *timerEndDate = nil;

// Stopwatch variables
static BOOL enabledForStopwatch = YES;
static NSDate *stopwatchStartDate = nil;

// Helper functions
static NSString *stringFromTime(double interval);

// Notifications & keys
static NSString *distributedMessagingCenterName = @"com.ludvigeriksson.statusbartimer_distributedmessagingcenter";
static NSString *stopwatchStartedNotification   = @"stopwatchStartedNotification";
static NSString *stopwatchStoppedNotification   = @"stopwatchStoppedNotification";
static CFStringRef settingsChangedNotification  = CFSTR("com.ludvigeriksson.statusbartimerprefs/settingschanged");

static NSString *stopwatchCurrentTimeIntervalKey = @"stopwatchCurrentTimeIntervalKey";
static CFStringRef statusBarTimerPrefsKey        = CFSTR("com.ludvigeriksson.statusbartimerprefs");
static CFStringRef alwaysShowMinutesKey          = CFSTR("SBTAlwaysShowMinutes");
static CFStringRef separatorKey                  = CFSTR("SBTSeparator");
static CFStringRef enabledForTimerKey            = CFSTR("SBTEnableForTimer");
static CFStringRef enabledForStopwatchKey        = CFSTR("SBTEnableForStopwatch");

@interface CPDistributedMessagingCenter : NSObject
+ (CPDistributedMessagingCenter *)centerNamed:(NSString *)name;
- (void)runServerOnCurrentThread;
- (void)registerForMessageName:(NSString*)messageName target:(id)target selector:(SEL)selector;
- (BOOL)sendMessageName:(NSString*)name userInfo:(NSDictionary*)info;
@end

@interface SBStatusBarStateAggregator : NSObject {
    NSTimer *_timeItemTimer;
}
- (void)_updateTimeItems;
-(void)_restartTimeItemTimer;
@end

%group SpringBoardHooks

%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    %orig;

    CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:distributedMessagingCenterName];
    [messagingCenter runServerOnCurrentThread];

    // Register Messages
    [messagingCenter registerForMessageName:stopwatchStartedNotification
       target:self
       selector:@selector(handleMessageNamed:withUserInfo:)];
    [messagingCenter registerForMessageName:stopwatchStoppedNotification
       target:self
       selector:@selector(handleMessageNamed:withUserInfo:)];

    // Delete UIStatusBar cache, which prevents status bar updates
    NSString *cachePath = @"/var/mobile/Library/Caches/com.apple.UIStatusBar";
    NSLog(@"StatusBarTimer: Removing UIStatusBar cache (contents of %@)", cachePath);

    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator* enumerator = [fileManager enumeratorAtPath:cachePath];
    NSError* error = nil;
    BOOL result;

    NSString* file;
    while (file = [enumerator nextObject]) {
        result = [fileManager removeItemAtPath:[cachePath stringByAppendingPathComponent:file] error:&error];
        if (!result && error) {
            NSLog(@"StatusBarTimer: Error removing file %@: %@", file, error);
        }
    }
}

%new
- (NSDictionary *)handleMessageNamed:(NSString *)name withUserInfo:(NSDictionary *)userInfo {
    if ([name isEqualToString:stopwatchStartedNotification]) {
        // When the stopwatch is already running and opened again
        // a "false" notification is sent, ignore that
        if (stopwatchStartDate == nil) {
            double currentInterval = [userInfo[stopwatchCurrentTimeIntervalKey] doubleValue];
            stopwatchStartDate = [NSDate dateWithTimeIntervalSinceNow:-currentInterval];
        }
    }
    if ([name isEqualToString:stopwatchStoppedNotification]) {
        stopwatchStartDate = nil;
    }
    return nil;
}

%end

%hook SBLockScreenTimerView

-(void)setEndDate:(id)date {
    timerEndDate = date;
    %orig;
}

%end

%hook SBStatusBarStateAggregator

- (void)_updateTimeItems {

    NSDateFormatter* timeItemDateFormatter = MSHookIvar<NSDateFormatter*>(self, "_timeItemDateFormatter");

    timeToAppend = 0;

    if (enabledForTimer) {
        // If there is a running timer, calculate time left based on timer end date
        if (timerEndDate != nil) {
            timeToAppend = [timerEndDate timeIntervalSinceDate:[NSDate date]];
            if (timeToAppend < 0) timeToAppend = 0;
        }
    }

    if (enabledForStopwatch) {
        // If there isn't a timer running, and is a stopwatch running, get the time
        if (timeToAppend == 0 && stopwatchStartDate != nil) {
            timeToAppend = [[NSDate date] timeIntervalSinceDate:stopwatchStartDate];
        }
    }

    if (timeToAppend == 0) {
        if (shouldRestoreDateFormat) {
            shouldRestoreDateFormat = NO;
            timeItemDateFormatter.dateFormat = oldDateFormat;
        }
        if (shouldSaveDateFormat) {
            oldDateFormat = timeItemDateFormatter.dateFormat;
        }
    } else {
        shouldSaveDateFormat = NO;
        shouldRestoreDateFormat = YES;
        if (oldDateFormat == nil) {
            NSLog(@"StatusBarTimer: <Error>: oldDateFormat was nil!");
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateStyle:NSDateFormatterNoStyle];
            [df setTimeStyle:NSDateFormatterShortStyle];
            oldDateFormat = df.dateFormat;
        }
        // Append the timer to the clock text
        NSString *append = @"";
        NSString *newDateFormat = oldDateFormat;
        if (timeToAppend > 0) {
            append = [NSString stringWithFormat:@" '%@ %@'", separator, stringFromTime(timeToAppend)];
            newDateFormat = [oldDateFormat stringByAppendingString:append];
        }

        [timeItemDateFormatter setDateFormat:newDateFormat];
    }

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


%group StopwatchHooks

%hook StopWatchViewController

-(void)setMode:(int)mode {
    %orig;

    CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:distributedMessagingCenterName];

    if (mode == 2) {
        // Timer started or resumed
        double currentInterval = MSHookIvar<double>(self, "_currentInterval");

        NSDictionary *userInfo = @{ stopwatchCurrentTimeIntervalKey : @(currentInterval) };
        [messagingCenter sendMessageName:stopwatchStartedNotification userInfo:userInfo];
    } else {
        // Timer stopped or reset
        [messagingCenter sendMessageName:stopwatchStoppedNotification userInfo:nil];
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
    if (hours > 0) {
        return [NSString stringWithFormat:@"%02lu:%02lu:%02lu", hours, minutes, seconds];
    } else if (minutes > 0 || alwaysShowMinutes) {
        return [NSString stringWithFormat:@"%02lu:%02lu", minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%02lu", seconds];
    }
}

// Gets called when settings changes
static void loadPrefs() {
    CFPreferencesAppSynchronize(statusBarTimerPrefsKey);
    if (CFBridgingRelease(CFPreferencesCopyAppValue(alwaysShowMinutesKey, statusBarTimerPrefsKey))) {
        alwaysShowMinutes = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(alwaysShowMinutesKey, statusBarTimerPrefsKey)) boolValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(separatorKey, statusBarTimerPrefsKey))) {
        separator = (id)CFBridgingRelease(CFPreferencesCopyAppValue(separatorKey, statusBarTimerPrefsKey));
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(enabledForTimerKey, statusBarTimerPrefsKey))) {
        enabledForTimer = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(enabledForTimerKey, statusBarTimerPrefsKey)) boolValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(enabledForStopwatchKey, statusBarTimerPrefsKey))) {
        enabledForStopwatch = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(enabledForStopwatchKey, statusBarTimerPrefsKey)) boolValue];
    }
}

// Subscribe to notifications when tweak is loaded
%ctor {
    NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
    if ([bundleIdentifier length]) {
        if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            NSLog(@"StatusBarTimer: initializing in SpringBoard");
            %init(SpringBoardHooks);
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, settingsChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
            loadPrefs();
        }
        if ([bundleIdentifier isEqualToString:@"com.apple.mobiletimer"]) {
            NSLog(@"StatusBarTimer: initializing in MobileTimer");
            %init(StopwatchHooks);
        }
    }
}
