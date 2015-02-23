//
//  AddressRequestController.m
//  AirBitz
//

#import "AddressRequestController.h"
#import "CommonTypes.h"
#import "ButtonSelectorView.h"
#import "Util.h"
#import "User.h"
#import "ABC.h"

@interface AddressRequestController () <UITextFieldDelegate,  ButtonSelectorDelegate>
{
	int _selectedWalletIndex;
    NSString *strName;
    NSString *strCategory;
    NSString *strNotes;
}

@property (nonatomic, weak) IBOutlet ButtonSelectorView *walletSelector;
@property (nonatomic, weak) IBOutlet UILabel *message;
@property (nonatomic, strong) NSArray  *arrayWallets;

@end

@implementation AddressRequestController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
	_walletSelector.delegate = self;
    _walletSelector.textLabel.text = NSLocalizedString(@"Wallet:", nil);
    [_walletSelector setButtonWidth:200];
    [self loadWalletInfo];

    if (_url) {
        NSDictionary *dict = [Util getUrlParameters:_url];
        strName = [dict objectForKey:@"provider"] ? [dict objectForKey:@"provider"] : @"";
        strNotes = [dict objectForKey:@"notes"] ? [dict objectForKey:@"notes"] : @"";
        strCategory = [dict objectForKey:@"category"] ? [dict objectForKey:@"category"] : @"";
        _returnUrl = [[NSURL alloc] initWithString:[[_url host] stringByRemovingPercentEncoding]];
    } else {
        strName = @"";
        strCategory = @"";
        strNotes = @"";
    }

    NSMutableString *msg = [[NSMutableString alloc] init];
    if ([strName length] > 0) {
        [msg appendFormat:NSLocalizedString(@"%@ has requested a bitcoin address to send money to.", nil), strName];
    } else {
        [msg appendString:NSLocalizedString(@"An app has requested a bitcoin address to send money to.", nil)];
    }
    [msg appendString:NSLocalizedString(@" Please choose a wallet to receive funds.", nil)];
    _message.text = msg;
}

- (void)loadWalletInfo
{
    // load all the non-archive wallets
    NSMutableArray *arrayWallets = [[NSMutableArray alloc] init];
    [CoreBridge loadWallets:arrayWallets archived:nil withTxs:NO];

    // create the array of wallet names
    _selectedWalletIndex = 0;

    NSMutableArray *arrayWalletNames =
        [[NSMutableArray alloc] initWithCapacity:[arrayWallets count]];
    for (int i = 0; i < [arrayWallets count]; i++) {
        Wallet *wallet = [arrayWallets objectAtIndex:i];
        [arrayWalletNames addObject:[NSString stringWithFormat:@"%@ (%@)",
            wallet.strName, [CoreBridge formatSatoshi:wallet.balance]]];
    }
    if (_selectedWalletIndex < [arrayWallets count]) {
        Wallet *wallet = [arrayWallets objectAtIndex:_selectedWalletIndex];
        _walletSelector.arrayItemsToSelect = [arrayWalletNames copy];
        [_walletSelector.button setTitle:wallet.strName forState:UIControlStateNormal];
        _walletSelector.selectedItemIndex = (int) _selectedWalletIndex;
    }
    self.arrayWallets = arrayWallets;
}

#pragma mark - Action Methods

- (IBAction)okay
{
    [self.view endEditing:YES];
    NSMutableString *strRequestID = [[NSMutableString alloc] init];
    NSMutableString *strRequestAddress = [[NSMutableString alloc] init];
    NSMutableString *strRequestURI = [[NSMutableString alloc] init];
    [self createRequest:strRequestID storeRequestURI:strRequestURI
        storeRequestAddressIn:strRequestAddress withAmount:0 withRequestState:kRequest];
    if (_returnUrl) {
        NSString *url = [_returnUrl absoluteString];
        NSMutableString *query;
        if ([url rangeOfString:@"?"].location == NSNotFound) {
            query = [[NSMutableString alloc] initWithFormat: @"%@?addr=%@", url, [Util urlencode:strRequestURI]];
        } else {
            query = [[NSMutableString alloc] initWithFormat: @"%@&addr=%@", url, [Util urlencode:strRequestURI]];
        }
        [query appendString:@"&provider=Airbitz"];
        [[UIApplication sharedApplication] openURL:[[NSURL alloc] initWithString:query]];
    }
    // finish
    [self.delegate AddressRequestControllerDone:self];
}

- (IBAction)cancel
{
    if (_returnUrl) {
        NSString *url = [_returnUrl absoluteString];
        NSMutableString *query;
        if ([url rangeOfString:@"?"].location == NSNotFound) {
            query = [[NSMutableString alloc] initWithFormat: @"%@?addr=", url];
        } else {
            query = [[NSMutableString alloc] initWithFormat: @"%@&addr=", url];
        }
        [[UIApplication sharedApplication] openURL:[[NSURL alloc] initWithString:query]];
    }
    // finish
    [self.delegate AddressRequestControllerDone:self];
}

- (void)createRequest:(NSMutableString *)strRequestID
    storeRequestURI:(NSMutableString *)strRequestURI
    storeRequestAddressIn:(NSMutableString *)strRequestAddress
    withAmount:(SInt64)amountSatoshi withRequestState:(RequestState)state
{
    [strRequestID setString:@""];
    [strRequestAddress setString:@""];
    [strRequestURI setString:@""];

    unsigned int width = 0;
    unsigned char *pData = NULL;
    char *pszURI = NULL;
    tABC_Error error;

    char *szRequestID = [self createReceiveRequestFor:amountSatoshi withRequestState:state];
    if (szRequestID) {
        Wallet *wallet = [self.arrayWallets objectAtIndex:_selectedWalletIndex];
        ABC_GenerateRequestQRCode([[User Singleton].name UTF8String],
            [[User Singleton].password UTF8String], [wallet.strUUID UTF8String],
            szRequestID, &pszURI, &pData, &width, &error);
        if (error.code == ABC_CC_Ok) {
            if (pszURI && strRequestURI) {
                [strRequestURI appendFormat:@"%s", pszURI];
                free(pszURI);
            }
        } else {
            [Util printABC_Error:&error];
        }
    }
    if (szRequestID) {
        free(szRequestID);
    }
    if (pData) {
        free(pData);
    }
}

- (char *)createReceiveRequestFor: (SInt64)amountSatoshi withRequestState:(RequestState)state
{
	tABC_Error error;
    tABC_TxDetails details;

    Wallet *wallet = [self.arrayWallets objectAtIndex:_selectedWalletIndex];

    memset(&details, 0, sizeof(tABC_TxDetails));
    details.amountSatoshi = 0;
	details.amountFeesAirbitzSatoshi = 0;
	details.amountFeesMinersSatoshi = 0;
    details.amountCurrency = 0;
    details.szName = (char *) [strName UTF8String];
    details.szNotes = (char *) [strNotes UTF8String];
	details.szCategory = (char *) [strCategory UTF8String];
	details.attributes = 0x0; //for our own use (not used by the core)
    details.bizId = 0;

	char *pRequestID;
    // create the request
	ABC_CreateReceiveRequest([[User Singleton].name UTF8String],
        [[User Singleton].password UTF8String], [wallet.strUUID UTF8String],
        &details, &pRequestID, &error);
	if (error.code == ABC_CC_Ok) {
		return pRequestID;
	} else {
		return 0;
	}
}

#pragma mark - ButtonSelectorView delegates

- (void)ButtonSelector:(ButtonSelectorView *)view selectedItem:(int)itemIndex
{
    _selectedWalletIndex = itemIndex;

    // Update wallet UUID
    Wallet *wallet = [self.arrayWallets objectAtIndex:_selectedWalletIndex];
    [_walletSelector.button setTitle:wallet.strName forState:UIControlStateNormal];
    _walletSelector.selectedItemIndex = _selectedWalletIndex;
}

@end