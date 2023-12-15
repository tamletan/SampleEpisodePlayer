//
//  EpisodeViewController.m
//  VideoCloudBasicPlayer
//
//  Created by ccvn on 14/12/2023.
//  Copyright © 2023 Brightcove. All rights reserved.
//

#import "EpisodeViewController.h"
#import "NowPlayingHandler.h"
#import "EYUtils.h"
@import BrightcovePlayerSDK;

static NSString * const kViewControllerPlaybackServicePolicyKey = @"";
static NSString * const kViewControllerAccountID = @"";
static NSString * const kViewControllerVideoID = @"";
static NSString * const kViewControllerAlternateVideoID = @"";

@interface EpisodeViewController () <BCOVPlaybackControllerDelegate, BCOVPUIPlayerViewDelegate>
@property (nonatomic, strong) BCOVPlaybackService *playbackService;
@property (nonatomic, strong) id<BCOVPlaybackController> playbackController;
@property (nonatomic) BCOVPUIPlayerView *playerView;
@property (nonatomic, strong) NowPlayingHandler *nowPlayingHandler;
@property (nonatomic, strong) NSString *videoId;
@property (nonatomic, weak) AVPlayer *currentPlayer;
@property (weak, nonatomic) IBOutlet UIView *videoContainer;

@end

@implementation EpisodeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupPlayback];
    [self setUpAudioSession];
    [self setupPlayerView];
    [self requestContentFromPlaybackService];
}

- (void)setupPlayback
{
    _playbackController = [BCOVPlayerSDKManager.sharedManager createPlaybackController];

    _playbackController.delegate = self;
    _playbackController.allowsExternalPlayback = YES;
    _playbackController.allowsBackgroundAudioPlayback = YES;
    _playbackController.autoPlay = YES;

    _playbackService = [[BCOVPlaybackService alloc] initWithAccountId:kViewControllerAccountID
                                                            policyKey:kViewControllerPlaybackServicePolicyKey];
}

- (void)setUpAudioSession
{
    NSError *categoryError = nil;
    BOOL success;
    
    // If the player is muted, then allow mixing.
    // Ensure other apps can have their background audio
    // active when this app is in foreground
    if (self.currentPlayer.isMuted)
    {
        success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&categoryError];
    }
    else
    {
        success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:0 error:&categoryError];
    }
    
    if (!success)
    {
        NSLog(@"AppDelegate Debug - Error setting AVAudioSession category.  Because of this, there may be no sound. `%@`", categoryError);
    }
}

- (void)setupPlayerView
{
    // Set up our player view.
    BCOVPUIPlayerViewOptions *options = [BCOVPUIPlayerViewOptions new];
    options.automaticControlTypeSelection = YES;
    
    BCOVPUIPlayerView *playerView = [[BCOVPUIPlayerView alloc] initWithPlaybackController:self.playbackController options:options controlsView:nil];
    playerView.delegate = self;

    [_videoContainer addSubview:playerView];
    playerView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [playerView.topAnchor constraintEqualToAnchor:_videoContainer.topAnchor],
                                              [playerView.rightAnchor constraintEqualToAnchor:_videoContainer.rightAnchor],
                                              [playerView.leftAnchor constraintEqualToAnchor:_videoContainer.leftAnchor],
                                              [playerView.bottomAnchor constraintEqualToAnchor:_videoContainer.bottomAnchor],
                                              ]];
    _playerView = playerView;

    // Associate the playerView with the playback controller.
    _playerView.playbackController = _playbackController;
    
    _nowPlayingHandler = [[NowPlayingHandler alloc] initWithPlaybackController:_playbackController];
}

- (void)requestContentFromPlaybackService
{
    NSDictionary *configuration = @{kBCOVPlaybackServiceConfigurationKeyAssetID:_videoId ?: kViewControllerVideoID};
    [self.playbackService findVideoWithConfiguration:configuration queryParameters:nil completion:^(BCOVVideo *video, NSDictionary *jsonResponse, NSError *error) {

        if (video)
        {
            [self.playbackController setVideos:@[ video ]];
        }
        else
        {
            NSLog(@"ViewController Debug - Error retrieving video playlist: `%@`", error);
        }

    }];
}

- (void)setEpisodeID:(NSString *)episodeId {
    _videoId = episodeId;
}

- (IBAction)goToNextEpisode:(UIButton *)sender {
    [self clearVideo];
    EpisodeViewController *evc = [EpisodeViewController createFromXIB];
    [evc setEpisodeID:kViewControllerAlternateVideoID];
    NSMutableArray* viewControllers = self.navigationController.viewControllers.mutableCopy;
    [viewControllers removeLastObject];
    [viewControllers addObject:evc];
    [self.navigationController setViewControllers:viewControllers animated:YES];
}

- (IBAction)resetEpisode:(UIButton *)sender {
    [self clearVideo];
    [self setEpisodeID:kViewControllerAlternateVideoID];
    [self setupPlayback];
    [self setUpAudioSession];
    [self setupPlayerView];
    [self requestContentFromPlaybackService];
}

- (void)clearVideo
{
    [_playbackController pause];
    _playbackController = nil;
    _playerView = nil;
    _nowPlayingHandler = nil;
}
#pragma mark - BCOVPlaybackControllerDelegate

- (void)playbackController:(id<BCOVPlaybackController>)controller didAdvanceToPlaybackSession:(id<BCOVPlaybackSession>)session
{
    NSLog(@"Advanced to new session.");
    
    self.currentPlayer = session.player;
    
    // Enable route detection for AirPlay
    // https://developer.apple.com/documentation/avfoundation/avroutedetector/2915762-routedetectionenabled
    self.playerView.controlsView.routeDetector.routeDetectionEnabled = YES;
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didProgressTo:(NSTimeInterval)progress
{
    NSLog(@"Progress: %0.2f seconds", progress);
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent
{
    if ([lifecycleEvent.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventEnd])
    {
        // Disable route detection for AirPlay
        // https://developer.apple.com/documentation/avfoundation/avroutedetector/2915762-routedetectionenabled
        self.playerView.controlsView.routeDetector.routeDetectionEnabled = NO;
    }
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session determinedMediaType:(BCOVSourceMediaType)mediaType
{
    switch (mediaType)
    {
        case BCOVSourceMediaTypeAudio:
            [self.nowPlayingHandler updateNowPlayingInfoForAudioOnly];
            break;
        default:
            break;
    }
}

#pragma mark - BCOVPUIPlayerViewDelegate

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    NSLog(@"pictureInPictureControllerDidStartPictureInPicture");
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    NSLog(@"pictureInPictureControllerDidStopPictureInPicture");
}

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    NSLog(@"pictureInPictureControllerWillStartPictureInPicture");
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    NSLog(@"pictureInPictureControllerWillStopPictureInPicture");
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error
{
    NSLog(@"failedToStartPictureInPictureWithError: %@", error.localizedDescription);
}

@end
