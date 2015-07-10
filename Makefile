StatusBarTimer_CFLAGS = -fobjc-arc
ARCHS = armv7 arm64

# Uncomment before release to remove build number
PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)

include theos/makefiles/common.mk

TWEAK_NAME = StatusBarTimer
StatusBarTimer_FILES = Tweak.xm
StatusBarTimer_PRIVATE_FRAMEWORKS = AppSupport

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
SUBPROJECTS += statusbartimerprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
