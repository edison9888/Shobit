//
//  SBListViewController.m
//  Shobit
//
//  Created by Uwe Dauernheim on 1/30/13.
//  Copyright (c) 2013 Uwe Dauernheim. All rights reserved.
//

#import "DDLog.h"
#import "DDTTYLogger.h"
#import "MBProgressHUD.h"
#import "SBListViewController.h"
#import "SBShopDatabase.h"
#import "SBMapViewController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

@interface SBListViewController ()
@property (strong, nonatomic) IBOutlet UITableView *listTableView;
@property (strong, nonatomic) IBOutlet UITextField *addItemTextField;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *emptyListButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonSpacer;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *archiveDoneButton;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (nonatomic, readonly, nonatomic) BOOL endEditing;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation SBListViewController

SBShopDatabase *shopDatabase;

#pragma mark - Framework generals

- (void)awakeFromNib {
  [super awakeFromNib];
}

- (void)viewDidLoad {
  // Navigation bar
  self.navigationItem.leftBarButtonItem = self.editButtonItem;
  
  // Toolbar
  NSMutableArray *toolbarButtons = [self.toolbarItems mutableCopy];
  [toolbarButtons removeObject:_emptyListButton];
  [toolbarButtons removeObject:_buttonSpacer];
  [toolbarButtons removeObject:_archiveDoneButton];
  [self setToolbarItems:toolbarButtons animated:YES];
  
  // Refresh control
  // TODO: Implement
  UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
  [refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
  [self.tableView addSubview:refreshControl];
  
  // Text field
  [_addItemTextField setDelegate:self];
  [_addItemTextField setTextAlignment:NSTextAlignmentCenter];
  [_addItemTextField setAllowsEditingTextAttributes:NO];
  
  [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
  // Progress HUD
  //    MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithView:_view];
  //	[_view addSubview:HUD];
  //	HUD.mode = MBProgressHUDModeCustomView;
  //	HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"HUDSuccess.png"]];
  //	HUD.labelText = @"Archived";
  //    [HUD showAnimated:YES whileExecutingBlock:^{
  //        sleep(3);
  //    }];
  
  // Location manager
  _locationManager = [[CLLocationManager alloc] init];
  _locationManager.delegate = self;
  [_locationManager startUpdatingLocation];
  
  // Import csv data
  NSURL *databaseUrl = [[self applicationSupportUrl] URLByAppendingPathComponent:@"shops.db"];
  NSURL *csvUrl = [[NSBundle mainBundle] URLForResource:@"shops" withExtension:@"csv"];
  shopDatabase = [[SBShopDatabase alloc] init:databaseUrl];
  [shopDatabase importCSV:csvUrl];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
  if ([[segue identifier] isEqualToString:@"showMap"]) {
    [[segue destinationViewController] setDetailItem: @"FOOBAR"];
  }
}

#pragma mark - CLLocationManager delegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
  [self updateMapZoomLocation:newLocation];
}

- (void)updateMapZoomLocation:(CLLocation *)newLocation {
  DDLogInfo(@"%@", [newLocation description]);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
  DDLogError(@"%@", [error description]);
}

#pragma mark - IBActions delegate methods

- (IBAction)editingDidBegin:(id)sender {
  self.navigationItem.leftBarButtonItem.enabled = NO;
  [[self addItemTextField] setPlaceholder:@""];
  
  UIView *accessoryView = [self createInputAccessoryView];
  [[self addItemTextField] setInputAccessoryView:accessoryView];
}

- (void)dismissKeyboard:(id)sender {
  // Fake editing did end
  [self didEndOnExit:sender];
  [_addItemTextField resignFirstResponder];
}

- (IBAction)didEndOnExit:(id)sender {
  NSString *newItemText = [[_addItemTextField text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  
  if ([newItemText length] > 0)
    [self insertNewObject:newItemText];
  
  [_addItemTextField setText:@""];
  [_addItemTextField reloadInputViews];
  
  if ([sender isKindOfClass: [UITextField class]]) {
    DDLogVerbose(@"User pressed \"Next\" button");
    _endEditing = NO;
  }
  else {
    if ([sender isKindOfClass: [UIBarButtonItem class]])
      DDLogVerbose(@"User pressed \"Done\" button");
    else
      DDLogVerbose(@"User pressed unknown button?!");
    _endEditing = YES;
  }
}

- (IBAction)editingDidEnd:(id)sender {
  [self.navigationItem.leftBarButtonItem setEnabled:YES];
  [_addItemTextField setPlaceholder:@"New item..."];
}

- (IBAction)archiveCheckedItems:(id)sender {
  // TODO: Implement
  UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Do you wan to archive all checked items?" delegate:nil cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Archive checked items", nil];
  [actionSheet showFromToolbar:[[self navigationController] toolbar]];
}

- (IBAction)emptyList:(id)sender {
  // TODO: Implement
  UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Are you sure you want to empty the list?" delegate:nil cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Empty list" otherButtonTitles:nil];
  [actionSheet showFromToolbar:[[self navigationController] toolbar]];
}

#pragma mark - UITextField delegate methods

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
  DDLogVerbose(@"Should end Editing?");
  return [self endEditing];
}

#pragma mark - IBAction methods

- (UIView *)createInputAccessoryView {
  UIToolbar *inputAccessoryView = [[UIToolbar alloc] init];
  [inputAccessoryView setBarStyle:UIBarStyleBlackTranslucent];
  [inputAccessoryView sizeToFit];
  
  UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
  UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard:)];
  
  NSArray *items = @[spaceItem, doneItem];
  [inputAccessoryView setItems:items animated:YES];
  return inputAccessoryView;
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return [[_fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  id <NSFetchedResultsSectionInfo> sectionInfo = [_fetchedResultsController sections][section];
  return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
  [self configureCell:cell atIndexPath:indexPath];
  return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  return YES;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
  NSMutableArray *toolbarButtons = [self.toolbarItems mutableCopy];
  if (editing) {
    [toolbarButtons addObject:_emptyListButton];
    [toolbarButtons addObject:_buttonSpacer];
    [toolbarButtons addObject:_archiveDoneButton];
  } else {
    [toolbarButtons removeObject:_emptyListButton];
    [toolbarButtons removeObject:_buttonSpacer];
    [toolbarButtons removeObject:_archiveDoneButton];
  }
  [self setToolbarItems:toolbarButtons animated:YES];
  [super setEditing:editing animated:animated];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    NSManagedObjectContext *context = [_fetchedResultsController managedObjectContext];
    [context deleteObject:[_fetchedResultsController objectAtIndexPath:indexPath]];
    
    NSError *error = nil;
    if (![context save:&error]) {
      // Replace this implementation with code to handle the error appropriately.
      // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
      //DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
      abort();
    }
  }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
  return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
  //    // TODO: Implement data structure update
  //    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
  //    NSString *stringToMove = [[_reorderingRows objectAtIndex:sourceIndexPath.row] retain];
  //    [_reorderingRows removeObjectAtIndex:sourceIndexPath.row];
  //    [_reorderingRows insertObject:stringToMove atIndex:destinationIndexPath.row];
  //    [stringToMove release];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if ([[tableView cellForRowAtIndexPath:indexPath] accessoryType] == UITableViewCellAccessoryCheckmark) {
    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType: UITableViewCellAccessoryNone];
  } else {
    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType: UITableViewCellAccessoryCheckmark];
  }
  [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
  NSManagedObject *object = [_fetchedResultsController objectAtIndexPath:indexPath];
  NSString *text = [[object valueForKey:@"name"] description];
  
  // Split amount and title
  NSError *error = NULL;
  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^([0-9]+) +(.+)$" options:NSRegularExpressionSearch error:&error];
  
  if (error) {
    DDLogError(@"%@", error);
  } else {
    NSTextCheckingResult* result = [regex firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
    
    if (result) {
      NSRange groupOne = [result rangeAtIndex:1];
      NSRange groupTwo = [result rangeAtIndex:2];
      
      NSString *amount = [text substringWithRange:groupOne];
      NSString *title = [text substringWithRange:groupTwo];
      
      [cell.detailTextLabel setText:title];
      [cell.textLabel setText:amount];
    } else {
      [cell.detailTextLabel setText:text];
      [cell.textLabel setText:@" "];
    }
  }
}

#pragma mark - Data code

- (void)insertNewObject:(NSString *)text {
  NSManagedObjectContext *context = [_fetchedResultsController managedObjectContext];
  NSEntityDescription *entity = [[_fetchedResultsController fetchRequest] entity];
  NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
  
  // If appropriate, configure the new managed object.
  // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
  [newManagedObject setValue:text forKey:@"name"];
  [newManagedObject setValue:[NSDate date] forKey:@"timestamp"];
  
  // Save the context.
  NSError *error = nil;
  if (![context save:&error]) {
    // Replace this implementation with code to handle the error appropriately.
    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
    //DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController {
  if (_fetchedResultsController != nil) {
    return _fetchedResultsController;
  }
  
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  // Edit the entity name as appropriate.
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"Item" inManagedObjectContext:_managedObjectContext];
  [fetchRequest setEntity:entity];
  
  // Set the batch size to a suitable number.
  [fetchRequest setFetchBatchSize:20];
  
  // Edit the sort key as appropriate.
  NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO];
  NSArray *sortDescriptors = @[sortDescriptor];
  
  [fetchRequest setSortDescriptors:sortDescriptors];
  
  // Edit the section name key path and cache name if appropriate.
  // nil for section name key path means "no sections".
  NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:_managedObjectContext sectionNameKeyPath:nil cacheName:@"List"];
  aFetchedResultsController.delegate = self;
  _fetchedResultsController = aFetchedResultsController;
  
	NSError *error = nil;
	if (![_fetchedResultsController performFetch:&error]) {
    // Replace this implementation with code to handle the error appropriately.
    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
    //DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
	}
  
  return _fetchedResultsController;
}

#pragma mark - Controller

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
  [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
  switch(type) {
    case NSFetchedResultsChangeInsert:
      [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
      break;
      
    case NSFetchedResultsChangeDelete:
      [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
      break;
  }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
  UITableView *tableView = self.tableView;
  
  switch(type) {
    case NSFetchedResultsChangeInsert:
      [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
      break;
      
    case NSFetchedResultsChangeDelete:
      [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
      break;
      
    case NSFetchedResultsChangeUpdate:
      [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
      break;
      
    case NSFetchedResultsChangeMove:
      [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
      [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
      break;
  }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
  [self.tableView endUpdates];
}

/*
 // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
 // In the simplest, most efficient, case, reload the table view.
 [_tableView reloadData];
 }
 */

#pragma mark - Helper

- (NSURL *)applicationSupportUrl {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSError *error = nil;
  NSURL *applicationSupportUrl = [fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
  
  if (error != nil) {
    DDLogError(@"%@", error);
  }
  
  return applicationSupportUrl;
}

@end
