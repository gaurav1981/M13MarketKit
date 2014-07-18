//
//  MKReceiptValidator.h
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

@class MKApplicationReceipt;

/**The completion block that returns when the receipt if verified.
 @param validAppReceipt Wether or not the application receipt is valid.
 @param receipt The receipt of the application. Access the in app purchase receipts property to 
 @param error The error object if there is an error.
 */
typedef void (^ReceiptValidationCompletionBlock)(BOOL validAppReceipt, MKApplicationReceipt *receipt, NSError *error);

//Error Codes
#define kMKReceiptValidationErrorCodeNoReceipt 1
#define kMKReceiptValidationErrorCodeInvalidBundleIdentifier 2
#define kMKReceiptValidationErrorCodeInvalidVersion 3
#define kMKReceiptValidationErrorCodeFailure 10

/**The object that represents the receipt of the application*/
@interface MKApplicationReceipt : NSObject
/**@name Initalization*/
/** Initalizes a receipt with the given receipt information.
 @param information The information to initalize the receipt with.
 @return A new receipt object.
 */
- (instancetype)initWithInformation:(NSDictionary *)information;

/**@name Properties*/
/**The app’s bundle identifier.*/
@property (nonatomic, strong, readonly) NSString *bundleIdentifier;
/**The app's bundle identifier in data form.*/
@property (nonatomic, strong, readonly) NSData *bundleIdentifierData;
/**The app’s version number.*/
@property (nonatomic, strong, readonly) NSString *applicationVersion;
/**An opaque value used, with other data, to compute the SHA-1 hash during validation.*/
@property (nonatomic, strong, readonly) NSData *opaqueValue;
/**A SHA-1 hash, used to validate the receipt.*/
@property (nonatomic, strong, readonly) NSData *sha1Hash;
/**The array of receipts for in-app purchases.*/
@property (nonatomic, strong, readonly) NSArray *inAppPurchaseReceipts;
/**The version of the app that was originally purchased.*/
@property (nonatomic, strong, readonly) NSString *originalApplicationVersion;
/**The date that the app receipt expires.
 @note This key is present only for apps purchased through the Volume Purchase Program. If this key is not present, the receipt does not expire. When validating a receipt, compare this date to the current date to determine whether the receipt is expired. Do not try to use this date to calculate any other information, such as the time remaining before expiration.
 */
@property (nonatomic, strong, readonly) NSDate *receiptExpirationDate;
 
@end

/**The object that represents a receipt for an in app purchase.*/
@interface MKInAppPurchaseReceipt : NSObject
/**@name Initalization*/
/** Initalizes a receipt with the given receipt information.
 @param information The information to initalize the receipt with.
 @return A new receipt object.
 */
- (instancetype)initWithInformation:(NSDictionary *)information;

/**@name Properties*/
/**The number of items purchased.*/
@property (nonatomic, assign, readonly) NSUInteger quantity;
/**The product identifier of the item that was purchased.*/
@property (nonatomic, strong, readonly) NSString *productIdentifier;
/**The transaction identifier of the item that was purchased.*/
@property (nonatomic, strong, readonly) NSString *transactionIdentifier;
/**For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier.*/
@property (nonatomic, strong, readonly) NSString *originalTransactionIdentifier;
/**The date and time that the item was purchased.
 @note For a transaction that restores a previous transaction, the purchase date is the date of the restoration. Use “Original Purchase Date” to get the date of the original transaction. In an auto-renewable subscription receipt, this is always the date when the subscription was purchased or renewed, regardless of whether the transaction has been restored.
 */
@property (nonatomic, strong, readonly) NSDate *purchaseDate;
/**For a transaction that restores a previous transaction, the date of the original transaction.*/
@property (nonatomic, strong, readonly) NSDate *originalPurchaseDate;
/**The expiration date for the subscription.*/
@property (nonatomic, strong, readonly) NSDate *subscriptionExpirationDate;
/**For a transaction that was canceled by Apple customer support, the time and date of the cancellation.*/
@property (nonatomic, strong, readonly) NSDate *cancelationDate;
/**The primary key for identifying subscription purchases.*/
@property (nonatomic, assign, readonly) NSUInteger webOrderLineItemIdentifier;

@end

/**Validates app bundle receipts.*/
@interface MKReceiptValidator : NSObject

/**The shared instance of the validator.*/
+ (instancetype)sharedValidator;
/**Validate the receipt with the given completion.
 @param completion The completion block to run upon validation of the receipt.
 @param force Wether or not to force the application to revalidate the receipt.
 */
- (void)validateReceiptWithCompletion:(ReceiptValidationCompletionBlock)completion forceRefresh:(BOOL)force;

@end


