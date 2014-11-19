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

@class GNEOutlineViewItem;
@class GNEOutlineViewParentItem;


// ------------------------------------------------------------------------------------------


extern NSString * const GNEOutlineViewItemPasteboardType;

extern NSString * const GNEOutlineViewItemParentItemKey;


// ------------------------------------------------------------------------------------------


@protocol GNEOutlineViewItemPasteboardWritingDelegate <NSObject>


- (NSInteger)rowForOutlineViewItem:(GNEOutlineViewItem *)item;


@end


// ------------------------------------------------------------------------------------------


@interface GNEOutlineViewItem : NSObject <NSCoding, NSPasteboardReading, NSPasteboardWriting>


@property (nonatomic, weak) id <GNEOutlineViewItemPasteboardWritingDelegate> pasteboardWritingDelegate;


/**
 Parent item of this object.
 */
@property (nonatomic, weak) GNEOutlineViewParentItem *parentItem;


/**
 Returns the outline view row of the receiver if it is being dragged, otherwise -1.
 */
@property (nonatomic, assign, readonly) NSInteger draggedRow;


/**
 Default initializer. The parent item points to this object's parent item. This reference must be kept up-to-date.
 
 @param parentItem Parent item of this object.
 @return Instance of WLOutlineViewItem or one of its subclasses.
 */
- (instancetype)initWithParentItem:(GNEOutlineViewParentItem *)parentItem;


@end