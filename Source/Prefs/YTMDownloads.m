#import "YTMDownloads.h"
#import "YTMTappableSlider.h"

static const CGFloat kPlayerBarHeight = 130.0;
static const CGFloat kArtworkSize     = 48.0;
static BOOL _dragging = NO;

// ─── Slider subclass: tap anywhere on the track to seek ─────────────────────
// @interface is in YTMTappableSlider.h — only one @implementation across the project.
@implementation YTMTappableSlider
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint pt    = [touch locationInView:self];
    float   ratio = (float)(pt.x / self.bounds.size.width);
    ratio         = MAX(0.0f, MIN(1.0f, ratio));
    self.value    = self.minimumValue + ratio * (self.maximumValue - self.minimumValue);
    return [super beginTrackingWithTouch:touch withEvent:event];
}
@end

@implementation YTMDownloads

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate   = self;
    self.tableView.backgroundColor = [UIColor colorWithRed:3/255.0 green:3/255.0 blue:3/255.0 alpha:1.0];
    [self.view addSubview:self.tableView];

    [self setupPlayerBar];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor     constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor  constraintEqualToAnchor:self.playerBarView.topAnchor],
    ]];

    self.currentIndex     = -1;
    self.repeatMode       = 0;
    self.isShuffleEnabled = NO;

    [self maybeShowEmptyState];
    [self refreshAudioFiles];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData)
                                                 name:@"ReloadDataNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.timeObserverToken && self.player) {
        [self.player removeTimeObserver:self.timeObserverToken];
    }
}

#pragma mark - Empty state

- (void)maybeShowEmptyState {
    if (self.audioFiles.count == 0) {
        self.imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"yt_outline_audio_48pt"
                                                                       inBundle:[NSBundle mainBundle]
                                              compatibleWithTraitCollection:nil]];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.tintColor   = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
        self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.tableView addSubview:self.imageView];

        self.label = [[UILabel alloc] initWithFrame:CGRectZero];
        self.label.text          = LOC(@"EMPTY");
        self.label.textColor     = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
        self.label.numberOfLines = 0;
        self.label.font          = [UIFont systemFontOfSize:16];
        self.label.textAlignment = NSTextAlignmentCenter;
        self.label.translatesAutoresizingMaskIntoConstraints = NO;
        [self.label sizeToFit];
        [self.tableView addSubview:self.label];

        [NSLayoutConstraint activateConstraints:@[
            [self.imageView.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
            [self.imageView.bottomAnchor  constraintEqualToAnchor:self.tableView.centerYAnchor constant:-30],
            [self.imageView.widthAnchor   constraintEqualToConstant:48],
            [self.imageView.heightAnchor  constraintEqualToConstant:48],
            [self.label.centerXAnchor     constraintEqualToAnchor:self.tableView.centerXAnchor],
            [self.label.topAnchor         constraintEqualToAnchor:self.imageView.bottomAnchor constant:20],
            [self.label.leadingAnchor     constraintEqualToAnchor:self.tableView.leadingAnchor  constant:20],
            [self.label.trailingAnchor    constraintEqualToAnchor:self.tableView.trailingAnchor constant:-20],
        ]];
    }
}

#pragma mark - Data

- (void)reloadData {
    [self refreshAudioFiles];
    [self.tableView reloadData];
}

- (void)refreshAudioFiles {
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *downloadsURL = [documentsURL URLByAppendingPathComponent:@"YTMusicUltimate"];

    NSError *error;
    NSArray *allFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:downloadsURL.path error:&error];
    if (error) { NSLog(@"Error reading directory: %@", error.localizedDescription); return; }

    NSPredicate *m4a = [NSPredicate predicateWithFormat:@"SELF ENDSWITH[c] '.m4a'"];
    NSPredicate *mp3 = [NSPredicate predicateWithFormat:@"SELF ENDSWITH[c] '.mp3'"];
    self.audioFiles  = [NSMutableArray arrayWithArray:[allFiles filteredArrayUsingPredicate:
                        [NSCompoundPredicate orPredicateWithSubpredicates:@[m4a, mp3]]]];

    self.imageView.tintColor = self.audioFiles.count == 0 ? [[UIColor whiteColor] colorWithAlphaComponent:0.8] : [UIColor clearColor];
    self.label.textColor     = self.audioFiles.count == 0 ? [[UIColor whiteColor] colorWithAlphaComponent:0.8] : [UIColor clearColor];
}

#pragma mark - Button helper

- (UIButton *)makeButtonWithSFSymbol:(NSString *)sfName size:(CGFloat)size {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:size];
    btn.tintColor = [UIColor whiteColor];
    [btn setImage:[[UIImage systemImageNamed:sfName withConfiguration:symCfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
         forState:UIControlStateNormal];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    return btn;
}

#pragma mark - Mini-player bar setup

- (void)setupPlayerBar {
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.playerBarView = blurView;
    [self.view addSubview:self.playerBarView];

    [NSLayoutConstraint activateConstraints:@[
        [self.playerBarView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.playerBarView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.playerBarView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
        [self.playerBarView.heightAnchor   constraintEqualToConstant:kPlayerBarHeight],
    ]];

    UIView *container = ((UIVisualEffectView *)self.playerBarView).contentView;

    // Separator
    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:sep];
    [NSLayoutConstraint activateConstraints:@[
        [sep.topAnchor      constraintEqualToAnchor:container.topAnchor],
        [sep.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor],
        [sep.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [sep.heightAnchor   constraintEqualToConstant:0.5],
    ]];

    // Artwork
    self.playerArtwork = [[UIImageView alloc] init];
    self.playerArtwork.contentMode = UIViewContentModeScaleAspectFill;
    self.playerArtwork.clipsToBounds = YES;
    self.playerArtwork.layer.cornerRadius = 6;
    self.playerArtwork.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.playerArtwork.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.playerArtwork];

    // Title
    self.playerTitleLabel = [[UILabel alloc] init];
    self.playerTitleLabel.text      = @"-";
    self.playerTitleLabel.textColor = [UIColor whiteColor];
    self.playerTitleLabel.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.playerTitleLabel.numberOfLines = 2;
    self.playerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.playerTitleLabel];

    // Progress slider
    self.progressSlider = [[YTMTappableSlider alloc] init];
    self.progressSlider.minimumTrackTintColor = [UIColor colorWithRed:30/255.0 green:150/255.0 blue:245/255.0 alpha:1.0];
    self.progressSlider.maximumTrackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
    self.progressSlider.thumbTintColor        = [UIColor whiteColor];
    [self.progressSlider addTarget:self action:@selector(sliderTouchBegan:) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(sliderTouchEnded:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.progressSlider];

    // Buttons
    self.prevButton      = [self makeButtonWithSFSymbol:@"backward.fill" size:20];
    self.playPauseButton = [self makeButtonWithSFSymbol:@"play.fill"     size:24];
    self.nextButton      = [self makeButtonWithSFSymbol:@"forward.fill"  size:20];
    self.repeatButton    = [self makeButtonWithSFSymbol:@"repeat"        size:16];
    self.shuffleButton   = [self makeButtonWithSFSymbol:@"shuffle"       size:16];

    [self.prevButton      addTarget:self action:@selector(prevTapped)       forControlEvents:UIControlEventTouchUpInside];
    [self.playPauseButton addTarget:self action:@selector(playPauseTapped)  forControlEvents:UIControlEventTouchUpInside];
    [self.nextButton      addTarget:self action:@selector(nextTapped)       forControlEvents:UIControlEventTouchUpInside];
    [self.repeatButton    addTarget:self action:@selector(repeatTapped)     forControlEvents:UIControlEventTouchUpInside];
    [self.shuffleButton   addTarget:self action:@selector(shuffleTapped)    forControlEvents:UIControlEventTouchUpInside];

    for (UIButton *btn in @[self.prevButton, self.playPauseButton, self.nextButton, self.repeatButton, self.shuffleButton]) {
        [container addSubview:btn];
    }

    // Layout: artwork top-left
    [NSLayoutConstraint activateConstraints:@[
        [self.playerArtwork.topAnchor     constraintEqualToAnchor:container.topAnchor constant:10],
        [self.playerArtwork.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor constant:12],
        [self.playerArtwork.widthAnchor   constraintEqualToConstant:kArtworkSize],
        [self.playerArtwork.heightAnchor  constraintEqualToConstant:kArtworkSize],
    ]];

    // Title right of artwork
    [NSLayoutConstraint activateConstraints:@[
        [self.playerTitleLabel.centerYAnchor  constraintEqualToAnchor:self.playerArtwork.centerYAnchor],
        [self.playerTitleLabel.leadingAnchor   constraintEqualToAnchor:self.playerArtwork.trailingAnchor constant:10],
        [self.playerTitleLabel.trailingAnchor  constraintEqualToAnchor:container.trailingAnchor constant:-12],
    ]];

    // Slider below artwork
    [NSLayoutConstraint activateConstraints:@[
        [self.progressSlider.topAnchor     constraintEqualToAnchor:self.playerArtwork.bottomAnchor constant:8],
        [self.progressSlider.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor constant:12],
        [self.progressSlider.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12],
    ]];

    // Controls row below slider
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.shuffleButton, self.prevButton, self.playPauseButton, self.nextButton, self.repeatButton
    ]];
    stack.axis         = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionEqualSpacing;
    stack.alignment    = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor     constraintEqualToAnchor:self.progressSlider.bottomAnchor constant:4],
        [stack.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-24],
    ]];

    // Tap anywhere on the bar (except buttons) to reopen the player screen
    UITapGestureRecognizer *barTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playerBarTapped)];
    [self.playerBarView addGestureRecognizer:barTap];
    // Allow buttons to still receive touches
    barTap.cancelsTouchesInView = NO;
}

#pragma mark - Playback

- (void)playTrackAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.audioFiles.count) return;

    if (self.timeObserverToken && self.player) {
        [self.player removeTimeObserver:self.timeObserverToken];
        self.timeObserverToken = nil;
    }

    self.currentIndex = index;

    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSString *filename  = self.audioFiles[index];
    NSURL *audioURL     = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"YTMusicUltimate/%@", filename]];
    NSString *title     = [filename stringByDeletingPathExtension];

    NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *imgPath = [[docsDir stringByAppendingPathComponent:@"YTMusicUltimate"]
                          stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", title]];

    // Update title immediately; load artwork in background to avoid blocking main thread.
    self.playerTitleLabel.text = title;
    self.playerArtwork.image   = [UIImage systemImageNamed:@"music.note"];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *artwork = [UIImage imageWithContentsOfFile:imgPath];
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.playerArtwork.image = artwork ?: [UIImage systemImageNamed:@"music.note"];
            // Push artwork into now playing info
            if (artwork) {
                NSMutableDictionary *info = [[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo mutableCopy] ?: [NSMutableDictionary dictionary];
                MPMediaItemArtwork *mpArt = [[MPMediaItemArtwork alloc] initWithBoundsSize:artwork.size
                                                                            requestHandler:^UIImage *(CGSize s) { return artwork; }];
                info[MPMediaItemPropertyArtwork] = mpArt;
                [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
            }
            [weakSelf syncPlayerVCStateWithIsPlaying:YES];
        });
    });

    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:audioURL];

    AVMutableMetadataItem *titleMeta = [AVMutableMetadataItem metadataItem];
    titleMeta.key      = AVMetadataCommonKeyTitle;
    titleMeta.keySpace = AVMetadataKeySpaceCommon;
    titleMeta.value    = title;

    item.externalMetadata = @[titleMeta];

    // Now Playing (lock screen)
    NSMutableDictionary *nowPlaying = [NSMutableDictionary dictionary];
    nowPlaying[MPMediaItemPropertyTitle]               = title;
    nowPlaying[MPNowPlayingInfoPropertyPlaybackRate]   = @(1.0);
    nowPlaying[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(0.0);
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nowPlaying;

    // Remote commands — register once per track (removeTarget:nil clears previous handlers)
    MPRemoteCommandCenter *rcc = [MPRemoteCommandCenter sharedCommandCenter];
    [rcc.playCommand                   removeTarget:nil];
    [rcc.pauseCommand                  removeTarget:nil];
    [rcc.togglePlayPauseCommand        removeTarget:nil];
    [rcc.nextTrackCommand              removeTarget:nil];
    [rcc.previousTrackCommand          removeTarget:nil];
    [rcc.changePlaybackPositionCommand removeTarget:nil];

    rcc.playCommand.enabled                    = YES;
    rcc.pauseCommand.enabled                   = YES;
    rcc.togglePlayPauseCommand.enabled         = YES;
    rcc.nextTrackCommand.enabled               = YES;
    rcc.previousTrackCommand.enabled           = YES;
    rcc.changePlaybackPositionCommand.enabled  = YES;

    [rcc.playCommand                   addTarget:self action:@selector(remotePlay)];
    [rcc.pauseCommand                  addTarget:self action:@selector(remotePause)];
    [rcc.togglePlayPauseCommand        addTarget:self action:@selector(remoteTogglePlayPause)];
    [rcc.nextTrackCommand              addTarget:self action:@selector(remoteNext)];
    [rcc.previousTrackCommand          addTarget:self action:@selector(remotePrev)];
    [rcc.changePlaybackPositionCommand addTarget:self action:@selector(remoteSeek:)];

    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:item];
    } else {
        [self.player replaceCurrentItemWithPlayerItem:item];
    }
    self.currentPlayerItem = item;
    [self.player play];
    [self updatePlayPauseButton:YES];

    __weak typeof(self) weakSelf = self;
    self.timeObserverToken = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 4)
                                                                       queue:dispatch_get_main_queue()
                                                                  usingBlock:^(CMTime time) {
        [weakSelf updateProgressSlider];
        // Sync the now-playing screen progress
        if (weakSelf.playerVC && weakSelf.player) {
            CMTime dur = weakSelf.player.currentItem.duration;
            if (!CMTIME_IS_INVALID(dur) && CMTimeGetSeconds(dur) > 0) {
                NSTimeInterval elapsed  = CMTimeGetSeconds(weakSelf.player.currentTime);
                NSTimeInterval duration = CMTimeGetSeconds(dur);
                float fraction = (float)(elapsed / duration);
                [weakSelf.playerVC updateProgress:fraction
                                  elapsedSeconds:elapsed
                                 durationSeconds:duration];
            }
        }
    }];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
        [self syncQueueToPlayerVC];
    });
}

- (void)playNextTrack {
    if (self.audioFiles.count == 0) return;
    // repeat-one: restart current track
    if (self.repeatMode == 2) { [self playTrackAtIndex:self.currentIndex]; return; }
    NSInteger next;
    if (self.isShuffleEnabled) {
        next = arc4random_uniform((uint32_t)self.audioFiles.count);
    } else {
        next = self.currentIndex + 1;
        if (next >= (NSInteger)self.audioFiles.count) {
            if (self.repeatMode == 1) { next = 0; }
            else { [self.player pause]; [self updatePlayPauseButton:NO]; [self syncPlayerVCState]; return; }
        }
    }
    [self playTrackAtIndex:next];
}

- (void)playPreviousTrack {
    if (self.audioFiles.count == 0) return;
    if (CMTimeGetSeconds(self.player.currentTime) > 3.0) {
        [self.player seekToTime:kCMTimeZero];
        return;
    }
    NSInteger prev = self.currentIndex - 1;
    if (prev < 0) prev = (self.repeatMode == 1) ? (NSInteger)self.audioFiles.count - 1 : 0;
    [self playTrackAtIndex:prev];
}

- (void)playerDidFinishPlaying:(NSNotification *)note {
    if (note.object == self.currentPlayerItem) [self playNextTrack];
}

#pragma mark - Controls

- (void)playPauseTapped {
    if (!self.player || self.currentIndex < 0) return;
    BOOL nowPlaying;
    if (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
        [self.player pause];
        nowPlaying = NO;
    } else {
        [self.player play];
        nowPlaying = YES;
    }
    [self updatePlayPauseButton:nowPlaying];
    [self syncPlayerVCStateWithIsPlaying:nowPlaying];
}

- (void)nextTapped  { [self playNextTrack]; }
- (void)prevTapped  { [self playPreviousTrack]; }

- (void)repeatTapped {
    self.repeatMode = (self.repeatMode + 1) % 3;
    UIColor *on  = [UIColor colorWithRed:30/255.0 green:150/255.0 blue:245/255.0 alpha:1.0];
    UIColor *off = [UIColor whiteColor];
    NSString *sfName = (self.repeatMode == 2) ? @"repeat.1" : @"repeat";
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16];
    [self.repeatButton setImage:[[UIImage systemImageNamed:sfName withConfiguration:cfg]
                                 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                       forState:UIControlStateNormal];
    self.repeatButton.tintColor = (self.repeatMode == 0) ? off : on;
    [self syncPlayerVCState];
}

- (void)shuffleTapped {
    self.isShuffleEnabled = !self.isShuffleEnabled;
    UIColor *color = self.isShuffleEnabled
        ? [UIColor colorWithRed:30/255.0 green:150/255.0 blue:245/255.0 alpha:1.0]
        : [UIColor whiteColor];
    self.shuffleButton.tintColor = color;
}

- (void)updatePlayPauseButton:(BOOL)isPlaying {
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:24];
    NSString *sfName = isPlaying ? @"pause.fill" : @"play.fill";
    [self.playPauseButton setImage:[[UIImage systemImageNamed:sfName withConfiguration:symCfg]
                                    imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                          forState:UIControlStateNormal];
}

#pragma mark - Slider

- (void)sliderTouchBegan:(UISlider *)slider { _dragging = YES; }
- (void)sliderTouchEnded:(UISlider *)slider {
    _dragging = NO;
    CMTime duration = self.player.currentItem.duration;
    if (CMTIME_IS_INVALID(duration)) return;
    CMTime seekTime = CMTimeMakeWithSeconds(slider.value * CMTimeGetSeconds(duration), 600);
    [self.player seekToTime:seekTime];
}

- (void)updateProgressSlider {
    if (_dragging) return;
    CMTime duration = self.player.currentItem.duration;
    CMTime current  = self.player.currentTime;
    if (CMTIME_IS_INVALID(duration) || CMTimeGetSeconds(duration) == 0) return;
    self.progressSlider.value = (float)(CMTimeGetSeconds(current) / CMTimeGetSeconds(duration));

    BOOL isPlaying = (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying);
    NSMutableDictionary *info = [[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo mutableCopy] ?: [NSMutableDictionary dictionary];
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(CMTimeGetSeconds(current));
    info[MPMediaItemPropertyPlaybackDuration]         = @(CMTimeGetSeconds(duration));
    info[MPNowPlayingInfoPropertyPlaybackRate]        = @(isPlaying ? 1.0 : 0.0);
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
}

#pragma mark - Remote commands

- (MPRemoteCommandHandlerStatus)remotePlay  { [self.player play];  [self updatePlayPauseButton:YES]; [self syncPlayerVCStateWithIsPlaying:YES]; return MPRemoteCommandHandlerStatusSuccess; }
- (MPRemoteCommandHandlerStatus)remotePause { [self.player pause]; [self updatePlayPauseButton:NO];  [self syncPlayerVCStateWithIsPlaying:NO];  return MPRemoteCommandHandlerStatusSuccess; }
- (MPRemoteCommandHandlerStatus)remoteTogglePlayPause {
    if (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
        return [self remotePause];
    } else {
        return [self remotePlay];
    }
}
- (MPRemoteCommandHandlerStatus)remoteNext  { [self playNextTrack];     return MPRemoteCommandHandlerStatusSuccess; }
- (MPRemoteCommandHandlerStatus)remotePrev  { [self playPreviousTrack]; return MPRemoteCommandHandlerStatusSuccess; }

- (MPRemoteCommandHandlerStatus)remoteSeek:(MPChangePlaybackPositionCommandEvent *)event {
    CMTime duration = self.player.currentItem.duration;
    if (CMTIME_IS_INVALID(duration)) return MPRemoteCommandHandlerStatusCommandFailed;
    CMTime seekTime = CMTimeMakeWithSeconds(event.positionTime, 600);
    [self.player seekToTime:seekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    return MPRemoteCommandHandlerStatusSuccess;
}

#pragma mark - Table view

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"\n\n" : nil;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 1 ? @"\n\n\n" : nil;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && self.audioFiles.count == 0) return 0;
    return UITableViewAutomaticDimension;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.audioFiles.count;
    if (section == 1) return 2;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];

    if (indexPath.section == 0 && indexPath.row < (NSInteger)self.audioFiles.count) {
        NSString *filename = self.audioFiles[indexPath.row];
        cell.textLabel.text          = [filename stringByDeletingPathExtension];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.textColor     = [UIColor whiteColor];
        cell.backgroundColor         = [[UIColor grayColor] colorWithAlphaComponent:0.25];

        BOOL isPlaying = (indexPath.row == self.currentIndex && self.player &&
                          self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying);
        cell.accessoryType = isPlaying ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.tintColor     = [UIColor colorWithRed:30/255.0 green:150/255.0 blue:245/255.0 alpha:1.0];

        NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSString *imgName = [NSString stringWithFormat:@"%@.png", [filename stringByDeletingPathExtension]];
        UIImage *image    = [UIImage imageWithContentsOfFile:[[docsDir stringByAppendingPathComponent:@"YTMusicUltimate"]
                                                              stringByAppendingPathComponent:imgName]];
        if (image) {
            CGFloat targetSize  = 37.5;
            CGFloat scaleFactor = targetSize / MAX(image.size.width, image.size.height);
            CGSize  scaledSize  = CGSizeMake(image.size.width * scaleFactor, image.size.height * scaleFactor);
            UIGraphicsBeginImageContextWithOptions(scaledSize, NO, 0.0);
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0,0,scaledSize.width,scaledSize.height) cornerRadius:6] addClip];
            [image drawInRect:CGRectMake(0,0,scaledSize.width,scaledSize.height)];
            UIImage *rounded = [UIGraphicsGetImageFromCurrentImageContext() imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            UIGraphicsEndImageContext();
            cell.imageView.image = rounded;
        } else {
            cell.imageView.image     = [UIImage systemImageNamed:@"music.note"];
            cell.imageView.tintColor = [UIColor whiteColor];
        }
    } else if (indexPath.section == 1) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell0"];
        NSArray *settingsData = @[
            @{@"title": LOC(@"SHARE_ALL"),  @"icon": @"square.and.arrow.up.on.square"},
            @{@"title": LOC(@"REMOVE_ALL"), @"icon": @"trash"},
        ];
        NSDictionary *data       = settingsData[indexPath.row];
        cell.textLabel.text      = data[@"title"];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.imageView.image     = [UIImage systemImageNamed:data[@"icon"]];
        cell.imageView.tintColor = indexPath.row == 1
            ? [UIColor redColor]
            : [UIColor colorWithRed:30/255.0 green:150/255.0 blue:245/255.0 alpha:1.0];
        cell.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.25];
    }
    return cell;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0) return nil;

    UIContextualAction *shareAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@""
        handler:^(UIContextualAction *a, UIView *sv, void (^done)(BOOL)) { [self showActivityViewControllerForIndexPath:indexPath]; done(YES); }];
    shareAction.image           = [UIImage systemImageNamed:@"square.and.arrow.up"];
    shareAction.backgroundColor = [UIColor systemBlueColor];

    UIContextualAction *renameAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@""
        handler:^(UIContextualAction *a, UIView *sv, void (^done)(BOOL)) { [self renameFileForIndexPath:indexPath]; done(YES); }];
    renameAction.image           = [UIImage systemImageNamed:@"pencil"];
    renameAction.backgroundColor = [UIColor systemOrangeColor];

    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@""
        handler:^(UIContextualAction *a, UIView *sv, void (^done)(BOOL)) { [self deleteFileForIndexPath:indexPath]; done(YES); }];
    deleteAction.image = [UIImage systemImageNamed:@"trash"];

    UISwipeActionsConfiguration *cfg = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, renameAction, shareAction]];
    cfg.performsFirstActionWithFullSwipe = YES;
    return cfg;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        [self playTrackAtIndex:indexPath.row];
        [self openPlayerScreen];
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) [self shareAll:indexPath];
        if (indexPath.row == 1) [self removeAll];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Player screen (Now Playing)

- (void)playerBarTapped {
    // Reopen player screen even when it was dismissed
    if (self.currentIndex < 0) return; // nothing playing yet
    [self openPlayerScreen];
}

- (void)openPlayerScreen {
    if (!self.playerVC) {
        self.playerVC = [[YTMDownloadsPlayerViewController alloc] init];
        self.playerVC.delegate = self;
    }
    [self syncPlayerVCState];
    [self syncQueueToPlayerVC];
    if (self.playerVC.presentingViewController == nil) {
        [self presentViewController:self.playerVC animated:YES completion:nil];
    }
}

- (void)syncPlayerVCState {
    if (!self.playerVC) return;
    BOOL playing = self.player && self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying;
    [self syncPlayerVCStateWithIsPlaying:playing];
}

- (void)syncPlayerVCStateWithIsPlaying:(BOOL)playing {
    if (!self.playerVC) return;
    NSString *title = (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.audioFiles.count)
        ? [self.audioFiles[self.currentIndex] stringByDeletingPathExtension]
        : @"-";
    UIImage *artwork = self.playerArtwork.image;
    [self.playerVC updateWithTitle:title
                           artwork:artwork
                         isPlaying:playing
                        repeatMode:self.repeatMode
                    shuffleEnabled:self.isShuffleEnabled];
}

- (void)syncQueueToPlayerVC {
    if (!self.playerVC) return;
    NSArray<NSString *> *snapshot = [self.audioFiles copy];
    NSInteger currentIdx = self.currentIndex;
    NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSString *> *titles   = [NSMutableArray arrayWithCapacity:snapshot.count];
        NSMutableArray<UIImage  *> *artworks = [NSMutableArray arrayWithCapacity:snapshot.count];

        for (NSString *filename in snapshot) {
            NSString *name = [filename stringByDeletingPathExtension];
            [titles addObject:name];
            NSString *imgPath = [[docsDir stringByAppendingPathComponent:@"YTMusicUltimate"]
                                  stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", name]];
            UIImage *art = [UIImage imageWithContentsOfFile:imgPath];
            [artworks addObject:art ?: [UIImage systemImageNamed:@"music.note"]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.playerVC updateQueue:titles artworks:artworks currentIndex:currentIdx];
        });
    });
}

#pragma mark - YTMDownloadsPlayerDelegate

- (void)playerDidTogglePlayPause { [self playPauseTapped]; }
- (void)playerDidRequestNext     { [self playNextTrack]; }
- (void)playerDidRequestPrev     { [self playPreviousTrack]; }

- (void)playerDidRequestSeekTo:(float)fraction {
    CMTime duration = self.player.currentItem.duration;
    if (CMTIME_IS_INVALID(duration)) return;
    CMTime seekTime = CMTimeMakeWithSeconds(fraction * CMTimeGetSeconds(duration), 600);
    [self.player seekToTime:seekTime];
}

- (void)playerDidToggleRepeat {
    [self repeatTapped];
    [self syncPlayerVCState];
}

- (void)playerDidToggleShuffle {
    [self shuffleTapped];
    [self syncPlayerVCState];
}

- (void)playerDidRequestJumpToIndex:(NSInteger)index {
    [self playTrackAtIndex:index];
}

#pragma mark - File actions

- (void)showActivityViewControllerForIndexPath:(NSIndexPath *)indexPath {
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *audioURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"YTMusicUltimate/%@", self.audioFiles[indexPath.row]]];
    [self activityControllerWithObjects:@[audioURL] sender:[self.tableView cellForRowAtIndexPath:indexPath]];
}

- (void)renameFileForIndexPath:(NSIndexPath *)indexPath {
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *audioURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"YTMusicUltimate/%@", self.audioFiles[indexPath.row]]];
    NSURL *coverURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"YTMusicUltimate/%@.png", [self.audioFiles[indexPath.row] stringByDeletingPathExtension]]];

    UITextView *textView = [[UITextView alloc] init];
    textView.backgroundColor    = [[UIColor blackColor] colorWithAlphaComponent:0.15];
    textView.layer.cornerRadius = 3.0;
    textView.layer.borderWidth  = 1.0;
    textView.layer.borderColor  = [[UIColor grayColor] colorWithAlphaComponent:0.5].CGColor;
    textView.textColor          = [UIColor whiteColor];
    textView.text               = [self.audioFiles[indexPath.row] stringByDeletingPathExtension];
    textView.editable           = YES;
    textView.scrollEnabled      = YES;
    textView.textAlignment      = NSTextAlignmentNatural;
    textView.font               = [UIFont systemFontOfSize:14.0];

    YTAlertView *alertView = [NSClassFromString(@"YTAlertView") confirmationDialogWithAction:^{
        NSString *newName  = [textView.text stringByReplacingOccurrencesOfString:@"/" withString:@""];
        NSString *ext      = [audioURL pathExtension];
        NSURL *newAudioURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"YTMusicUltimate/%@.%@", newName, ext]];
        NSURL *newCoverURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"YTMusicUltimate/%@.png", newName]];
        NSError *err = nil;
        [[NSFileManager defaultManager] moveItemAtURL:audioURL toURL:newAudioURL error:&err];
        [[NSFileManager defaultManager] moveItemAtURL:coverURL toURL:newCoverURL error:&err];
        if (!err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self reloadData];
                [[NSClassFromString(@"YTMToastController") alloc] showMessage:LOC(@"DONE")];
            });
        }
    } actionTitle:LOC(@"RENAME")];
    alertView.title = @"YTMusicUltimate";

    UIView *customView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, alertView.frameForDialog.size.width - 50, 75)];
    textView.frame = customView.frame;
    [customView addSubview:textView];
    alertView.customContentView = customView;
    [alertView show];
}

- (void)deleteFileForIndexPath:(NSIndexPath *)indexPath {
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *audioURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"YTMusicUltimate/%@", self.audioFiles[indexPath.row]]];
    NSURL *coverURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"YTMusicUltimate/%@.png", [self.audioFiles[indexPath.row] stringByDeletingPathExtension]]];

    YTAlertView *alertView = [NSClassFromString(@"YTAlertView") confirmationDialogWithAction:^{
        BOOL audioRemoved = [[NSFileManager defaultManager] removeItemAtURL:audioURL error:nil];
        BOOL coverRemoved = [[NSFileManager defaultManager] removeItemAtURL:coverURL error:nil];
        if (audioRemoved && coverRemoved) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (indexPath.row == self.currentIndex) {
                    [self.player pause];
                    self.currentIndex = -1;
                    self.playerTitleLabel.text = @"-";
                    self.playerArtwork.image   = nil;
                    [self updatePlayPauseButton:NO];
                }
                [self.audioFiles removeObjectAtIndex:indexPath.row];
                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                [self maybeShowEmptyState];
            });
        }
    } actionTitle:LOC(@"DELETE")];
    alertView.title    = @"YTMusicUltimate";
    alertView.subtitle = [NSString stringWithFormat:LOC(@"DELETE_MESSAGE"), [self.audioFiles[indexPath.row] stringByDeletingPathExtension]];
    [alertView show];
}

- (void)shareAll:(NSIndexPath *)indexPath {
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *audiosFolder = [documentsURL URLByAppendingPathComponent:@"YTMusicUltimate"];
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:audiosFolder
                                                           includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                                              options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                error:nil];
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"pathExtension.lowercaseString == 'm4a' || pathExtension.lowercaseString == 'mp3'"];
    files = [files filteredArrayUsingPredicate:pred];
    [self activityControllerWithObjects:files sender:[self.tableView cellForRowAtIndexPath:indexPath]];
}

- (void)removeAll {
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *audiosFolder = [documentsURL URLByAppendingPathComponent:@"YTMusicUltimate"];
    YTAlertView *alertView = [NSClassFromString(@"YTAlertView") confirmationDialogWithAction:^{
        if ([[NSFileManager defaultManager] removeItemAtURL:audiosFolder error:nil]) {
            [self.audioFiles removeAllObjects];
            [self.player pause];
            self.currentIndex = -1;
            self.playerTitleLabel.text = @"-";
            self.playerArtwork.image   = nil;
            [self updatePlayPauseButton:NO];
            self.imageView.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
            self.label.textColor     = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
            dispatch_async(dispatch_get_main_queue(), ^{ [self.tableView reloadData]; });
        }
    } actionTitle:LOC(@"DELETE")];
    alertView.title    = @"YTMusicUltimate";
    alertView.subtitle = [NSString stringWithFormat:LOC(@"DELETE_MESSAGE"), LOC(@"ALL_DOWNLOADS")];
    [alertView show];
}

- (void)activityControllerWithObjects:(NSArray<id> *)items sender:(UIView *)sender {
    if (items.count == 0) return;
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    activityVC.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypePrint];
    UIPopoverPresentationController *popover = activityVC.popoverPresentationController;
    if (popover && sender) {
        popover.sourceView = sender;
        popover.sourceRect = CGRectMake(CGRectGetWidth(sender.bounds) - 10.0, CGRectGetMidY(sender.bounds), 1.0, 1.0);
        popover.permittedArrowDirections = UIPopoverArrowDirectionRight;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

@end
