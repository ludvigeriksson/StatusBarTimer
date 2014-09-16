include theos/makefiles/common.mk

BUNDLE_NAME = StatusBarTimerPrefs
StatusBarTimerPrefs_FILES = StatusBarTimerPrefs.mm
StatusBarTimerPrefs_INSTALL_PATH = /Library/PreferenceBundles
StatusBarTimerPrefs_FRAMEWORKS = UIKit
StatusBarTimerPrefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/StatusBarTimerPrefs.plist$(ECHO_END)
