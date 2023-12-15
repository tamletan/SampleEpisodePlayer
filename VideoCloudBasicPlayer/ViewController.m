//
//  ViewController.m
//  VideoCloudBasicPlayer
//
//  Copyright © 2020 Brightcove, Inc. All rights reserved.
//

#import "ViewController.h"
#import "EpisodeViewController.h"
#import "EYUtils.h"

@interface ViewController ()

@end


@implementation ViewController

#pragma mark Setup Methods

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (IBAction)openEpisodePressed:(id)sender
{
    EpisodeViewController *evc = [EpisodeViewController createFromXIB];
    [self.navigationController pushViewController:evc animated:YES];
}

@end
