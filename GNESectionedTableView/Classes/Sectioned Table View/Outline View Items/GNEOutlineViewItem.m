//
//  GNEOutlineViewItem.m
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

#import "GNEOutlineViewItem.h"
#import "GNEOutlineViewParentItem.h"


// ------------------------------------------------------------------------------------------


NSString * const GNEOutlineViewItemPasteboardType = @"com.goneeast.GNEOutlineViewItemPasteboardType";

NSString * const GNEOutlineViewItemParentItemKey = @"GNEOutlineViewItemParentItem";
static NSString * const GNEOutlineViewItemDraggedRowKey = @"GNEOutlineViewItemDraggedRowKey";


// ------------------------------------------------------------------------------------------


@implementation GNEOutlineViewItem


// ------------------------------------------------------------------------------------------
#pragma mark - Initialization
// ------------------------------------------------------------------------------------------
- (instancetype)initWithParentItem:(GNEOutlineViewParentItem *)parentItem
{
    if ((self = [super init]))
    {
        _parentItem = parentItem; // Don't use accessor here because it may be nil (GNEOutlineViewParentItem).
        _draggedRow = -1;
    }
    
    return self;
}


// ------------------------------------------------------------------------------------------
#pragma mark - Dealloc
// ------------------------------------------------------------------------------------------
- (void)dealloc
{
    _pasteboardWritingDelegate = nil;
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSCoding
// ------------------------------------------------------------------------------------------
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super init]))
    {
        _parentItem = [aDecoder decodeObjectForKey:GNEOutlineViewItemParentItemKey];
        NSNumber *rowNumber = [aDecoder decodeObjectForKey:GNEOutlineViewItemDraggedRowKey];
        _draggedRow = (rowNumber) ? [rowNumber integerValue] : -1;
    }
    
    return self;
}


- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.parentItem forKey:GNEOutlineViewItemParentItemKey];
    id <GNEOutlineViewItemPasteboardWritingDelegate> delegate = self.pasteboardWritingDelegate;
    if ([delegate respondsToSelector:@selector(rowForOutlineViewItem:)])
    {
        NSInteger row = [delegate rowForOutlineViewItem:self];
        [aCoder encodeObject:@(row) forKey:GNEOutlineViewItemDraggedRowKey];
    }
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSPasteboardReader
// ------------------------------------------------------------------------------------------
- (instancetype)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type
{
    if ([type isEqualToString:GNEOutlineViewItemPasteboardType])
    {
        return [NSKeyedUnarchiver unarchiveObjectWithData:propertyList];
    }
    
    return nil;
}


+ (NSArray *)readableTypesForPasteboard:(NSPasteboard * __unused)pasteboard
{
    return @[GNEOutlineViewItemPasteboardType];
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSPasteboardWriter
// ------------------------------------------------------------------------------------------
- (NSArray *)writableTypesForPasteboard:(NSPasteboard * __unused)pasteboard
{
    return @[GNEOutlineViewItemPasteboardType];
}


- (id)pasteboardPropertyListForType:(NSString *)type
{
    if ([type isEqualToString:GNEOutlineViewItemPasteboardType])
    {
        NSData *plistData = [NSKeyedArchiver archivedDataWithRootObject:self];
        
        return plistData;
    }
    
    return nil;
}


// ------------------------------------------------------------------------------------------
#pragma mark - Description
// ------------------------------------------------------------------------------------------
- (NSString *)description
{
    return [NSString
            stringWithFormat:@"<%@: %p> Parent: %@", [self className], self, self.parentItem];
}


// ------------------------------------------------------------------------------------------
#pragma mark - Equality
// ------------------------------------------------------------------------------------------
- (BOOL)isEqual:(id)object
{
    return (self == object);
}


- (NSUInteger)hash
{
    return (NSUInteger)self;
}


// ------------------------------------------------------------------------------------------
#pragma mark - Accessors
// ------------------------------------------------------------------------------------------
- (void)setParentItem:(GNEOutlineViewParentItem *)parentItem
{
    NSParameterAssert(parentItem);
    
    if (_parentItem != parentItem)
    {
        _parentItem = parentItem;
    }
}


@end