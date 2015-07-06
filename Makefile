StatusBarTimer_CFLAGS = -fobjc-arc
ARCHS = armv7 arm64

include theos/makefiles/common.mk

TWEAK_NAME = StatusBarTimer
StatusBarTimer_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 MobileTimer"
	install.exec "killall -9 SpringBoard"
SUBPROJECTS += statusbartimerprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
