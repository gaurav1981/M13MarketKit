//
//  MKStoreFrontCell.m
//  M13MarketKit
/*
 Copyright (c) 2014 Brandon McQuilkin
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MKStoreFrontCell.h"
#import "MKMarket.h"
#import "MKProduct.h"
#import <M13ProgressSuite/M13ProgressViewBar.h>
#import <StoreKit/StoreKit.h>

@implementation MKStoreFrontCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        self.contentView.clipsToBounds = YES;
        
        _productNameLabel = [[UILabel alloc] init];
        _productNameLabel.font = [UIFont systemFontOfSize:18.0];
        [self.contentView addSubview:_productNameLabel];
        
        _productPriceLabel = [[UILabel alloc] init];
        _productPriceLabel.font = [UIFont systemFontOfSize:12.0];
        _productPriceLabel.textColor = [UIColor grayColor];
        [self.contentView addSubview:_productPriceLabel];
        
        _progressView = [[M13ProgressViewBar alloc] init];
        _progressView.progressBarThickness = 2.0;
        _progressView.showPercentage = NO;
        [self.contentView addSubview:_progressView];
        _progressView.hidden = YES;
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    //[super setSelected:selected animated:animated];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.contentView.bounds;
    _productNameLabel.frame = CGRectMake(20.0, 5.0, bounds.size.width - 40.0, 20.0);
    _productPriceLabel.frame = CGRectMake(20.0, 30.0, bounds.size.width - 40.0, 15.0);
    _progressView.frame = CGRectMake(20.0, 36.0, bounds.size.width - 40.0, 2.0);
}

- (void)setProduct:(MKProduct *)product
{
    //Remove old observer
    if (_product) {
        [_product removeObserver:self forKeyPath:@"instalationProgress"];
        [_product removeObserver:self forKeyPath:@"purchaseInProgress"];
        [_product removeObserver:self forKeyPath:@"purchaseDeferred"];
        [_product removeObserver:self forKeyPath:@"installing"];
    }
    
    _product = product;
    //Name
    _productNameLabel.text = product.skProduct.localizedTitle;
    //price label
    
    if (_product.state == MKProductStateAvailableToPurchase) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterCurrencyStyle;
        formatter.locale = _product.skProduct.priceLocale;
        _productPriceLabel.text = [formatter stringFromNumber:_product.skProduct.price];
    } else if (_product.state == MKProductStateNotAvailable) {
        _productPriceLabel.text = @"Not Available";
    } else if (_product.state == MKProductStateNotAvailableDueToMinimumApplicationVersion) {
        _productPriceLabel.text = [NSString stringWithFormat:@"Please update %@ to download.", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]];
    } else if (_product.state == MKProductStatePurchaseDeferred) {
        _productPriceLabel.text = @"Waiting for approval.";
    } else if (_product.state == MKProductStatePurchasedNeedsUpdate) {
        _productPriceLabel.text = @"Update";
    } else if (_product.state == MKProductStatePurchasedNotInstalled) {
        _productPriceLabel.text = @"Download";
    } else if (_product.state == MKProductStatePurchasedUpToDate) {
        _productPriceLabel.text = @"Redownload";
    } else if (_product.state == MKProductStatePurchaseInProgress) {
        _productPriceLabel.text = @"Purchasing";
    }
    
    //Progress
    [_progressView setProgress:0.0 animated:NO];
    
    //Updates
    [_product addObserver:self forKeyPath:@"instalationProgress" options:NSKeyValueObservingOptionNew context:nil];
    [_product addObserver:self forKeyPath:@"purchaseInProgress" options:NSKeyValueObservingOptionNew context:nil];
    [_product addObserver:self forKeyPath:@"purchaseDeferred" options:NSKeyValueObservingOptionNew context:nil];
    [_product addObserver:self forKeyPath:@"installing" options:NSKeyValueObservingOptionNew context:nil];
    
    //Accessory
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    if (_product.state == MKProductStateAvailableToPurchase) {
        [button setImage:[[UIImage imageNamed:@"PurchaseIcon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(purchaseProduct:) forControlEvents:UIControlEventTouchUpInside];
        
    } else if (_product.state == MKProductStatePurchaseDeferred) {
        [button setImage:[[UIImage imageNamed:@"PurchaseIcon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        button.enabled = NO;
        [button addTarget:self action:@selector(purchaseProduct:) forControlEvents:UIControlEventTouchUpInside];
        
    } else if (_product.state == MKProductStatePurchasedNeedsUpdate) {
        [button setImage:[[UIImage imageNamed:@"UpdateIcon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(update) forControlEvents:UIControlEventTouchUpInside];
        
    } else if (_product.state == MKProductStatePurchasedNotInstalled) {
        [button setImage:[[UIImage imageNamed:@"PurchasedIcon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(update) forControlEvents:UIControlEventTouchUpInside];
        
    } else if (_product.state == MKProductStatePurchasedUpToDate) {
        [button setImage:[[UIImage imageNamed:@"PurchasedIcon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(update) forControlEvents:UIControlEventTouchUpInside];
    } else if (_product.state == MKProductStatePurchaseInProgress) {
        [button setImage:[[UIImage imageNamed:@"PurchasedIcon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        button.enabled = NO;
        [button addTarget:self action:@selector(update) forControlEvents:UIControlEventTouchUpInside];
    }
    
    button.frame = CGRectMake(0, 0, 30.0, 30.0);
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.accessoryView = button;
    
    [self setNeedsDisplay];
}

- (void)dealloc
{
    [_product removeObserver:self forKeyPath:@"instalationProgress"];
    [_product removeObserver:self forKeyPath:@"purchaseInProgress"];
    [_product removeObserver:self forKeyPath:@"purchaseDeferred"];
    [_product removeObserver:self forKeyPath:@"installing"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"instalationProgress"]) {
        if (_product.instalationProgress <= 1.0) {
            if (_progressView.indeterminate) {
                [_progressView setIndeterminate:NO];
            }
            [_progressView setProgress:_product.instalationProgress animated:YES];
        } else {
            [_progressView setIndeterminate:YES];
        }
    } else if ([keyPath isEqualToString:@"purchaseInProgress"] || [keyPath isEqualToString:@"purchaseDeferred"] || [keyPath isEqualToString:@"installing"]) {
        //Need to reset the cell looks.
        if (_product.installing) {
            _progressView.hidden = NO;
            _productPriceLabel.hidden = YES;
            ((UIButton *)self.accessoryView).enabled = NO;
        } else {
            _progressView.hidden = YES;
            _productPriceLabel.hidden = NO;
            ((UIButton *)self.accessoryView).enabled = YES;
        }
        
        self.product = _product;
        
        if ([_delegate respondsToSelector:@selector(updateHeightForCell:)]) {
            [_delegate updateHeightForCell:self];
        }
    }
}

- (void)purchase
{
    [[MKMarket sharedMarket] purchaseProduct:_product];
}

- (void)update
{
    [[MKMarket sharedMarket] provideContentForProduct:_product];
}

@end
