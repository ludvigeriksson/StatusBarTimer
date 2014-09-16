static NSString *path = @"/var/mobile/Library/Preferences/com.ludvigeriksson.statusbartimer.plist";
static long tempTimeLeft = 0;

static NSString *separator = @"-"; // Default separator

%hook TimerViewController

- (void)saveState {
    %orig;

    // Will enter background

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    dict[@"background"] = [NSNumber numberWithBool:YES];
    [dict writeToFile:path atomically:NO];
}

- (void)reloadState {
    %orig;

    // Will enter foreground

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    dict[@"background"] = [NSNumber numberWithBool:NO];
    [dict writeToFile:path atomically:NO];
}

%end

%hook TimerControlsView

- (void)setState:(int)fp8 {

    if (fp8 == 1) {

        // Timer is stopped

        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        dict[@"timeLeft"] = @(0);
        [dict writeToFile:path atomically:NO];

    } else if (fp8 == 2) {

        // Timer is paused

        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        dict[@"isPaused"] = [NSNumber numberWithBool:YES];
        [dict writeToFile:path atomically:NO];

    }

    %orig;
}

- (void)setTime:(double)fp8 {
    %orig;

    // Only update the dictionary once per second for better performance
    if (round(fp8) != tempTimeLeft) {

        // Write current time left to path

        tempTimeLeft = round(fp8);
        NSDictionary *dict = @{ @"timeLeft"   : @(tempTimeLeft),
                                @"isPaused"   : [NSNumber numberWithBool:NO],
                                @"background" : [NSNumber numberWithBool:NO] };
        [dict writeToFile:path atomically:NO];
    }
}

%end

// Format the time left

static NSString *stringFromTime(double interval) {
    long time    = round(interval);
    long seconds = time % 60;
    long minutes = (time / 60) % 60;
    long hours   = (time / 3600);
    if (hours) {
        return [NSString stringWithFormat:@"%02lu:%02lu:%02lu", hours, minutes, seconds];
    } else if (minutes) {
        return [NSString stringWithFormat:@"%02lu:%02lu", minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%02lu", seconds];
    }
}

%hook SBStatusBarStateAggregator

- (void)_updateTimeItems {

    // Read the timer value from path

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];

    if ([dict[@"background"] boolValue] &&
        ![dict[@"isPaused"] boolValue] &&
        ([dict[@"timeLeft"] integerValue] > 0)) {

        // If the timer is in the background the countdown must happen here

        dict[@"timeLeft"] = @([dict[@"timeLeft"] integerValue] - 1);
        [dict writeToFile:path atomically:NO];
    }

    long timeLeft = [dict[@"timeLeft"] integerValue];


    // Append the timer to the clock text

    NSDateFormatter* timeItemDateFormatter = MSHookIvar<NSDateFormatter*>(self, "_timeItemDateFormatter");

    NSString *dateFormat = @"HH:mm";
    NSString *append = timeLeft ? [NSString stringWithFormat:@" '%@ %@'", separator, stringFromTime(timeLeft)] : @"";
    dateFormat = [dateFormat stringByAppendingString:append];

    [timeItemDateFormatter setDateFormat:dateFormat];

    %orig;
}

// Set the update interval for the time in the status bar to 1 second

-(void)_restartTimeItemTimer {
    %orig;

    NSTimer *timeItemTimer = MSHookIvar<NSTimer*>(self, "_timeItemTimer");
    [timeItemTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:1]];
}

%end

static void loadPrefs() {
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.ludvigeriksson.statusbartimerprefs.plist"];
    if(prefs) {
        separator = prefs[@"SBTSeparator"] ? prefs[@"SBTSeparator"] : separator;
    }
}

%ctor
{
CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, CFSTR("com.ludvigeriksson.statusbartimerprefs/settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
loadPrefs();
}