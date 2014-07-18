//
//  MKProduct.m
//  M13MarketKit
/*
 Copyright (c) 2014 Brandon McQuilkin
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MKProduct.h"
#import "MKReceiptValidator.h"

@interface MKProduct ()
/**Wether or not the application supports the product.*/
@property (nonatomic, assign, readonly) BOOL supported;
/**Wether or not the product has been purchased.*/
@property (nonatomic, assign, readonly) BOOL isPurchased;
/**Wether or not the product is installed*/
@property (nonatomic, assign, readonly) BOOL isInstalled;
/**Wether or not the product installed is up to date.*/
@property (nonatomic, assign, readonly) BOOL isUpToDate;
/**The receipt for the product.*/
@property (nonatomic, strong, readonly) MKInAppPurchaseReceipt *receipt;

@end

@implementation MKProduct

- (instancetype)initWithProductInformation:(NSDictionary *)info
{
    self = [super init];
    if (self) {
        _identifier = info[kMKProductIdentifierKey];
        _type = (MKProductType)((NSNumber *)info[kMKProductTypeKey]).integerValue;
        _version = info[kMKProductVersionKey];
        _minimumApplicationVersion = info[kMKProductMinimumApplicationVersionKey];
        _contentURL = [NSURL URLWithString:info[kMKProductContentURLKey]];
        _availableForPurchase = ((NSNumber *)info[kMKProductAvailableForPurchaseKey]).boolValue;
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        _date = [formatter dateFromString:info[kMKProductDateKey]];
        _iconURL = [NSURL URLWithString:info[kMKProductIconURLKey]];
        _otherProperties = info[kMKProductOtherPropertiesKey];
        [self refreshProductProperties];
    }
    return self;
}

- (void)refreshProductProperties
{
    //Check the minimum application version.
    NSString *productVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if ([self compareVersionString:_minimumApplicationVersion toString:productVersion] == NSOrderedSame || [self compareVersionString:_minimumApplicationVersion toString:productVersion] == NSOrderedDescending) {
        _supported = YES;
    } else {
        _supported = NO;
    }
    
    //Check to see if the product is installed.
    if ([_delegate respondsToSelector:@selector(productInstalled:)]) {
        _isInstalled = [_delegate productInstalled:self];
    }
    
    if (_isInstalled && [_delegate respondsToSelector:@selector(versionOfInstalledProduct:)]) {
        NSString *installedVersion = [_delegate versionOfInstalledProduct:self];
        
        if ([self compareVersionString:self.version toString:installedVersion] == NSOrderedSame) {
            _isUpToDate = YES;
        } else {
            _isUpToDate = NO;
        }
    }
    
    //Check for a receipt
    [[MKReceiptValidator sharedValidator] validateReceiptWithCompletion:^(BOOL validAppReceipt, MKApplicationReceipt *receipt, NSError *error) {
        if (validAppReceipt && receipt) {
            for (MKInAppPurchaseReceipt *iapReceipt in receipt.inAppPurchaseReceipts) {
                if ([iapReceipt.productIdentifier isEqualToString:_identifier]) {
                    _receipt = iapReceipt;
                    _isPurchased = YES;
                }
            }
        }
        if ([_delegate respondsToSelector:@selector(productInformationUpdated:)]) {
            [_delegate productInformationUpdated:self];
        }
    } forceRefresh:NO];
}

- (NSComparisonResult)compareVersionString:(NSString *)string1 toString:(NSString *)string2
{
    //Compares two version strings by components.
    NSArray *array1 = [string1 componentsSeparatedByString:@"."];
    NSArray *array2 = [string2 componentsSeparatedByString:@"."];
    
    int max = (int)MIN(array1.count, array2.count);
    for (int i = 0; i < max; i++) {
        NSString *unit1 = array1[i];
        NSString *unit2 = array2[i];
        
        if (unit1.intValue == unit2.intValue) {
            continue;
        } else if (unit1 < unit2) {
            return NSOrderedAscending;
        } else {
            return NSOrderedDescending;
        }
    }
    
    return NSOrderedSame;
}

- (MKProductState)state
{
    //Supported?
    if (!_supported) {
        return MKProductStateNotAvailableDueToMinimumApplicationVersion;
    }
    
    //Purchase in progress
    if (_purchaseDeferred) {
        return MKProductStatePurchaseDeferred;
    }
    
    if (_purchaseInProgress) {
        return MKProductStatePurchaseInProgress;
    }
    
    //Available
    if (_availableForPurchase && _skProduct && !_isPurchased) {
        return MKProductStateAvailableToPurchase;
    }
    
    //Was the purchased canceled by apple?
    if (_receipt.cancelationDate) {
        if ([[NSDate date] compare:_receipt.cancelationDate] == NSOrderedDescending) {
            return MKProductStateAvailableToPurchase;
        }
    }
    
    //Purchased
    if (_isPurchased && _isInstalled && _isUpToDate && _receipt) {
        return MKProductStatePurchasedUpToDate;
    } else if (_isPurchased && _isInstalled && _receipt) {
        return MKProductStatePurchasedNeedsUpdate;
    } else if (_isPurchased && _receipt) {
        return MKProductStatePurchasedNotInstalled;
    }
    
    return MKProductStateNotAvailable;
}



@end
