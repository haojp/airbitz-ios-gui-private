//
//  SettingsViewController.m
//  AirBitz
//
//  Created by Carson Whitsett on 2/28/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "SettingsViewController.h"
#import "RadioButtonCell.h"
#import "ABC.h"
#import "User.h"
#import "PlainCell.h"
#import "TextFieldCell.h"
#import "BooleanCell.h"
#import "ButtonCell.h"
#import "ButtonOnlyCell.h"
#import "SignUpViewController.h"

#define SECTION_BITCOIN_DENOMINATION    0
#define SECTION_USERNAME                1
#define SECTION_OPTIONS                 2
#define SECTION_DEFAULT_EXCHANGE        3
#define SECTION_LOGOUT                  4
#define SECTION_COUNT                   5

#define DENOMINATION_CHOICES            3

#define ROW_PASSWORD                    0
#define ROW_PIN                         1
#define ROW_RECOVERY_QUESTIONS          2

typedef struct sDenomination
{
    char *szLabel;
    int64_t satoshi;
} tDenomination ;

tDenomination gaDenominations[DENOMINATION_CHOICES] = {
    {
        "Bitcoin", 100000000
    },
    {
        "mBitcoin", 100000
    },
    {
        "uBitcoin", 100
    }
};


@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate, BooleanCellDelegate, ButtonCellDelegate, TextFieldCellDelegate, ButtonOnlyCellDelegate, SignUpViewControllerDelegate>
{
	tABC_AccountSettings    *_pAccountSettings;
	TextFieldCell           *_activeTextFieldCell;
	UITapGestureRecognizer  *_tapGesture;
    SignUpViewController    *_signUpController;
}

@property (nonatomic, weak) IBOutlet UITableView *tableView;

@end

@implementation SettingsViewController

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
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
	self.tableView.delaysContentTouches = NO;
	
	tABC_Error Error;
    Error.code = ABC_CC_Ok;

    _pAccountSettings = NULL;
    ABC_LoadAccountSettings([[User Singleton].name UTF8String],
                            [[User Singleton].password UTF8String],
                            &_pAccountSettings,
                            &Error);
    [self printABC_Error:&Error];
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	
}

-(void)dealloc
{
	if(_pAccountSettings)
	{
		ABC_FreeAccountSettings(_pAccountSettings);
	}
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Misc Methods

// looks for the denomination choice in the settings
- (NSInteger)denominationChoice
{
    NSInteger retVal = 0;

    if (_pAccountSettings)
    {
        for (int i = 0; i < DENOMINATION_CHOICES; i++)
        {
            if (_pAccountSettings->bitcoinDenomination.satoshi == gaDenominations[i].satoshi)
            {
                retVal = i;
                break;
            }
        }
    }

    return retVal;
}

// modifies the denomination choice in the settings
- (void)setDenominationChoice:(NSInteger)nChoice
{
    if (_pAccountSettings)
    {
        // set the new values
        _pAccountSettings->bitcoinDenomination.satoshi = gaDenominations[nChoice].satoshi;
        if (_pAccountSettings->bitcoinDenomination.szLabel != NULL)
        {
            free(_pAccountSettings->bitcoinDenomination.szLabel);
        }
        _pAccountSettings->bitcoinDenomination.szLabel = strdup(gaDenominations[nChoice].szLabel);

        // update the settings in the core
        tABC_Error Error;
        ABC_UpdateAccountSettings([[User Singleton].name UTF8String],
                                  [[User Singleton].password UTF8String],
                                  _pAccountSettings,
                                  &Error);
        [self printABC_Error:&Error];
    }
}

- (void)bringUpSignUpViewInMode:(tSignUpMode)mode
{
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
    _signUpController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SignUpViewController"];

    _signUpController.mode = mode;
    _signUpController.delegate = self;

    CGRect frame = self.view.bounds;
    frame.origin.x = frame.size.width;
    _signUpController.view.frame = frame;
    [self.view addSubview:_signUpController.view];

    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^
     {
         _signUpController.view.frame = self.view.bounds;
     }
                     completion:^(BOOL finished)
     {
     }];
}

- (void)printABC_Error:(const tABC_Error *)pError
{
    if (pError)
    {
        if (pError->code != ABC_CC_Ok)
        {
            printf("Code: %d, Desc: %s, Func: %s, File: %s, Line: %d\n",
                   pError->code,
                   pError->szDescription,
                   pError->szSourceFunc,
                   pError->szSourceFile,
                   pError->nSourceLine
                   );
        }
    }
}

#pragma mark - Action Methods

- (IBAction)Back
{
	[self.delegate SettingsViewControllerDone:self];
}

- (IBAction)Info
{
	NSLog(@"Info button pressed");
}

- (void)booleanCell:(BooleanCell *)cell switchToggled:(UISwitch *)theSwitch
{
	NSLog(@"Switch toggled:%i", theSwitch.on);
}

- (void)buttonCellButtonPressed:(ButtonCell *)cell
{
	NSLog(@"Button was pressed");
}

- (void)buttonOnlyCellButtonPressed:(ButtonOnlyCell *)cell
{
	NSLog(@"Change Categories");
	//log out for now
	[[User Singleton] clear];
	[self.delegate SettingsViewControllerDone:self];
}

#pragma mark - textFieldCell delegates

- (void)textFieldCellBeganEditing:(TextFieldCell *)cell
{
	//scroll the tableView so that this cell is above the keyboard
	_activeTextFieldCell = cell;
	if(!_tapGesture)
	{
		_tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
		[self.tableView	addGestureRecognizer:_tapGesture];
	}
}

- (void) handleTapFrom: (UITapGestureRecognizer *)recognizer
{
    //Code to handle the gesture
	[self.view endEditing:YES];
	[self.tableView removeGestureRecognizer:_tapGesture];
	_tapGesture = nil;
}

-(void)textFieldCellEndEditing:(TextFieldCell *)cell
{
	[_activeTextFieldCell resignFirstResponder];
	_activeTextFieldCell = nil;
}

#pragma mark - keyboard callbacks

- (void)keyboardWillShow:(NSNotification *)notification
{
	if (_activeTextFieldCell)
	{
		//NSDictionary *userInfo = [notification userInfo];
		//CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
		
		//CGRect ownFrame = [self.view.window convertRect:keyboardFrame toView:self.view];
		//NSLog(@"Own frame: %f, %f, %f, %f", ownFrame.origin.x, ownFrame.origin.y, ownFrame.size.width, ownFrame.size.height);
		//NSLog(@"Table frame: %f, %f, %f, %f", self.tableView.frame.origin.x, self.tableView.frame.origin.y, self.tableView.frame.size.width, self.tableView.frame.size.height);
		CGPoint p = CGPointMake(0, 165.0);
		
		[self.tableView setContentOffset:p animated:YES];
	}
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	if (_activeTextFieldCell)
	{
		_activeTextFieldCell = nil;
	}
}

#pragma mark - Custom Table Cells

- (RadioButtonCell *)getRadioButtonCellForTableView:(UITableView *)tableView withImage:(UIImage *)bkgImage andIndexPath:(NSIndexPath *)indexPath
{
	RadioButtonCell *cell;
	static NSString *cellIdentifier = @"RadioButtonCell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[RadioButtonCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	cell.bkgImage.image = bkgImage;
	
	if (indexPath.row == 0)
	{
		cell.name.text = NSLocalizedString(@"Bitcoin", @"settings text");
	}
	if (indexPath.row == 1)
	{
		cell.name.text = NSLocalizedString(@"mBitcoin = (0.001 Bitcoin)", @"settings text");
	}
	if (indexPath.row == 2)
	{
		cell.name.text = NSLocalizedString(@"uBitcoin = (0.000001 Bitcoin)", @"settings text");
	}
	cell.radioButton.image = [UIImage imageNamed:(indexPath.row == [self denominationChoice] ? @"btn_selected" : @"btn_unselected")];
	return cell;
}

- (PlainCell *)getPlainCellForTableView:(UITableView *)tableView withImage:(UIImage *)bkgImage andIndexPath:(NSIndexPath *)indexPath
{
	PlainCell *cell;
	static NSString *cellIdentifier = @"PlainCell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[PlainCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	cell.bkgImage.image = bkgImage;
	
	if (indexPath.section == SECTION_USERNAME)
	{
		if (indexPath.row == 0)
		{
			cell.name.text = NSLocalizedString(@"Change password", @"settings text");
		}
		if (indexPath.row == 1)
		{
			cell.name.text = NSLocalizedString(@"Change withdrawal PIN", @"settings text");
		}
		if (indexPath.row == 2)
		{
			cell.name.text = NSLocalizedString(@"Change recovery questions", @"settings text");
		}
	}
	
	return cell;
}

- (TextFieldCell *)getTextFieldCellForTableView:(UITableView *)tableView withImage:(UIImage *)bkgImage andIndexPath:(NSIndexPath *)indexPath
{
	TextFieldCell *cell;
	static NSString *cellIdentifier = @"TextFieldCell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[TextFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	cell.bkgImage.image = bkgImage;
	cell.delegate = self;
	if (indexPath.section == SECTION_USERNAME)
	{
		if(indexPath.row == 3)
		{
			cell.name.placeholder = NSLocalizedString(@"First Name (optional)", @"settings text");
		}
		if(indexPath.row == 4)
		{
			cell.name.placeholder = NSLocalizedString(@"Last Name (optional)", @"settings text");
		}
		if(indexPath.row == 5)
		{
			cell.name.placeholder = NSLocalizedString(@"Nickname / handle", @"settings text");
		}
	}
	
	return cell;
}

- (BooleanCell *)getBooleanCellForTableView:(UITableView *)tableView withImage:(UIImage *)bkgImage andIndexPath:(NSIndexPath *)indexPath
{
	BooleanCell *cell;
	static NSString *cellIdentifier = @"BooleanCell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[BooleanCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	cell.bkgImage.image = bkgImage;
	cell.delegate = self;
	if (indexPath.section == 2)
	{
		if(indexPath.row == 0)
		{
			cell.name.text = NSLocalizedString(@"Send name on payment", @"settings text");
		}
	}
	
	return cell;
}

- (ButtonCell *)getButtonCellForTableView:(UITableView *)tableView withImage:(UIImage *)bkgImage andIndexPath:(NSIndexPath *)indexPath
{
	ButtonCell *cell;
	static NSString *cellIdentifier = @"ButtonCell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[ButtonCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	cell.bkgImage.image = bkgImage;
	cell.delegate = self;
	if (indexPath.section == 2)
	{
		if (indexPath.row == 1)
		{
			cell.name.text = NSLocalizedString(@"Auto log off after", @"settings text");
		}
		if (indexPath.row == 2)
		{
			cell.name.text = NSLocalizedString(@"Language", @"settings text");
		}
		if (indexPath.row == 3)
		{
			cell.name.text = NSLocalizedString(@"Default Currency", @"settings text");
		}
	}
	if (indexPath.section == 3)
	{
		if (indexPath.row == 0)
		{
			cell.name.text = NSLocalizedString(@"US dollar", @"settings text");
		}
		if (indexPath.row == 1)
		{
			cell.name.text = NSLocalizedString(@"Canadian dollar", @"settings text");
		}
		if (indexPath.row == 2)
		{
			cell.name.text = NSLocalizedString(@"Euro", @"settings text");
		}
		if (indexPath.row == 3)
		{
			cell.name.text = NSLocalizedString(@"Mexican Peso", @"settings text");
		}
		if (indexPath.row == 4)
		{
			cell.name.text = NSLocalizedString(@"Yuan", @"settings text");
		}
	}
	return cell;
}

- (ButtonOnlyCell *)getButtonOnlyCellForTableView:(UITableView *)tableView withIndexPath:(NSIndexPath *)indexPath
{
	ButtonOnlyCell *cell;
	static NSString *cellIdentifier = @"ButtonOnlyCell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[ButtonOnlyCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	cell.delegate = self;
	//[cell.button setTitle:NSLocalizedString(@"Change Categories", @"settings text") forState:UIControlStateNormal]; //cw temp replace this button with log out functionality
	[cell.button setTitle:NSLocalizedString(@"Log Out", @"settings text") forState:UIControlStateNormal];
	
	return cell;
}

#pragma mark - UITableView delegates

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch(section)
	{
        case SECTION_BITCOIN_DENOMINATION:
            return 3;
            break;

        case SECTION_USERNAME:
            return 6;
            break;

        case SECTION_OPTIONS:
            return 4;
            break;

        case SECTION_DEFAULT_EXCHANGE:
            return 5;
            break;

        case SECTION_LOGOUT:
            return 1;
            break;
            
        default:
            return 0;
            break;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ((indexPath.section == SECTION_OPTIONS) || (indexPath.section == SECTION_LOGOUT))
	{
		return 47.0;
	}

	return 37.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if (section == SECTION_LOGOUT)
	{
		return 0.0;
	}

	return 37.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	static NSString *cellIdentifier = @"SettingsSectionHeader";
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		[NSException raise:@"headerView == nil.." format:@"No cells with matching CellIdentifier loaded from your storyboard"];
	}
	UILabel *label = (UILabel *)[cell viewWithTag:1];
	if (section == SECTION_BITCOIN_DENOMINATION)
	{
		label.text = NSLocalizedString(@"BITCOIN DENOMINATION", @"section header in settings table");
	}
	if (section == SECTION_USERNAME)
	{
		label.text = NSLocalizedString(@"USERNAME", @"section header in settings table");
	}
	if (section == SECTION_OPTIONS)
	{
		label.text = @" ";
	}
	if (section == SECTION_DEFAULT_EXCHANGE)
	{
		label.text = NSLocalizedString(@"DEFAULT EXCHANGE", @"section header in settings table");
	}
	
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell;

    if (indexPath.section == SECTION_LOGOUT)
	{
		//show Change Categories button
		cell = [self getButtonOnlyCellForTableView:tableView withIndexPath:indexPath];
	}
	else
	{
		UIImage *cellImage;
		if ((indexPath.section == SECTION_OPTIONS) || ([tableView numberOfRowsInSection:indexPath.section] == 1))
		{
			cellImage = [UIImage imageNamed:@"bd_cell_single"];
		}
		else
		{
			if (indexPath.row == 0)
			{
				cellImage = [UIImage imageNamed:@"bd_cell_top"];
			}
			else
			{
				if (indexPath.row == [tableView numberOfRowsInSection:indexPath.section] - 1)
				{
					cellImage = [UIImage imageNamed:@"bd_cell_bottom"];
				}
				else
				{
					cellImage = [UIImage imageNamed:@"bd_cell_middle"];
				}
			}
		}
		
		if (indexPath.section == SECTION_BITCOIN_DENOMINATION)
		{
			cell = [self getRadioButtonCellForTableView:tableView withImage:cellImage andIndexPath:(NSIndexPath *)indexPath];
		}
		if (indexPath.section == SECTION_USERNAME)
		{
			if (indexPath.row < 3)
			{
				cell = [self getPlainCellForTableView:tableView withImage:cellImage andIndexPath:indexPath];
			}
			else
			{
				cell = [self getTextFieldCellForTableView:tableView withImage:cellImage andIndexPath:(NSIndexPath *)indexPath];
			}
		}
		if (indexPath.section == SECTION_OPTIONS)
		{
			if (indexPath.row == 0)
			{
				cell = [self getBooleanCellForTableView:tableView withImage:cellImage andIndexPath:indexPath];
			}
			else
			{
				cell = [self getButtonCellForTableView:tableView withImage:cellImage andIndexPath:(NSIndexPath *)indexPath];
			}
		}
		if (indexPath.section == SECTION_DEFAULT_EXCHANGE)
		{
			cell = [self getButtonCellForTableView:tableView withImage:cellImage andIndexPath:(NSIndexPath *)indexPath];
		}
	}

	
	cell.selectedBackgroundView.backgroundColor = [UIColor clearColor];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSLog(@"Selected section:%i, row:%i", (int)indexPath.section, (int)indexPath.row);

    switch (indexPath.section)
	{
        case SECTION_BITCOIN_DENOMINATION:
            [self setDenominationChoice:indexPath.row];
            [tableView reloadData];
            break;

        case SECTION_USERNAME:
            if (indexPath.row == ROW_PASSWORD)
            {
                [self bringUpSignUpViewInMode:SignUpMode_ChangePassword];
            }
            else if (indexPath.row == ROW_PIN)
            {
                [self bringUpSignUpViewInMode:SignUpMode_ChangePIN];
            }
            break;

        case SECTION_OPTIONS:
            break;

        case SECTION_DEFAULT_EXCHANGE:
            break;

        case SECTION_LOGOUT:
            break;

        default:
            break;
	}
}

#pragma mark SignUpViewControllerDelegates

-(void)signupViewControllerDidFinish:(SignUpViewController *)controller
{
	[controller.view removeFromSuperview];
	_signUpController = nil;
}

@end
