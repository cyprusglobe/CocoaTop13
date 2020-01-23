ARCHS = arm64
TARGET = iphone:clang:13.0
FINALPACKAGE = 1
STRIP=0
APPLICATION_NAME = CocoaTop
ADDITIONAL_OBJCFLAGS = -fobjc-arc

CocoaTop_FILES = RootViewController.m SockViewController.m Proc.m ProcArray.m NetArray.m Sock.m Column.m GridCell.m Setup.m SetupColumns.m AppIcon.m TextViewController.m PopupMenuView.m BackButtonHandler.m Compat.m AppDelegate.m main.m
CocoaTop_FRAMEWORKS = UIKit IOKit CoreGraphics MessageUI
CocoaTop_RESOURCE_DIRS = res
CocoaTop_CODESIGN_FLAGS = -Stask.xml

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/application.mk
