#import "GridCell.h"

/*
@interface SmallGraph : UIView
@property (retain) NSArray *dots;
@end

@implementation SmallGraph

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	self.backgroundColor = [UIColor whiteColor]; // clear
	return self;
}

+ (id)graphWithFrame:(CGRect)frame
{
	return [[[SmallGraph alloc] initWithFrame:frame] autorelease];
}

//void draw1PxStroke(CGContextRef context, CGPoint startPoint, CGPoint endPoint, CGColorRef color)
//{
//	CGContextSaveGState(context);
//	CGContextSetLineCap(context, kCGLineCapSquare);
//	CGContextSetLineWidth(context, 1.0);
//	CGContextSetStrokeColorWithColor(context, color);
//	CGContextMoveToPoint(context, startPoint.x + 0.5, startPoint.y + 0.5);
//	CGContextAddLineToPoint(context, endPoint.x + 0.5, endPoint.y + 0.5);
//	CGContextStrokePath(context);
//	CGContextRestoreGState(context);
//}

- (void)drawRect:(CGRect)rect
{
	if (!self.dots) return;
	CGContextRef context = UIGraphicsGetCurrentContext();
	UIColor *color = [UIColor colorWithRed:0.7 green:0.7 blue:1.0 alpha:1.0];
	CGFloat width = self.bounds.size.width,
			height = self.bounds.size.height;
	CGPoint bot = CGPointMake(self.bounds.origin.x + 0.5, self.bounds.origin.y + height + 0.5);

	CGContextSaveGState(context);
	CGContextSetLineCap(context, kCGLineCapSquare);
	CGContextSetLineWidth(context, 1.0);
	CGContextSetStrokeColorWithColor(context, color.CGColor);
	for (NSNumber *val in self.dots) {
//		draw1PxStroke(context, bot, CGPointMake(bot.x, bot.y - (height * [val unsignedIntegerValue] / 100)), color.CGColor);
		CGContextMoveToPoint(context, bot.x, bot.y);
		CGContextAddLineToPoint(context, bot.x, bot.y - (height * [val unsignedIntegerValue] / 200));
		CGContextStrokePath(context);
		bot.x++;
		if (bot.x >= width) break;
	}
	CGContextRestoreGState(context);
}

- (void)dealloc
{
	[_dots release];
	[super dealloc];
}

@end
*/

@implementation GridTableCell

+ (NSString *)reuseIdWithIcon:(bool)withicon
{
	return withicon ? @"GridTableIconCell" : @"GridTableCell";
}

- (instancetype)initWithIcon:(bool)withicon
{
	self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:[GridTableCell reuseIdWithIcon:withicon]];
	self.accessoryView = [[UIView new] autorelease];
	self.id = 0;
	return self;
}

+ (instancetype)cellWithIcon:(bool)withicon
{
	return [[[GridTableCell alloc] initWithIcon:withicon] autorelease];
}

- (void)configureWithId:(int)id columns:(NSArray *)columns size:(CGSize)size
{
	// Configuration did not change
	if (self.id == id)
		return;
	// Remove old views
	if (self.labels)
		for (UILabel *item in self.labels) [item removeFromSuperview];
	if (self.dividers)
		for (UIView *item in self.dividers) [item removeFromSuperview];
	// Create new views
	self.labels = [NSMutableArray arrayWithCapacity:columns.count-1];
	self.dividers = [NSMutableArray arrayWithCapacity:columns.count];
	self.extendArgsLabel = [[NSUserDefaults standardUserDefaults] boolForKey:@"FullWidthCommandLine"];
	if (size.height < 40)
		self.textLabel.font = [UIFont systemFontOfSize:12.0];
	else if (self.extendArgsLabel)
		size.height /= 2;
	NSUInteger totalCol;
	for (PSColumn *col in columns)
		if (col.tag == 1) {
			self.firstColWidth = totalCol = col.width - 5;
			self.textLabel.adjustsFontSizeToFitWidth = !(col.style & ColumnStyleEllipsis);
		} else {
			UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(totalCol, 0, 1, size.height)];
			divider.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1];
			[self.dividers addObject:divider];
			[self.contentView addSubview:divider];
			[divider release];

			//if (col.tag == 4) {
			//	SmallGraph *graph = [SmallGraph graphWithFrame:CGRectMake(totalCol + 1, 0, col.width - 1, size.height)];
			//	graph.tag = 1000;//col.tag;
			//	[self.labels addObject:graph];
			//	[self.contentView addSubview:graph];
			//	[graph release];
			//}
			UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(totalCol + 4, 0, col.width - 8, size.height)];
			label.textAlignment = col.align;
			label.font = col.style & ColumnStyleMonoFont ? [UIFont fontWithName:@"Courier" size:13.0] : [UIFont systemFontOfSize:12.0];
			label.adjustsFontSizeToFitWidth = !(col.style & ColumnStyleEllipsis);
			label.backgroundColor = [UIColor clearColor];
			label.tag = col.tag;
			[self.labels addObject:label];
			[self.contentView addSubview:label];
			[label release];

			totalCol += col.width;
		}
	if (self.extendArgsLabel) {
		UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(self.firstColWidth, size.height, totalCol - self.firstColWidth, 1)];
		[self.dividers addObject:divider];
		divider.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1];
		[self.contentView addSubview:divider];
		[divider release];
	}
	self.id = id;
}

- (void)updateWithProc:(PSProc *)proc columns:(NSArray *)columns
{
	self.textLabel.text = proc.name;
	self.detailTextLabel.text = [proc.executable stringByAppendingString:proc.args];
	if (proc.icon)
		[self.imageView initWithImage:proc.icon];
	for (PSColumn *col in columns)
		if (col.tag > 1) {
			//if (col.tag == 4) {
			//	SmallGraph *graph = (SmallGraph *)[self viewWithTag:1000];//col.tag];
			//	if (graph) { graph.dots = [proc.cpuhistory copy]; [graph setNeedsDisplay]; }
			//} //else {
			UILabel *label = (UILabel *)[self viewWithTag:col.tag];
			if (label) label.text = col.getData(proc);
		}
}

- (void)updateWithSock:(PSSock *)sock columns:(NSArray *)columns
{
	for (PSColumn *col in columns) {
		UILabel *label = col.tag > 1 ? (UILabel *)[self viewWithTag:col.tag] : self.textLabel;
		if (label) {
			// The cell label gets a shorter text (sock.name), but the summary page will get the full one
			label.text = col.style & ColumnStyleTooLong ? sock.name : col.getData(sock);
			label.textColor = sock.color;
		}
	}
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGRect frame;
	NSInteger imageWidth = self.imageView.frame.size.width;
	frame = self.contentView.frame;
		frame.origin.x = 5;
		frame.size.width -= 10;
		self.contentView.frame = frame;
	frame = self.imageView.frame;
		frame.origin.x = 0;
		self.imageView.frame = frame;
	frame = self.textLabel.frame;
		frame.origin.x = imageWidth;
		if (frame.origin.x) frame.origin.x += 5;
		frame.size.width = self.firstColWidth - imageWidth - 5;
		self.textLabel.frame = frame;
	frame = self.detailTextLabel.frame;
		frame.origin.x = imageWidth;
		if (frame.origin.x) frame.origin.x += 5;
		if (!self.extendArgsLabel) frame.size.width = self.firstColWidth - imageWidth - 5;
			else frame.size.width = self.contentView.frame.size.width - imageWidth;
		self.detailTextLabel.frame = frame;
}

- (void)dealloc
{
	[_labels release];
	[_dividers release];
	[super dealloc];
}

@end


@implementation GridHeaderView

- (instancetype)initWithColumns:(NSArray *)columns size:(CGSize)size footer:(bool)footer
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
	self = [super initWithReuseIdentifier:@"Header"];
	self.backgroundView = ({
		UIView *view = [[UIView alloc] initWithFrame:self.bounds];
		view.backgroundColor = [UIColor colorWithRed:.75 green:.75 blue:.75 alpha:.85];
		view;
	});
#elif __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
	self = [super initWithReuseIdentifier:@"Header"];
#else
	self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height)];
	self.backgroundColor = [UIColor colorWithRed:.75 green:.75 blue:.75 alpha:.85];
#endif
	self.labels = [[NSMutableArray arrayWithCapacity:columns.count] retain];
	self.dividers = [[NSMutableArray arrayWithCapacity:columns.count] retain];
	NSUInteger totalCol = 0;
	for (PSColumn *col in columns) {
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(totalCol + 2, 0, col.width - 4, size.height)];
		[self.labels addObject:label];
		[label release];
		label.textAlignment = footer && col.getSummary ? col.align : NSTextAlignmentCenter;
		label.font = footer && col.tag != 1 ? [UIFont systemFontOfSize:12.0] : [UIFont boldSystemFontOfSize:16.0];
		label.adjustsFontSizeToFitWidth = YES;
		label.text = footer ? @"-" : col.name;
		label.textColor = [UIColor blackColor];
		label.backgroundColor = [UIColor clearColor];
		label.tag = col.tag;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
		[self.contentView addSubview:label];
#else
		[self addSubview:label];
#endif
		totalCol += col.width;
	}
	return self;
}

+ (instancetype)headerWithColumns:(NSArray *)columns size:(CGSize)size
{
	return [[[GridHeaderView alloc] initWithColumns:columns size:size footer:NO] autorelease];
}

+ (instancetype)footerWithColumns:(NSArray *)columns size:(CGSize)size
{
	return [[[GridHeaderView alloc] initWithColumns:columns size:size footer:YES] autorelease];
}

- (void)sortColumnOld:(PSColumn *)oldCol New:(PSColumn *)newCol desc:(BOOL)desc
{
	UILabel *label;
	if (oldCol && oldCol != newCol)
	if ((label = (UILabel *)[self viewWithTag:oldCol.tag])) {
		label.textColor = [UIColor blackColor];
		label.text = oldCol.name;
	}
	if ((label = (UILabel *)[self viewWithTag:newCol.tag])) {
		label.textColor = [UIColor whiteColor];
		label.text = [newCol.name stringByAppendingString:(desc ? @"\u25BC" : @"\u25B2")];
	}
}

- (void)updateSummaryWithColumns:(NSArray *)columns procs:(PSProcArray *)procs
{
	for (PSColumn *col in columns)
		if (col.getSummary) {
			UILabel *label = (UILabel *)[self viewWithTag:col.tag];
			if (label) label.text = col.getSummary(procs);
		}
}

- (void)dealloc
{
	[_labels release];
	[_dividers release];
	[super dealloc];
}

@end
