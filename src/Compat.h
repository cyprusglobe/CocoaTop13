#ifndef __IPHONE_7_0
#define __IPHONE_7_0 70000
#endif

#ifndef __IPHONE_8_0
#define __IPHONE_8_0 80000
#endif

#ifndef __IPHONE_9_0
#define __IPHONE_9_0 90000
#endif

#ifndef NSFoundationVersionNumber_iOS_7_0
#define NSFoundationVersionNumber_iOS_7_0 1047.00
#endif

#ifndef NSFoundationVersionNumber_iOS_8_0
#define NSFoundationVersionNumber_iOS_8_0 1134.0
#endif

#ifndef NSFoundationVersionNumber_iOS_9_0
#define NSFoundationVersionNumber_iOS_9_0 1221.0
#endif

#ifndef NSFoundationVersionNumber_iOS_10_0
#define NSFoundationVersionNumber_iOS_10_0 1300
#endif

uint64_t mach_time_to_milliseconds(uint64_t mach_time);

@interface PSSymLink : NSObject
+ (NSString *)simplifyPathName:(NSString *)path;
@end
