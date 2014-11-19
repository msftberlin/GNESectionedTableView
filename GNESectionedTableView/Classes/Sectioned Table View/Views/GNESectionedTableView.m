//
//  GNESectionedTableView.m
//  GNESectionedTableView
//
//  Created by Anthony Drendel on 5/27/14.
//  Copyright (c) 2014 Gone East LLC. All rights reserved.
//
//
//  The MIT License (MIT)
//
//  Copyright (c) 2014 Gone East LLC
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#import "GNESectionedTableView.h"
#import "NSOutlineView+GNE_Additions.h"

#import "GNEOutlineViewItem.h"
#import "GNEOutlineViewParentItem.h"

// ------------------------------------------------------------------------------------------


static NSString * const kOutlineViewOutlineColumnIdentifier = @"com.goneeast.OutlineViewOutlineColumn";
static NSString * const kOutlineViewStandardColumnIdentifier = @"com.goneeast.OutlineViewStandardColumn";

static NSString * const kOutlineViewStandardHeaderRowViewIdentifier =
                                                        @"com.goneeast.OutlineViewStandardHeaderRowViewIdentifier";
static NSString * const kOutlineViewStandardHeaderCellViewIdentifier =
                                                        @"com.goneeast.OutlineViewStandardHeaderCellViewIdentifier";

static const CGFloat kDefaultRowHeight = 32.0f;


// ------------------------------------------------------------------------------------------


@interface GNESectionedTableView () <NSOutlineViewDataSource, NSOutlineViewDelegate, GNEOutlineViewItemPasteboardWritingDelegate>
{
    NSTableColumn *_privateOutlineColumn; // NSOutlineView doesn't retain its outlineColumn property
}


/// Array of outline view parent items that map to the table view's sections.
@property (nonatomic, strong) NSMutableArray *outlineViewParentItems;

/// Array of arrays of outline view items that map to the table view's rows.
@property (nonatomic, strong) NSMutableArray *outlineViewItems;


@end


// ------------------------------------------------------------------------------------------


@implementation GNESectionedTableView


// ------------------------------------------------------------------------------------------
#pragma mark - Initialization
// ------------------------------------------------------------------------------------------
- (instancetype)init
{
    if ((self = [super init]))
    {
        [self p_commonInitialization];
    }
    
    return self;
}


- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self p_commonInitialization];
    }
    
    return self;
}


- (void)p_commonInitialization
{
    _outlineViewParentItems = [NSMutableArray array];
    _outlineViewItems = [NSMutableArray array];
    
    self.dataSource = self;
    self.delegate = self;
    
    self.wantsLayer = YES;
    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
    
    self.gridStyleMask = NSTableViewGridNone;
    
    self.headerView = nil;
    self.cornerView = nil;
    
    _privateOutlineColumn = [[NSTableColumn alloc] initWithIdentifier:kOutlineViewOutlineColumnIdentifier];
    self.outlineTableColumn = _privateOutlineColumn;
    NSTableColumn *standardColumn = [[NSTableColumn alloc] initWithIdentifier:kOutlineViewStandardColumnIdentifier];
    standardColumn.resizingMask = NSTableColumnAutoresizingMask;
    [self addTableColumn:standardColumn];
    self.allowsColumnResizing = NO;
    
    self.columnAutoresizingStyle = NSTableViewSequentialColumnAutoresizingStyle;
    self.autoresizesOutlineColumn = NO;
    
    self.rowSizeStyle = NSTableViewRowSizeStyleCustom;
    
    [self expandItem:nil expandChildren:YES];
}


// ------------------------------------------------------------------------------------------
#pragma mark - Dealloc
// ------------------------------------------------------------------------------------------
- (void)dealloc
{
    _tableViewDataSource = nil;
    _tableViewDelegate = nil;
    
    _privateOutlineColumn = nil;
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSView
// ------------------------------------------------------------------------------------------
- (void)viewDidMoveToWindow
{
    if ([self window])
    {
        [self p_sizeStandardTableColumnToFit];
        [self p_registerForDraggedTypes];
    }
}


- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self p_sizeStandardTableColumnToFit];
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSOutlineView
// ------------------------------------------------------------------------------------------
// Disable responsive scrolling
- (CGRect)preparedContentRect
{
    return [self visibleRect];
}


// Disable responsive scrolling
- (void)prepareContentInRect:(CGRect __unused)rect
{
    
}


// ------------------------------------------------------------------------------------------
#pragma mark - GNESectionedTableView - Public - Insertion, Deletion, Move, and Update
// ------------------------------------------------------------------------------------------
- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withAnimation:(NSTableViewAnimationOptions)animationOptions
{
#ifdef DEBUG
    NSLog(@"%@\n%@", NSStringFromSelector(_cmd), indexPaths);
#endif
    
    [self p_checkIndexPathsArray:indexPaths];
    
    NSArray *groupedIndexPaths = [self p_sortedIndexPathsGroupedBySectionInIndexPaths:indexPaths];
    
    [self beginUpdates];
    for (NSArray *indexPathsInSection in groupedIndexPaths)
    {
        @autoreleasepool
        {
            NSMutableIndexSet *insertedIndexes = [NSMutableIndexSet indexSet];
            NSUInteger section = ((NSIndexPath *)indexPathsInSection.firstObject).gne_section;
            
            GNEOutlineViewParentItem *parentItem = [self p_outlineViewParentItemForSection:section];
            NSAssert1(parentItem, @"No outline view parent item exists for section %lu", (long unsigned)section);
            
            if (parentItem == nil)
            {
                return;
            }
            
            NSUInteger parentItemIndex = [self.outlineViewParentItems indexOfObject:parentItem];
            NSParameterAssert(parentItemIndex < self.outlineViewItems.count);
            
            NSMutableArray *rows = self.outlineViewItems[parentItemIndex];
            
            for (NSIndexPath *indexPath in indexPathsInSection)
            {
                GNEOutlineViewItem *outlineViewItem = [[GNEOutlineViewItem alloc] initWithParentItem:parentItem];
                [insertedIndexes addIndex:[rows gne_insertObject:outlineViewItem atIndex:indexPath.gne_row]];
            }
            
            [self insertItemsAtIndexes:insertedIndexes inParent:parentItem withAnimation:animationOptions];
        }
    }
    [self endUpdates];
    
    [self p_checkDataSourceIntegrity];
}


- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withAnimation:(NSTableViewAnimationOptions)animationOptions
{
#ifdef DEBUG
    NSLog(@"%@\n%@", NSStringFromSelector(_cmd), indexPaths);
#endif
    
    [self p_checkIndexPathsArray:indexPaths];
    
    NSArray *groupedIndexPaths = [self p_reverseSortedIndexPathsGroupedBySectionInIndexPaths:indexPaths];
    
    NSIndexPath *firstIndexPath = nil;
    
    [self beginUpdates];
    for (NSArray *indexPathsInSection in groupedIndexPaths)
    {
        firstIndexPath = indexPathsInSection.firstObject;
        
        if (firstIndexPath == nil)
        {
            continue;
        }
        
        GNEOutlineViewItem *firstItem = [self p_outlineViewItemAtIndexPath:firstIndexPath];
        
        if (firstItem == nil)
        {
            continue;
        }
        
        GNEOutlineViewParentItem *parentItem = firstItem.parentItem;
        
        NSParameterAssert(parentItem);
        
        NSMutableIndexSet *deletedIndexes = [NSMutableIndexSet indexSet];
        for (NSIndexPath *indexPath in indexPathsInSection)
        {
            GNEOutlineViewItem *item = [self p_outlineViewItemAtIndexPath:indexPath];
            
            if (item == nil)
            {
                continue;
            }
         
            NSParameterAssert([item.parentItem isEqual:parentItem]);
            
#if DEBUG
            NSIndexPath *actualIndexPath = [self p_indexPathOfOutlineViewItem:item];
            NSParameterAssert([actualIndexPath compare:indexPath] == NSOrderedSame);
#endif
            
            // Add the item's index path row to the index set that will be passed to the NSOutlineView.
            [deletedIndexes addIndex:indexPath.gne_row];
            
            // Delete the actual item from the outline view items array.
            [self.outlineViewItems[indexPath.gne_section] removeObjectAtIndex:indexPath.gne_row];
        }
        
        // Delete the outline view rows with the supplied animation.
        [self removeItemsAtIndexes:deletedIndexes inParent:parentItem withAnimation:animationOptions];
    }
    [self endUpdates];
    
    [self p_checkDataSourceIntegrity];
}


- (void)moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    NSParameterAssert(fromIndexPath);
    NSParameterAssert(toIndexPath);
    
    NSUInteger toSection = toIndexPath.gne_section;
    
    GNEOutlineViewParentItem *toParentItem = [self p_outlineViewParentItemForSection:toSection];
    
    NSParameterAssert(toParentItem);
    if (toParentItem == nil)
    {
        return;
    }
    
    GNEOutlineViewItem *fromItem = [self p_outlineViewItemAtIndexPath:fromIndexPath];
    
    NSParameterAssert(fromItem);
    if (fromItem == nil)
    {
        return;
    }
    
    [self p_animateMoveOfOutlineViewItem:fromItem toRow:toIndexPath.gne_row inOutlineViewParentItem:toParentItem];
    
    [self p_checkDataSourceIntegrity];
}


- (void)moveRowsAtIndexPaths:(NSArray *)fromIndexPaths toIndexPaths:(NSArray *)toIndexPaths
{
    NSParameterAssert(fromIndexPaths.count == toIndexPaths.count);
    
    [self p_checkIndexPathsArray:fromIndexPaths];
    [self p_checkIndexPathsArray:toIndexPaths];
    
    NSUInteger moveCount = fromIndexPaths.count;
    
    [self beginUpdates];
    for (NSUInteger i = 0; i < moveCount; i++)
    {
        NSIndexPath *fromIndexPath = fromIndexPaths[i];
        NSIndexPath *toIndexPath = toIndexPaths[i];
        
        if ([fromIndexPath compare:toIndexPath] == NSOrderedSame)
        {
            continue;
        }
        
        [self moveRowAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    }
    [self endUpdates];
    
    [self p_checkDataSourceIntegrity];
}


- (void)moveRowsAtIndexPaths:(NSArray *)fromIndexPaths toIndexPath:(NSIndexPath *)toIndexPath
{
#ifdef DEBUG
    NSLog(@"%@\nFrom %@ to %@", NSStringFromSelector(_cmd), fromIndexPaths, toIndexPath);
#endif
    
    [self p_checkIndexPathsArray:fromIndexPaths];
    
    GNEOutlineViewParentItem *toParentItem = [self p_outlineViewParentItemForSection:toIndexPath.gne_section];
    
    NSArray *groupedIndexPaths = [self p_reverseSortedIndexPathsGroupedBySectionInIndexPaths:fromIndexPaths];
    
    [self beginUpdates];
    for (NSArray *indexPathsInSection in groupedIndexPaths)
    {
        NSIndexPath *firstIndexPath = indexPathsInSection.firstObject;
        
        if (firstIndexPath == nil)
        {
            continue;
        }
        
        GNEOutlineViewItem *firstItem = [self p_outlineViewItemAtIndexPath:firstIndexPath];
        
        if (firstItem == nil)
        {
            continue;
        }
        
        GNEOutlineViewParentItem *parentItem = firstItem.parentItem;
        
        NSParameterAssert(parentItem);
        
        [self beginUpdates];
        for (NSIndexPath *indexPath in indexPathsInSection)
        {
            GNEOutlineViewItem *item = [self p_outlineViewItemAtIndexPath:indexPath];
            [self p_animateMoveOfOutlineViewItem:item
                                           toRow:toIndexPath.gne_row
                         inOutlineViewParentItem:toParentItem];
        }
        [self endUpdates];
    }
    [self endUpdates];
}


- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths
{
#ifdef DEBUG
    NSLog(@"%@\n%@", NSStringFromSelector(_cmd), indexPaths);
#endif
    
    [self p_checkIndexPathsArray:indexPaths];
    
    NSArray *groupedIndexPaths = [self p_sortedIndexPathsGroupedBySectionInIndexPaths:indexPaths];
    
    [self beginUpdates];
    for (NSArray *indexPathsInSection in groupedIndexPaths)
    {
        for (NSIndexPath *indexPath in indexPathsInSection)
        {
            GNEOutlineViewItem *item = [self p_outlineViewItemAtIndexPath:indexPath];
            
            if (item == nil)
            {
                continue;
            }
            
            [self reloadItem:item];
        }
    }
    [self endUpdates];
    
    [self p_checkDataSourceIntegrity];
}


- (void)insertSections:(NSIndexSet *)sections withAnimation:(NSTableViewAnimationOptions)animationOptions
{
#ifdef DEBUG
    NSLog(@"%@\n%@", NSStringFromSelector(_cmd), sections);
#endif
    
    NSParameterAssert([self.tableViewDataSource respondsToSelector:@selector(tableView:numberOfRowsInSection:)]);
    
    NSMutableIndexSet *insertedSections = [NSMutableIndexSet indexSet];
    
    NSMutableArray *outlineViewParentItemsCopy = [NSMutableArray arrayWithArray:self.outlineViewParentItems];
    NSMutableArray *outlineViewItemsCopy = [NSMutableArray arrayWithArray:self.outlineViewItems];
    
    [sections enumerateIndexesUsingBlock:^(NSUInteger proposedSection, BOOL *stop __unused)
    {
        @autoreleasepool
        {
            NSUInteger sectionCount = outlineViewParentItemsCopy.count;
            NSUInteger section = (proposedSection > sectionCount) ? sectionCount : proposedSection;
            
            GNEOutlineViewParentItem *parentItem = [[GNEOutlineViewParentItem alloc] init];
            parentItem.visible = [self p_outlineViewParentItemIsVisibleForSection:section];
            [outlineViewParentItemsCopy gne_insertObject:parentItem atIndex:section];
            
            NSMutableArray *rows = [NSMutableArray array];
            [outlineViewItemsCopy gne_insertObject:rows atIndex:section];
            
            NSUInteger rowCount = [self.tableViewDataSource tableView:self numberOfRowsInSection:section];
            
            for (NSUInteger row = 0; row < rowCount; row++)
            {
                GNEOutlineViewItem *item = [[GNEOutlineViewItem alloc] initWithParentItem:parentItem];
                
                [rows addObject:item];
            }
            
            [insertedSections addIndex:section];
        }
    }];
    
    NSParameterAssert(sections.count == insertedSections.count);
    
    self.outlineViewParentItems = outlineViewParentItemsCopy;
    self.outlineViewItems = outlineViewItemsCopy;
    
    [self insertItemsAtIndexes:insertedSections inParent:nil withAnimation:animationOptions];
    [self p_expandParentItemsAtIndexes:insertedSections];
    
    [self p_checkDataSourceIntegrity];
}


- (void)deleteSections:(NSIndexSet *)sections withAnimation:(NSTableViewAnimationOptions)animationOptions
{
#ifdef DEBUG
    NSLog(@"%@\n%@", NSStringFromSelector(_cmd), sections);
#endif
    
    NSMutableArray *outlineViewParentItemsCopy = [NSMutableArray arrayWithArray:self.outlineViewParentItems];
    NSMutableArray *outlineViewItemsCopy = [NSMutableArray arrayWithArray:self.outlineViewItems];
    
    NSMutableIndexSet *deletedSections = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger section, BOOL *stop __unused)
    {
        GNEOutlineViewParentItem *parentItem = [self p_outlineViewParentItemForSection:section];
        
        if (parentItem)
        {
            NSUInteger index = [self p_sectionForOutlineViewParentItem:parentItem];
            
            if (index != NSNotFound)
            {
                NSParameterAssert([deletedSections containsIndex:index] == NO);
                
                [deletedSections addIndex:index];
                
                NSParameterAssert(index < outlineViewParentItemsCopy.count);
                NSParameterAssert(index < outlineViewItemsCopy.count);
                
                [outlineViewParentItemsCopy removeObjectAtIndex:index];
                [outlineViewItemsCopy removeObjectAtIndex:index];
            }
        }
    }];
    
    NSParameterAssert(sections.count == deletedSections.count);
    
    self.outlineViewParentItems = outlineViewParentItemsCopy;
    self.outlineViewItems = outlineViewItemsCopy;
    
    [self removeItemsAtIndexes:deletedSections inParent:nil withAnimation:animationOptions];
    
    [self p_checkDataSourceIntegrity];
}


- (void)moveSection:(NSUInteger)fromSection toSection:(NSUInteger)toSection
{
    [self moveSections:[NSIndexSet indexSetWithIndex:fromSection] toSection:toSection];
}


- (void)moveSections:(NSIndexSet *)fromSections toSection:(NSUInteger)toSection
{
#ifdef DEBUG
    NSLog(@"%@\nFrom: %@ To: %lu", NSStringFromSelector(_cmd), fromSections, toSection);
#endif
    
    NSParameterAssert(self.outlineViewParentItems.count == self.outlineViewItems.count);
    
    NSMutableIndexSet *validSections = [[self p_indexSetByRemovingInvalidSectionsFromIndexSet:fromSections]
                                        mutableCopy];
    
    /**
     If the target section is the first section in the fromSections parameter, remove it and insert all of the
     other sections above it.
     */
    while (validSections.firstIndex == toSection)
    {
        [validSections removeIndex:toSection];
        toSection += 1;
    }
    
    __block NSUInteger sectionsAbove = 0;
    __block NSUInteger sectionsBelow = 0;
    
    /**
     If the target section is contained in the fromSections parameter, remove it, insert the sections greater than
     it above it, and insert all of the sections less than it below it.
     */
    if ([validSections containsIndex:toSection])
    {
        [validSections removeIndex:toSection];
        toSection += 1;
        sectionsBelow += 1;
    }
    
    [self beginUpdates];
    [validSections enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger fromSection,
                                                                                 BOOL *stop __unused)
    {
        // Set defaults.
        NSUInteger convertedFromSection = fromSection;
        NSUInteger convertedToSection = toSection;
        
        if (fromSection > toSection)
        {
            sectionsAbove += 1;
            convertedFromSection = fromSection + (sectionsAbove - 1);
        }
        else if (fromSection < toSection)
        {
            sectionsBelow += 1;
            convertedToSection = toSection - sectionsBelow;
        }
        
        GNEOutlineViewParentItem *parentItem = [self p_outlineViewParentItemForSection:convertedFromSection];
        NSUInteger parentItemIndex = [self p_sectionForOutlineViewParentItem:parentItem];
        
        NSParameterAssert(parentItemIndex != NSNotFound && parentItemIndex < self.outlineViewItems.count);
        
        if (parentItemIndex == NSNotFound || parentItemIndex >= self.outlineViewItems.count)
        {
            return;
        }
        
        NSMutableArray *rows = self.outlineViewItems[parentItemIndex];
        
        [self.outlineViewParentItems removeObjectAtIndex:parentItemIndex];
        [self.outlineViewItems removeObjectAtIndex:parentItemIndex];
        
        [self.outlineViewParentItems gne_insertObject:parentItem atIndex:convertedToSection];
        [self.outlineViewItems gne_insertObject:rows atIndex:convertedToSection];
        
        [self moveItemAtIndex:(NSInteger)parentItemIndex
                     inParent:nil
                      toIndex:(NSInteger)convertedToSection
                     inParent:nil];
    }];
    [self endUpdates];
    
    [self p_checkDataSourceIntegrity];
}


- (void)reloadSections:(NSIndexSet *)sections
{
#ifdef DEBUG
    NSLog(@"%@\n%@", NSStringFromSelector(_cmd), sections);
#endif
    
    NSParameterAssert(self.outlineViewParentItems.count == self.outlineViewItems.count);
    
    NSUInteger sectionCount = self.outlineViewParentItems.count;
    
    [self beginUpdates];
    [sections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL *stop __unused)
    {
        GNEOutlineViewParentItem *parentItem = nil;
        if (section < sectionCount && (parentItem = [self p_outlineViewParentItemForSection:section]))
        {
            [self reloadItem:parentItem reloadChildren:YES];
        }
    }];
    [self endUpdates];
    
    [self p_checkDataSourceIntegrity];
}


// ------------------------------------------------------------------------------------------
#pragma mark - Expand/Collapse Sections
// ------------------------------------------------------------------------------------------
- (BOOL)isSectionExpanded:(NSUInteger)section
{
    NSParameterAssert(section < self.outlineViewParentItems.count);
    
    if (section < self.outlineViewParentItems.count)
    {
        GNEOutlineViewParentItem *parentItem = self.outlineViewParentItems[section];
        
        return [self isItemExpanded:parentItem];
    }
    
    return NO;
}


- (void)expandSection:(NSUInteger)section animated:(BOOL)animated
{
    NSParameterAssert(section < self.outlineViewParentItems.count);
    
    if (section < self.outlineViewParentItems.count)
    {
        GNEOutlineViewParentItem *parentItem = self.outlineViewParentItems[section];
        NSOutlineView *outlineView = (animated) ? self.animator : self;
        [outlineView expandItem:parentItem];
    }
}


- (void)collapseSection:(NSUInteger)section animated:(BOOL)animated
{
    NSParameterAssert(section < self.outlineViewParentItems.count);
    
    if (section < self.outlineViewParentItems.count)
    {
        GNEOutlineViewParentItem *parentItem = self.outlineViewParentItems[section];
        NSOutlineView *outlineView = (animated) ? self.animator : self;
        [outlineView collapseItem:parentItem];
    }
}


// ------------------------------------------------------------------------------------------
#pragma mark - GNESectionedTableView - Public - Cell Frames
// ------------------------------------------------------------------------------------------
- (CGRect)frameOfCellAtIndexPath:(NSIndexPath *)indexPath
{
    GNEOutlineViewItem *item = [self p_outlineViewItemAtIndexPath:indexPath];
    if (item)
    {
        NSInteger row = [self rowForItem:item];
        
        return [super frameOfCellAtColumn:0 row:row];
    }
    
    return CGRectZero;
}


// ------------------------------------------------------------------------------------------
#pragma mark - GNESectionedTableView - Internal - Build Data Source Arrays
// ------------------------------------------------------------------------------------------
- (void)p_buildOutlineViewItemArrays
{
    NSUInteger sectionCount = [self p_numberOfSections];
    for (NSUInteger section = 0; section < sectionCount; section++)
    {
        GNEOutlineViewParentItem *parentItem = [[GNEOutlineViewParentItem alloc] init];
        parentItem.pasteboardWritingDelegate = self;
        BOOL isVisible = [self p_outlineViewParentItemIsVisibleForSection:section];
        parentItem.visible = isVisible;
        
        [self.outlineViewParentItems addObject:parentItem];
        NSMutableArray *rowArray = [NSMutableArray array];
        [self.outlineViewItems addObject:rowArray];
        
        NSUInteger rowCount = [self p_numberOfRowsInSection:section];
        for (NSUInteger row = 0; row < rowCount; row++)
        {
            GNEOutlineViewItem *item = [[GNEOutlineViewItem alloc] initWithParentItem:parentItem];
            item.pasteboardWritingDelegate = self;
            [rowArray addObject:item];
        }
    }
}


/**
 Determines if the outline view parent item for the specified item is visible to the user based on the 
 height and row view of the section header returned by the table view delegate.
 
 @discussion This method should only be called when originally building the outline view item arrays. After the
 outline view parent items' visible property is initially set, it's up to the user to reload the cell.
 @param section Section of the outline view parent item.
 @return YES if the outline view parent item is visible, otherwise NO.
 */
- (BOOL)p_outlineViewParentItemIsVisibleForSection:(NSUInteger)section
{
    if ([self.tableViewDelegate respondsToSelector:@selector(tableView:heightForHeaderInSection:)] &&
        [self.tableViewDelegate respondsToSelector:@selector(tableView:rowViewForHeaderInSection:)])
    {
        CGFloat height = [self.tableViewDelegate tableView:self heightForHeaderInSection:section];
        NSTableRowView *rowView = [self.tableViewDelegate tableView:self rowViewForHeaderInSection:section];
        
        if (height >= 1.0f && rowView)
        {
            return YES;
        }
    }
    
    return NO;
}


// ------------------------------------------------------------------------------------------
#pragma mark - GNESectionedTableView - Internal - Insert, Delete, Move Outline View Items
// ------------------------------------------------------------------------------------------
/**
 Animates the move of the specified outline view item to the specified row in its current parent.
 
 @param item Outline view item to move.
 @param toRow Row index to move the outline view item to.
 */
- (void)p_animateMoveOfOutlineViewItem:(GNEOutlineViewItem *)item toRow:(NSUInteger)toRow
{
    NSParameterAssert(item);
    
    GNEOutlineViewParentItem *parentItem = item.parentItem;
    
    NSUInteger section = [self p_sectionForOutlineViewParentItem:parentItem];

    NSParameterAssert(section != NSNotFound);
    if (section == NSNotFound)
    {
        return;
    }
    
    NSIndexPath *fromIndexPath = [self p_indexPathOfOutlineViewItem:item];
    
    NSParameterAssert(fromIndexPath);
    if (fromIndexPath == nil)
    {
        return;
    }
    
    NSUInteger fromSection = fromIndexPath.gne_section;
    NSUInteger fromRow = fromIndexPath.gne_row;
    
    toRow = (fromRow < toRow) ? (toRow - 1) : toRow;
    
    [self.outlineViewItems[fromSection] removeObjectAtIndex:fromRow];
    [self.outlineViewItems[fromSection] gne_insertObject:item atIndex:toRow];
    
    [self moveItemAtIndex:(NSInteger)fromRow
                 inParent:parentItem
                  toIndex:(NSInteger)toRow
                 inParent:parentItem];
}


/**
 Animates the move of the specified outline view item to the specified row in the specified outline view parent item.
 
 @param item Outline view item to move.
 @param toRow Row index to move the outline view item to.
 @param toParentItem Outline view parent item to move the specified outline view item to.
 */
- (void)p_animateMoveOfOutlineViewItem:(GNEOutlineViewItem *)item
                                 toRow:(NSUInteger)toRow
               inOutlineViewParentItem:(GNEOutlineViewParentItem *)toParentItem
{
    NSParameterAssert(item);
    NSParameterAssert(toParentItem);
    
    GNEOutlineViewParentItem *fromParentItem = item.parentItem;
    
    if ([fromParentItem isEqual:toParentItem])
    {
        [self p_animateMoveOfOutlineViewItem:item toRow:toRow];
        return;
    }
    
    NSIndexPath *actualIndexPath = [self p_indexPathOfOutlineViewItem:item];
    NSUInteger toSection = [self p_sectionForOutlineViewParentItem:toParentItem];
    
    NSParameterAssert(actualIndexPath);
    NSParameterAssert(toSection != NSNotFound);
    if (actualIndexPath == nil || toSection == NSNotFound)
    {
        return;
    }
    
    NSUInteger fromSection = actualIndexPath.gne_section;
    NSUInteger fromRow = actualIndexPath.gne_row;
    
    [self.outlineViewItems[fromSection] removeObjectAtIndex:fromRow];
    
    item.parentItem = toParentItem;
    
    [(NSMutableArray *)self.outlineViewItems[toSection] gne_insertObject:item atIndex:toRow];
    
    [self moveItemAtIndex:(NSInteger)fromRow
                 inParent:fromParentItem
                  toIndex:(NSInteger)toRow
                 inParent:toParentItem];
}


/**
 Returns an array of arrays. Each inner array contains all of the specified index paths belonging to the same 
 section. The sections and rows are all sorted in ascending order (from smallest to largest).
 
 @param indexPaths Array of index paths to group and sort.
 @return Array of arrays of index paths sorted in ascending order by section and row.
 */
- (NSArray *)p_sortedIndexPathsGroupedBySectionInIndexPaths:(NSArray *)indexPaths
{
    SEL comparator = NSSelectorFromString(@"gne_compare:");
    
    return [self p_sortedIndexPathsGroupedBySectionInIndexPaths:indexPaths usingSelector:comparator];
}


/**
 Returns an array of arrays. Each inner array contains all of the specified index paths belonging to the same
 section. The sections and rows are all sorted in descending order (from largest to smallest).
 
 @param indexPaths Array of index paths to group and sort.
 @return Array of arrays of index paths sorted in descending order by section and row.
 */
- (NSArray *)p_reverseSortedIndexPathsGroupedBySectionInIndexPaths:(NSArray *)indexPaths
{
    SEL comparator = NSSelectorFromString(@"gne_reverseCompare:");
    
    return [self p_sortedIndexPathsGroupedBySectionInIndexPaths:indexPaths usingSelector:comparator];
}


- (NSArray *)p_sortedIndexPathsGroupedBySectionInIndexPaths:(NSArray *)indexPaths usingSelector:(SEL)comparator
{
    NSMutableArray *groupedIndexPaths = [NSMutableArray array];
    NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:comparator];
    
    NSUInteger currentSection = NSNotFound;
    NSMutableArray *indexPathsInCurrentSection = nil;
    
    for (NSIndexPath *indexPath in sortedIndexPaths)
    {
        if (currentSection != indexPath.gne_section)
        {
            currentSection = indexPath.gne_section;
            indexPathsInCurrentSection = [NSMutableArray array];
            [groupedIndexPaths addObject:indexPathsInCurrentSection];
        }
        
        [indexPathsInCurrentSection addObject:indexPath];
    }
    
    return groupedIndexPaths;
}


/**
 Returns an index set that contains all of the valid section indexes in the specified index set.
 
 @param sections Index set containing indexes corresponding to outline view parent items in the outline view parent
 items array.
 @return Index set containing all of the valid section indexes in the specified index set.
 */
- (NSIndexSet *)p_indexSetByRemovingInvalidSectionsFromIndexSet:(NSIndexSet *)sections
{
    NSParameterAssert(self.outlineViewParentItems.count == self.outlineViewItems.count);
    
    if (sections.count == 0)
    {
        return sections;
    }
    
    NSMutableIndexSet *validSections = [NSMutableIndexSet indexSet];
    [validSections addIndexes:sections];
    
    NSUInteger sectionCount = self.outlineViewParentItems.count;
    
    [sections enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger section, BOOL *stop)
    {
        if (section < sectionCount)
        {
            *stop = YES;
        }
        else
        {
            [validSections removeIndex:section];
        }
    }];
    
    return validSections;
}


// ------------------------------------------------------------------------------------------
#pragma mark - GNESectionedTableView - Internal - Retrieving Outline View Items
// ------------------------------------------------------------------------------------------
/**
 Returns the index pointing to the specified outline view parent item in the outline view parent items array.
 
 @param parentItem Outline view parent item to locate.
 @return Index matching the current location of the specified outline view parent item in table view's outline
 view parent items array, or NSNotFound if the outline view parent item could not be found.
 */
- (NSUInteger)p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)parentItem
{
    NSParameterAssert([parentItem isKindOfClass:[GNEOutlineViewParentItem class]]);
    
    NSUInteger index = [self.outlineViewParentItems indexOfObject:parentItem];
    
    return index;
}


/**
 Returns an index set of all of the sections headers contained in the specified row indexes, or nil if the
 row indexes do not correspond to any section headers.
 
 @param rowIndexes Table view indexes.
 @return Index set of the section headers or nil if the specified row indexes don't correspond to any
 section headers.
 */
- (NSIndexSet *)p_indexSetOfSectionHeadersAtTableViewRows:(NSIndexSet *)rowIndexes
{
    NSMutableIndexSet *sectionIndexes = [NSMutableIndexSet indexSet];
    
    __weak typeof(self) weakSelf = self;
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop __unused)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;

        GNEOutlineViewItem *item = [strongSelf itemAtRow:(NSInteger)idx];
        if (item.parentItem == nil)
        {
            NSParameterAssert([item isKindOfClass:[GNEOutlineViewParentItem class]]);
            NSUInteger section = [strongSelf p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)item];
            if (section != NSNotFound)
            {
                [sectionIndexes addIndex:section];
            }
        }
    }];
    
    return ((sectionIndexes.count > 0) ? [sectionIndexes copy] : nil);
}


/**
 Returns the index path pointing to the specified outline view item in the outline view items array.
 
 @param item Outline view item to locate.
 @return Index path matching the current location of the specified outline view item in table view's outline view
            items array, or nil if it couldn't be found.
 */
- (NSIndexPath *)p_indexPathOfOutlineViewItem:(GNEOutlineViewItem *)item
{
    NSUInteger sectionCount = self.outlineViewItems.count;
    
    // If it's a outline view parent item, find its section and then make an appropriate index path for it.
    GNEOutlineViewParentItem *parentItem = item.parentItem;
    if (parentItem == nil)
    {
        NSUInteger section = [self p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)item];
        
        return [NSIndexPath gne_indexPathForRow:NSNotFound inSection:section];
    }

    // Find the outline view item in its parent's section.
    NSUInteger section = [self p_sectionForOutlineViewParentItem:parentItem];
    if (section != NSNotFound && section < sectionCount)
    {
        NSArray *sectionArray = self.outlineViewItems[section];
        
        NSUInteger row = [sectionArray indexOfObject:item];
        if (row != NSNotFound)
        {
            return [NSIndexPath gne_indexPathForRow:row inSection:section];
        }
    }
    
    // If the item wasn't found, iterate through all of the sections to find it.
    for (section = 0; section < sectionCount; section++)
    {
        NSArray *sectionArray = self.outlineViewItems[section];
        NSUInteger row = [sectionArray indexOfObject:item];
        if (row != NSNotFound)
        {
            return [NSIndexPath gne_indexPathForRow:row inSection:section];
        }
    }
    
    return nil;
}


/**
 Returns an array of the index paths of the rows contained in the specified table view row indexes, or nil if
 the table view row indexes do not correspond to any rows.
 
 @param rowIndexes Table view indexes.
 @return Array of the index paths for the rows or nil if the specified table view row indexes don't
 correspond to any rows.
 */
- (NSArray *)p_indexPathsOfRowsAtTableViewRows:(NSIndexSet *)rowIndexes
{
    NSMutableArray *indexPaths = [NSMutableArray array];
    
    __weak typeof(self) weakSelf = self;
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop __unused)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;

        GNEOutlineViewItem *item = [strongSelf itemAtRow:(NSInteger)idx];
        if (item.parentItem)
        {
            NSIndexPath *indexPath = [strongSelf p_indexPathOfOutlineViewItem:item];
            if (indexPath)
            {
                [indexPaths addObject:indexPath];
            }
        }
    }];
    
    return ((indexPaths.count > 0) ? [NSArray arrayWithArray:indexPaths] : nil);
}


/**
 Returns the outline view item or outline view parent item located at the specified index in the outline view
    items array or outline view parent items array, or nil if the item couldn't be found.
 
 @discussion Returns an outline view item if parentItem is not nil, otherwise returns an outline view parent item.
 @param index Index of the desired outline view item or parent item.
 @param parentItem Outline view parent item for the desired outline view item or nil if searching for an outline
            view parent item.
 @return Outline view item or outline view parent item located at the specified index of the specified parent.
 */
- (GNEOutlineViewItem *)p_outlineViewItemAtIndex:(NSUInteger)index ofParent:(GNEOutlineViewParentItem *)parentItem
{
    NSParameterAssert(parentItem == nil || [parentItem isKindOfClass:[GNEOutlineViewParentItem class]]);
    
    if (parentItem)
    {
        NSUInteger section = [self p_sectionForOutlineViewParentItem:parentItem];
        
        if (section < self.outlineViewItems.count && index < ((NSArray *)self.outlineViewItems[section]).count)
        {
            NSArray *sectionArray = self.outlineViewItems[section];
            
            return sectionArray[index];
        }
    }
    else if (index < self.outlineViewParentItems.count)
    {
        return self.outlineViewParentItems[index];
    }
    
    NSAssert2(NO, @"Could not find item at index %lu of parent %@", (unsigned long)index, parentItem);
    
    return nil;
}


/**
 Returns the outline view parent item for the specified section.
 
 @param section Section to use to find a matching outline view parent item.
 @return Outline view parent item for the specified section, otherwise nil.
 */
- (GNEOutlineViewParentItem *)p_outlineViewParentItemForSection:(NSUInteger)section
{
    NSIndexPath *indexPath = [NSIndexPath gne_indexPathForRow:NSNotFound inSection:section];
    
    return [self p_outlineViewParentItemWithIndexPath:indexPath];
}


/**
 Returns the outline view parent item at the specified index path.
 
 @param indexPath Index path to use to find a matching outline view parent item.
 @return Outline view parent item at the specified index path, otherwise nil.
 */
- (GNEOutlineViewParentItem *)p_outlineViewParentItemWithIndexPath:(NSIndexPath *)indexPath
{
    NSParameterAssert(indexPath);
    NSParameterAssert(indexPath.gne_row == NSNotFound);
    
    NSUInteger parentItemsCount = self.outlineViewParentItems.count;
    
    NSParameterAssert(indexPath.gne_section < parentItemsCount);
    
    if (indexPath.gne_section < parentItemsCount)
    {
        return self.outlineViewParentItems[indexPath.gne_section];
    }
    
    return nil;
}


/**
 Returns the outline view item at the specified index path.
 
 @param indexPath Index path to use to find a matching outline view item.
 @return Outline view item at the specified index path, otherwise nil.
 */
- (GNEOutlineViewItem *)p_outlineViewItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSParameterAssert(indexPath);
    
    // If it's an outline view parent item, call the appropriate method.
    if (indexPath.gne_row == NSNotFound)
    {
        return [self p_outlineViewParentItemForSection:indexPath.gne_section];
    }
    
    NSUInteger sectionCount = self.outlineViewItems.count;
    
    NSParameterAssert(indexPath.gne_section < sectionCount);
    
    if (indexPath.gne_section < sectionCount)
    {
        NSArray *sectionArray = self.outlineViewItems[indexPath.gne_section];
        NSUInteger rowCount = sectionArray.count;
        
        NSParameterAssert(indexPath.gne_row < rowCount);
        
        if (indexPath.gne_row < rowCount)
        {
            return sectionArray[indexPath.gne_row];
        }
    }
    
    return nil;
}


// ------------------------------------------------------------------------------------------
#pragma mark - GNESectionedTableView - Internal - Expand/Collapse Parent Items
// ------------------------------------------------------------------------------------------
- (void)p_expandParentItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSUInteger count = self.outlineViewParentItems.count;
    __weak typeof(self) weakSelf = self;
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop __unused)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (index < count)
        {
            GNEOutlineViewParentItem *parentItem = strongSelf.outlineViewParentItems[index];
            [strongSelf expandItem:parentItem];
        }
    }];
}


- (void)p_collapseParentItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSUInteger count = self.outlineViewParentItems.count;
    __weak typeof(self) weakSelf = self;
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop __unused)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (index < count)
        {
            GNEOutlineViewParentItem *parentItem = strongSelf.outlineViewParentItems[index];
            [strongSelf collapseItem:parentItem];
        }
    }];
}


// ------------------------------------------------------------------------------------------
#pragma mark - GNESectionedTableView - Internal - Counts
// ------------------------------------------------------------------------------------------
- (NSUInteger)p_numberOfSections
{
    if ([self.tableViewDataSource respondsToSelector:@selector(numberOfSectionsInTableView:)])
    {
        return [self.tableViewDataSource numberOfSectionsInTableView:self];
    }
    
    return 0;
}


- (NSUInteger)p_numberOfRowsInSection:(NSUInteger)section
{
    if ([self.tableViewDataSource respondsToSelector:@selector(tableView:numberOfRowsInSection:)])
    {
        return [self.tableViewDataSource tableView:self numberOfRowsInSection:section];
    }
    
    return 0;
}


- (NSUInteger)p_numberOfRowsInOutlineView
{
    NSUInteger sectionCount = self.outlineViewItems.count;
    NSUInteger rowCount = 0;
    
    for (NSUInteger section = 0; section < sectionCount; section++)
    {
        rowCount += ((NSArray *)self.outlineViewItems[section]).count;
    }
    
    return (sectionCount + rowCount); // Section headers count as rows even if they are not "visible"
}


- (NSUInteger)p_numberOfOutlineViewItemsForOutlineViewParentItem:(GNEOutlineViewParentItem *)parentItem
{
    NSParameterAssert([parentItem isKindOfClass:[GNEOutlineViewParentItem class]]);
    
    NSUInteger section = [self p_sectionForOutlineViewParentItem:parentItem];
    if (section < self.outlineViewItems.count)
    {
        return ((NSArray *)self.outlineViewItems[section]).count;
    }
    
    return 0;
}


// ------------------------------------------------------------------------------------------
#pragma mark - GNESectionedTableView - Internal - Drag-and-drop
// ------------------------------------------------------------------------------------------
- (void)p_registerForDraggedTypes
{
    [self unregisterDraggedTypes];
    
    NSArray *draggedTypes = @[GNEOutlineViewItemPasteboardType];
    
    if ([self.tableViewDataSource respondsToSelector:@selector(draggedTypesForTableView:)])
    {
        NSArray *additionalTypes = [self.tableViewDataSource draggedTypesForTableView:self];
        
        if (additionalTypes.count > 0)
        {
            draggedTypes = [draggedTypes arrayByAddingObjectsFromArray:additionalTypes];
        }
    }
    
    [self registerForDraggedTypes:draggedTypes];
}


- (NSDragOperation)p_dragOperationForDrop:(id<NSDraggingInfo>)info
                        toProposedSection:(NSUInteger)toSection
{
    __block BOOL canDrag = YES;
    
    __weak typeof(self) weakSelf = self;
    [info enumerateDraggingItemsWithOptions:0
                                    forView:self
                                    classes:@[[GNEOutlineViewItem class]]
                              searchOptions:nil
                                 usingBlock:^(NSDraggingItem *draggingItem,
                                              NSInteger idx __unused,
                                              BOOL *stop)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        GNEOutlineViewItem *draggedItem = [strongSelf p_draggedItemForDraggingItem:draggingItem];
        
        if (draggedItem)
        {
            GNEOutlineViewParentItem *parentItem = draggedItem.parentItem;
            
            SEL sectionSelector = @selector(tableView:canDragSection:toSection:);
            SEL rowSelector = @selector(tableView:canDragRowAtIndexPath:toSection:);
            if (parentItem == nil &&
                [strongSelf.tableViewDataSource respondsToSelector:sectionSelector])
            {
                NSParameterAssert([draggedItem isKindOfClass:[GNEOutlineViewParentItem class]]);
                
                NSUInteger fromSection = [strongSelf p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)draggedItem];
                canDrag = [strongSelf.tableViewDataSource tableView:strongSelf
                                                     canDragSection:fromSection
                                                          toSection:toSection];
            }
            else if (parentItem && [strongSelf.tableViewDataSource respondsToSelector:rowSelector])
            {
                NSIndexPath *fromIndexPath = [strongSelf p_indexPathOfOutlineViewItem:draggedItem];
                canDrag = [strongSelf.tableViewDataSource tableView:strongSelf
                                              canDragRowAtIndexPath:fromIndexPath
                                                          toSection:toSection];
            }
            
            if (canDrag == NO && stop)
            {
                *stop = YES;
            }
        }
    }];
    
    // TODO: Add ability to retarget drop here.
    // - (NSIndexPath *)tableView:(GNESectionedTableView *)tableView targetIndexPathForMoveFromSection:(NSUInteger *)fromSection toProposedSection:(NSUInteger)proposedToSection
    // - (NSIndexPath *)tableView:(GNESectionedTableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)fromIndexPath toProposedIndexPath:(NSIndexPath *)proposedToIndexPath
    
    return ((canDrag) ? NSDragOperationMove : NSDragOperationNone);
}


- (NSDragOperation)p_dragOperationForDrop:(id<NSDraggingInfo>)info
                      toProposedIndexPath:(NSIndexPath *)toIndexPath
{
    __block BOOL canDrag = YES;
    
    __weak typeof(self) weakSelf = self;
    [info enumerateDraggingItemsWithOptions:0
                                    forView:self
                                    classes:@[[GNEOutlineViewItem class]]
                              searchOptions:nil
                                 usingBlock:^(NSDraggingItem *draggingItem,
                                              NSInteger idx __unused,
                                              BOOL *stop)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;

        GNEOutlineViewItem *draggedItem = [strongSelf p_draggedItemForDraggingItem:draggingItem];

        if (draggedItem)
        {
            GNEOutlineViewParentItem *parentItem = draggedItem.parentItem;
            
            SEL rowSelector = @selector(tableView:canDragRowAtIndexPath:toIndexPath:);
            if (parentItem && [strongSelf.tableViewDataSource respondsToSelector:rowSelector])
            {
                NSIndexPath *fromIndexPath = [strongSelf p_indexPathOfOutlineViewItem:draggedItem];
                canDrag = [strongSelf.tableViewDataSource tableView:strongSelf
                                              canDragRowAtIndexPath:fromIndexPath
                                                        toIndexPath:toIndexPath];
            }

            if (canDrag == NO && stop)
            {
                *stop = YES;
            }
        }
    }];
    
    // TODO: Add ability to retarget drop here.
    // - (NSIndexPath *)tableView:(GNESectionedTableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)fromIndexPath toProposedIndexPath:(NSIndexPath *)proposedToIndexPath
    
    return ((canDrag) ? NSDragOperationMove : NSDragOperationNone);
}


- (BOOL)p_isDraggingSectionsAndRows:(id<NSDraggingInfo>)info
{
    __block BOOL hasSections = NO;
    __block BOOL hasRows = NO;
    
    __weak typeof(self) weakSelf = self;
    [info enumerateDraggingItemsWithOptions:0
                                    forView:self
                                    classes:@[[GNEOutlineViewItem class]]
                              searchOptions:0
                                 usingBlock:^(NSDraggingItem *draggingItem,
                                              NSInteger idx __unused,
                                              BOOL *stop)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        GNEOutlineViewItem *draggedItem = [strongSelf p_draggedItemForDraggingItem:draggingItem];
        
        if (draggedItem.parentItem == nil)
        {
            hasSections = YES;
        }
        else
        {
            hasRows = YES;
        }
        
        if (hasSections && hasRows && stop)
        {
            *stop = YES;
        }
    }];
    
    return (hasSections && hasRows);
}


- (GNEOutlineViewItem *)p_draggedItemForDraggingItem:(NSDraggingItem *)draggingItem
{
    GNEOutlineViewItem *draggedItem = nil;
    
    GNEOutlineViewItem *item = draggingItem.item;
    NSInteger row = item.draggedRow;
    
    if (row >= 0)
    {
        draggedItem = [self itemAtRow:row];
    }
    
    return draggedItem;
}


// ------------------------------------------------------------------------------------------
#pragma mark - GNESectionedTableView - Internal - Debug Checks
// ------------------------------------------------------------------------------------------
#ifdef DEBUG
- (void)p_checkDataSourceIntegrity
{
    id dataSource = (id)self.tableViewDataSource;
    
    SEL numberOfSectionsSelector = NSSelectorFromString(@"numberOfSections");
    SEL numberOfRowsSelector = NSSelectorFromString(@"numberOfRows");
    
    NSParameterAssert([dataSource respondsToSelector:numberOfSectionsSelector]);
    NSParameterAssert([dataSource respondsToSelector:numberOfRowsSelector]);
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSUInteger numberOfSectionsInDataSource = (NSUInteger)[dataSource performSelector:numberOfSectionsSelector];
#pragma clang diagnostic pop
    NSUInteger numberOfSectionsInOutlineView = (NSUInteger)[self p_numberOfSections];
    
    NSParameterAssert(numberOfSectionsInDataSource == numberOfSectionsInOutlineView);
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSUInteger numberOfRowsInDataSource = (NSUInteger)[dataSource performSelector:numberOfRowsSelector];
#pragma clang diagnostic pop
    NSUInteger numberOfRowsInOutlineView = [self p_numberOfRowsInOutlineView] - [self p_numberOfSections];
    
    NSParameterAssert(numberOfRowsInDataSource == numberOfRowsInOutlineView);
}
#else
- (void)p_checkDataSourceIntegrity
{
    
}
#endif


#ifdef DEBUG
- (void)p_checkIndexPathsArray:(NSArray *)indexPaths
{
    for (NSIndexPath *indexPath in indexPaths)
    {
        NSParameterAssert([indexPath isKindOfClass:[NSIndexPath class]] && indexPath.length == 2);
    }
}
#else
- (void)p_checkIndexPathsArray:(NSArray * __unused)indexPaths
{
    
}
#endif


// ------------------------------------------------------------------------------------------
#pragma mark - NSOutlineView - Reloading Data
// ------------------------------------------------------------------------------------------
// TODO: Perhaps nil out outline view item arrays, -[super reloadData], rebuild arrays, -[super reloadData]
- (void)reloadData
{
    __weak typeof(self) weakSelf = self;
    [self performAfterAnimations:^(NSOutlineView *__weak ov __unused)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil)
        {
            return;
        }
        
        [strongSelf.outlineViewParentItems removeAllObjects];
        [strongSelf.outlineViewItems removeAllObjects];
        
        [strongSelf p_buildOutlineViewItemArrays];
        
        [super reloadData];
        [strongSelf expandItem:nil expandChildren:YES];
    }];
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSOutlineView - Cell Frames
// ------------------------------------------------------------------------------------------
- (NSRect)frameOfOutlineCellAtRow:(NSInteger __unused)row
{
    return CGRectZero;
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSOutlineViewDataSource - Required
// ------------------------------------------------------------------------------------------
- (NSInteger)numberOfRowsInOutlineView:(NSOutlineView * __unused)outlineView
{
    return (NSInteger)[self p_numberOfRowsInOutlineView];
}


- (id)outlineView:(NSOutlineView * __unused)outlineView
            child:(NSInteger)index
           ofItem:(GNEOutlineViewParentItem *)parentItem
{
    NSParameterAssert(parentItem == nil || [parentItem isKindOfClass:[GNEOutlineViewParentItem class]]);
    
    return [self p_outlineViewItemAtIndex:(NSUInteger)index ofParent:parentItem];
}


- (BOOL)outlineView:(NSOutlineView * __unused)outlineView isItemExpandable:(GNEOutlineViewItem *)item
{
    NSParameterAssert(item == nil || [item isKindOfClass:[GNEOutlineViewItem class]]);
    
    if (item)
    {
        if (item.parentItem == nil)
        {
            return YES; // Parent items should always be expandable.
        }
        else
        {
            return NO; // Child items should never be expandable.
        }
    }
    
    return YES; // Root item is always expandable
}


- (NSInteger)outlineView:(NSOutlineView * __unused)outlineView numberOfChildrenOfItem:(GNEOutlineViewItem *)item
{
    NSParameterAssert(item == nil || [item isKindOfClass:[GNEOutlineViewItem class]]);
    
    if (item)
    {
        if (item.parentItem == nil)
        {
            return (NSInteger)[self p_numberOfOutlineViewItemsForOutlineViewParentItem:(GNEOutlineViewParentItem *)item];
        }
        else // Child objects cannot have children (they are too young!!!).
        {
            return 0;
        }
    }
    
    return (NSInteger)[self.outlineViewParentItems count]; // root item has all of the parent items (sections) as children.
}


-           (id)outlineView:(NSOutlineView * __unused)outlineView
  objectValueForTableColumn:(NSTableColumn * __unused)tableColumn
                     byItem:(GNEOutlineViewItem *)item
{
    NSParameterAssert(item == nil || [item isKindOfClass:[GNEOutlineViewItem class]]);
    
    return item;
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSOutlineViewDelegate - View Size and Appearance
// ------------------------------------------------------------------------------------------
- (CGFloat)outlineView:(NSOutlineView * __unused)outlineView heightOfRowByItem:(GNEOutlineViewItem *)item
{
    NSParameterAssert([item isKindOfClass:[GNEOutlineViewItem class]]);
    
    // Section header
    if (item.parentItem == nil)
    {
        NSUInteger section = [self p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)item];
        if (section != NSNotFound && [self p_outlineViewParentItemIsVisibleForSection:section])
        {
            return [self.tableViewDelegate tableView:self heightForHeaderInSection:section];
        }
        
        return WLSectionedTableViewInvisibleRowHeight;
    }
    
    // Row
    NSIndexPath *indexPath = [self p_indexPathOfOutlineViewItem:item];
    if (indexPath && [self.tableViewDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)])
    {
        return [self.tableViewDelegate tableView:self heightForRowAtIndexPath:indexPath];
    }
    
    return kDefaultRowHeight;
}


- (BOOL)outlineView:(NSOutlineView * __unused)outlineView isGroupItem:(GNEOutlineViewItem *)item
{
    NSParameterAssert(item == nil || [item isKindOfClass:[GNEOutlineViewItem class]]);
    
    return NO;
}


- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(GNEOutlineViewItem *)item
{
    NSParameterAssert(item == nil || [item isKindOfClass:[GNEOutlineViewItem class]]);
    NSParameterAssert([self.tableViewDataSource respondsToSelector:@selector(tableView:rowViewForRowAtIndexPath:)]);
    
    // Section header
    if (item.parentItem == nil)
    {
        NSUInteger section = [self p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)item];
        if (section != NSNotFound &&
            [self.tableViewDelegate respondsToSelector:@selector(tableView:rowViewForHeaderInSection:)])
        {
            return [self.tableViewDelegate tableView:self rowViewForHeaderInSection:section];
        }
        else
        {
            NSTableRowView *rowView = [outlineView makeViewWithIdentifier:kOutlineViewStandardHeaderRowViewIdentifier
                                                                    owner:outlineView];
            
            if (rowView == nil)
            {
                rowView = [[NSTableRowView alloc] initWithFrame:CGRectZero];
                [rowView setAutoresizingMask:NSViewWidthSizable];
                rowView.identifier = kOutlineViewStandardHeaderRowViewIdentifier;
                rowView.backgroundColor = [NSColor clearColor];
            }
            
            return rowView;
        }
    }
    
    // Row
    NSIndexPath *indexPath = [self p_indexPathOfOutlineViewItem:item];
    if (indexPath)
    {
        return [self.tableViewDataSource tableView:self rowViewForRowAtIndexPath:indexPath];
    }
    
    return nil;
}


- (NSView *)outlineView:(NSOutlineView * __unused)outlineView
     viewForTableColumn:(NSTableColumn * __unused)tableColumn
                   item:(GNEOutlineViewItem *)item
{
    NSParameterAssert(item == nil || [item isKindOfClass:[GNEOutlineViewItem class]]);
    NSParameterAssert([self.tableViewDataSource respondsToSelector:@selector(tableView:cellViewForRowAtIndexPath:)]);
    
    // Section header
    if (item.parentItem == nil)
    {
        NSUInteger section = [self p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)item];
        if (section != NSNotFound &&
            [self.tableViewDelegate respondsToSelector:@selector(tableView:cellViewForHeaderInSection:)])
        {
            return [self.tableViewDelegate tableView:self cellViewForHeaderInSection:section];
        }
        
        return nil;
    }
    
    // Row
    NSIndexPath *indexPath = [self p_indexPathOfOutlineViewItem:item];
    if (indexPath)
    {
        return [self.tableViewDataSource tableView:self cellViewForRowAtIndexPath:indexPath];
    }
    
    return nil;
}


- (void)outlineView:(NSOutlineView * __unused)outlineView
      didAddRowView:(NSTableRowView *)rowView
             forRow:(NSInteger)row
{
    if ([self.tableViewDelegate respondsToSelector:@selector(tableView:didDisplayRowView:forRow:)])
    {
        [self.tableViewDelegate tableView:self didDisplayRowView:rowView forRow:(NSUInteger)row];
    }
    
    NSTableCellView *cellView = (rowView.numberOfColumns > 0) ? [rowView viewAtColumn:0] : nil;
    if (cellView &&
        [self.tableViewDelegate respondsToSelector:@selector(tableView:didDisplayCellView:forRow:)])
    {
        [self.tableViewDelegate tableView:self didDisplayCellView:cellView forRow:(NSUInteger)row];
    }
}


- (void)outlineView:(NSOutlineView * __unused)outlineView
   didRemoveRowView:(NSTableRowView *)rowView
             forRow:(NSInteger)row
{
    if ([self.tableViewDelegate respondsToSelector:@selector(tableView:didEndDisplayingRowView:forRow:)])
    {
        [self.tableViewDelegate tableView:self didEndDisplayingRowView:rowView forRow:(NSUInteger)row];
    }
    
    NSTableCellView *cellView = (rowView.numberOfColumns > 0) ? [rowView viewAtColumn:0] : nil;
    if (cellView &&
        [self.tableViewDelegate respondsToSelector:@selector(tableView:didEndDisplayingCellView:forRow:)])
    {
        [self.tableViewDelegate tableView:self didEndDisplayingCellView:cellView forRow:(NSUInteger)row];
    }
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSOutlineViewDelegate - Selection
// ------------------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView * __unused)outlineView shouldSelectItem:(GNEOutlineViewItem *)item
{
    NSParameterAssert(item == nil || [item isKindOfClass:[GNEOutlineViewItem class]]);
    
    // Don't allow the selection of the root object (not that it is even possible).
    if (item == nil)
    {
        return NO;
    }
    
    NSIndexPath *indexPath = [self p_indexPathOfOutlineViewItem:item];
    
    if (indexPath == nil)
    {
        return NO;
    }

    SEL sectionSelector = @selector(tableView:shouldSelectHeaderInSection:);
    SEL rowSelector = @selector(tableView:shouldSelectRowAtIndexPath:);
    
    if (item.parentItem == nil)
    {
        if ([self.tableViewDelegate respondsToSelector:sectionSelector])
        {
            return [self.tableViewDelegate tableView:self
                         shouldSelectHeaderInSection:indexPath.gne_section];
        }
        
        return NO; // By default, don't allow the section headers to be selected.
    }
    else
    {
        if ([self.tableViewDelegate respondsToSelector:rowSelector])
        {
            return [self.tableViewDelegate tableView:self shouldSelectRowAtIndexPath:indexPath];
        }
        
        return YES; // Allow selection of normal rows by default.
    }
    
    return NO;
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    if ([self isEqual:notification.object] == NO)
    {
        return;
    }
    
    NSIndexSet *selectedRows = self.selectedRowIndexes;
    
    SEL deselectSelector = @selector(tableViewDidDeselectAllHeadersAndRows:);
    SEL selectHeaderSelector = @selector(tableView:didSelectHeaderInSection:);
    SEL selectRowSelector = @selector(tableView:didSelectRowAtIndexPath:);
    SEL selectHeadersSelector = @selector(tableView:didSelectHeadersInSections:);
    SEL selectRowsSelector = @selector(tableView:didSelectRowsAtIndexPaths:);
    
    if (selectedRows.count == 0 &&
        [self.tableViewDelegate respondsToSelector:deselectSelector])
    {
        [self.tableViewDelegate tableViewDidDeselectAllHeadersAndRows:self];
    }
    else if (selectedRows.count == 1)
    {
        GNEOutlineViewItem *item = [self itemAtRow:(NSInteger)selectedRows.firstIndex];
        GNEOutlineViewParentItem *parentItem = item.parentItem;
        if (parentItem == nil && [self.tableViewDelegate respondsToSelector:selectHeaderSelector])
        {
            NSParameterAssert([item isKindOfClass:[GNEOutlineViewParentItem class]]);
            NSUInteger section = [self p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)item];
            [self.tableViewDelegate tableView:self didSelectHeaderInSection:section];
        }
        else if (parentItem && [self.tableViewDelegate respondsToSelector:selectRowSelector])
        {
            NSIndexPath *indexPath = [self p_indexPathOfOutlineViewItem:item];
            [self.tableViewDelegate tableView:self didSelectRowAtIndexPath:indexPath];
        }
    }
    else
    {
        NSIndexSet *sectionHeaders = [self p_indexSetOfSectionHeadersAtTableViewRows:selectedRows];
        if (sectionHeaders.count > 0 && [self.tableViewDelegate respondsToSelector:selectHeadersSelector])
        {
            [self.tableViewDelegate tableView:self didSelectHeadersInSections:sectionHeaders];
        }
        
        NSArray *rowIndexPaths = [self p_indexPathsOfRowsAtTableViewRows:selectedRows];
        if (rowIndexPaths.count > 0 && [self.tableViewDelegate respondsToSelector:selectRowsSelector])
        {
            [self.tableViewDelegate tableView:self didSelectRowsAtIndexPaths:rowIndexPaths];
        }
    }
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSOutlineViewDataSource - Drag-and-drop
// ------------------------------------------------------------------------------------------
- (id<NSPasteboardWriting>)outlineView:(NSOutlineView * __unused)outlineView
               pasteboardWriterForItem:(GNEOutlineViewItem *)item
{
    NSParameterAssert([item isKindOfClass:[GNEOutlineViewItem class]]);
    
    BOOL canDrag = YES;
    
    GNEOutlineViewParentItem *parentItem = item.parentItem;
    if (parentItem == nil &&
        [self.tableViewDataSource respondsToSelector:@selector(tableView:canDragSection:)])
    {
        NSParameterAssert([item isKindOfClass:[GNEOutlineViewParentItem class]]);
        
        NSUInteger section = [self p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)item];
        canDrag = [self.tableViewDataSource tableView:self canDragSection:section];
    }
    else if (parentItem &&
             [self.tableViewDataSource respondsToSelector:@selector(tableView:canDragRowAtIndexPath:)])
    {
        NSIndexPath *indexPath = [self p_indexPathOfOutlineViewItem:item];
        canDrag = [self.tableViewDataSource tableView:self canDragRowAtIndexPath:indexPath];
    }
    
    return ((canDrag) ? item : nil);
}


- (void)outlineView:(NSOutlineView *)outlineView
    draggingSession:(NSDraggingSession *)session
   willBeginAtPoint:(NSPoint __unused)screenPoint
           forItems:(NSArray * __unused)draggedItems
{
    session.draggingFormation = NSDraggingFormationNone;
    CGPoint draggingLocation = session.draggingLocation;
    CGRect screenDraggingLocation = CGRectMake(draggingLocation.x, draggingLocation.y, 0.0f, 0.0f);
    CGRect windowDraggingLocation = [outlineView.window convertRectFromScreen:screenDraggingLocation];
    CGPoint convertedDraggingLocation = [outlineView.superview convertPoint:windowDraggingLocation.origin
                                                                   fromView:nil];
    [session enumerateDraggingItemsWithOptions:0
                                       forView:outlineView
                                       classes:@[[GNEOutlineViewItem class]]
                                 searchOptions:nil
                                    usingBlock:^(NSDraggingItem *draggingItem,
                                                 NSInteger idx,
                                                 BOOL *stop __unused)
    {
        GNEOutlineViewItem *item = draggingItem.item;
        NSInteger column = [outlineView columnWithIdentifier:kOutlineViewStandardColumnIdentifier];
        NSInteger row = item.draggedRow;
        
        if ([item isKindOfClass:[GNEOutlineViewItem class]] && column >= 0 && row >= 0)
        {
            NSTableCellView *cellView = [outlineView viewAtColumn:column row:row makeIfNecessary:NO];
            draggingItem.imageComponentsProvider = ^ NSArray * ()
            {
                return cellView.draggingImageComponents;
            };
            CGRect draggingFrame = draggingItem.draggingFrame;
            // Center the cell over the cursor.
            CGFloat originY = ceil(convertedDraggingLocation.y + (cellView.bounds.size.height / 2.0));
            // Stack the dragging items on top of each other.
            originY += ceil(idx * cellView.bounds.size.height);
            draggingFrame.origin.y = originY;
            
            draggingItem.draggingFrame = draggingFrame;
        }
    }];
}


- (NSDragOperation)outlineView:(NSOutlineView * __unused)outlineView
                  validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(GNEOutlineViewItem *)proposedParentItem
            proposedChildIndex:(NSInteger)proposedChildIndex
{
    // If both sections and rows are selected, the drop is invalid.
    if ([self p_isDraggingSectionsAndRows:info])
    {
        return NSDragOperationNone;
    }
    
    // Don't allow items to be dragged "on" rows.
    if (proposedParentItem &&
        ([proposedParentItem isKindOfClass:[GNEOutlineViewParentItem class]] == NO))
    {
        return NSDragOperationNone;
    }
    
    NSDragOperation dragOperation = NSDragOperationNone;
    
    if (proposedParentItem == nil)
    {
        dragOperation = [self p_dragOperationForDrop:info
                                   toProposedSection:(NSUInteger)proposedChildIndex];
    }
    else
    {
        NSUInteger toSection = [self p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)proposedParentItem];
        NSIndexPath *toIndexPath = [NSIndexPath gne_indexPathForRow:(NSUInteger)proposedChildIndex
                                                          inSection:toSection];
        dragOperation = [self p_dragOperationForDrop:info toProposedIndexPath:toIndexPath];
    }
    
    return dragOperation;
}


- (BOOL)outlineView:(NSOutlineView * __unused)outlineView
         acceptDrop:(id<NSDraggingInfo>)info
               item:(GNEOutlineViewItem * __unused)proposedParentItem
         childIndex:(NSInteger)proposedChildIndex
{
    NSMutableIndexSet *fromSections = [NSMutableIndexSet indexSet];
    NSMutableArray *fromIndexPaths = [NSMutableArray array];
    
    __weak typeof(self) weakSelf = self;
    [info enumerateDraggingItemsWithOptions:0
                                    forView:self
                                    classes:@[[GNEOutlineViewItem class]]
                              searchOptions:0
                                 usingBlock:^(NSDraggingItem *draggingItem,
                                              NSInteger idx __unused,
                                              BOOL *stop __unused)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        GNEOutlineViewItem *draggedItem = [strongSelf p_draggedItemForDraggingItem:draggingItem];
        
        if (draggedItem)
        {
            GNEOutlineViewParentItem *parentItem = draggedItem.parentItem;
            if (parentItem == nil)
            {
                NSUInteger section = [self p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)draggedItem];
                [fromSections addIndex:section];
            }
            else
            {
                NSIndexPath *indexPath = [self p_indexPathOfOutlineViewItem:draggedItem];
                [fromIndexPaths addObject:indexPath];
            }
        }
    }];
    
    [self beginUpdates];
    if (proposedParentItem == nil) // Move items to the specified section.
    {
        SEL sectionSelector = @selector(tableView:didDragSections:toSection:);
        if ([self.tableViewDataSource respondsToSelector:sectionSelector])
        {
            [self.tableViewDataSource tableView:self
                                didDragSections:fromSections
                                      toSection:(NSUInteger)proposedChildIndex];
        }
        
        SEL rowSelector = @selector(tableView:didDragRowsAtIndexPaths:toSection:);
        if ([self.tableViewDataSource respondsToSelector:rowSelector])
        {
            [self.tableViewDataSource tableView:self
                        didDragRowsAtIndexPaths:fromIndexPaths
                                      toSection:(NSUInteger)proposedChildIndex];
        }
    }
    else // Calculate the destination index path and move the items there.
    {
        NSParameterAssert([proposedParentItem isKindOfClass:[GNEOutlineViewParentItem class]]);
        
        NSUInteger toSection = [self p_sectionForOutlineViewParentItem:(GNEOutlineViewParentItem *)proposedParentItem];
        NSIndexPath *toIndexPath = [NSIndexPath gne_indexPathForRow:(NSUInteger)proposedChildIndex
                                                          inSection:toSection];
        
        SEL rowSelector = @selector(tableView:didDragRowsAtIndexPaths:toIndexPath:);
        if ([self.tableViewDataSource respondsToSelector:rowSelector])
        {
            [self.tableViewDataSource tableView:self
                        didDragRowsAtIndexPaths:fromIndexPaths
                                    toIndexPath:toIndexPath];
        }
    }
    [self endUpdates];
    
    return YES;
}


- (void)outlineView:(NSOutlineView * __unused)outlineView
    draggingSession:(NSDraggingSession * __unused)session
       endedAtPoint:(NSPoint __unused)screenPoint
          operation:(NSDragOperation __unused)operation
{
    
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSDraggingSource
// ------------------------------------------------------------------------------------------
- (void)draggingSession:(NSDraggingSession * __unused)session
           movedToPoint:(NSPoint __unused)screenPoint
{
    
}


// ------------------------------------------------------------------------------------------
#pragma mark - GNEOutlineViewItemPasteboardWritingDelegate
// ------------------------------------------------------------------------------------------
- (NSInteger)rowForOutlineViewItem:(GNEOutlineViewItem *)item
{
    if (item)
    {
        return [self rowForItem:item];
    }
    
    return -1;
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSOutlineView - Table Columns
// ------------------------------------------------------------------------------------------
- (void)p_sizeStandardTableColumnToFit
{
    NSTableColumn *standardColumn = nil;
    if ((standardColumn = [self tableColumnWithIdentifier:kOutlineViewStandardColumnIdentifier]))
    {
        [standardColumn setWidth:self.bounds.size.width];
    }
}


// ------------------------------------------------------------------------------------------
#pragma mark - GNESectionedTableView - Accessors
// ------------------------------------------------------------------------------------------
- (void)setTableViewDataSource:(id<GNESectionedTableViewDataSource>)tableViewDataSource
{
    NSParameterAssert(tableViewDataSource == nil ||
                      [tableViewDataSource conformsToProtocol:@protocol(GNESectionedTableViewDataSource)]);
    
    if (_tableViewDataSource != tableViewDataSource)
    {
        _tableViewDataSource = tableViewDataSource;
        
        [self reloadData];
    }
}


- (void)setTableViewDelegate:(id<GNESectionedTableViewDelegate>)tableViewDelegate
{
    NSParameterAssert(tableViewDelegate == nil ||
                      [tableViewDelegate conformsToProtocol:@protocol(GNESectionedTableViewDelegate)]);
    
    if (_tableViewDelegate != tableViewDelegate)
    {
        _tableViewDelegate = tableViewDelegate;
        
        [self p_registerForDraggedTypes];
        [self reloadData];
    }
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSOutlineView - Accessors
// ------------------------------------------------------------------------------------------
- (id <NSOutlineViewDataSource>)dataSource
{
    return self;
}


- (void)setDataSource:(id<NSOutlineViewDataSource> __unused)aSource
{
    [super setDataSource:self];
}


- (id <NSOutlineViewDelegate>)delegate
{
    return self;
}


- (void)setDelegate:(id<NSOutlineViewDelegate> __unused)anObject
{
    [super setDelegate:self];
}



@end