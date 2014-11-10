static NSString *path = @"/var/mobile/Library/Preferences/com.ludvigeriksson.statusbartimer.plist";

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
%log;
    if (fp8 == 1) {

        // Timer is stopped

        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        dict[@"timeLeft"]  = @(0);
        dict[@"isRunning"] = [NSNumber numberWithBool:NO];
        [dict writeToFile:path atomically:NO];

    } else if (fp8 == 2) {

        // Timer is paused

        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        dict[@"isPaused"] = [NSNumber numberWithBool:YES];
        [dict writeToFile:path atomically:NO];

    } else if (fp8 == 3) {

        // Timer is started or resumed (or the timer app is opened with timer running)

        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        if (!dict) dict = [[NSMutableDictionary alloc] init];

        if (![dict[@"isRunning"] boolValue]) {

            // Timer is started

            dict[@"timeLeft"]  = @([self countDownDuration]);
        }

        dict[@"isRunning"] = [NSNumber numberWithBool:YES];
        dict[@"isPaused"]  = [NSNumber numberWithBool:NO];
        dict[@"date"]      = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceReferenceDate]];
        [dict writeToFile:path atomically:NO];
    }

    %orig;
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

static void changeTimeFormat();

%hook SBStatusBarStateAggregator

- (void)_updateTimeItems {

    // Read the timer value from path

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];

    if (![dict[@"isPaused"] boolValue] &&
        ([dict[@"timeLeft"] integerValue] > 0)) {

        // Count down the timer

        NSDate *dateNow = [NSDate date];
        NSTimeInterval timeElapsed = [dateNow timeIntervalSinceDate:[[NSDate alloc] initWithTimeIntervalSinceReferenceDate:[dict[@"date"] doubleValue]]];
        double timeLeft = [dict[@"timeLeft"] doubleValue] - timeElapsed;

        if (timeLeft < 1) timeLeft = 0.0;

        dict[@"date"]     = [NSNumber numberWithDouble:[dateNow timeIntervalSinceReferenceDate]];
        dict[@"timeLeft"] = @(timeLeft);
        [dict writeToFile:path atomically:NO];
    }

    long timeLeft = round([dict[@"timeLeft"] doubleValue]);


    // Append the timer to the clock text

    NSDateFormatter* timeItemDateFormatter = MSHookIvar<NSDateFormatter*>(self, "_timeItemDateFormatter");

    if (!dict[@"dateFormat"]) {
        changeTimeFormat();
    }

    NSString *originalDateFormat = dict[@"dateFormat"];

    NSString *append = timeLeft ? [NSString stringWithFormat:@" '%@ %@'", separator, stringFromTime(timeLeft)] : @"";
    NSString *dateFormat = [originalDateFormat stringByAppendingString:append];

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

// Gets called when separator changes in settings
static void loadPrefs() {
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.ludvigeriksson.statusbartimerprefs.plist"];
    if(prefs) {
        separator = prefs[@"SBTSeparator"] ? prefs[@"SBTSeparator"] : separator;
    }
}

// Gets called when the time format of the phone changes
static void changeTimeFormat() {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateStyle:NSDateFormatterNoStyle];
    [df setTimeStyle:NSDateFormatterShortStyle];
    dict[@"dateFormat"] = df.dateFormat;
    [dict writeToFile:path atomically:NO];
}

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, CFSTR("com.ludvigeriksson.statusbartimerprefs/settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    loadPrefs();
}

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, CFSTR("UIApplicationSignificantTimeChangeNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    changeTimeFormat();
}