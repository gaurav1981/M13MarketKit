//
//  MKMarket.h
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
@protocol MKProductDelegate;
@class MKProduct;
@class SKPaymentTransaction;

/**Called whenever the product list changes.*/
#define kMKMarketProductListChangedNotification @"MKMarketUpdatedProductList"
/**Called when a product list refresh completes.*/
#define kMKMarketProductListUpdateFinishedNoification @"MKMarketFinishedUpdatingProductList"
/**Called when a product restore completes*/
#define kMKMarketCompletedRestoringTransactionsNotification @"MKMarketFinishedRestoringTransactions"

@protocol MKMarketDelegate <NSObject>

/**Asks the delegate wether or not the given product is installed.
 @note This is separated from MKProduct to allow custom install locations.
 @param product The product to check wheter or not it is installed.
 @return Wether or not the product is installed.*/
- (BOOL)productInstalled:(MKProduct *)product;
/**Asks the delegate for the version of the installed product.
 @param product The product to retreive the installed version of.
 @return The installed product version string.
 */
- (NSString *)versionOfInstalledProduct:(MKProduct *)product;
/**Asks the delegate for the path string to install the product to. The zip file containing the product will be unzipped into this location.
 @param product The product that will be installed.
 @return The path to unzip the product content to.
 */
- (NSString *)locationToInstallProduct:(MKProduct *)product;
/**If the download manager does not support installing the non-consumable product, the delegate needs to provide the content. This can also be called for a consumable product, it will be called when the consumable amount is not set for the product. (This allows one to use hard coded values instead.)
 @note One must call [[SKPaymentQueue defaultQueue] finishTransaction:transaction] once you provide the content. Otherwise the transaction will never be finished. You are also responsible for sending the notification to tell the table to refresh.
 @param product The product to provide the content for.
 */
- (void)provideContentForProduct:(MKProduct *)product transaction:(SKPaymentTransaction *)transaction;
@end

@interface MKMarket : NSObject

/**@name Initalization*/
/**Get the shared market
 @return The market.
 */
+ (instancetype)sharedMarket;

/**@name Properties*/
/**The market's delegate.*/
@property (nonatomic, strong) id <MKMarketDelegate> delegate;
/**The URL to the file that contains the product information.
 @note For the file format, see the example.*/
@property (nonatomic, strong) NSURL *productInformationFileURL;
/**All the products that were loaded from the product list.
 @note This does include products that were not validated by the prodyct request.
 */
@property (nonatomic, strong, readonly) NSDictionary *products;
/**All the products that the user has purchased.*/
@property (nonatomic, strong, readonly) NSDictionary *purchasedProducts;
/**All the products that are available to purchase.*/
@property (nonatomic, strong, readonly) NSDictionary *purchasableProducts;
/**The consumable identifiers and their coresponding values.*/
@property (nonatomic, strong, readonly) NSDictionary *consumableInventory;

/**@name Actions*/
/**Refresh the list of products.*/
- (void)refreshProductList;
/**Begin the purchase for a product.
 @param product The product to purchase.*/
- (void)purchaseProduct:(MKProduct *)product;
/**Restore the completed transactions.*/
- (void)restoreCompletedTransactions;
/**Provide the content for the given product.*/
- (void)provideContentForProduct:(MKProduct *)product;

/**@name Background Handling*/
/**To allow for background downloading, one must implement the UIApplication delegate protocol: `- (void)application:(UIApplication *)application
 handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler`. The delegate protocol can then call this method of MKMarket to respond to the download. If this is not implemented, backround downloading will not work, The product will never be installed.
 */
- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler;

@end
