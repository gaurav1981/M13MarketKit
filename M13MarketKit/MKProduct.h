//
//  MKProduct.h
//  M13MarketKit
/*
 Copyright (c) 2014 Brandon McQuilkin
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>

@class MKProduct;
@class SKProduct;

/** The type of product the MKProduct represents*/
typedef enum : NSUInteger {
    MKProductTypeConsumable,
    MKProductTypeNonConsumable,
    MKProductTypeAutoRenewableSubscription,
    MKProductTypeNonRenewableSubscription,
    MKProductTypeFreeSubscription
} MKProductType;

/**The current state of the MKProduct*/
typedef enum : NSUInteger {
    MKProductStateNotAvailable,
    MKProductStateNotAvailableDueToMinimumApplicationVersion,
    MKProductStateAvailableToPurchase,
    MKProductStatePurchaseDeferred,
    MKProductStatePurchaseInProgress,
    MKProductStatePurchasedNotInstalled,
    MKProductStatePurchasedUpToDate,
    MKProductStatePurchasedNeedsUpdate
} MKProductState;

#define kMKProductIdentifierKey @"identifier"
#define kMKProductTypeKey @"type"
#define kMKProductVersionKey @"version"
#define kMKProductMinimumApplicationVersionKey @"minimumApplicationVersion"
#define kMKProductContentURLKey @"contentURL"
#define kMKProductAvailableForPurchaseKey @"available"
#define kMKProductDateKey @"date"
#define kMKProductIconURLKey @"iconURL"
#define kMKProductOtherPropertiesKey @"other"

@protocol MKProductDelegate <NSObject>

/** Asks the delegate wether or not the given product is installed.
 @note This is separated from MKProduct to allow custom install locations.
 @param product The product to check wheter or not it is installed.
 @return Wether or not the product is installed.*/
- (BOOL)productInstalled:(MKProduct *)product;
/**Asks the delegate for the version of the installed product.
 @param product The product to retreive the installed version of.
 @return The installed product version string.
 */
- (NSString *)versionOfInstalledProduct:(MKProduct *)product;
/**Notifies the delegate that the product updated its information.
 @param The product that was updated.
 */
- (void)productInformationUpdated:(MKProduct *)product;

@end

/**
 An object that represents a single product in a store.
 */
@interface MKProduct : NSObject

/**@name Initalization*/
/**
 Create a new product with the given information dictionary.
 @param info The dictionary representing the product information.
 @return A new product.
*/
- (instancetype)initWithProductInformation:(NSDictionary *)info;

/**@name Delegate*/
/**The delegate that checks wether or not the product is installed.*/
@property (nonatomic, strong) id delegate;

/**@name Product Properties*/
/**The unique string representing the product.
 @note Must be of string type in json storage.
 */
@property (nonatomic, strong, readonly) NSString *identifier;
/**The type of product.
 @note Must be of integer type in json storage. (0 = Consumable, 1 = NonConsumable, 2 = AutoRenewSub, 3 = NonRenewSub, 4 = FreeSub)
 */
@property (nonatomic, assign, readonly) MKProductType type;
/**The current available version of the product.
 @note Must be of string type in json storage and in the form of "#.#.#".
 */
@property (nonatomic, assign, readonly) NSString *version;
/**The minimum application version that supports the product.
 @note Must be of string type in json storage abd in the form of "#.#.#".
 */
@property (nonatomic, strong, readonly) NSString *minimumApplicationVersion;
/**The URL location of the product content, if not contained in an SKDownload. Supports: http://, https://, and file://.
 @note Must be of string type in json storage.
 @note If a local file in the application bundle, the path must start with "file://bundle". "bundle" will get replaced with the bundle path.
 */
@property (nonatomic, strong, readonly) NSURL *contentURL;
/**Wether or not the item is available for purchase. (This is an override in case you need to block the product for a period of time.)
 @note Must be of BOOL type in json storage
 */
@property (nonatomic, assign, readonly) BOOL availableForPurchase;
/**The date associated with the product, usually the release date. (Mainly used for display/sorting purposes.)
 @note Must be of string type in json storage, use short date format.
 */
@property (nonatomic, strong, readonly) NSDate *date;
/**The URL location of the product icon. Supports: http://, https://, and file://.
 @note Must be of string type in json storage.
 */
@property (nonatomic, strong, readonly) NSURL *iconURL;
/**
 Allows one to store their own properties without subclassing everything. These properties will not be used in the purchasing process, but instead used for display purposes.
 */
@property (nonatomic, strong, readonly) NSDictionary *otherProperties;

/**@name Purchasing*/
/**The current state of the product.*/
@property (nonatomic, assign, readonly) MKProductState state;
/**The SKProduct for the product.*/
@property (nonatomic, strong) SKProduct *skProduct;
/**Wether or not a purchase in progress for the given product.*/
@property (nonatomic, assign) BOOL purchaseInProgress;
/**Wether or not the purchase is deferred.*/
@property (nonatomic, assign) BOOL purchaseDeferred;
/**Wether or not the product is currently being installed.*/
@property (nonatomic, assign) BOOL installing;
/**The progress of the instalation.
 @note The progress is from 0.0 - 1.0, the progress can also be float_max, this coresponds to the processing phase that is indeterminate.
 */
@property (nonatomic, assign) float instalationProgress;

/**
 Call this method to refresh the internal cached properties. This should be run on product purchase, deletion, and install.
 */
- (void)refreshProductProperties;


@end
 