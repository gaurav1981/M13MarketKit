//
//  MKReceiptValidator.m
//  M13MarketKit
/*
 Copyright (c) 2014 Brandon McQuilkin
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MKReceiptValidator.h"
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

#import <OpenSSL/pkcs7.h>
#import <OpenSSL/objects.h>
#import <OpenSSL/sha.h>
#import <OpenSSL/x509.h>
#import <OpenSSL/err.h>

//Bundle information
#define kBundleVersionConstant    @"4.0.0"
#define kBundleIdentifierConstant @"com.BrandonMcQuilkin.WhatsMyStageOn"

#define kM13MarketKitErrorDomain @"com.BrandonMcQuilkin.M13MarketKit"

// ASN.1 values for the App Store receipt
#define kBundleIdentifierField 2
#define kVersionField 3
#define kOpaqueValueField 4
#define kHashField 5
#define kInAppPurchasesField 17
#define kOriginalVersionField 19
#define kExpirationDateField 21

// ASN.1 values for In-App Purchase values
#define kIAPQuantityField                       1701
#define kIAPProductIdentifierField              1702
#define kIAPTransactionIdentifierField          1703
#define kIAPPurchaseDateField                   1704
#define kIAPOriginalTransactionIdentifierField	1705
#define kIAPOriginalPurchaseDateField           1706
#define kIAPSubscriptionExpirationDateField     1708
#define kIAPWebOrderLineItemIdentifierField     1711
#define kIAPCancelationDateField                1712

//Keys for the dictionaries
NSString *kApplicationReceiptBundleIdentifier		= @"BundleIdentifier";
NSString *kApplicationReceiptBundleIdentifierData	= @"BundleIdentifierData";
NSString *kApplicationReceiptVersion				= @"Version";
NSString *kApplicationReceiptOpaqueValue			= @"OpaqueValue";
NSString *kApplicationReceiptHash					= @"Hash";
NSString *kApplicationReceiptInApp					= @"InApp";
NSString *kApplicationReceiptOriginalVersion        = @"OrigVer";
NSString *kApplicationReceiptExpirationDate         = @"ExpDate";

NSString *kIAPReceiptQuantity                       = @"Quantity";
NSString *kIAPReceiptProductIdentifier              = @"ProductIdentifier";
NSString *kIAPReceiptTransactionIdentifier          = @"TransactionIdentifier";
NSString *kIAPReceiptPurchaseDate                   = @"PurchaseDate";
NSString *kIAPReceiptOriginalTransactionIdentifier  = @"OriginalTransactionIdentifier";
NSString *kIAPReceiptOriginalPurchaseDate           = @"OriginalPurchaseDate";
NSString *kIAPReceiptSubscriptionExpirationDate     = @"SubExpDate";
NSString *kIAPReceiptCancellationDate               = @"CancelDate";
NSString *kIAPReceiptWebOrderLineItemID             = @"WebItemId";

@interface NSDate (RFC3339)
/**Gives you the date from an RFC 3339 formatted string.*/
+ (NSDate *)dateFromRFC3339String:(NSString *)dateString;
@end

@implementation NSDate (RFC3339)

+ (NSDateFormatter *)internetDateTimeFormatter {
            NSLocale *en_US_POSIX = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            NSDateFormatter *internetDateTimeFormatter = [[NSDateFormatter alloc] init];
            [internetDateTimeFormatter setLocale:en_US_POSIX];
            [internetDateTimeFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    return internetDateTimeFormatter;
}

+ (NSDate *)dateFromRFC3339String:(NSString *)dateString
{
    // Keep dateString around a while (for thread-safety)
    NSDate *date = nil;
    if (dateString && dateString.length > 0) {
        NSDateFormatter *dateFormatter = [NSDate internetDateTimeFormatter];
        @synchronized(dateFormatter) {
            
            // Process date
            NSString *RFC3339String = [[NSString stringWithString:dateString] uppercaseString];
            RFC3339String = [RFC3339String stringByReplacingOccurrencesOfString:@"Z" withString:@"-0000"];
            // Remove colon in timezone as it breaks NSDateFormatter in iOS 4+.
            // - see https://devforums.apple.com/thread/45837
            if (RFC3339String.length > 20) {
                RFC3339String = [RFC3339String stringByReplacingOccurrencesOfString:@":"
                                                                         withString:@""
                                                                            options:0
                                                                              range:NSMakeRange(20, RFC3339String.length-20)];
            }
            if (!date) { // 1996-12-19T16:39:57-0800
                [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZ"];
                date = [dateFormatter dateFromString:RFC3339String];
            }
            if (!date) { // 1937-01-01T12:00:27.87+0020
                [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSSZZZ"];
                date = [dateFormatter dateFromString:RFC3339String];
            }
            if (!date) { // 1937-01-01T12:00:27
                [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss"];
                date = [dateFormatter dateFromString:RFC3339String];
            }
            if (!date) { //2014-06-16T20:18:04Z
                [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssZ"];
            }
            if (!date) NSLog(@"Could not parse RFC3339 date: \"%@\" Possible invalid format.", dateString);
            
        }
    }
    // Finished with date string
    return date;
}

@end



@interface MKReceiptValidator () <SKRequestDelegate>
/**The array of completion blocks to run upon validation of the receipt.*/
@property (nonatomic, strong, readonly) NSMutableArray *completionBlocks;
/**Wether or not the app receipt passed validation.*/
@property (nonatomic, assign, readonly) BOOL passedValidation;
/**The validated receipt.*/
@property (nonatomic, strong, readonly) MKApplicationReceipt *validatedReceipt;
/**Wether or not we began to refresh the receipt.*/
@property (nonatomic, assign, readonly) BOOL beganReceiptRefresh;
/**Wether or not we refreshed the receipt.*/
@property (nonatomic, assign, readonly) BOOL hasRefreshedReceipt;
/**The reqest to refresh the receipts*/
@property (nonatomic, strong, readonly) SKReceiptRefreshRequest *refreshRequest;

@end

@implementation MKReceiptValidator

+ (instancetype)sharedValidator
{
    static dispatch_once_t onceToken;
    static MKReceiptValidator *validator;
    dispatch_once(&onceToken, ^{
        validator = [[MKReceiptValidator alloc] init];
    });
    return validator;
}

- (void)validateReceiptWithCompletion:(ReceiptValidationCompletionBlock)completion forceRefresh:(BOOL)force
{
    if (!force && _passedValidation && _validatedReceipt) {
        //Already validated, just send the validated receipt.
        completion(YES, _validatedReceipt, nil);
        return;
    } else {
        if (!_completionBlocks) {
            _completionBlocks = [NSMutableArray array];
        }
        if (completion != nil) {
            [_completionBlocks addObject:completion];
        }
    }
    
    if (force) {
        _hasRefreshedReceipt = NO;
    }
    
    //We need to validate the receipt.
    NSLog(@"Attempting to validate the receipt...");
    
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSString *receiptPath = [receiptURL path];
    NSError *error;
    [self validateReceiptAtPath:receiptPath error:&error];
    
    if (_passedValidation && _validatedReceipt) {
        NSLog(@"Receipt passed validation.");
        [self runCompletionBlocksWithSuccess:YES error:nil];
    } else if (!_beganReceiptRefresh && !_hasRefreshedReceipt) {
        //If we have not refreshed the receipt, refresh it.
        NSLog(@"Receipt Failed validation: %@, %@", error.localizedDescription, error.localizedFailureReason);
        NSLog(@"Refreshing receipt...");
        _refreshRequest = [[SKReceiptRefreshRequest alloc] init];
        _refreshRequest.delegate = self;
        [_refreshRequest start];
    } else if (_hasRefreshedReceipt && !_passedValidation) {
        NSLog(@"Receipt Failed validation: %@, %@", error.localizedDescription, error.localizedFailureReason);
        [self runCompletionBlocksWithSuccess:NO error:error];
    }
}

- (void)requestDidFinish:(SKRequest *)request
{
    NSLog(@"Receipt refresh succeded...");
    _refreshRequest = nil;
    _hasRefreshedReceipt = YES;
    _beganReceiptRefresh = NO;
    [self validateReceiptWithCompletion:nil forceRefresh:NO];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    NSLog(@"Receipt refresh failed.");
    _refreshRequest = nil;
    _hasRefreshedReceipt = YES;
    _beganReceiptRefresh = NO;
    //Failure
    [self runCompletionBlocksWithSuccess:NO error:error];
}

- (void)validateReceiptAtPath:(NSString *)path error:(NSError **)error;
{
    //Use defined values since the values in the info.plist can be changed.
    NSString *bundleVersion = (NSString*)kBundleVersionConstant;
    NSString *bundleIdentifier = (NSString *)kBundleIdentifierConstant;
    _validatedReceipt = nil;
    _passedValidation = NO;
    
    //Check that the identifier and versions match.
    NSCAssert([bundleVersion isEqualToString:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]],
              @"The hard coded CFBundleShortVersionString does not match the bundle string.");
    NSCAssert([bundleIdentifier isEqualToString:[[NSBundle mainBundle] bundleIdentifier]], @"The hard-coded bundle identifier does not match the bundle identifier.");
    
    MKApplicationReceipt *receipt = [self applicationReceiptAtPath:path];
    
    //Do we have a receipt
    if (!receipt) {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: NSLocalizedString(@"Application receipt failed to validate.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"There was no receipt to validate.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Refresh the application receipt.", nil)
                                   };
        *error = [NSError errorWithDomain:kM13MarketKitErrorDomain code:kMKReceiptValidationErrorCodeNoReceipt userInfo:userInfo];
        return;
    }
    
    //Validate the receipt
    unsigned char uuidBytes[16];
    NSUUID *vendorUUID = [[UIDevice currentDevice] identifierForVendor];
    [vendorUUID getUUIDBytes:uuidBytes];
    
    NSMutableData *input = [NSMutableData data];
    [input appendBytes:uuidBytes length:sizeof(uuidBytes)];
    [input appendData:receipt.opaqueValue];
    [input appendData:receipt.bundleIdentifierData];
    
    NSMutableData *hash = [NSMutableData dataWithLength:SHA_DIGEST_LENGTH];
    SHA1([input bytes], [input length], [hash mutableBytes]);
    
    if (![bundleIdentifier isEqualToString:receipt.bundleIdentifier]) {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: NSLocalizedString(@"Application receipt failed to validate.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The receipt bundle identifier does not match the application's bundle identifier", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"The application bundle has been edited. Epic Fail", nil)
                                   };
        *error = [NSError errorWithDomain:kM13MarketKitErrorDomain code:kMKReceiptValidationErrorCodeInvalidBundleIdentifier userInfo:userInfo];
        return;
    }
    
    if (![bundleVersion isEqualToString:receipt.applicationVersion]) {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: NSLocalizedString(@"Application receipt failed to validate.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The receipt application version does not match the application's version", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"The application bundle has been edited. Epic Fail", nil)
                                   };
        *error = [NSError errorWithDomain:kM13MarketKitErrorDomain code:kMKReceiptValidationErrorCodeInvalidVersion userInfo:userInfo];
        return;
    }
    
    if (![hash isEqualToData:receipt.sha1Hash]) {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: NSLocalizedString(@"Application receipt failed to validate.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The receipt application version does not match the application's version", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"The application bundle has been edited. Epic Fail",;nil)
                                   };
        *error = [NSError errorWithDomain:kM13MarketKitErrorDomain code:kMKReceiptValidationErrorCodeInvalidVersion userInfo:userInfo];
        return;
    }
    
    _validatedReceipt = receipt;
    _passedValidation = YES;
}

- (void)runCompletionBlocksWithSuccess:(BOOL)success error:(NSError *)error
{
    //Run each completion that has been stored.
    @synchronized(_completionBlocks) {
        NSArray *blocks = [_completionBlocks copy];
        for (ReceiptValidationCompletionBlock completion in blocks) {
            completion(success, _validatedReceipt, error);
            [_completionBlocks removeObject:completion];
        }
    }
}

- (NSData *)appleRootCertificateData
{
    // Obtain the Apple Inc. root certificate from http://www.apple.com/certificateauthority/
    // Add the AppleIncRootCertificate.cer to your app's resource bundle.
    
    return [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"]];
}

- (NSArray *)receiptsFromInAppPurchaseData:(NSData *)data
{
    //Setup
    int type = 0;
    int xclass = 0;
    long length = 0;
    
    NSUInteger dataLenght = [data length];
    const uint8_t *p = [data bytes];
    
    const uint8_t *end = p + dataLenght;
    
    //The array to hold the receipts
    NSMutableArray *resultArray = [NSMutableArray array];
    
    //While we have data to process
    while (p < end) {
        //Get the main object
        ASN1_get_object(&p, &length, &type, &xclass, end - p);
        
        const uint8_t *set_end = p + length;
        
        //This should be as set of receipts, of not a set, we have a problem.
        if(type != V_ASN1_SET) {
            break;
        }
        
        //The dictionary to set up the receipt with
        NSMutableDictionary *item = [[NSMutableDictionary alloc] initWithCapacity:6];
        
        //While we have data in the set to process.
        while (p < set_end) {
            //Get a receipt object
            ASN1_get_object(&p, &length, &type, &xclass, set_end - p);
            
            //If not a sequence, we have a problem.
            if (type != V_ASN1_SEQUENCE) {
                break;
            }
            
            const uint8_t *seq_end = p + length;
            
            //Get the attribute type and version.
            int attr_type = 0;
            int attr_version = 0;
            
            // Attribute type
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            if (type == V_ASN1_INTEGER) {
                if(length == 1) {
                    attr_type = p[0];
                }
                else if(length == 2) {
                    attr_type = p[0] * 0x100 + p[1]
                    ;
                }
            }
            p += length;
            
            // Attribute version
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            if (type == V_ASN1_INTEGER && length == 1) {
                attr_version = p[0];
            }
            p += length;
            
            //Parse the attributes (Check to see if it is a documented attribute that we want)
            if (attr_type == kIAPCancelationDateField || attr_type == kIAPOriginalPurchaseDateField || attr_type ==kIAPOriginalTransactionIdentifierField || attr_type == kIAPProductIdentifierField || attr_type == kIAPPurchaseDateField || attr_type == kIAPQuantityField || attr_type == kIAPSubscriptionExpirationDateField || attr_type == kIAPTransactionIdentifierField || attr_type == kIAPWebOrderLineItemIdentifierField) {
                
                //The storage key
                NSString *key = nil;
                
                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                
                if (type == V_ASN1_OCTET_STRING) {
                    
                    //Process integers
                    if (attr_type == kIAPQuantityField || attr_type == kIAPWebOrderLineItemIdentifierField) {
                        int num_type = 0;
                        long num_length = 0;
                        const uint8_t *num_p = p;
                        //Get the integer
                        ASN1_get_object(&num_p, &num_length, &num_type, &xclass, seq_end - num_p);
                        //Check to see that is an integer, and process the data.
                        if (num_type == V_ASN1_INTEGER) {
                            NSUInteger quantity = 0;
                            if (num_length) {
                                quantity += num_p[0];
                                if (num_length > 1) {
                                    quantity += num_p[1] * 0x100;
                                    if (num_length > 2) {
                                        quantity += num_p[2] * 0x10000;
                                        if (num_length > 3) {
                                            quantity += num_p[3] * 0x1000000;
                                        }
                                    }
                                }
                            }
                            
                            //Store the values
                            NSNumber *num = [[NSNumber alloc] initWithUnsignedInteger:quantity];
                            if (attr_type == kIAPQuantityField) {
                                [item setObject:num forKey:kIAPReceiptQuantity];
                            } else if (attr_type == kIAPWebOrderLineItemIdentifierField) {
                                [item setObject:num forKey:kIAPReceiptWebOrderLineItemID];
                            }
                        }
                    }
                    
                    //Process strings
                    if (attr_type == kIAPProductIdentifierField || attr_type == kIAPTransactionIdentifierField || attr_type == kIAPOriginalTransactionIdentifierField || attr_type == kIAPPurchaseDateField || attr_type == kIAPOriginalPurchaseDateField || attr_type == kIAPSubscriptionExpirationDateField || attr_type == kIAPCancelationDateField) {
                        
                        int str_type = 0;
                        long str_length = 0;
                        const uint8_t *str_p = p;
                        //Get the string
                        ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                        
                        if (str_type == V_ASN1_UTF8STRING) {
                            switch (attr_type) {
                                case kIAPProductIdentifierField:
                                    key = kIAPReceiptProductIdentifier;
                                    break;
                                case kIAPTransactionIdentifierField:
                                    key = kIAPReceiptTransactionIdentifier;
                                    break;
                                case kIAPOriginalTransactionIdentifierField:
                                    key = kIAPReceiptOriginalTransactionIdentifier;
                                    break;
                            }
                            
                            if (key) {
                                NSString *string = [[NSString alloc] initWithBytes:str_p length:(NSUInteger)str_length encoding:NSUTF8StringEncoding];
                                [item setObject:string forKey:key];
                            }
                        }
                        
                        if (str_type == V_ASN1_IA5STRING) {
                            switch (attr_type) {
                                case kIAPPurchaseDateField:
                                    key = kIAPReceiptPurchaseDate;
                                    break;
                                case kIAPOriginalPurchaseDateField:
                                    key = kIAPReceiptOriginalPurchaseDate;
                                    break;
                                case kIAPSubscriptionExpirationDateField:
                                    key = kIAPReceiptSubscriptionExpirationDate;
                                    break;
                                case kIAPCancelationDateField:
                                    key = kIAPReceiptCancellationDate;
                                    break;
                            }
                            
                            if (key) {
                                NSString *string = [[NSString alloc] initWithBytes:str_p length:(NSUInteger)str_length encoding:NSASCIIStringEncoding];
                                [item setObject:string forKey:key];
                            }
                        }
                    }
                }
                
                p += length;
                
            }
            
            // Skip any remaining fields in this SEQUENCE
            while (p < seq_end) {
                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                p += length;
            }
            
        }
        
        // Skip any remaining fields in this SET
        while (p < set_end) {
            ASN1_get_object(&p, &length, &type, &xclass, set_end - p);
            p += length;
        }
        
        [resultArray addObject:[[MKInAppPurchaseReceipt alloc] initWithInformation:item]];
    }
    
    return [resultArray copy];
}

- (MKApplicationReceipt *)applicationReceiptAtPath:(NSString *)receiptPath
{
    //Get the root certificate
    NSData *rootCertificateData = [self appleRootCertificateData];
    
    ERR_load_PKCS7_strings();
    ERR_load_X509_strings();
    OpenSSL_add_all_digests();
    
    // Expected input is a PKCS7 container with signed data containing an ASN.1 SET of SEQUENCE structures. Each SEQUENCE contains two INTEGERS and an OCTET STRING.
    
    const char * path = [receiptPath fileSystemRepresentation];
    FILE *fp = fopen(path, "rb");
    if (fp == NULL) {
        return nil;
    }
    
    PKCS7 *p7 = d2i_PKCS7_fp(fp, NULL);
    fclose(fp);
    
    // Check if the receipt file was invalid (otherwise we go crashing and burning)
    if (p7 == NULL) {
        return nil;
    }
    
    if (!PKCS7_type_is_signed(p7)) {
        PKCS7_free(p7);
        return nil;
    }
    
    if (!PKCS7_type_is_data(p7->d.sign->contents)) {
        PKCS7_free(p7);
        return nil;
    }
    
    int verifyReturnValue = 0;
    X509_STORE *store = X509_STORE_new();
    if (store) {
        const uint8_t *data = (uint8_t *)(rootCertificateData.bytes);
        X509 *appleCA = d2i_X509(NULL, &data, (long)rootCertificateData.length);
        if (appleCA) {
            BIO *payload = BIO_new(BIO_s_mem());
            X509_STORE_add_cert(store, appleCA);
            
            if (payload) {
                verifyReturnValue = PKCS7_verify(p7,NULL,store,NULL,payload,0);
                BIO_free(payload);
            }
            
            X509_free(appleCA);
        }
        
        X509_STORE_free(store);
    }
    
    EVP_cleanup();
    
    if (verifyReturnValue != 1) {
        PKCS7_free(p7);
        return nil;
    }
    
    ASN1_OCTET_STRING *octets = p7->d.sign->contents->d.data;
    const uint8_t *p = octets->data;
    const uint8_t *end = p + octets->length;
    
    int type = 0;
    int xclass = 0;
    long length = 0;
    
    //Get the receipt object
    ASN1_get_object(&p, &length, &type, &xclass, end - p);
    if (type != V_ASN1_SET) {
        PKCS7_free(p7);
        return nil;
    }
    
    //The information to set up the receipt with.
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    
    
    //While we have data to process
    while (p < end) {
        
        //Get an object
        ASN1_get_object(&p, &length, &type, &xclass, end - p);
        if (type != V_ASN1_SEQUENCE) {
            break;
        }
        
        const uint8_t *seq_end = p + length;
        
        int attr_type = 0;
        int attr_version = 0;
        
        // Attribute type
        ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
        if (type == V_ASN1_INTEGER && length == 1) {
            attr_type = p[0];
        }
        p += length;
        
        // Attribute version
        ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
        if (type == V_ASN1_INTEGER && length == 1) {
            attr_version = p[0];
            attr_version = attr_version;
        }
        p += length;
        
        // Only parse attributes we're interested in
        if (attr_type == kBundleIdentifierField || attr_type == kVersionField || attr_type == kOpaqueValueField || attr_type == kHashField ||attr_type == kInAppPurchasesField || attr_type == kOriginalVersionField || attr_type == kExpirationDateField) {
            //The key for the data
            NSString *key = nil;
            
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            if (type == V_ASN1_OCTET_STRING) {
                NSData *data = [NSData dataWithBytes:p length:(NSUInteger)length];
                
                // Bytes
                if (attr_type == kBundleIdentifierField || attr_type == kOpaqueValueField || attr_type == kHashField) {
                    switch (attr_type) {
                        case kBundleIdentifierField:
                            // This is included for hash generation
                            key = kApplicationReceiptBundleIdentifierData;
                            break;
                        case kOpaqueValueField:
                            key = kApplicationReceiptOpaqueValue;
                            break;
                        case kHashField:
                            key = kApplicationReceiptHash;
                            break;
                    }
                    if (key) {
                        [info setObject:data forKey:key];
                    }
                }
                
                // Strings
                if (attr_type == kBundleIdentifierField || attr_type == kVersionField || attr_type == kOriginalVersionField) {
                    int str_type = 0;
                    long str_length = 0;
                    const uint8_t *str_p = p;
                    ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                    if (str_type == V_ASN1_UTF8STRING) {
                        switch (attr_type) {
                            case kBundleIdentifierField:
                                key = kApplicationReceiptBundleIdentifier;
                                break;
                            case kVersionField:
                                key = kApplicationReceiptVersion;
                                break;
                            case kOriginalVersionField:
                                key = kApplicationReceiptOriginalVersion;
                                break;
                        }
                        
                        if (key) {
                            NSString *string = [[NSString alloc] initWithBytes:str_p length:(NSUInteger)str_length encoding:NSUTF8StringEncoding];
                            [info setObject:string forKey:key];
                        }
                    }
                }
                
                // In-App purchases
                if (attr_type == kInAppPurchasesField) {
                    NSArray *inApp = [self receiptsFromInAppPurchaseData:data];
                    NSArray *current = info[kApplicationReceiptInApp];
                    if (current) {
                        info[kApplicationReceiptInApp] = [current arrayByAddingObjectsFromArray:inApp];
                    } else {
                        [info setObject:inApp forKey:kApplicationReceiptInApp];
                    }
                }
            }
            p += length;
        }
        
        // Skip any remaining fields in this SEQUENCE
        while (p < seq_end) {
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            p += length;
        }
    }
    
    PKCS7_free(p7);
    
    return [[MKApplicationReceipt alloc] initWithInformation:info];
}


@end

@implementation MKApplicationReceipt

- (instancetype)initWithInformation:(NSDictionary *)information
{
    self = [super init];
    if (self) {
        _bundleIdentifier = information[kApplicationReceiptBundleIdentifier];
        _bundleIdentifierData = information[kApplicationReceiptBundleIdentifierData];
        _sha1Hash = information[kApplicationReceiptHash];
        _inAppPurchaseReceipts = information[kApplicationReceiptInApp];
        _opaqueValue = information[kApplicationReceiptOpaqueValue];
        _originalApplicationVersion = information[kApplicationReceiptOriginalVersion];
        _applicationVersion = information[kApplicationReceiptVersion];
        _receiptExpirationDate = [NSDate dateFromRFC3339String:information[kApplicationReceiptExpirationDate]];
    }
    return self;
}

@end

@implementation MKInAppPurchaseReceipt

- (instancetype)initWithInformation:(NSDictionary *)information
{
    self = [super init];
    if (self) {
        _quantity = ((NSNumber *)information[kIAPReceiptQuantity]).unsignedIntegerValue;
        _productIdentifier = information[kIAPReceiptProductIdentifier];
        _transactionIdentifier = information[kIAPReceiptTransactionIdentifier];
        _originalTransactionIdentifier = information[kIAPReceiptOriginalTransactionIdentifier];
        _purchaseDate = [NSDate dateFromRFC3339String:information[kIAPReceiptPurchaseDate]];
        _originalPurchaseDate = [NSDate dateFromRFC3339String:information[kIAPReceiptOriginalPurchaseDate]];
        _subscriptionExpirationDate = [NSDate dateFromRFC3339String:information[kIAPReceiptSubscriptionExpirationDate]];
        _cancelationDate = [NSDate dateFromRFC3339String:information[kIAPReceiptCancellationDate]];
        _webOrderLineItemIdentifier = ((NSNumber *)information[kIAPReceiptWebOrderLineItemID]).unsignedIntegerValue;
    }
    return self;
}

@end
