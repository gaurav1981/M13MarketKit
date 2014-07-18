//
//  MKStorePresentationController.m
//  M13MarketKit
/*
 Copyright (c) 2014 Brandon McQuilkin
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MKStoreFrontPresentationController.h"
#import "MKStoreFrontPurchasableViewController.h"
#import "MKStoreFrontPurchasedViewController.h"
#import "MKMarket.h"

@interface MKStoreFrontPresentationController ()

@end

@implementation MKStoreFrontPresentationController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //Setup view controllers.
    MKStoreFrontPurchasableViewController *vc1 = [[MKStoreFrontPurchasableViewController alloc] initWithStyle:UITableViewStylePlain];
    vc1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Store" image:[UIImage imageNamed:@"ShopIcon.png"] selectedImage:[UIImage imageNamed:@"ShopIconSelected.png"]];
    MKStoreFrontPurchasedViewController *vc2 = [[MKStoreFrontPurchasedViewController alloc] initWithStyle:UITableViewStylePlain];
    vc2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Purchased" image:[UIImage imageNamed:@"PurchasedIcon.png"] selectedImage:[UIImage imageNamed:@"PurchasedIconSelected.png"]];
    self.viewControllers = @[vc1, vc2];
    
    //Force load all the tabs so that they can respond to notifications.
    [self.viewControllers makeObjectsPerformSelector:@selector(view)];
    
    //Load the products
    [[MKMarket sharedMarket] refreshProductList];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
