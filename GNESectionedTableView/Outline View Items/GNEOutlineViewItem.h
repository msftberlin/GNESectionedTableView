//
//  GNEOutlineViewItem.h
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

@import Cocoa;

@class GNEOutlineViewItem;
@class GNEOutlineViewParentItem;

// ------------------------------------------------------------------------------------------

extern NSString  * _Nonnull  const GNEOutlineViewItemPasteboardType;
extern NSString  * _Nonnull  const GNEOutlineViewItemParentItemKey;

// ------------------------------------------------------------------------------------------

@protocol GNEOutlineViewItemPasteboardWritingDelegate <NSObject>

- (NSIndexPath * _Nullable)draggedIndexPathForOutlineViewItem:(GNEOutlineViewItem * _Nonnull)item;

@end

// ------------------------------------------------------------------------------------------

@interface GNEOutlineViewItem : NSObject <NSSecureCoding, NSPasteboardReading, NSPasteboardWriting>

@property (nonatomic, weak) id <GNEOutlineViewItemPasteboardWritingDelegate> _Nullable pasteboardWritingDelegate;

/// Parent item of this object.
@property (nonatomic, weak) GNEOutlineViewParentItem * _Nullable parentItem;

/// Index path of the receiver if it is being dragged, otherwise nil.
@property (nullable, nonatomic, strong, readonly) NSIndexPath *draggedIndexPath;

- (nonnull instancetype)initWithParentItem:(GNEOutlineViewParentItem * _Nullable)parentItem NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@end
