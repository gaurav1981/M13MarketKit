//
//  MKMarket.m
//  M13MarketKit
/*
 Copyright (c) 2014 Brandon McQuilkin
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MKMarket.h"
#import "MKProduct.h"
#import "MKReceiptValidator.h"
#import <zipzap.h>
#import <objc/runtime.h>
#import <StoreKit/StoreKit.h>

#define kMKMarketProductsToInstallKey @"MKMarketProductsToInstall"

@interface MKMarket () <SKProductsRequestDelegate, SKPaymentTransactionObserver, NSURLConnectionDataDelegate, MKProductDelegate, NSURLSessionDownloadDelegate, NSURLSessionDelegate, NSURLSessionTaskDelegate>

/**The products request.*/
@property (nonatomic, strong) SKProductsRequest *productsRequest;
/**The data for the product list.*/
@property (nonatomic, strong) NSMutableData *productListData;
/**The product list request.*/
@property (nonatomic, strong) NSURLConnection *productListConnection;
/**The application delegate completion handler*/
@property (nonatomic, copy) void (^completionHandler)();
/**Wether or not we are currently loading the product list.*/
@property (nonatomic, assign) BOOL loadingProductList;
/**A list of products that are currently downloading. The keys are the unique session identifiers for the NSURLSessionDownloadTask that is downloading the data for the product.*/
@property (nonatomic, strong) NSMutableDictionary *downloadTasks;

@end

@implementation MKMarket

+ (instancetype)sharedMarket
{
    static MKMarket *market;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        market = [[MKMarket alloc] init];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:market];
    });
    return market;
}

//---------------------------------
//
#pragma mark - Loading product list.
//
//---------------------------------

- (void)refreshProductList
{
    if (!_productInformationFileURL || _loadingProductList) {
        return;
    }
    
    NSLog(@"Begin refreshing product list...");
    _loadingProductList = YES;
    
        //Reset the lists, and notify the observers.
        _products = nil;
        _purchasableProducts = nil;
        _purchasedProducts = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kMKMarketProductListChangedNotification object:nil];
        
        if ([_productInformationFileURL isFileURL]) {
            //Load the local file
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                //Load and process in background
                NSData *data = [NSData dataWithContentsOfURL:_productInformationFileURL];
                [self processProductListData:data];
                });
        } else {
            //Load the external file
            //Setup the request
            NSMutableURLRequest *productListRequest = [[NSMutableURLRequest alloc] init];
            [productListRequest setURL:_productInformationFileURL];
            productListRequest.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
            productListRequest.timeoutInterval = 30.0;
            
            //Load the file
            _productListConnection = [NSURLConnection connectionWithRequest:productListRequest delegate:self];
            [_productListConnection start];
        }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    //Setup the data for the product list
    if (connection == _productListConnection) {
        NSLog(@"Product list connection received response...");
        _productListData = [[NSMutableData alloc] init];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    //Append the data
    if (connection == _productListConnection) {
        [_productListData appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    //Process the data
    if (connection == _productListConnection) {
        _productListConnection = nil;
        [self processProductListData:_productListData];
        _productListData = nil;
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (connection == _productListConnection) {
        //Failure
        _productListConnection = nil;
        _productListData = nil;
        _loadingProductList = NO;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to load products list: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [alert show];
        });
        [[NSNotificationCenter defaultCenter] postNotificationName:kMKMarketProductListUpdateFinishedNoification object:nil];
    }
}

- (void)processProductListData:(NSData *)data
{
    NSLog(@"Process product list...");
    NSError *error;
    //Load the raw information
    NSArray *productDictionaries = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    //Check for errors
    if (error) {
        _loadingProductList = NO;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to load products list: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [alert show];
        });
        [[NSNotificationCenter defaultCenter] postNotificationName:kMKMarketProductListUpdateFinishedNoification object:nil];
        return;
    }
    
    if (!productDictionaries) {
        _loadingProductList = NO;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Failed to load products list: No list to load." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [alert show];
        });
        [[NSNotificationCenter defaultCenter] postNotificationName:kMKMarketProductListUpdateFinishedNoification object:nil];
        return;
    }
    
    //Create the products
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSDictionary *productDict in productDictionaries) {
        MKProduct *product = [[MKProduct alloc] initWithProductInformation:productDict];
        product.delegate = self;
        [dict setObject:product forKey:product.identifier];
    }
    
    _products = [dict copy];
    
    //Create and start the products request
    NSLog(@"Starting product request...");
    _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:_products.allKeys]];
    _productsRequest.delegate = self;
    [_productsRequest start];
    
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSLog(@"Product request received response...");
    NSLog(@"Invalid products: %@", response.invalidProductIdentifiers);
    _productsRequest = nil;
    [self processProductRequest:response.products];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    NSLog(@"Product request failed: %@", error.localizedDescription);
    _productsRequest = nil;
    _loadingProductList = NO;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to load products list: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [alert show];
    });
    [[NSNotificationCenter defaultCenter] postNotificationName:kMKMarketProductListUpdateFinishedNoification object:nil];
}

- (void)processProductRequest:(NSArray *)validProducts
{
    NSLog(@"Processing product request response: %lu products", (unsigned long)validProducts.count);
    for (SKProduct *skProduct in validProducts) {
        MKProduct *product = _products[skProduct.productIdentifier];
        product.skProduct = skProduct;
    }
    
    //Sort the products
    NSMutableDictionary *tempPurchased = [NSMutableDictionary dictionary];
    NSMutableDictionary *tempPurchaseable = [NSMutableDictionary dictionary];
    for (MKProduct *product in _products.allValues) {
        if (product.state == MKProductStateAvailableToPurchase || product.state == MKProductStatePurchaseDeferred || product.state == MKProductStatePurchaseInProgress) {
            [tempPurchaseable setObject:product forKey:product.identifier];
        } else if (product.state == MKProductStatePurchasedNotInstalled || product.state == MKProductStatePurchasedNeedsUpdate || product.state == MKProductStatePurchasedUpToDate) {
            [tempPurchased setObject:product forKey:product.identifier];
        }
    }
    
    _purchasableProducts = [tempPurchaseable copy];
    _purchasedProducts = [tempPurchased copy];
    
    _loadingProductList = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMKMarketProductListUpdateFinishedNoification object:nil];
    
    //Process completed downloads if necessary
    [self processCompletedDownloads];
}

//---------------------------------
//
#pragma mark - Product Delegate
//
//---------------------------------

- (BOOL)productInstalled:(MKProduct *)product
{
    if ([_delegate respondsToSelector:@selector(productInstalled:)]) {
        return [_delegate productInstalled:product];
    } else {
        return NO;
    }
}

- (NSString *)versionOfInstalledProduct:(MKProduct *)product
{
    if ([_delegate respondsToSelector:@selector(versionOfInstalledProduct:)]) {
        return [_delegate versionOfInstalledProduct:product];
    } else {
        return nil;
    }
}

- (void)productInformationUpdated:(MKProduct *)product
{
    NSLog(@"Information updated for product: %@", product.identifier);
    
    NSMutableDictionary *tempPurchased = [_purchasedProducts mutableCopy];
    NSMutableDictionary *tempPurchasable = [_purchasableProducts mutableCopy];
    
    //Remove the product from its list
    [tempPurchased removeObjectForKey:product.identifier];
    [tempPurchasable removeObjectForKey:product.identifier];
    
    //Add back in
    if (product.state == MKProductStateAvailableToPurchase || product.state == MKProductStatePurchaseDeferred || product.state == MKProductStatePurchaseInProgress) {
        [tempPurchasable setObject:product forKey:product.identifier];
    } else if (product.state == MKProductStatePurchasedNotInstalled || product.state == MKProductStatePurchasedNeedsUpdate || product.state == MKProductStatePurchasedUpToDate) {
        [tempPurchased setObject:product forKey:product.identifier];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMKMarketProductListChangedNotification object:nil];
}

//---------------------------------
//
#pragma mark - Purchasing
//
//---------------------------------

- (void)purchaseProduct:(MKProduct *)product
{
    if (product.state == MKProductStateAvailableToPurchase) {
        NSLog(@"Begin purchase for product: %@", product.identifier);
        product.purchaseInProgress = YES;
        [[SKPaymentQueue defaultQueue] addPayment:[SKPayment paymentWithProduct:product.skProduct]];
    }
}

- (void)restoreCompletedTransactions
{
    NSLog(@"Begin restoring transactions...");
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

//---------------------------------
//
#pragma mark - SKPaymentQueue
//
//---------------------------------

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    //Do diffrent things depending on the state of the transaction.
    for (SKPaymentTransaction *transaction in transactions) {
        MKProduct *product = _products[transaction.payment.productIdentifier];
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                product.purchaseInProgress = YES;
                product.purchaseDeferred = NO;
                break;
            case SKPaymentTransactionStatePurchased:
                product.purchaseInProgress = YES;
                product.purchaseDeferred = NO;
                [self completeTransaction:transaction forProduct:product];
                break;
            case SKPaymentTransactionStateDeferred:
                product.purchaseInProgress = NO;
                product.purchaseDeferred = YES;
                break;
            case SKPaymentTransactionStateRestored:
                product.purchaseInProgress = NO;
                product.purchaseDeferred = NO;
                [self completeTransaction:transaction forProduct:product];
                break;
            case SKPaymentTransactionStateFailed:
                product.purchaseInProgress = NO;
                product.purchaseDeferred = NO;
                [self failedTransaction:transaction forProduct:product];
                break;
            default:
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions
{
    //These products have been installed.
    for (SKPaymentTransaction *transaction in transactions) {
        MKProduct *product = _products[transaction.payment.productIdentifier];
        product.purchaseInProgress = NO;
        product.purchaseDeferred = NO;
        [product refreshProductProperties];
        NSLog(@"Transaction removed: %@", transaction.payment.productIdentifier);
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    //Notify the delegate
    NSLog(@"Completed restoring transactions...");
    [[NSNotificationCenter defaultCenter] postNotificationName:kMKMarketCompletedRestoringTransactionsNotification object:nil];
    //Update the table, start py updating the receipt.
    [[MKReceiptValidator sharedValidator] validateReceiptWithCompletion:^(BOOL validAppReceipt, MKApplicationReceipt *receipt, NSError *error) {
        //Need to update the products
        for (MKProduct *product in _products) {
            [product refreshProductProperties];
        }
    } forceRefresh:YES];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    //Notify the delegate
    NSLog(@"Failed to restor transactions...");
    [[NSNotificationCenter defaultCenter] postNotificationName:kMKMarketCompletedRestoringTransactionsNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMKMarketProductListChangedNotification object:nil];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to restore tranactions: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [alert show];
    });
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction forProduct:(MKProduct *)product
{
    NSLog(@"Verifing receipt for transaction: %@", product.identifier);
    //Verify the receipt, which needs to be updated
    [[MKReceiptValidator sharedValidator] validateReceiptWithCompletion:^(BOOL validAppReceipt, MKApplicationReceipt *receipt, NSError *error) {
        if (validAppReceipt && receipt) {
            //Now update the product properties (No consequence for doing this twice as the receipt is cached.
            [product refreshProductProperties];
            
            if (product.state == MKProductStatePurchasedNeedsUpdate || product.state == MKProductStatePurchasedNotInstalled || product.state == MKProductStatePurchasedUpToDate) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kMKMarketProductListChangedNotification object:nil];
                [self provideContentForProduct:product];
            } else {
                //Finish the failed transaction.
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                product.purchaseInProgress = NO;
                product.purchaseDeferred = NO;
            }
        } else {
            //failure
            NSLog(@"Transaction for product: %@ failed to validate receipt.", product.identifier);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to find receipt for product: %@", product.skProduct.localizedTitle] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            dispatch_sync(dispatch_get_main_queue(), ^{
                [alert show];
            });
            //Finish the failed transaction.
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            product.purchaseInProgress = NO;
            product.purchaseDeferred = NO;
        }
        
    } forceRefresh:YES];
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction forProduct:(MKProduct *)product
{
    NSLog(@"Transaction for product: %@ failed: %@", product.identifier, transaction.error.localizedDescription);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to process transaction for %@: %@", product.skProduct.localizedTitle, transaction.error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [alert show];
    });
    //Finish the failed transaction.
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

//---------------------------------
//
#pragma mark - Providing Content
//
//---------------------------------

- (void)provideContentForProduct:(MKProduct *)product
{
    [self provideContentForProduct:product transaction:nil];
}

- (void)provideContentForProduct:(MKProduct *)product transaction:(SKPaymentTransaction *)transaction
{
    NSLog(@"Providing content for product: %@", product.identifier);
    product.installing = YES;
    if (product.type == MKProductTypeNonConsumable) {
        [self provideContentForNonConsumable:product transaction:transaction];
    } else if (product.type == MKProductTypeConsumable){
        [self provideContentForConsumable:product transaction:transaction];
    } else {
        //Not sure what to do, ask the delegate to provide the content.
        [_delegate provideContentForProduct:product transaction:transaction];
    }
}

#pragma mark - consumables

- (void)provideContentForConsumable:(MKProduct *)product transaction:(SKPaymentTransaction *)transaction
{
    //Default perstance not implemented yet
    [_delegate provideContentForProduct:product transaction:transaction];
}

#pragma mark - Non consumables

- (void)provideContentForNonConsumable:(MKProduct *)product transaction:(SKPaymentTransaction *)transaction
{
    if (transaction.downloads) {
        if (transaction.downloads.count > 0) {
            //Start the downloads
            NSLog(@"Starting product SKDownloads...");
            [[SKPaymentQueue defaultQueue] startDownloads:transaction.downloads];
        }
    } else if (product.contentURL) {
        if ([product.contentURL isFileURL]) {
            [self provideLocalContentForNonConsumable:product transaction:transaction];
        } else {
            [self provideExternalContentForNonConsumable:product transaction:transaction];
        }
    } else {
        //Not sure what to do, ask the delegate to provide the content.
        [_delegate provideContentForProduct:product transaction:transaction];
    }
}

- (void)provideLocalContentForNonConsumable:(MKProduct *)product transaction:(SKPaymentTransaction *)transaction
{
    NSLog(@"Providing local content for product: %@", product.identifier);
    //Get the path of the resource to move
    NSMutableString *path = [product.contentURL mutableCopy];
    NSString *bundlePath = [NSBundle mainBundle].resourcePath;
    [path replaceOccurrencesOfString:@"bundle/" withString:bundlePath options:NSLiteralSearch range:NSMakeRange(0, 12)];
    
    //Install
    [self installProductContentAtPath:path forProduct:product transaction:transaction];
}

- (NSURLSession *)backgroundSession
{
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.BrandonMcQuilkin.MarketKit"];
        configuration.HTTPMaximumConnectionsPerHost = 5;
        session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    });
    return session;
}

- (void)provideExternalContentForNonConsumable:(MKProduct *)product transaction:(SKPaymentTransaction *)transaction
{
    NSLog(@"Providing external content for product: %@", product.identifier);
    //Finish the transaction. No sure how to persist it?
#warning Shouldn't be completing the transaction here. Not sure how to have the transaction persist with support for background downloading.
    if (transaction) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
    //Setup to download content in the background
    NSURLRequest *request = [NSURLRequest requestWithURL:product.contentURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60.0];
    NSURLSessionDownloadTask *task = [[self backgroundSession] downloadTaskWithRequest:request];
    
    //Add the task to the list
    if (!_downloadTasks) {
        _downloadTasks = [NSMutableDictionary dictionary];
    }
    [_downloadTasks setObject:product forKey:[NSNumber numberWithUnsignedInteger:task.taskIdentifier]];
    
    //Start downloading
    [task resume];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads
{
    for (SKDownload *download in downloads) {
        SKPaymentTransaction *transaction = download.transaction;
        MKProduct *product = _products[transaction.payment.productIdentifier];
        
        switch (download.downloadState) {
            case SKDownloadStateFinished:
                [self installProductContentAtPath:download.contentURL.path forProduct:product transaction:transaction];
                break;
            case SKDownloadStateFailed:
                [self skDownloadFailedToProvideContent:download];
                break;
            case SKDownloadStateCancelled:
                [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
                break;
            case SKDownloadStateActive:
                [self updateProgressForDownload:download];
                break;
            case SKDownloadStateWaiting:
                
                break;
            case SKDownloadStatePaused:
                
                break;
            default:
                break;
        }
    }
}

- (void)updateProgressForDownload:(SKDownload *)download
{
    MKProduct *product = _products[download.transaction.payment.productIdentifier];
    product.instalationProgress = download.progress;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    //Get the product
    NSNumber *key = [NSNumber numberWithUnsignedInteger:downloadTask.taskIdentifier];
    MKProduct *product = _downloadTasks[key];
    //Update its progress
    product.instalationProgress = (float)((double)totalBytesWritten / (double) totalBytesExpectedToWrite);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSLog(@"Finished downloading content from: %@ to: %@", downloadTask.originalRequest.URL, location);
    
    //Move the temporary file, as it will most likely be deleted after this method returns. (It seems to be as soon as you step out of the method.
    NSString *tempDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    tempDirectory = [tempDirectory stringByAppendingPathComponent:@"MKMarket"];
    
    BOOL isDir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:tempDirectory isDirectory:&isDir];
    
    NSError *error;
    if (!exists) {
        [[NSFileManager defaultManager] createDirectoryAtPath:tempDirectory withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    //If we cant create the directory, exit.
    if (error) {
        NSLog(@"Unable to create temporary storage directory: %@", error.localizedDescription);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Unable to create temporary storage directory: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [alert show];
        });
        return;
    }
    
    NSString *tempFile = [tempDirectory stringByAppendingPathComponent:downloadTask.response.suggestedFilename];
    
    //Remove the file if it already exists.
    [[NSFileManager defaultManager] removeItemAtPath:tempFile error:nil];
    
    error = nil;
    BOOL copied = [[NSFileManager defaultManager] copyItemAtPath:location.path toPath:tempFile error:&error];
    
    //If we failed, return
    if (!copied || error) {
        NSLog(@"Unable to copy download: %@", error.localizedDescription);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Unable to copy download: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [alert show];
        });
        return;
    }
    
    NSLog(@"Moved temporary file to new location...");
    
    //Get the content url for the download to identify the product when installing.
    NSURL *downloadURL = downloadTask.originalRequest.URL;
    
    //Store the URLs for later processing.
    NSMutableDictionary *dict = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:kMKMarketProductsToInstallKey] mutableCopy];
    
    if (dict == nil) {
        dict = [[NSMutableDictionary alloc] init];
    }
    
    //Add the location of the download file to the dict, with the external location as the key, so we can use that to identify the download.
    [dict setObject:tempFile forKey:downloadURL.absoluteString];
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:kMKMarketProductsToInstallKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    //Process the completed downloads if we can.
    [self processCompletedDownloads];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (!error) {
        //NSLog(@"Task for URL completed without error: %@", task.originalRequest.URL);
    } else {
        NSLog(@"Task for URL: %@ completed with error: %@", task.originalRequest.URL, error.localizedDescription);
        //Get the product
        NSNumber *key = [NSNumber numberWithUnsignedInteger:task.taskIdentifier];
        MKProduct *product = _downloadTasks[key];
        [_downloadTasks removeObjectForKey:key];
        
        //End Installing
        product.installing = NO;
        product.purchaseInProgress = NO;
        product.instalationProgress = 0.0;
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Unable to download %@. %@", product.skProduct.localizedTitle, error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [alert show];
        });
    }
}

- (void)processCompletedDownloads
{
    //Get the list of products
    NSMutableDictionary *dict = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:kMKMarketProductsToInstallKey] mutableCopy];
    
    //If there are no products, update the list, then process
    if (_products == nil || _products.count == 0) {
        [self refreshProductList];
        return;
    }
    
    for (NSString *externalLocation in dict.allKeys) {
        NSString *localLocation = dict[externalLocation];
        
        for (MKProduct *aProduct in _products.allValues) {
            if ([aProduct.contentURL.absoluteString isEqualToString:externalLocation]) {
                //We have a match, install it
                aProduct.installing = YES;
                [self installProductContentAtPath:localLocation forProduct:aProduct transaction:nil];
                //Remove from the list
                [dict removeObjectForKey:externalLocation];
            }
        }
    }
    
    //Persist updates
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:kMKMarketProductsToInstallKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    NSLog(@"Handle events for background URL session...");
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    _completionHandler = completionHandler;
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    NSLog(@"All background URL session events completed.");
    if (_completionHandler) {
        _completionHandler();
    }
}

- (void)installProductContentAtPath:(NSString *)path forProduct:(MKProduct *)product transaction:(SKPaymentTransaction *)transaction
{
    NSLog(@"Installing content for product...");
    product.instalationProgress = 2.0;
    
    //Get the path to install the resource to
    NSString *installPath = [_delegate locationToInstallProduct:product];
    
    //We must have an install path.
    if (!installPath) {
        return;
    }
    
    //Remove the directory at the install path if one exists
    if ([[NSFileManager defaultManager] fileExistsAtPath:installPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:installPath error:nil];
    }
    
    //Install the content
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        
        NSError *error;
        if ([path.pathExtension.uppercaseString isEqualToString:@"ZIP"]) {
            //Unzip the file to the location
            NSLog(@"Decompressing to: %@", installPath);
            
            NSFileManager* fileManager = [NSFileManager defaultManager];
            NSURL* pathURL = [NSURL fileURLWithPath:installPath];
            ZZArchive* archive = [ZZArchive archiveWithContentsOfURL:[NSURL fileURLWithPath:path]];
            for (ZZArchiveEntry* entry in archive.entries)
            {
                NSURL* targetPath = [pathURL URLByAppendingPathComponent:entry.fileName];
                
                if (entry.fileMode & S_IFDIR) {
                    // check if directory bit is set
                    [fileManager createDirectoryAtURL:targetPath withIntermediateDirectories:YES attributes:nil error:nil];
                } else {
                    // Some archives don't have a separate entry for each directory and just
                    // include the directory's name in the filename. Make sure that directory exists
                    // before writing a file into it.
                    [fileManager createDirectoryAtURL:[targetPath URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
                    
                    [[entry newDataWithError:&error] writeToURL:targetPath atomically:NO];
                    
                    if (error) {
                        NSLog(@"Error creating file: %@", error);
                    }
                }
            }
            
            if (!error) {
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            }
        } else {
            //Copy to location
            [[NSFileManager defaultManager] copyItemAtPath:path toPath:installPath error:&error];
        }
        
        if (error) {
            //Failure
            NSLog(@"Failed to install: %@: %@", product.identifier, error.localizedDescription);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to install %@: %@", product.skProduct.localizedTitle, error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            dispatch_sync(dispatch_get_main_queue(), ^{
                [alert show];
            });
        }
        //Finish the failed transaction.
        if (transaction) {
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
        product.purchaseInProgress = NO;
        product.installing = NO;
        product.installing = NO;
        //Update the table
        [self productInformationUpdated:product];
        NSLog(@"Content for product installed.");
    } else {
        //Something is wrong. No file to install
        NSLog(@"Failed to install %@: No content to install.", product.identifier);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to install %@: No content to install.", product.skProduct.localizedTitle] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [alert show];
        });
        //Finish the failed transaction.
        if (transaction) {
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
        product.purchaseInProgress = NO;
        product.purchaseDeferred = NO;
        product.installing = NO;
        //Update the table
        [self productInformationUpdated:product];
    }
    
}

- (void)skDownloadFailedToProvideContent:(SKDownload *)download
{
    NSLog(@"SKDownload for product %@ failed: %@", download.transaction.payment.productIdentifier, download.error.localizedDescription);
    MKProduct *product = _products[download.transaction.payment.productIdentifier];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to download content for %@: %@", product.skProduct.localizedTitle, download.error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [alert show];
    });
    //Finish the failed transaction.
    [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
    product.purchaseInProgress = NO;
    product.purchaseDeferred = NO;
    product.installing = NO;
    //Update the table
    [self productInformationUpdated:product];
}

@end
