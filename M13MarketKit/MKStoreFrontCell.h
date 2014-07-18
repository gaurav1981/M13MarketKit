//
//  MKStoreFrontCell.h
//  M13MarketKit
/*
 Copyright (c) 2014 Brandon McQuilkin
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <UIKit/UIKit.h>
@class MKProduct;
@class M13ProgressViewBar;
@class MKStoreFrontCell;

@protocol MKStoreFrontCellDelegate <NSObject>

/**Notifies the delegate that the height of the specified cell needs to change.*/
- (void)updateHeightForCell:(MKStoreFrontCell *)cell;

@end



@interface MKStoreFrontCell : UITableViewCell

/**The product the cell is displaying information for.*/
@property (nonatomic, strong) MKProduct *product;
/**The label that displays the product name.*/
@property (nonatomic, strong) UILabel *productNameLabel;
/**The label that displays the product price.*/
@property (nonatomic, strong) UILabel *productPriceLabel;
/**The progress view displayed when downloading*/
@property (nonatomic, strong) M13ProgressViewBar *progressView;
/**The object that reponds to the delegate methods.*/
@property (nonatomic, strong) id <MKStoreFrontCellDelegate> delegate;

@end
