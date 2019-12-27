#import "Compat.h"
#import "RootViewController.h"
#import "SockViewController.h"
#import "Setup.h"
#import "SetupColumns.h"
#import "GridCell.h"
#import "Column.h"
#import "Proc.h"
#import "ProcArray.h"

#define NTSTAT_PREQUERY_INTERVAL	0.1

@implementation RootViewController
{
	GridHeaderView *header;
	GridHeaderView *footer;
    UILabel *statusLabel;
	UISearchBar *filter;
	PSProcArray *procs;
	NSTimer *timer;
	NSArray *columns;
	PSColumn *sortColumn;
	PSColumn *filterColumn;
	BOOL sortDescending;
	CGFloat timerInterval;
	NSUInteger configId;
	NSString *configChange;
	pid_t selectedPid;
}

- (void)popupMenuTappedItem:(NSInteger)item
{
	UIViewController* view = nil;
	switch (item) {
        case 0: view = [[SetupViewController alloc] initWithStyle:UITableViewStyleGrouped]; break;
        case 1: view = [[SetupColsViewController alloc] initWithStyle:UITableViewStyleGrouped]; break;
	}
    if (view) {
		[self.navigationController pushViewController:view animated:YES];
    }
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	bool isPhone = [[UIDevice currentDevice] userInterfaceIdiom]  == UIUserInterfaceIdiomPhone;

//	self.wantsFullScreenLayout = YES;
    
	[self popupMenuWithItems:@[@"Settings", @"Columns"] selected:-1 aligned:UIControlContentHorizontalAlignmentLeft];
    
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithImage:[UIImage imageNamed:@"UIButtonBarHamburger"]
                                             style:UIBarButtonItemStylePlain
                                             target:self
                                             action:@selector(popupMenuToggle)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                              target:self
                                              action:@selector(refreshProcs:)];
	statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width - (isPhone ? 80 : 150), 40)];
	statusLabel.backgroundColor = [UIColor clearColor];
	self.navigationItem.leftBarButtonItems = @[self.navigationItem.leftBarButtonItem, [[UIBarButtonItem alloc] initWithCustomView:statusLabel]];

	filter = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 0)];
	filter.autocapitalizationType = UITextAutocapitalizationTypeNone;
	filter.autocorrectionType = UITextAutocorrectionTypeNo;
	filter.spellCheckingType = UITextSpellCheckingTypeNo;
//	filter.returnKeyType = UIReturnKeyDone;
//	filter.showsCancelButton = YES;
//	filter.showsSearchResultsButton = NO;
	filter.delegate = self; 
	[filter sizeToFit];  
	self.tableView.tableHeaderView = filter;

    self.tableView.estimatedRowHeight = 0;
    self.tableView.estimatedSectionHeaderHeight = 0;
    self.tableView.estimatedSectionFooterHeight = 0;
    self.tableView.sectionHeaderHeight = 24;
    self.tableView.sectionFooterHeight = 24;
	[self.tableView setSeparatorInset:UIEdgeInsetsZero];
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{
		@"Columns" : @[@0, @1, @3, @5, @20, @6, @7, @9, @12, @13],
		@"UpdateInterval" : @"1",
		@"FullWidthCommandLine" : @NO,
		@"ColorDiffs" : @YES,
		@"AutoJumpNewProcess" : @NO,
		@"FirstColumnStyle" : @"Bundle Identifier",
		@"ShowHeader" : @YES,
		@"ShowFooter" : @YES,
		@"ShortenPaths" : @YES,
		@"SortColumn" : @1,         @"SortDescending" : @NO,		// Main page (sort by pid)
		@"FilterColumn" : @0,
		@"ProcInfoMode" : @0,
		@"Mode0SortColumn" : @1001, @"Mode0SortDescending" : @NO,	// Summary (by initial column order)
		@"Mode1SortColumn" : @2000, @"Mode1SortDescending" : @NO,	// Threads (by thread id)
		@"Mode2SortColumn" : @3002, @"Mode2SortDescending" : @YES,	// FDs (backwards by type)
		@"Mode3SortColumn" : @4001, @"Mode3SortDescending" : @NO,	// Modules (by address)
	}];
	configChange = @"";
	configId = 0;
	selectedPid = -1;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)filterText
{
	[procs filter:filterText column:filterColumn];
	[self.tableView reloadData];
	[footer updateSummaryWithColumns:columns procs:procs];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
	searchBar.placeholder = [NSString stringWithFormat:@"filter by %@ <tap another column>", filterColumn.fullname.lowercaseString];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
	searchBar.placeholder = [NSString stringWithFormat:@"filter by %@", filterColumn.fullname.lowercaseString];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
	[searchBar resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	[filter resignFirstResponder];
}

- (void)preRefreshProcs:(NSTimer *)_timer
{
	// Time to query network statistics
	[procs.nstats query];
	// And update the view when statistics arrive
	if (timer.isValid)
		[timer invalidate];
	timer = [NSTimer scheduledTimerWithTimeInterval:NTSTAT_PREQUERY_INTERVAL target:self selector:@selector(refreshProcs:) userInfo:nil repeats:NO];
}

- (void)refreshProcs:(NSTimer *)_timer
{
	// Rearm the timer: this way the timer will wait for a full interval after each 'fire'
	if (timerInterval >= 0.1 + NTSTAT_PREQUERY_INTERVAL) {
		if (timer.isValid)
			[timer invalidate];
		timer = [NSTimer scheduledTimerWithTimeInterval:(timerInterval - NTSTAT_PREQUERY_INTERVAL) target:self selector:@selector(preRefreshProcs:) userInfo:nil repeats:NO];
	}
	// Do not refresh while the user is killing a process
	if (self.tableView.editing)
		return;
	[procs refresh];
	[procs sortUsingComparator:sortColumn.sort desc:sortDescending];
    
	[procs filter:filter.text column:filterColumn];
	[self.tableView reloadData];
	[footer updateSummaryWithColumns:columns procs:procs];
	// Status bar
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
		statusLabel.text = [NSString stringWithFormat:@"Free: %.1f MB  CPU: %.1f%%",
			(float)procs.memFree / 1024 / 1024,
			(float)procs.totalCpu / 10];
	else
		statusLabel.text = [NSString stringWithFormat:@"Processes: %lu   Threads: %lu   Free: %.1f/%.1f MB   CPU: %.1f%%",
			(unsigned long)procs.totalCount,
			(unsigned long)procs.threadCount,
			(float)procs.memFree / 1024 / 1024,
			(float)procs.memTotal / 1024 / 1024,
			(float)procs.totalCpu / 10];
	// Query network statistics, cause no one did it before.
	if (![_timer isKindOfClass:[NSTimer class]])
		[procs.nstats query];
	// First time refresh? Or returned from a sub-page.
	if (_timer == nil) {
		// We don't need info about new processes, they are all new :)
		[procs setAllDisplayed:ProcDisplayNormal];
		NSUInteger idx = NSNotFound;
		if (selectedPid != -1) {
			idx = [procs indexForPid:selectedPid];
			selectedPid = -1;
		}
		if (idx != NSNotFound && procs[idx].display != ProcDisplayTerminated) {
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
		}
	} else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoJumpNewProcess"]) {
		// If there's a new/terminated process, scroll to it
		NSUInteger
			idx = [procs indexOfDisplayed:ProcDisplayStarted];
		if (idx == NSNotFound)
			idx = [procs indexOfDisplayed:ProcDisplayTerminated];
		if (idx != NSNotFound) {
			// Processes at the end of the list are in priority for scrolling!
			PSProc *last = procs[procs.count-1];
			if (last.display == ProcDisplayStarted || last.display == ProcDisplayTerminated)
				idx = procs.count-1;
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]
				atScrollPosition:UITableViewScrollPositionNone animated:YES];
		}
		// [self.tableView insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
		// [self.tableView deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
	}
}

- (void)sortHeader:(UIGestureRecognizer *)gestureRecognizer
{
	CGPoint loc = [gestureRecognizer locationInView:header];
	for (PSColumn *col in columns) {
		if (loc.x > col.width) {
			loc.x -= col.width;
			continue;
		}
		if (filter.isFirstResponder && !filter.text.length) {
			// Change filtering column
			filterColumn = col;
			[[NSUserDefaults standardUserDefaults] setInteger:col.tag forKey:@"FilterColumn"];
			[self searchBarTextDidEndEditing:filter];
		} else {
			// Change sorting column
			sortDescending = sortColumn == col ? !sortDescending : col.style & ColumnStyleSortDesc;
			[header sortColumnOld:sortColumn New:col desc:sortDescending];
			sortColumn = col;
			[[NSUserDefaults standardUserDefaults] setInteger:col.tag forKey:@"SortColumn"];
			[[NSUserDefaults standardUserDefaults] setBool:sortDescending forKey:@"SortDescending"];
			[timer fire];
		}
		break;
	}
}

- (void)scrollToBottom
{
	[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[self.tableView numberOfRowsInSection:0]-1 inSection:0]
		atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)columnConfigChanged
{
	// When configId changes, all cells are reconfigured
	configId++;
	columns = [PSColumn psGetShownColumnsWithWidth:self.tableView.bounds.size.width];
	// Find sort column and create table header
	filterColumn = [PSColumn psColumnWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"FilterColumn"]];
	[self searchBarTextDidEndEditing:filter];
	sortColumn = [PSColumn psColumnWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"SortColumn"]];
	if (!sortColumn) sortColumn = columns[0];
	sortDescending = [[NSUserDefaults standardUserDefaults] boolForKey:@"SortDescending"];
	header = [GridHeaderView headerWithColumns:columns size:CGSizeMake(self.tableView.bounds.size.width, self.tableView.sectionHeaderHeight)];
	footer = [GridHeaderView footerWithColumns:columns size:CGSizeMake(self.tableView.bounds.size.width, self.tableView.sectionFooterHeight)];
	[header sortColumnOld:nil New:sortColumn desc:sortDescending];
	[header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sortHeader:)]];
	[footer addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollToBottom)]];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.navigationController.navigationBar.barTintColor = nil;
	// When major options change, process list is rebuilt from scratch
	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	NSString *configCheck = [NSString stringWithFormat:@"%d-%@", [def boolForKey:@"ShortenPaths"], [def stringForKey:@"FirstColumnStyle"]];
	if (![configChange isEqualToString:configCheck]) {
		procs = [PSProcArray psProcArrayWithIconSize:self.tableView.rowHeight];
		configChange = configCheck;
	}
	[self columnConfigChanged];
	// Hide filter bar
	CGFloat minOffset = filter.frame.size.height - self.tableView.contentInset.top;
	if (self.tableView.contentOffset.y < minOffset)
		self.tableView.contentOffset = CGPointMake(0, minOffset);
	// Refresh interval
	timerInterval = [[NSUserDefaults standardUserDefaults] floatForKey:@"UpdateInterval"];
	[self refreshProcs:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	if (timer.isValid)
		[timer invalidate];
	header = nil;
	footer = nil;
	columns = nil;
}

- (BOOL)shouldAutorotate {
    return [self.navigationController supportedInterfaceOrientations];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return [self.navigationController supportedInterfaceOrientations];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context)
    {
        UIInterfaceOrientation fromInterfaceOrientation = [UIApplication sharedApplication].windows[0].windowScene.interfaceOrientation;
        [self didRotate:fromInterfaceOrientation];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context)
    {

    }];

    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)didRotate:(UIInterfaceOrientation)fromInterfaceOrientation
{
    UIInterfaceOrientation deviceOrientation = [UIApplication sharedApplication].windows[0].windowScene.interfaceOrientation;
	if ((fromInterfaceOrientation == UIInterfaceOrientationPortrait || fromInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) &&
		(deviceOrientation == UIInterfaceOrientationPortrait || deviceOrientation == UIInterfaceOrientationPortraitUpsideDown))
		return;
	if ((fromInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || fromInterfaceOrientation == UIInterfaceOrientationLandscapeRight) &&
		(deviceOrientation == UIInterfaceOrientationLandscapeLeft || deviceOrientation == UIInterfaceOrientationLandscapeRight))
		return;
	[self columnConfigChanged];
	[timer fire];
}

#pragma mark -
#pragma mark Table view data source

// Section header/footer will be used as a grid header/footer
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowHeader"] ? header : nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowFooter"] ? footer : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowHeader"] ? self.tableView.sectionHeaderHeight : 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowFooter"] ? self.tableView.sectionFooterHeight : 0;
}

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

// Data is acquired from PSProcArray
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return procs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	PSProc *proc = nil;
	if (indexPath.row < procs.count && columns && columns.count)
		proc = procs[indexPath.row];
	GridTableCell *cell = [tableView dequeueReusableCellWithIdentifier:[GridTableCell reuseIdWithIcon:proc.icon != nil]];
	if (cell == nil)
		cell = [GridTableCell cellWithIcon:proc.icon != nil];
	[cell configureWithId:configId columns:columns];
	if (proc)
		[cell updateWithProc:proc columns:columns];
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	display_t display = ((PSProc *)procs[indexPath.row]).display;
	if (display == ProcDisplayTerminated)
		cell.backgroundColor = [UIColor colorWithRed:1 green:0.7 blue:0.7 alpha:1];
	else if (display == ProcDisplayStarted)
		cell.backgroundColor = [UIColor colorWithRed:0.7 green:1 blue:0.7 alpha:1];
	else if (indexPath.row & 1)
		cell.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:.15 green:.15 blue:.15 alpha:1];
            }else{
                return [UIColor colorWithRed:.95 green:.95 blue:.95 alpha:1];
            }
        }];
	else
		cell.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor blackColor];
            }else{
                return [UIColor whiteColor];
            }
        }];
}

- (void)tableView:(UITableView *)tableView sendSignal:(int)sig toProcessAtIndexPath:(NSIndexPath *)indexPath
{
	PSProc *proc = procs[indexPath.row];
	// task_for_pid(mach_task_self(), pid, &task)
	// task_terminate(task)
	if (kill(proc.pid, sig)) {
		NSString *msg = [NSString stringWithFormat:@"Error %d while terminating app", errno];
		UIAlertController* alertController = [UIAlertController alertControllerWithTitle:proc.name message:msg preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
        [alertController addAction:cancelAction];
        [self presentViewController:alertController animated:YES completion:nil];
	}
	// Refresh immediately to show process termination
	tableView.editing = NO;
	[timer performSelector:@selector(fire) withObject:nil afterDelay:.1f];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"KILL";
}

- (NSString *)tableView:(UITableView *)tableView titleForSwipeAccessoryButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"TERM";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete)
		[self tableView:tableView sendSignal:SIGKILL toProcessAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView swipeAccessoryButtonPushedForRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self tableView:tableView sendSignal:SIGTERM toProcessAtIndexPath:indexPath];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	BOOL anim = NO;
	if (filter.isFirstResponder)
		[filter resignFirstResponder];
	PSProc *proc = procs[indexPath.row];
	selectedPid = proc.pid;
	[self.navigationController pushViewController:[[SockViewController alloc] initWithProc:proc] animated:anim];
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning
{
	if (timer.isValid)
		[timer invalidate];
//	statusLabel = nil;
//	header = nil;
//	footer = nil;
//	sortColumn = nil;
//	filterColumn = nil;
//	procs = nil;
//	columns = nil;
	[super didReceiveMemoryWarning];
}

- (void)dealloc
{
	if (timer.isValid)
		[timer invalidate];
}

@end
