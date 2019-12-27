#import "Compat.h"
#import <mach/mach_time.h>

uint64_t mach_time_to_milliseconds(uint64_t mach_time)
{
    // Here should be issued.
	static mach_timebase_info_data_t timebase = {0};
	if (!timebase.denom)
		mach_timebase_info(&timebase);
	return mach_time * timebase.numer / timebase.denom / 1000000;
}


@implementation PSSymLink

+ (NSString *)absoluteSymLinkDestination:(NSString *)link
{
	if ([link hasSuffix:@"/"])
		link = [link substringToIndex:link.length - 1];
	NSString *target = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:link error:NULL];
	if (!target)
		return @"";
	if (target && ![target hasPrefix:@"/"])
		target = [[link stringByDeletingLastPathComponent] stringByAppendingPathComponent:target];
	return [target stringByAppendingString:@"/"];
}

// Replace some symlinks to shorten path
+ (NSString *)simplifyPathName:(NSString *)path
{
	static NSArray *source = nil, *target = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		// Initialize symlinks
		source = @[@"/var/", @"/var/stash/", @"/usr/include/", @"/usr/share/", @"/usr/lib/pam/", @"/tmp/", @"/User/", @"/Applications/", @"/Library/Ringtones/", @"/Library/Wallpaper/"];
		NSMutableArray *results = [NSMutableArray arrayWithCapacity:source.count];
		for (NSString *src in source)
			[results addObject:[PSSymLink absoluteSymLinkDestination:src]];
		target = [results copy];
	});
	path = [path stringByStandardizingPath];
	if (![path hasPrefix:@"/"] || ![[NSUserDefaults standardUserDefaults] boolForKey:@"ShortenPaths"])
		return path;
	// Replace link targets with symlinks
	for (int i = 0; i < target.count; i++) {
		NSString *key = target[i], *val = source[i];
		if (!key.length)
			continue;
		if ([[path stringByAppendingString:@"/"] isEqualToString:key])
			path = [val substringToIndex:val.length - 1];
		else if ([path hasPrefix:key])
			path = [val stringByAppendingString:[path substringFromIndex:key.length]];
	}
	// Replace long bundle path with a short "old" version
	static NSString *appBundle = @"/User/Containers/Bundle/Application/";
	if (path.length > appBundle.length + 37 && [path hasPrefix:appBundle])
		path = [NSString stringWithFormat:@"/User/Applications/%@.../%@",
			[path substringWithRange:NSMakeRange(appBundle.length, 4)],	// First four chars from App ID
			[path substringFromIndex:appBundle.length + 37]];				// The rest of the path
	static NSString *appData = @"/User/Containers/Data/Application/";
	if (path.length > appData.length + 37 && [path hasPrefix:appData])
		path = [NSString stringWithFormat:@"%@%@.../%@", appData,
			[path substringWithRange:NSMakeRange(appData.length, 4)],	// First four chars from App ID
			[path substringFromIndex:appData.length + 37]];				// The rest of the path
	return path;
}

@end
