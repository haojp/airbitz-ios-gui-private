//
//  SendConfirmationViewController.m
//  AirBitz
//
//  Created by Carson Whitsett on 3/27/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "SendConfirmationViewController.h"
#import "ABC.h"
#import "ConfirmationSliderView.h"
#import "User.h"
#import "CalculatorView.h"
#import "SendStatusViewController.h"
#import "TransactionDetailsViewController.h"
#import "CoreBridge.h"
#import "Util.h"
#import "CommonTypes.h"

@interface SendConfirmationViewController () <UITextFieldDelegate, ConfirmationSliderViewDelegate, CalculatorViewDelegate, TransactionDetailsViewControllerDelegate>
{
	ConfirmationSliderView              *_confirmationSlider;
	UITextField                         *_selectedTextField;
	SendStatusViewController            *_sendStatusController;
	TransactionDetailsViewController    *_transactionDetailsController;
	BOOL                                _callbackSuccess;
	NSString                            *_strReason;
	Transaction                         *_completedTransaction;	// nil until sendTransaction is successfully completed
}

@property (weak, nonatomic) IBOutlet UIView                 *viewDisplayArea;

@property (weak, nonatomic) IBOutlet UIImageView            *imageTopEmboss;
@property (weak, nonatomic) IBOutlet UILabel                *labelSendFromTitle;
@property (weak, nonatomic) IBOutlet UILabel                *labelSendFrom;
@property (weak, nonatomic) IBOutlet UILabel                *labelSendToTitle;
@property (nonatomic, weak) IBOutlet UILabel                *addressLabel;
@property (weak, nonatomic) IBOutlet UIView                 *viewBTC;
@property (nonatomic, weak) IBOutlet UILabel                *amountBTCSymbol;
@property (nonatomic, weak) IBOutlet UILabel                *amountBTCLabel;
@property (nonatomic, weak) IBOutlet UITextField            *amountBTCTextField;
@property (weak, nonatomic) IBOutlet UIView                 *viewUSD;
@property (nonatomic, weak) IBOutlet UILabel                *amountUSDSymbol;
@property (nonatomic, weak) IBOutlet UILabel                *amountUSDLabel;
@property (nonatomic, weak) IBOutlet UITextField            *amountUSDTextField;
@property (nonatomic, weak) IBOutlet UIButton               *maxAmountButton;
@property (nonatomic, weak) IBOutlet UILabel                *conversionLabel;
@property (weak, nonatomic) IBOutlet UILabel                *labelPINTitle;
@property (weak, nonatomic) IBOutlet UILabel                *txFeesLabel;
@property (weak, nonatomic) IBOutlet UIImageView            *imagePINEmboss;
@property (nonatomic, weak) IBOutlet UITextField            *withdrawlPIN;
@property (nonatomic, weak) IBOutlet UIView                 *confirmSliderContainer;
@property (nonatomic, weak) IBOutlet UIButton               *btn_alwaysConfirm;
@property (weak, nonatomic) IBOutlet UILabel                *labelAlwaysConfirm;
@property (nonatomic, weak) IBOutlet CalculatorView         *keypadView;

@property (nonatomic, strong) UIButton  *buttonBlocker;

@end

@implementation SendConfirmationViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
	{
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    //
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] 
        initWithTarget:self
                action:@selector(dismissKeyboard)];

    [self.view addGestureRecognizer:tap];

    // resize ourselves to fit in area
    [Util resizeView:self.view withDisplayView:self.viewDisplayArea];

    self.keypadView.currencyNum = self.wallet.currencyNum;
	self.withdrawlPIN.delegate = self;
	self.amountBTCTextField.delegate = self;
	self.amountUSDTextField.delegate = self;
	self.keypadView.delegate = self;
	self.amountBTCTextField.inputView = self.keypadView;
	self.amountUSDTextField.inputView = self.keypadView;

    // make sure the edit fields are in front of the blocker
    [self.viewDisplayArea bringSubviewToFront:self.amountBTCTextField];
    [self.viewDisplayArea bringSubviewToFront:self.amountUSDTextField];
    [self.viewDisplayArea bringSubviewToFront:self.withdrawlPIN];

	[self setWalletLabel];
	
	CGRect frame = self.keypadView.frame;
	frame.origin.y = self.view.frame.size.height;
	self.keypadView.frame = frame;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(myTextDidChange:)
												 name:UITextFieldTextDidChangeNotification
											   object:self.withdrawlPIN];
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(exchangeRateUpdate:)
                                                 name:NOTIFICATION_EXCHANGE_RATE_CHANGE
                                               object:nil];
				
	_confirmationSlider = [ConfirmationSliderView CreateInsideView:self.confirmSliderContainer withDelegate:self];

    [self updateDisplayLayout];
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)myTextDidChange:(NSNotification *)notification
{
	if(notification.object == self.withdrawlPIN)
	{
		if(self.withdrawlPIN.text.length == 4)
		{
			[self.withdrawlPIN resignFirstResponder];
		}
	}
	else
	{
		NSLog(@"Text changed for some field");
	}
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	self.amountBTCLabel.text = [User Singleton].denominationLabel; 
    self.amountBTCTextField.text = [CoreBridge formatSatoshi:self.amountToSendSatoshi withSymbol:false];
    self.conversionLabel.text = [CoreBridge conversionString:self.wallet];
    
    NSString *prefix;
    NSString *suffix;
    
    if ([self.sendToAddress length] > 10)
    {
        prefix = [self.sendToAddress substringToIndex:5];
        suffix = [self.sendToAddress substringFromIndex: [self.sendToAddress length] - 5];
        self.addressLabel.text = [NSString stringWithFormat:@"%@...%@", prefix, suffix];
    }
    else
    {
        self.addressLabel.text = self.sendToAddress;
    }
    
    
    
	
	tABC_CC result;
	double currency;
	tABC_Error error;
	
	result = ABC_SatoshiToCurrency([[User Singleton].name UTF8String], [[User Singleton].password UTF8String],
                                   self.amountToSendSatoshi, &currency, self.wallet.currencyNum, &error);
				
	if(result == ABC_CC_Ok)
	{
		self.amountUSDTextField.text = [NSString stringWithFormat:@"%.2f", currency];
	}
    [self updateFeeFieldContents];
	
	if (self.amountToSendSatoshi)
	{
		[self.withdrawlPIN becomeFirstResponder];
	}
	else
	{
		self.amountUSDTextField.text = nil;
		self.amountBTCTextField.text = nil;
		[self.amountUSDTextField becomeFirstResponder];
	}
    [self exchangeRateUpdate:nil]; 
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Notification Handlers

- (void)exchangeRateUpdate: (NSNotification *)notification
{
    NSLog(@"Updating exchangeRateUpdate");
	[self updateTextFieldContents];
}

#pragma mark - Actions Methods

- (IBAction)Back:(id)sender
{
	[self.withdrawlPIN resignFirstResponder];
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 CGRect frame = self.view.frame;
		 frame.origin.x = frame.size.width;
		 self.view.frame = frame;
	 }
	 completion:^(BOOL finished)
	 {
		 [self.delegate sendConfirmationViewControllerDidFinish:self];
	 }];
}

- (IBAction)alwaysConfirm:(UIButton *)sender
{
	if(sender.selected)
	{
		sender.selected = NO;
	}
	else
	{
		sender.selected = YES;
	}
}

- (IBAction)selectMaxAmount
{
    if (self.wallet != nil)
    {
        _selectedTextField = self.amountBTCTextField;
        self.amountToSendSatoshi = MAX(self.wallet.balance, 0);
        self.amountBTCTextField.text = [CoreBridge formatSatoshi:self.amountToSendSatoshi 
                                                      withSymbol:false
                                                overrideDecimals:[CoreBridge currencyDecimalPlaces]];
    }
    [self updateTextFieldContents];
}

- (void)dismissKeyboard
{
	[self.withdrawlPIN resignFirstResponder];
	[self.amountUSDTextField resignFirstResponder];
	[self.amountBTCTextField resignFirstResponder];
}

- (void)updateDisplayLayout
{
    // if we are on a smaller screen
    if (!IS_IPHONE5)
    {
        // be prepared! lots and lots of magic numbers here to jam the controls to fit on a small screen

        CGRect frame;

        frame = self.imageTopEmboss.frame;
        frame.size.height = 150;
        frame.origin.y = 0;
        self.imageTopEmboss.frame = frame;

        frame = self.labelSendFromTitle.frame;
        frame.origin.y = 2;
        self.labelSendFromTitle.frame = frame;

        frame = self.labelSendFrom.frame;
        frame.origin.y = self.labelSendFromTitle.frame.origin.y;
        self.labelSendFrom.frame = frame;

        frame = self.labelSendToTitle.frame;
        frame.origin.y = self.labelSendFromTitle.frame.origin.y + self.labelSendFromTitle.frame.size.height + 0;
        self.labelSendToTitle.frame = frame;

        frame = self.addressLabel.frame;
        frame.origin.y = self.labelSendToTitle.frame.origin.y;
        self.addressLabel.frame = frame;

        frame = self.viewBTC.frame;
        frame.origin.y = self.labelSendToTitle.frame.origin.y + self.labelSendToTitle.frame.size.height + 1;
        self.viewBTC.frame = frame;

        frame = self.amountBTCTextField.frame;
        frame.origin.y = self.viewBTC.frame.origin.y + 7;
        self.amountBTCTextField.frame = frame;

        frame = self.viewUSD.frame;
        frame.origin.y = self.viewBTC.frame.origin.y + self.viewBTC.frame.size.height + (-3);
        self.viewUSD.frame = frame;

        frame = self.amountUSDTextField.frame;
        frame.origin.y = self.viewUSD.frame.origin.y + 7;
        self.amountUSDTextField.frame = frame;

        frame = self.conversionLabel.frame;
        frame.origin.y = self.viewUSD.frame.origin.y + self.viewUSD.frame.size.height + (-6);
        self.conversionLabel.frame = frame;

        frame = self.imagePINEmboss.frame;
        frame.origin.y = self.imageTopEmboss.frame.origin.y + self.imageTopEmboss.frame.size.height + 4;
        self.imagePINEmboss.frame = frame;

        frame = self.labelPINTitle.frame;
        frame.origin.y = self.imagePINEmboss.frame.origin.y + 11;
        self.labelPINTitle.frame = frame;

        frame = self.withdrawlPIN.frame;
        frame.origin.y = self.imagePINEmboss.frame.origin.y + 5;
        self.withdrawlPIN.frame = frame;

        frame = self.confirmSliderContainer.frame;
        frame.origin.y = self.imagePINEmboss.frame.origin.y + self.imagePINEmboss.frame.size.height + 30;
        self.confirmSliderContainer.frame = frame;

        frame = self.btn_alwaysConfirm.frame;
        frame.origin.y = self.confirmSliderContainer.frame.origin.y + self.confirmSliderContainer.frame.size.height + 25;
        self.btn_alwaysConfirm.frame = frame;

        frame = self.labelAlwaysConfirm.frame;
        frame.origin.y = self.btn_alwaysConfirm.frame.origin.y + self.btn_alwaysConfirm.frame.size.height + 0;
        self.labelAlwaysConfirm.frame = frame;
    }
}

- (void)showSendStatus
{
	UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
	_sendStatusController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SendStatusViewController"];



	CGRect frame = self.view.bounds;
	//frame.origin.x = frame.size.width;
	_sendStatusController.view.frame = frame;
	[self.view addSubview:_sendStatusController.view];
	_sendStatusController.view.alpha = 0.0;

	_sendStatusController.messageLabel.text = NSLocalizedString(@"Sending...", @"status message");

	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 _sendStatusController.view.alpha = 1.0;
	 }
     completion:^(BOOL finished)
	 {
	 }];
}

- (void)hideSendStatus
{
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
    {
        _sendStatusController.view.alpha = 0.0;
    }
    completion:^(BOOL finished)
    {
        [_sendStatusController.view removeFromSuperview];
        _sendStatusController = nil;
    }];
}

- (void)initiateSendRequest
{
	tABC_Error Error;
	tABC_CC result;
	tABC_WalletInfo **aWalletInfo = NULL;
    unsigned int nCount;
	double currency;
	
	result = ABC_SatoshiToCurrency([[User Singleton].name UTF8String], [[User Singleton].password UTF8String],
                                   self.amountToSendSatoshi, &currency, self.wallet.currencyNum, &Error);
	if (result == ABC_CC_Ok)
	{
		ABC_GetWallets([[User Singleton].name UTF8String], [[User Singleton].password UTF8String], &aWalletInfo, &nCount, &Error);
		
		if (nCount)
		{
			tABC_TxDetails Details;
			Details.amountSatoshi = self.amountToSendSatoshi;
			Details.amountCurrency = currency;
			Details.amountFeesAirbitzSatoshi = 5000;
			Details.amountFeesMinersSatoshi = 10000;
			Details.szName = "Anonymous";
			Details.szCategory = "";
			Details.szNotes = "";
			Details.attributes = 0x2;
			
			tABC_WalletInfo *info = aWalletInfo[self.selectedWalletIndex];
			
			result = ABC_InitiateSendRequest([[User Singleton].name UTF8String],
										[[User Singleton].password UTF8String],
										info->szUUID,
										[self.sendToAddress UTF8String],
										&Details,
										ABC_SendConfirmation_Callback,
										(__bridge void *)self,
										&Error);
			if (result == ABC_CC_Ok)
			{
				[self showSendStatus];
			}
			else
			{
				[Util printABC_Error:&Error];
			}
			
			ABC_FreeWalletInfoArray(aWalletInfo, nCount);
		}
	}
}

- (void)setWalletLabel
{
	tABC_WalletInfo **aWalletInfo = NULL;
    unsigned int nCount;
	tABC_Error Error;

    ABC_GetWallets([[User Singleton].name UTF8String], [[User Singleton].password UTF8String], &aWalletInfo, &nCount, &Error);
    [Util printABC_Error:&Error];

	if (nCount > self.selectedWalletIndex)
	{
		tABC_WalletInfo *pInfo = aWalletInfo[self.selectedWalletIndex];
        
        NSMutableString *coinFormatted = [[NSMutableString alloc] init];
        [coinFormatted appendFormat:@"%@ (%@)",
         [NSString stringWithUTF8String:pInfo->szName],
         [CoreBridge formatSatoshi:pInfo->balanceSatoshi]];

        self.labelSendFrom.text = coinFormatted;
	}

    ABC_FreeWalletInfoArray(aWalletInfo, nCount);
}

- (void)launchTransactionDetailsWithTransaction:(Transaction *)transaction
{
	UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
	_transactionDetailsController = [mainStoryboard instantiateViewControllerWithIdentifier:@"TransactionDetailsViewController"];
	
	_transactionDetailsController.delegate = self;
	_transactionDetailsController.transaction = transaction;
	_transactionDetailsController.wallet = self.wallet;
    _transactionDetailsController.bOldTransaction = NO;
    _transactionDetailsController.transactionDetailsMode = TD_MODE_SENT;
	CGRect frame = self.view.bounds;
	frame.origin.x = frame.size.width;
	_transactionDetailsController.view.frame = frame;
	
	//transactionDetailsController.nameLabel.text = self.nameLabel;

	
	[self.view addSubview:_transactionDetailsController.view];
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 _transactionDetailsController.view.frame = self.view.bounds;
	 }
					 completion:^(BOOL finished)
	 {
	 }];
	
}

- (void)failedToSend:(NSArray *)params
{
    NSString *title = params[0];
    NSString *message = params[1];
    UIAlertView *alert = [[UIAlertView alloc]
                            initWithTitle:title
                            message:message
                            delegate:nil
                            cancelButtonTitle:@"OK"
                            otherButtonTitles:nil];
    [alert show];
    [self hideSendStatus];
}

- (void)sendBitcoinComplete:(NSString *)transactionID
{
	[self performSelector:@selector(showTransactionDetails:) withObject:transactionID afterDelay:3.0]; //show sending screen for 3 seconds
}

- (void)showTransactionDetails:(NSString *)transactionID
{
	if (_callbackSuccess)
	{
		tABC_WalletInfo **aWalletInfo = NULL;
		tABC_Error error;
		tABC_TxInfo *txInfo;
		//tABC_TxDetails *details;
		unsigned int nCount;

		ABC_GetWallets([[User Singleton].name UTF8String], [[User Singleton].password UTF8String], &aWalletInfo, &nCount, &error);

		if (nCount)
		{
			tABC_WalletInfo *walletInfo = aWalletInfo[self.selectedWalletIndex];

			NSLog(@"Transaction complete with Transaction ID: %@", transactionID);


			tABC_CC result = ABC_GetTransaction([[User Singleton].name UTF8String],
                                                [[User Singleton].password UTF8String],
                                                walletInfo->szUUID,
                                                [transactionID UTF8String],
                                                &txInfo,
                                                &error);

			if (result == ABC_CC_Ok)
			{
				_completedTransaction = [[Transaction alloc] init];

				NSString *address;
				if(txInfo->countOutputs)
				{
					address = [NSString stringWithUTF8String:txInfo->aOutputs[0]->szAddress];
				}
				else
				{
					address = @"NO ADDRESS";
				}

				_completedTransaction.strID = transactionID;
				_completedTransaction.strWalletUUID = [NSString stringWithUTF8String:walletInfo->szUUID];
				_completedTransaction.strWalletName = [NSString stringWithUTF8String:walletInfo->szName];
				_completedTransaction.strAddress = address;
				_completedTransaction.date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)txInfo->timeCreation];
				_completedTransaction.bConfirmed = NO;
				_completedTransaction.confirmations = 0;

				_completedTransaction.amountSatoshi = txInfo->pDetails->amountSatoshi;
				_completedTransaction.balance = 0;
				_completedTransaction.strCategory = [NSString stringWithUTF8String:txInfo->pDetails->szCategory];
				_completedTransaction.strNotes = [NSString stringWithUTF8String:txInfo->pDetails->szNotes];

				ABC_FreeWalletInfoArray(aWalletInfo, nCount);
				ABC_FreeTransaction(txInfo);
				
				[self launchTransactionDetailsWithTransaction:_completedTransaction];
			}
		}
	}
	else
	{
		NSLog(@"Error: %@", _strReason);
	}
	
}

- (void)updateTextFieldContents
{
	double currency;
    int64_t satoshi;
	tABC_Error error;

	if (_selectedTextField == self.amountBTCTextField)
	{
        self.amountToSendSatoshi = [CoreBridge denominationToSatoshi: self.amountBTCTextField.text];
		if (ABC_SatoshiToCurrency([[User Singleton].name UTF8String], [[User Singleton].password UTF8String],
                                  self.amountToSendSatoshi, &currency, self.wallet.currencyNum, &error) == ABC_CC_Ok)
			self.amountUSDTextField.text = [NSString stringWithFormat:@"%.2f", currency];
	}
	else if (_selectedTextField == self.amountUSDTextField)
	{
        currency = [self.amountUSDTextField.text doubleValue];
		if (ABC_CurrencyToSatoshi([[User Singleton].name UTF8String], [[User Singleton].password UTF8String],
                                  currency, self.wallet.currencyNum, &satoshi, &error) == ABC_CC_Ok)
		{
			self.amountToSendSatoshi = satoshi;
            self.amountBTCTextField.text = [CoreBridge formatSatoshi:satoshi
                                                          withSymbol:false
                                                    overrideDecimals:[CoreBridge currencyDecimalPlaces]];
		}
	}
    [self updateFeeFieldContents];
}

- (void)updateFeeFieldContents
{
    int64_t fees = 0;
	tABC_Error error;
    if ([CoreBridge calcSendFees:self.wallet.strUUID
                          sendTo:self.sendToAddress
                    amountToSend:self.amountToSendSatoshi
                  storeResultsIn:&fees])
    {
        double currencyFees = 0.0;
        self.conversionLabel.textColor = [UIColor whiteColor];
        self.amountBTCTextField.textColor = [UIColor whiteColor];
        self.amountUSDTextField.textColor = [UIColor whiteColor];

        NSMutableString *coinFeeString = [[NSMutableString alloc] init];
        NSMutableString *fiatFeeString = [[NSMutableString alloc] init];
        [coinFeeString appendString:@"+ "];
        [coinFeeString appendString:[CoreBridge formatSatoshi:fees withSymbol:false]];
        [coinFeeString appendString:@" "];
        [coinFeeString appendString:[User Singleton].denominationLabel];

        if (ABC_SatoshiToCurrency([[User Singleton].name UTF8String], [[User Singleton].password UTF8String], 
                                  fees, &currencyFees, self.wallet.currencyNum, &error) == ABC_CC_Ok)
        {
            [fiatFeeString appendString:@"+ "];
            [fiatFeeString appendString:[CoreBridge formatCurrency:currencyFees
                                                   withCurrencyNum:self.wallet.currencyNum
                                                        withSymbol:false]];
            [fiatFeeString appendString:@" "];
            [fiatFeeString appendString:self.wallet.currencyAbbrev];
        }
        self.amountBTCLabel.text = coinFeeString; 
        self.amountUSDLabel.text = fiatFeeString;
        self.conversionLabel.text = [CoreBridge conversionString:self.wallet];
    }
    else
    {
        NSString *message = NSLocalizedString(@"Insufficient funds", nil);
        self.conversionLabel.text = message;
        self.conversionLabel.textColor = [UIColor redColor];
        self.amountBTCTextField.textColor = [UIColor redColor];
        self.amountUSDTextField.textColor = [UIColor redColor];
    }
    [self alineTextFields:self.amountBTCLabel alignWith:self.amountBTCTextField];
    [self alineTextFields:self.amountUSDLabel alignWith:self.amountUSDTextField];
}

- (void)alineTextFields:(UILabel *)child alignWith:(UITextField *)parent
{
    NSDictionary *attributes = @{NSFontAttributeName: parent.font};
    CGSize parentText = [parent.text sizeWithAttributes:attributes];

    CGRect parentField = parent.frame;
    CGRect childField = child.frame;
    int origX = childField.origin.x;
    int newX = parentField.origin.x + parentText.width;
    int newWidth = childField.size.width + (origX - newX);
    childField.origin.x = newX;
    childField.size.width = newWidth;
    child.frame = childField;
}


#pragma mark - UITextField delegates

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	_selectedTextField = textField;
    if (_selectedTextField == self.amountBTCTextField)
        self.keypadView.calcMode = CALC_MODE_COIN;
    else if (_selectedTextField == self.amountUSDTextField)
        self.keypadView.calcMode = CALC_MODE_FIAT;
	self.keypadView.textField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
}

#pragma mark - ConfirmationSlider delegates

- (void)ConfirmationSliderDidConfirm:(ConfirmationSliderView *)controller
{
	//make sure PIN is good
	
	if (self.withdrawlPIN.text.length)
	{
		//make sure the entered PIN matches the PIN stored in the Core
		tABC_Error error;
		char *szPIN = NULL;
		
		ABC_GetPIN([[User Singleton].name UTF8String], [[User Singleton].password UTF8String], &szPIN, &error);
		[Util printABC_Error:&error];
		NSLog(@"current PIN: %s", szPIN);
		if (szPIN)
		{
			NSString *storedPIN = [NSString stringWithUTF8String:szPIN];
			if ([self.withdrawlPIN.text isEqualToString:storedPIN])
			{
				NSLog(@"SUCCESS!");
				[self initiateSendRequest];
			}
			else
			{
				UIAlertView *alert = [[UIAlertView alloc]
									  initWithTitle:NSLocalizedString(@"Incorrect PIN", nil)
									  message:NSLocalizedString(@"You must enter the correct withdrawl PIN in order to proceed", nil)
									  delegate:self
									  cancelButtonTitle:@"OK"
									  otherButtonTitles:nil];
				[alert show];
			}
			free(szPIN);
		}
		
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc]
							  initWithTitle:NSLocalizedString(@"Incorrect PIN", nil)
							  message:NSLocalizedString(@"You must enter your withdrawl PIN in order to proceed", nil)
							  delegate:self
							  cancelButtonTitle:@"OK"
							  otherButtonTitles:nil];
		[alert show];
		
	}
	[_confirmationSlider resetIn:1.0];
}

#pragma mark - Calculator delegates

- (void)CalculatorDone:(CalculatorView *)calculator
{
	[self.amountUSDTextField resignFirstResponder];
	[self.amountBTCTextField resignFirstResponder];
	[self.withdrawlPIN becomeFirstResponder];
}

- (void)CalculatorValueChanged:(CalculatorView *)calculator
{
	[self updateTextFieldContents];
}

#pragma mark - TransactionDetailsViewController delegates

- (void)TransactionDetailsViewControllerDone:(TransactionDetailsViewController *)controller
{
	[controller.view removeFromSuperview];
	_transactionDetailsController = nil;

	[_sendStatusController.view removeFromSuperview];
	_sendStatusController = nil;

	[self.delegate sendConfirmationViewControllerDidFinish:self];
}

#pragma mark - ABC Callbacks

void ABC_SendConfirmation_Callback(const tABC_RequestResults *pResults)
{
    if (pResults)
    {
        SendConfirmationViewController *controller = (__bridge id)pResults->pData;
        controller->_callbackSuccess = (BOOL)pResults->bSuccess;
        controller->_strReason = [NSString stringWithFormat:@"%s", pResults->errorInfo.szDescription];
		
        if (pResults->requestType == ABC_RequestType_SendBitcoin)
        {
            if (pResults->bSuccess)
            {
                [controller performSelectorOnMainThread:@selector(sendBitcoinComplete:)
                                             withObject:[NSString stringWithUTF8String:pResults->pRetData]
                                          waitUntilDone:FALSE];
                free(pResults->pRetData);
            } else {
                free(pResults->pRetData);
                NSString *title = NSLocalizedString(@"Error during send", nil);
                NSString *message;
                if (pResults->errorInfo.code == ABC_CC_InsufficientFunds) {
                    message =
                        NSLocalizedString(@"You do not have enough funds to send this transaction.", nil);
                } else if (pResults->errorInfo.code == ABC_CC_ServerError) {
                    message =
                        NSLocalizedString([NSString stringWithUTF8String:pResults->errorInfo.szDescription], nil);
                } else {
                    message =
                        NSLocalizedString(@"There was an error when we were trying to send the funds. Please try again later.", nil);
                }
                NSArray *params = [NSArray arrayWithObjects: title, message, nil];
                [controller performSelectorOnMainThread:@selector(failedToSend:) 
                                             withObject:params
                                          waitUntilDone:FALSE];
            }
        }
    }
}

@end
