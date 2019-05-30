PACKAGE_VERSION=$(THEOS_PACKAGE_BASE_VERSION)
include $(THEOS)/makefiles/common.mk

ARCHS = armv7 arm64 arm64e
BUNDLE_NAME = Prefs
Prefs_FILES = PBXRootListController.m
Prefs_INSTALL_PATH = /Library/PreferenceBundles
Prefs_FRAMEWORKS = UIKit
Prefs_PRIVATE_FRAMEWORKS = Preferences


Prefs_LIBRARIES = colorpicker
Prefs_EXTRA_FRAMEWORKS = Cephei CepheiPrefs

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/Prefs.plist$(ECHO_END)
