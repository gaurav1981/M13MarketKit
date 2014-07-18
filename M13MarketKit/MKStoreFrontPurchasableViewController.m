//
//  MKStoreFrontViewController.m
//  M13MarketKit
/*
 Copyright (c) 2014 Brandon McQuilkin
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MKStoreFrontPurchasableViewController.h"
#import "MKMarket.h"
#import "MKProduct.h"
#import "MKStoreFrontCell.h"

@interface MKStoreFrontPurchasableViewController () <MKStoreFrontCellDelegate>

@property (nonatomic, strong) NSArray *products;

@end

@implementation MKStoreFrontPurchasableViewController

- (instancetype)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)loadView
{
    [super loadView];
    
    //Register Cell
    [self.tableView registerClass:[MKStoreFrontCell class] forCellReuseIdentifier:@"PurchaseCell"];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:kMKMarketProductListUpdateFinishedNoification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:kMKMarketProductListChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:kMKMarketCompletedRestoringTransactionsNotification object:nil];
    
#warning Bug with UITableViewController in UITabBarController?
    //Doesn't happen here?
    /*if (self.tableView.contentInset.top == 0) {
        CGFloat offset = 44;
        if (![UIApplication sharedApplication].statusBarHidden) {
            offset += 20;
        }
        self.tableView.contentOffset = CGPointMake(0, offset);
        self.tableView.contentInset = UIEdgeInsetsMake(offset, 0, 0, 0);
    }*/
}


- (void)refresh
{
    [[MKMarket sharedMarket] refreshProductList];
}

- (void)reloadTable
{
    NSLog(@"Purchaseable: %i, Purchased: %i", [MKMarket sharedMarket].purchasableProducts.allValues.count, [MKMarket sharedMarket].purchasedProducts.allValues.count);
    _products = [MKMarket sharedMarket].purchasableProducts.allValues;
    _products = [_products sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"skProduct.localizedTitle" ascending:YES]]];

    //End refreshing if necessary
    if (self.refreshControl.isRefreshing) {
        [self.refreshControl endRefreshing];
    }
    
    [self.tableView reloadData];
}

- (void)updateHeightForCell:(MKStoreFrontCell *)cell
{
    //Update the heights of the cells.
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return _products.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MKStoreFrontCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PurchaseCell" forIndexPath:indexPath];
    
    // Configure the cell...
    //The cell handles everything, less messy that way.
    cell.product = _products[indexPath.row];
    cell.delegate = self;
    
    return cell;
}

@end
