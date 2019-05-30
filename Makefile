PACKAGE_VERSION=$(THEOS_PACKAGE_BASE_VERSION)
ARCHS = armv7 arm64 arm64e
TARGET = iphone:clang:11.2:9.0
SYSROOT = $(THEOS)/sdks/iPhoneOS11.2.sdk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Pagebar
Pagebar_FILES = Tweak.xm
Pagebar_LIBRARIES = colorpicker
PageBar_EXTRA_FRAMEWORKS = Cephie CepheiPrefs

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
