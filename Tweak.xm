// SpringBoard variables
static NSString *separator = @"-"; // Default separator
static BOOL alwaysShowMinutes = NO;
static NSString *oldDateFormat = nil;
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
static NSString *stopwatchStartedNotification = @"stopwatchStartedNotification";
static NSString *stopwatchStoppedNotification = @"stopwatchStoppedNotification";
static NSString *stopwatchCurrentTimeIntervalKey = @"stopwatchCurrentTimeIntervalKey";


#import "AppSupport/CPDistributedMessagingCenter.h"

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

    if (timerEndDate == nil && stopwatchStartDate == nil && timeToAppend == 0) {
        // Save old date format to make compatible with other tweaks like 'Date in Statusbar'
        oldDateFormat = timeItemDateFormatter.dateFormat;
    }
    if (oldDateFormat == nil) {
        // Make sure oldDateFormat never is nil
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateStyle:NSDateFormatterNoStyle];
        [df setTimeStyle:NSDateFormatterShortStyle];
        oldDateFormat = df.dateFormat;
    }

    if (enabledForTimer) {
        // If there is a running timer, calculate time left based on timer end date
        if (timerEndDate != nil) {
            timeToAppend = [timerEndDate timeIntervalSinceDate:[NSDate date]];
            if (timeToAppend < 0) timeToAppend = 0;
        } else {
            timeToAppend = 0;
        }
    }

    if (enabledForStopwatch) {
        // If there isn't a timer running, and is a stopwatch running, get the time
        if (timeToAppend == 0 && stopwatchStartDate != nil) {
            timeToAppend = [[NSDate date] timeIntervalSinceDate:stopwatchStartDate];
        }
    }

    // Append the timer to the clock text
    NSString *append = @"";
    NSString *newDateFormat = oldDateFormat;
    if (timeToAppend > 0) {
        append = [NSString stringWithFormat:@" '%@ %@'", separator, stringFromTime(timeToAppend)];
        newDateFormat = [oldDateFormat stringByAppendingString:append];
    }

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

// Subscribe to notifications when tweak is loaded
%ctor {
    NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
    if ([bundleIdentifier length]) {
        if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            %init(SpringBoardHooks);
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, CFSTR("com.ludvigeriksson.statusbartimerprefs/settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
            loadPrefs();
        }
        if ([bundleIdentifier isEqualToString:@"com.apple.mobiletimer"]) {
            %init(StopwatchHooks);
        }
    }
}