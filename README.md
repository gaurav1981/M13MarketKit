<img src="https://raw.github.com/Marxon13/M13MarketKit/master/ReadmeResources/M13MarketKitBanner.png">

M13MarketKit
=============
M13MarketKit is a complete backend for handling in app purchases. It also includes a basic storefront as an example, or for use. 

Features:
-------------

* Handles all three kinds of in app purchases; Consumable, non-consumable, and subscription.
* Handles receipt verification.
* Automatically persists transactions.
* Only 3 things need to be provided to M13MarketKit:
	* The URL for the list of all the in app purchases. (JSON)
	* The bundle identifier for the application.
	* The bundle version for the application.
* Handles providing content, through SKDownload or from a web server automatically.
* Minimal coding is required to get M13MarketKit to work with any project.

Setup:
-------------
1. Add via CocoaPods!
2. Set the URL of the product list as early as possible. Perferably in the Application Delegate.
    
    ```
    MKMarket *market = [MKMarket sharedMarket];
    market.productInformationFileURL = [NSURL urlWithString:@"http://www.website.com/StoreList.json"];
    ```
    
3. Add the four delegate methods to your project. 
	
	```
	 - (BOOL)productInstalled:(MKProduct *)product
	 {
	 	//Do what is needed to determine if a product's content is installed.
	 }
	 
	 - (NSString *)versionOfInstalledProduct:(MKProduct *)product
	 {
	 	//Read the information for an installed product to determine what version is installed. Returns a string in the format of "1.0.0"
	 }
	 
	 - (NSString *)locationToInstallProduct:(MKProduct *)product
	 {
	 	//Returns the path to the location to install the product. Usually the library directory or the documents directory (If you add the "do not backup" attribute).
	 }
	 
	 - (void)provideContentForProduct:(MKProduct *)product transaction:(SKPaymentTransaction *)transaction; 
	 {
	    //Asks the delegate to provide content for products it does not know how to provide the content for.
	 }
	``` 
	
4. If not using the provided store front:
	* Respond to the notifications store front notifications:
	
	```
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:kMKMarketProductListUpdateFinishedNoification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:kMKMarketProductListChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:kMKMarketCompletedRestoringTransactionsNotification object:nil];
   	```
	* Ask M13MarketKit to refresh the product list to load the product information.
	
	```
	[[MKMarket sharedMarket] refreshProductList];
	```
	
	*  To respond to changes in transactions take a look at the provided store front.
	
Sample Product List
-------------------

```
[  
   {  
      "identifier":"com.BrandonMcQuilkin.M13MarketKit.Product1",
      "type":1,
      "minimumApplicationVersion":"4.0.0",
      "version":"1.3",
      "contentURL":"http://www.m13marketkit.com/Products/Product1Content.zip",
      "available":true,
      "date":"05-19-2012"
   },
   {  
      "identifier":"com.BrandonMcQuilkin.M13MarketKit.Product2",
      "type":1,
      "minimumApplicationVersion":"4.0.0",
      "version":"1.2",
      "contentURL":"http://www.m13marketkit.com/Products/Product1Content.zip",
      "available":true,
      "date":"05-30-2012"
   }
]
```

Contact Me:
-------------
If you have any questions comments or suggestions, send me a message. If you find a bug, or want to submit a pull request, let me know.

License:
--------
MIT License

> Copyright (c) 2014 Brandon McQuilkin
> 
> Permission is hereby granted, free of charge, to any person obtaining 
>a copy of this software and associated documentation files (the  
>"Software"), to deal in the Software without restriction, including 
>without limitation the rights to use, copy, modify, merge, publish, 
>distribute, sublicense, and/or sell copies of the Software, and to 
>permit persons to whom the Software is furnished to do so, subject to  
>the following conditions:
> 
> The above copyright notice and this permission notice shall be 
>included in all copies or substantial portions of the Software.
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
>EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
>MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
>IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
>CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
>TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
>SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.