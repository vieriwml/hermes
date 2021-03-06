/**
 * @file StationController.m
 * @brief Implementation of editing stations
 */

#import "HermesAppDelegate.h"
#import "ImageLoader.h"
#import "Pandora/Station.h"
#import "StationController.h"

@implementation StationController

- (void) showSpinner {
  [progress setHidden:FALSE];
  [progress startAnimation:nil];
}

- (void) hideSpinner {
  [progress setHidden:TRUE];
  [progress stopAnimation:nil];
}

- (id) init {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  Pandora *pandora = [[NSApp delegate] pandora];
  [center addObserver:self
             selector:@selector(stationInfo:)
                 name:@"hermes.station-info"
               object:nil];
  [center addObserver:self
             selector:@selector(hideSpinner)
                 name:@"hermes.station-renamed"
               object:pandora];
  [center addObserver:self
             selector:@selector(hideSpinner)
                 name:@"hermes.feedback-deleted"
               object:pandora];
  [center addObserver:self
             selector:@selector(searchCompleted:)
                 name:@"hermes.search-results"
               object:pandora];
  [center addObserver:self
             selector:@selector(seedAdded:)
                 name:@"hermes.seed-added"
               object:pandora];
  [center addObserver:self
             selector:@selector(seedDeleted:)
                 name:@"hermes.seed-removed"
               object:pandora];
  return [super init];
}

/**
 * @brief Begin editing a station by displaying all the necessary dialogs
 *
 * @param station the station to edit
 */
- (void) editStation: (Station*) station {
  [stationName setEnabled:FALSE];
  [stationName setStringValue:@""];
  [stationCreated setStringValue:@""];
  [stationGenres setStringValue:@""];
  [art setImage:nil];
  [progress setHidden:FALSE];
  [progress startAnimation:nil];
  [[[NSApp delegate] pandora] stationInfo: station];
  cur_station = station;
  station_url = nil;

  [seedAdd setEnabled:FALSE];
  [seedDel setEnabled:FALSE];
  [deleteFeedback setEnabled:FALSE];
  alikes = adislikes = nil;
  [likes reloadData];
  [dislikes reloadData];
  seeds = lastResults = nil;
  [seedsCurrent reloadData];
  [seedsResults reloadData];
  [self showSpinner];
  [window setIsVisible:TRUE];
  [window makeKeyAndOrderFront:nil];
}

/**
 * @brief Callback invoked when a station's info arrives
 *
 * This actually sets up the GUI and prepares everything for editing
 */
- (void) stationInfo: (NSNotification*) notification {
  NSDictionary *info = [notification userInfo];
  [progress setHidden:TRUE];
  [progress stopAnimation:nil];

  station_url = info[@"url"];
  if ([cur_station allowRename]) {
    [stationName setEnabled:TRUE];
    [stationName setToolTip:@"Change the station's name"];
  } else {
    [stationName setEnabled:FALSE];
    [stationName setToolTip:@"Not allowed to change the station's name"];
  }
  [stationName setStringValue:info[@"name"]];
  NSArray *genres = info[@"genres"];
  [stationGenres setStringValue:[genres componentsJoinedByString:@", "]];
  [stationCreated setStringValue:
    [NSDateFormatter localizedStringFromDate:info[@"created"]
                                   dateStyle:NSDateFormatterShortStyle
                                   timeStyle:NSDateFormatterNoStyle]];
  if (info[@"art"] != nil) {
    [[ImageLoader loader] loadImageURL:info[@"art"]
                              callback:^(NSData* data) {
      NSImage *image = [[NSImage alloc] initWithData:data];
      if (image == nil) {
        image = [NSImage imageNamed:@"missing-album"];
      }
      [art setImage:image];
    }];
  } else {
    [art setImage:[NSImage imageNamed:@"missing-album"]];
  }

  alikes = info[@"likes"];
  adislikes = info[@"dislikes"];
  [deleteFeedback setEnabled:TRUE];
  seeds = info[@"seeds"];
  if ([cur_station allowAddMusic]) {
    [seedAdd setEnabled:TRUE];
    [seedDel setEnabled:TRUE];
    [seedSearch setEnabled:TRUE];
    [seedAdd setToolTip:@""];
    [seedDel setToolTip:@""];
    [seedSearch setToolTip:@""];
  } else {
    [seedAdd setEnabled:NO];
    [seedDel setEnabled:NO];
    [seedSearch setEnabled:NO];
    [seedAdd setToolTip:@"Cannot add seeds to this station"];
    [seedDel setToolTip:@"Cannot modify the seeds of this station"];
    [seedSearch setToolTip:@"Cannot add seeds to this station"];
  }
  [likes reloadData];
  [dislikes reloadData];
  [seedsCurrent reloadData];
  [seedsResults reloadData];
  [seedsCurrent expandItem:@"songs"];
  [seedsCurrent expandItem:@"artists"];
}

- (IBAction) renameStation:(id)sender {
  Pandora *pandora = [[NSApp delegate] pandora];
  [pandora renameStation:[cur_station token] to:[stationName stringValue]];
  [cur_station setName:[stationName stringValue]];
  [self showSpinner];
}

- (IBAction) gotoPandora:(id)sender {
  NSURL *url = [NSURL URLWithString:station_url];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

/* ============================ Searching for a seed */

- (IBAction) searchSeeds:(id)sender {
  Pandora *pandora = [[NSApp delegate] pandora];
  [self showSpinner];
  [pandora search:[seedSearch stringValue]];
}

- (void) searchCompleted:(NSNotification*) not {
  lastResults = [not userInfo];
  [self hideSpinner];
  [seedsResults reloadData];
  for (NSString *string in [lastResults allKeys]) {
    if ([lastResults[string] count] > 0) {
      [seedsResults expandItem:string];
    } else {
      [seedsResults collapseItem:string];
    }
  }
}

/* ============================ Adding a seed */

- (IBAction) addSeed:(id)sender {
  NSIndexSet *set = [seedsResults selectedRowIndexes];
  if ([set count] == 0) return;
  Pandora *pandora = [[NSApp delegate] pandora];

  [set enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
    id item = [seedsResults itemAtRow:idx];
    if (![item isKindOfClass:[SearchResult class]]) {
      return;
    }
    SearchResult *d = item;
    [pandora addSeed:[d value] to:cur_station];
    [self showSpinner];
  }];
  [seedsResults deselectAll:nil];
}

- (void) seedAdded:(NSNotification*) not {
  [self hideSpinner];
  NSDictionary *seed = [not userInfo];
  NSMutableArray *container;
  if (seed[@"songName"] == nil) {
    container = seeds[@"artists"];
  } else {
    container = seeds[@"songs"];
  }
  [container addObject:seed];
  [seedsCurrent reloadData];
}

/* ============================ Deleting a seed */

- (IBAction) deleteSeed:(id)sender {
  NSIndexSet *set = [seedsCurrent selectedRowIndexes];
  if ([set count] == 0) return;
  Pandora *pandora = [[NSApp delegate] pandora];
  __block int deleted = 0;

  [set enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
    id item = [seedsCurrent itemAtRow:idx];
    if (![item isKindOfClass:[NSDictionary class]]) {
      return;
    }
    NSDictionary *d = item;
    [pandora removeSeed:d[@"seedId"]];
    deleted++;
  }];

  if (deleted == 0) {
    return;
  }
  [self showSpinner];
  [seedsCurrent setEnabled:FALSE];
  [deleteFeedback setEnabled:FALSE];
}

- (void) seedDeleted:(NSNotification*) not {
  [self hideSpinner];
  NSIndexSet *set = [seedsCurrent selectedRowIndexes];
  NSMutableArray *todel = [NSMutableArray array];

  [set enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
    id item = [seedsCurrent itemAtRow:idx];
    if ([item isKindOfClass:[NSDictionary class]]) {
      [todel addObject:item];
    }
  }];

  for (NSDictionary *d in todel) {
    [seeds enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
      NSMutableArray *arr = obj;
      [arr removeObject:d];
    }];
  }

  [seedsCurrent deselectAll:nil];
  [seedsCurrent reloadData];

  [seedsCurrent setEnabled:TRUE];
  [deleteFeedback setEnabled:TRUE];
}

- (void) seedFailedDeletion:(NSNotification*) not {
  NSAlert *alert =
    [NSAlert
      alertWithMessageText:@"Cannot delete all seeds from a station"
      defaultButton:@"OK"
      alternateButton:nil
      otherButton:nil
      informativeTextWithFormat:@"There must always be at least one seed"];
  [alert setAlertStyle:NSWarningAlertStyle];
  [alert setIcon:[NSImage imageNamed:@"error_icon"]];

  [alert beginSheetModalForWindow:window
      modalDelegate:nil
      didEndSelector:nil
      contextInfo:NULL];

  [self hideSpinner];
  [seedsCurrent setEnabled:TRUE];
  [seedsCurrent becomeFirstResponder];
  [deleteFeedback setEnabled:TRUE];
}

/* ============================ Deleting feedback */

- (NSArray*) delfeed:(NSArray*)feed table:(NSTableView*)view {
  NSIndexSet *set = [view selectedRowIndexes];
  if ([set count] == 0) { return feed; }
  [self showSpinner];
  Pandora *pandora = [[NSApp delegate] pandora];

  [set enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
    NSDictionary *song = feed[idx];
    [pandora deleteFeedback:song[@"feedbackId"]];
  }];

  NSMutableArray *arr = [NSMutableArray array];
  [arr addObjectsFromArray:feed];
  [arr removeObjectsAtIndexes:set];

  return arr;
}

- (IBAction) deleteFeedback:(id)sender {
  alikes = [self delfeed:alikes table:likes];
  adislikes = [self delfeed:adislikes table:dislikes];
  [likes reloadData];
  [dislikes reloadData];
  [likes deselectAll:nil];
  [dislikes deselectAll:nil];
}

/* ============================ NSTableViewDataSource protocol */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  if (aTableView == likes) {
    return [alikes count];
  } else {
    return [adislikes count];
  }
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(NSInteger)rowIndex {

  NSArray *arr = aTableView == likes ? alikes : adislikes;

  if ((NSUInteger) rowIndex >= [arr count]) { return nil; }
  NSDictionary *d = arr[rowIndex];
  return [NSString stringWithFormat:@"%@ - %@",
                    d[@"songName"],
                    d[@"artistName"]];
}

- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification {
  if ([aNotification object] == likes) {
    [dislikes deselectAll:nil];
  } else {
    [likes deselectAll:nil];
  }
}

/* ============================ NSOutlineViewDataSource protocol */
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
  NSDictionary *d = outlineView == seedsCurrent ? seeds : lastResults;
  if (item == nil) {
    return [d allKeys][index];
  }
  return d[item][index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
  NSDictionary *d = outlineView == seedsCurrent ? seeds : lastResults;
  return d[item] != nil;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
  NSDictionary *d = outlineView == seedsCurrent ? seeds : lastResults;
  if (item == nil) {
    return [[d allKeys] count];
  }
  return [d[item] count];
}

- (id)outlineView:(NSOutlineView *)outlineView
  objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
  if ([item isKindOfClass:[NSString class]]) {
    return [item capitalizedString];
  }

  if (outlineView == seedsResults) {
    SearchResult *result = item;
    return [result name];
  }

  NSDictionary *i = item;
  NSString *artist = i[@"artistName"];
  NSString *song   = i[@"songName"];
  if (song == nil) {
    return artist;
  }
  return [NSString stringWithFormat:@"%@ - %@", song, artist];
}

@end
