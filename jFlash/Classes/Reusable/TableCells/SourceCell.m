/*
File: SourceCell.m
Abstract: UITableView utility cell that describes where to find UIView code.
Version: 1.7
*/

#import "SourceCell.h"
#import "Constants.h"

// cell identifier for this custom cell
NSString *kSourceCell_ID = @"SourceCell_ID";

@implementation SourceCell

@synthesize sourceLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	{
		// turn off selection use
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		
		sourceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		sourceLabel.backgroundColor = [UIColor clearColor];
		sourceLabel.opaque = NO;
		sourceLabel.textAlignment = NSTextAlignmentCenter;
		sourceLabel.textColor = [UIColor grayColor];
		sourceLabel.highlightedTextColor = [UIColor blackColor];
		sourceLabel.font = [UIFont systemFontOfSize:12];
		
		[self.contentView addSubview:sourceLabel];
	}
	return self;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	sourceLabel.frame = [self.contentView bounds];
}

- (void)dealloc
{
	[sourceLabel release];
	
    [super dealloc];
}

@end
