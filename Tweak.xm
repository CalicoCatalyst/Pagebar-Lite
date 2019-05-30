#import <UIKit/UIKit.h>
#import <SpringBoard/SBFolderView.h>
#import <libcolorpicker.h>

static BOOL tweakEnabled = YES;
static BOOL moveBelowDock = NO;
static BOOL hideMyDock = NO;
static BOOL transparentDockBG = NO;
static BOOL expandDong = NO;
static NSString *selectedTheme = @"pagebar";
static CGFloat barHeight = 5.0f;
static BOOL offsetInvert = NO;
static CGFloat offsetBar = 0.0f;
static NSString *activeColor = @"#FFFFFF";
static NSString *inactiveColor = @"#FFFFFF";


#define kIdentifier @"live.calicocat.pagebar"
#define kSettingsChangedNotification (CFStringRef)@"live.calicocat.pagebar/settingschanged"
#define kSettingsPath @"/var/mobile/Library/Preferences/live.calicocat.pagebar.plist"


#define kColIdentifier @"live.calicocat.pagebar-colors"
#define kColSettingsChangedNotification (CFStringRef)@"live.calicocat.pagebar-colors/settingschanged"
#define kColSettingsPath @"/var/mobile/Library/Preferences/live.calicocat.pagebar-colors.plist"



NSDictionary *prefs = nil;
NSDictionary *colors= nil;


/* 
Reload our preference bundle
*/
static void reloadPrefs() {
	if ([NSHomeDirectory() isEqualToString:@"/var/mobile"]) {
		CFArrayRef keyList = CFPreferencesCopyKeyList((CFStringRef)kIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
		if (keyList) {
			prefs = (NSDictionary *)CFPreferencesCopyMultiple(keyList, (CFStringRef)kIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
			if (!prefs) {
				prefs = [NSDictionary new];
			}
			CFRelease(keyList);
		}
		CFArrayRef keyColList = CFPreferencesCopyKeyList((CFStringRef)kColIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
		if (keyColList) {
			colors = (NSDictionary *)CFPreferencesCopyMultiple(keyColList, (CFStringRef)kColIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
			if (!colors) {
				colors = [NSDictionary new];
			}
			CFRelease(keyColList);
		}
	} else {
		prefs = [NSDictionary dictionaryWithContentsOfFile:kSettingsPath];
		colors= [NSDictionary dictionaryWithContentsOfFile:kColSettingsPath];
	}
}
static BOOL boolValueForKey(NSString *key, BOOL defaultValue) {
	return (prefs && [prefs objectForKey:key]) ? [[prefs objectForKey:key] boolValue] : defaultValue;
}

static void preferencesChanged() {
	CFPreferencesAppSynchronize((CFStringRef)kIdentifier);
	reloadPrefs();

	tweakEnabled = boolValueForKey(@"dotsenabled", YES);
	moveBelowDock = boolValueForKey(@"dockhidden", NO);
	hideMyDock = boolValueForKey(@"hideMyDock", NO);
	transparentDockBG = boolValueForKey(@"transparentDockBG", NO);
	expandDong = boolValueForKey(@"expandDong", NO);
	selectedTheme = [prefs objectForKey:@"style"] ?: @"pagebar";
	if (!tweakEnabled) {
		selectedTheme=@"default";
	}
	barHeight = [[prefs objectForKey:@"barHeight"] floatValue] ?: 4.0;
	offsetInvert = boolValueForKey(@"offsetInvert", NO);
	offsetBar = [[prefs objectForKey:@"barOffset"] floatValue] ?: 0.0;
	offsetBar = !offsetInvert ? offsetBar : (0 - offsetBar);
	if (!boolValueForKey(@"changeBarOffset", NO)) {
		offsetBar = 0.0;
	}
	if (!boolValueForKey(@"changeBarHeight", NO)) {
		barHeight = 4.0;
	}
	NSMutableDictionary *colorss = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/live.calicocat.pagebar-colors.plist"];
        
	activeColor = [colorss objectForKey:@"activeColor"];
	inactiveColor = [colorss objectForKey:@"inactiveColor"];
}

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
preferencesChanged();
}


/* 
For highly custom pagebars that require a completely new UIView, that new UIView
		is added as a subview of the SBRootFolderView

We
 do 99% of the value processing here, everything everywhere else just passes variables here
*/

@interface SBRootFolderView : SBFolderView

@property (nonatomic, assign) BOOL subviewAdded;
@property (nonatomic, assign) BOOL topOffsetAdded;
@property (nonatomic, assign) float topOffsetValue;
@property (nonatomic, assign) float activeBarWidth;
@property (nonatomic, assign) float currentOffset;
@property (nonatomic, assign) UIView *barContainer;
@property (nonatomic, assign) UIView *activeDot;
@property (nonatomic, assign) UIView *pageBar;
@property (nonatomic, assign) NSUInteger currentIconListViewCount;
@property (nonatomic,readonly) NSUInteger iconListViewCount;
-(BOOL)respondsToSelector:(SEL)aSelector;

-(void)updateBarForOffsetDistanceX:(CGFloat)x;
-(void)setBarContainerTopOffset:(CGFloat)topDist withOffset:(CGFloat)x;

@end


%hook SBRootFolderView

%property (nonatomic, assign) BOOL subviewAdded;
%property (nonatomic, assign) BOOL topOffsetAdded;
%property (nonatomic, assign) float topOffsetValue;
%property (nonatomic, assign) float activeBarWidth;
%property (nonatomic, assign) float currentOffset;
%property (nonatomic, assign) UIView *barContainer;
%property (nonatomic, assign) UIView *pageBar;
%property (nonatomic, assign) UIView *activeDot;
%property (nonatomic, assign) NSUInteger currentIconListViewCount;

-(id)init {
	if ((self = %orig)) {
		// Set the variable to no. Everything in this tweak that injects / passes code
		// 		should check this variable to ensure that we have the variables in place we need.
		self.subviewAdded=NO;
		self.topOffsetAdded=NO;
	}
	return self;
}

%new 
-(void) setBarContainerTopOffset:(CGFloat)topDist withOffset:(CGFloat)x {	
	/*
	Due to how the pagebar is added in, how I get the normal device pagebar offset 
		(by getting the offset value from the original page dots)

	This is also where we check screen sizes, and whether we should be sticking it 42px from the bottom of the page (dockless)

	This is also where we have to do the today page offset value. 


	*/
	if (self.subviewAdded && [selectedTheme isEqual:@"pagebar"]){
			CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width; // 375
			CGFloat noDockHeight =  42;
			CGFloat boxHeightForTopOffset = (moveBelowDock || hideMyDock) ? [UIScreen mainScreen].bounds.size.height - noDockHeight + offsetBar : topDist + offsetBar; // 667 (close enough)
			CGFloat pagebarContainerHeight = self.barContainer.frame.size.height; // 44
			self.topOffsetValue = boxHeightForTopOffset;
			self.topOffsetAdded = true;
			self.barContainer.frame = CGRectMake(0.0, boxHeightForTopOffset, screenWidth, pagebarContainerHeight);
		if (x < screenWidth) {
			self.barContainer.frame = CGRectOffset(self.barContainer.frame, screenWidth - x, 0);
		}
	}
}

%new
-(void) updateBarForOffsetDistanceX:(CGFloat)x {
	if (!self.subviewAdded || !([selectedTheme isEqual:@"pagebar"])) {
		return;
	}
  // comment values are for reference for my specific device. probably useless to u
	CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width; // 375
	CGFloat noDockHeight =  42;
	CGFloat boxHeightForTopOffset = (moveBelowDock || hideMyDock) ? [UIScreen mainScreen].bounds.size.height - noDockHeight + offsetBar : self.subviews[0].subviews[0].frame.size.height + offsetBar ; // 667 (close enough)
	CGFloat pagebarContainerHeight = self.barContainer.frame.size.height; // 44
	CGFloat activeBarWidth = self.activeDot.frame.size.width; // 16

	self.activeDot.layer.backgroundColor = [LCPParseColorString(activeColor, @"#FFFFFF") CGColor];
	self.pageBar.layer.backgroundColor = [[LCPParseColorString(inactiveColor, @"#FFFFFF") colorWithAlphaComponent:0.4] CGColor];
	/*
	If a new iconlist is added/removed, just recreate the entire thing
	TODO: find a new way to do this.
	*/
	if (self.currentIconListViewCount != self.iconListViewCount) {
		// Page removed / added
		// Easiest way to handle is to just recreate the entire thing by calling layoutSubviews on it.
		// TODO: maybe find a cleaner way
		self.subviewAdded = NO;
		[self.barContainer removeFromSuperview];
		[self layoutSubviews];
	}

	/*
	If the user is swiping left onto the today view, have the pagebar stick to the dock
	*/
	self.barContainer.frame = CGRectMake(0.0, boxHeightForTopOffset, screenWidth, pagebarContainerHeight);
	if (x < screenWidth) {
		self.barContainer.frame = CGRectOffset(self.barContainer.frame, screenWidth - x, 0);
	}


	/*
	If the user is swiping left (moving the pageview right)
	*/
	
	float movementFromLastUpdate = x - self.currentOffset;
	// This formula took me 20 minutes to figure out
	// Remember your algebra kiddos
	float distance = (movementFromLastUpdate / (screenWidth / activeBarWidth));
	// float leftbuffer =  (x / (screenWidth / activeBarWidth));
	self.activeDot.frame = CGRectOffset(self.activeDot.frame, distance, 0);
	self.currentOffset = x;

	self.currentIconListViewCount = self.iconListViewCount;

}

-(void) layoutSubviews {
	%orig;
	// UIView *subview = self.subviews[0];
	// UIView *iconscrollview = subview.subviews[0];
	if (!self.subviewAdded && [selectedTheme isEqual:@"pagebar"]) {
		// Get these vals from config
		CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width; // 375
		CGFloat noDockHeight =  42;
		CGFloat boxHeightForTopOffset = (moveBelowDock || hideMyDock) ? [UIScreen mainScreen].bounds.size.height - noDockHeight + offsetBar : self.subviews[0].subviews[0].frame.size.height  + offsetBar; // 667 (close enough)
		CGFloat pagebarContainerHeight = 44.0f; // 44
		CGFloat pagebarHeight = barHeight; // 4.0
		CGFloat activeBarWidth = 16.0; // 16
		// CGFloat activeBarHeight = 4.0f; // 4.0
		self.currentOffset = screenWidth;

		UIView *pagebarContainer = [[UIView alloc] initWithFrame:CGRectMake(0.0f,boxHeightForTopOffset, screenWidth, pagebarContainerHeight)];


		//debug stuff via back layer, probably useless
		// pagebarContainer.layer.backgroundColor = [[UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:0.00] CGColor];
		[self addSubview:pagebarContainer];
		self.barContainer = pagebarContainer;
		self.subviewAdded=YES;

		float pageCount = (float)self.iconListViewCount;
		pageCount = pageCount + 1.0f; // i dont remember why but leave the +1 here
		self.activeBarWidth = activeBarWidth;

		float pageBarTotalWidth = activeBarWidth * pageCount;

		float leftPageBarOffset = (screenWidth / 2.0f) - (pageBarTotalWidth / 2.0f);
		float topPageBarOffset =  (pagebarContainerHeight / 2.0f) - (pagebarHeight / 2.0f) + 4.0f;

		UIView *pageBar = [[UIView alloc] initWithFrame:CGRectMake(leftPageBarOffset, topPageBarOffset, pageBarTotalWidth, pagebarHeight)];
        
		pageBar.layer.backgroundColor = [[LCPParseColorString(inactiveColor, @"#FFFFFF") colorWithAlphaComponent:0.4] CGColor];
		pageBar.layer.cornerRadius = 1.5;
		pageBar.clipsToBounds = YES;
		self.pageBar = pageBar;
		[self.barContainer addSubview:pageBar];

		UIView *activeBar = [[UIView alloc] initWithFrame:CGRectMake(activeBarWidth, 0.0f, activeBarWidth, pagebarHeight)];
		activeBar.layer.backgroundColor = [LCPParseColorString(activeColor, @"#FFFFFF") CGColor];
		activeBar.layer.cornerRadius = 1.5;
		self.activeDot = activeBar;
		[self.pageBar addSubview:activeBar];

	}

}

-(void) _animateViewsForPullingToSearch {
		%orig;
		if (!self.subviewAdded || !([selectedTheme isEqual:@"pagebar"])) {
			return;
		}
		if (self.subviewAdded){
			[self sendSubviewToBack:self.barContainer];
		}
}

%end


@interface SBDockView : UIView
@end

%hook SBDockView
-(void)layoutSubviews {
	%orig;
	if (hideMyDock) {
		[self.subviews setValue:@YES forKeyPath:@"hidden"];
	}
}
-(BOOL)isHidden {
	if (hideMyDock) {
		return YES;
	} else {
		return %orig;
	}
}
%end

@interface SBWallpaperEffectView : UIView 
@end 

%hook SBWallpaperEffectView
-(void) layoutSubviews {
	%orig;
	SBRootFolderView *fview = (SBRootFolderView *)self.superview.superview.superview;
		if ([fview respondsToSelector:@selector(updateBarForOffsetDistanceX:)]){ 
			self.hidden = transparentDockBG;
		}
}
%end



@interface SBIconScrollView : UIView
@end

%hook SBIconScrollView

-(void)setContentOffset:(CGPoint)point {
	%orig(point);
	/*
	This isn't called for every pixel, I think, but it does get called quite a bit while scrolling
	so we need to animate the movement, but make it really fast. Just to fill in the stuff.
	*/
	// SBIconListPageControl* _pageControl = MSHookIvar<SBIconListPageControl*>(self, "_pageControl");
	// [_pageControl setFrame:CGRectMake(0,0,0,0)];
	SBRootFolderView *fview = (SBRootFolderView *)self.superview.superview;
	if ([fview respondsToSelector:@selector(updateBarForOffsetDistanceX:)] && [selectedTheme isEqual:@"pagebar"]){
		[fview updateBarForOffsetDistanceX:point.x];
		[fview setBarContainerTopOffset:self.frame.size.height + 20.0f withOffset:point.x];
	}
}

-(void)layoutSubviews {
	%orig;
	
	if (expandDong) {
		SBRootFolderView *fview = (SBRootFolderView *)self.superview.superview;
		if ([fview respondsToSelector:@selector(updateBarForOffsetDistanceX:)]){
			CGFloat statusbarHeight = 44.0f;
			CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
			CGFloat insetValue = screenHeight - self.frame.size.height - statusbarHeight;
			UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, -insetValue, 0);
			self.frame = UIEdgeInsetsInsetRect(self.frame, insets);
		}
	}
	
}

%end



@interface SBIconListPageControl : UIView
@property (nonatomic, assign) BOOL offsetConfigured;
@end

%hook SBIconListPageControl

%property (nonatomic, assign) BOOL offsetConfigured;

-(id)init {
	if ((self = %orig)) {
		// Set the variable to no. Everything in this tweak that injects / passes code
		// 		should check this variable to ensure that we have the variables in place we need.
		self.offsetConfigured = NO;
	}
	return self;
}
-(id)initWithFrame:(CGRect)arg1 {
	id x = %orig(arg1);
	// [self setFrame:self.frame];
	return x;

}


-(void)layoutSubviews {
  %orig;
  if ([selectedTheme isEqual:@"pagebar"] || [selectedTheme isEqual:@"hidden"]) {
	self.hidden = YES;
  } else {
  	self.hidden = NO;
  }
  if (moveBelowDock && !self.offsetConfigured){
	[self setFrame:self.frame];
  }

  self.offsetConfigured = YES;
}
-(void)_setIndicatorImage:(id)arg toEnabled:(BOOL)arg2 index:(NSUInteger)arg3 {
	%orig(arg, arg2, arg3);
	[self setFrame:self.frame];
}

-(void)_transitionIndicator:(id)arg toEnabled:(BOOL)arg2 index:(NSUInteger)arg3 {
	%orig(arg, arg2, arg3);
	[self setFrame:self.frame];
}
-(id)_iconListIndicatorImage:(BOOL)arg {
	id x = %orig(arg);
	[self setFrame:self.frame];
	return x;
}
-(id)imageSetCache {
	id x = %orig();
	[self setFrame:self.frame];
	return x;
}
-(CGFloat)defaultHeight {
	CGFloat x = %orig();
	[self setFrame:self.frame];
	return x;
}
-(void)_invalidateIndicators {
	%orig;
	[self setFrame:self.frame];
}
-(CGFloat)defaultIndicatorHeight {
	CGFloat x = %orig();
	[self setFrame:self.frame];
	return x;
}
-(void)setTransform:(CGAffineTransform)arg1 {
	// do nothing
	// we do this to keep relocated shit from bouncing all over the screen when loaded in.
	NSLog(@"breaking setTransform");
}
-(void)_setTransformForBackdropMaskViews:(CGAffineTransform)arg {
	NSLog(@"breaking another setTransform");
}
-(void)setFrame:(CGRect)arg1 {
	CGFloat statusbarHeight = 44.0f;
	CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
	CGFloat translateDistance = screenHeight - statusbarHeight;
	CGRect newFrame = CGRectMake(arg1.origin.x, translateDistance + offsetBar, self.frame.size.width, self.frame.size.height);
	if (moveBelowDock) {
		%orig(newFrame);
	} else {
		%orig(arg1);
	}
}

%end

@interface _UILegibilityImageView : UIImageView
@property (nonatomic, assign) BOOL shrunk;

@end 


%hook _UILegibilityImageView

%property (nonatomic, assign) BOOL shrunk;

-(id)init {
	if ((self = %orig)) {
		// Set the variable to no. Everything in this tweak that injects / passes code
		// 		should check this variable to ensure that we have the variables in place we need.
		self.shrunk = NO;
	}
	return self;
}
-(void)setImage:(id)arg1 {


	arg1 = [arg1 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	%orig(arg1);
	//self.image = [self.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	if ([selectedTheme isEqual:@"minidots"] && self.frame.size.height == 7.0 && self.frame.size.width == 7.0 && !self.shrunk) {
	
		self.transform = CGAffineTransformScale(self.transform, 0.74, 0.74);
		[self setTintColor:LCPParseColorString(activeColor, @"#FFFFFF")];
		self.shrunk = YES;
	} else if ([selectedTheme isEqual:@"default"] && self.frame.size.height == 7.0 && self.frame.size.width == 7.0 && !self.shrunk) {
	
		self.transform = CGAffineTransformScale(self.transform, .99, .99);
		[self setTintColor:LCPParseColorString(activeColor, @"#FFFFFF")];
		self.shrunk = YES;
	}
}
%end

%ctor {
	preferencesChanged();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback) PreferencesChangedCallback, CFSTR("live.calicocat.pagebar.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)preferencesChanged, kSettingsChangedNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
