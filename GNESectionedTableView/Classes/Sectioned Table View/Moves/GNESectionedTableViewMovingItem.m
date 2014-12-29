//
//  GNESectionedTableViewMovingItem.m
//  GNESectionedTableView
//
//  Created by Anthony Drendel on 12/22/14.
//  Copyright (c) 2014 Gone East LLC. All rights reserved.
//

#import "GNESectionedTableViewMovingItem.h"
#import "GNESectionedTableView.h"


// ------------------------------------------------------------------------------------------


@interface GNESectionedTableViewMovingItem ()

@property (nonatomic, strong) NSImageView *imageView;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, copy, readwrite) NSIndexPath *indexPath;

@end


// ------------------------------------------------------------------------------------------


@implementation GNESectionedTableViewMovingItem


// ------------------------------------------------------------------------------------------
#pragma mark - Initialization
// ------------------------------------------------------------------------------------------
- (instancetype)initWithTableCellView:(NSTableCellView *)cellView
                                frame:(CGRect)frame
                            indexPath:(NSIndexPath *)indexPath
{
    GNEParameterAssert(cellView);
    GNEParameterAssert(indexPath);
    
    if (cellView == nil || indexPath == nil)
    {
        return nil;
    }
    
    if ((self = [super init]))
    {
        _imageView = [self p_imageViewWithTableCellView:cellView frame:frame];
        _frame = frame;
        _indexPath = [indexPath copy];
    }
    
    return self;
}


- (instancetype)initForSectionWithTableCellViews:(NSArray *)cellViews
                                           frame:(CGRect)frame
                                 headerIndexPath:(NSIndexPath *)indexPath
{
    GNEParameterAssert(cellViews.count > 0);
    GNEParameterAssert(indexPath);
    
    if (cellViews.count == 0 || indexPath == nil)
    {
        return nil;
    }
    
    if ((self = [super init]))
    {
        _imageView = [self p_imageViewWithTableCellViews:cellViews frame:frame];
        _frame = frame;
        _indexPath = [indexPath copy];
    }
    
    return self;
}


// ------------------------------------------------------------------------------------------
#pragma mark - NSObject - Compare
// ------------------------------------------------------------------------------------------
- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[GNESectionedTableViewMovingItem class]])
    {
        return [self isEqualToDraggingItem:(GNESectionedTableViewMovingItem *)object];
    }
    
    return NO;
}


- (BOOL)isEqualToDraggingItem:(GNESectionedTableViewMovingItem *)otherDraggingItem
{
    return (self.indexPath && otherDraggingItem.indexPath &&
            [self.indexPath compare:otherDraggingItem.indexPath] == NSOrderedSame);
}


// ------------------------------------------------------------------------------------------
#pragma mark - Private - Image View
// ------------------------------------------------------------------------------------------
- (NSImageView *)p_imageViewWithTableCellView:(NSTableCellView *)cellView
                                        frame:(CGRect)frame
{
    GNEParameterAssert(CGSizeEqualToSize(cellView.bounds.size, frame.size));
    
    NSImage *image = [self p_imageForCellView:cellView];
    
    NSImageView *imageView = [[NSImageView alloc] initWithFrame:frame];
    imageView.wantsLayer = YES;
    imageView.image = image;
    
    return imageView;
}


- (NSImageView *)p_imageViewWithTableCellViews:(NSArray *)cellViews frame:(CGRect)frame
{
#if DEBUG
    {
        CGRect unionRect = CGRectZero;
        CGFloat originYOffset = 0.0f;
        
        for (NSTableCellView *cellView in cellViews)
        {
            CGRect cellViewFrame = cellView.bounds;
            cellViewFrame.origin.y = originYOffset;
            unionRect = CGRectUnion(unionRect, cellViewFrame);

            originYOffset += cellViewFrame.size.height;
        }
        
        GNEParameterAssert(CGSizeEqualToSize(frame.size, unionRect.size));
    }
#endif
    
    NSMutableArray *cellViewImages = [NSMutableArray array];
    for (NSTableCellView *cellView in cellViews)
    {
        NSImage *cellViewImage = [self p_imageForCellView:cellView];
        if (cellViewImage)
        {
            [cellViewImages addObject:cellViewImage];
        }
    }
    
    
    NSImage *image = [NSImage imageWithSize:frame.size flipped:YES drawingHandler:^BOOL(NSRect dstRect)
    {
        CGFloat originYOffset = 0.0f;
        
        for (NSImage *cellViewImage in cellViewImages)
        {
            CGRect cellViewImageFrame = CGRectMake(dstRect.origin.x,
                                                   dstRect.origin.y + originYOffset,
                                                   cellViewImage.size.width,
                                                   cellViewImage.size.height);
            
            [cellViewImage drawInRect:cellViewImageFrame];
            
            originYOffset += cellViewImage.size.height;
        }
        
        return YES;
    }];
    
    NSImageView *imageView = [[NSImageView alloc] initWithFrame:frame];
    imageView.wantsLayer = YES;
    imageView.image = image;
    
    return imageView;
}


- (NSImage *)p_imageForCellView:(NSTableCellView *)cellView
{
    CGRect bounds = cellView.bounds;
    CGSize size = bounds.size;
    NSBitmapImageRep *imageRep = [cellView bitmapImageRepForCachingDisplayInRect:bounds];
    imageRep.size = size;
    [cellView cacheDisplayInRect:bounds toBitmapImageRep:imageRep];
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image addRepresentation:imageRep];
    
    return image;
}


// ------------------------------------------------------------------------------------------
#pragma mark - Accessors
// ------------------------------------------------------------------------------------------
- (NSView *)view
{
    return (NSView *)self.imageView;
}


@end
