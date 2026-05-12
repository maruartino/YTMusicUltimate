#import "YTMDownloadsPlayerViewController.h"

static const CGFloat kArtworkCornerRadius = 16.0;
static const CGFloat kArtShadowRadius     = 24.0;
static const CGFloat kArtShadowOpacity    = 0.55;
static const CGFloat kArtPlayingScale     = 1.0;
static const CGFloat kArtPausedScale      = 0.82;

// ─── Queue cell ─────────────────────────────────────────────────────────────
@interface YTMQueueCell : UITableViewCell
@property (nonatomic, strong) UIImageView *thumbImageView;
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UIImageView *playingIndicator;
- (void)configureWithTitle:(NSString *)title artwork:(nullable UIImage *)artwork isCurrentTrack:(BOOL)current isPlaying:(BOOL)playing;
@end

@implementation YTMQueueCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle  = UITableViewCellSelectionStyleDefault;

        self.thumbImageView = [[UIImageView alloc] init];
        self.thumbImageView.contentMode       = UIViewContentModeScaleAspectFill;
        self.thumbImageView.clipsToBounds     = YES;
        self.thumbImageView.layer.cornerRadius = 6;
        self.thumbImageView.backgroundColor   = [UIColor colorWithWhite:0.2 alpha:1.0];
        self.thumbImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.thumbImageView];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.textColor     = [UIColor whiteColor];
        self.titleLabel.font          = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
        self.titleLabel.numberOfLines = 2;
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.titleLabel];

        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12];
        self.playingIndicator = [[UIImageView alloc] initWithImage:
            [[UIImage systemImageNamed:@"waveform" withConfiguration:cfg]
             imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        self.playingIndicator.tintColor = [UIColor colorWithRed:30/255.0 green:150/255.0 blue:245/255.0 alpha:1.0];
        self.playingIndicator.contentMode = UIViewContentModeScaleAspectFit;
        self.playingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        self.playingIndicator.hidden = YES;
        [self.contentView addSubview:self.playingIndicator];

        [NSLayoutConstraint activateConstraints:@[
            [self.thumbImageView.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [self.thumbImageView.centerYAnchor  constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.thumbImageView.widthAnchor    constraintEqualToConstant:44],
            [self.thumbImageView.heightAnchor   constraintEqualToConstant:44],
            [self.titleLabel.leadingAnchor      constraintEqualToAnchor:self.thumbImageView.trailingAnchor constant:12],
            [self.titleLabel.centerYAnchor      constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.titleLabel.trailingAnchor     constraintEqualToAnchor:self.playingIndicator.leadingAnchor constant:-8],
            [self.playingIndicator.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [self.playingIndicator.centerYAnchor  constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.playingIndicator.widthAnchor  constraintEqualToConstant:20],
            [self.playingIndicator.heightAnchor constraintEqualToConstant:20],
            [self.contentView.heightAnchor      constraintGreaterThanOrEqualToConstant:60],
        ]];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title artwork:(nullable UIImage *)artwork isCurrentTrack:(BOOL)current isPlaying:(BOOL)playing {
    self.titleLabel.text = title;
    self.titleLabel.textColor = current
        ? [UIColor colorWithRed:30/255.0 green:150/255.0 blue:245/255.0 alpha:1.0]
        : [UIColor whiteColor];
    self.thumbImageView.image = artwork ?: [UIImage systemImageNamed:@"music.note"];
    if (!artwork) self.thumbImageView.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    self.playingIndicator.hidden = !(current && playing);
}

@end

// ─── Main VC ────────────────────────────────────────────────────────────────
@interface YTMDownloadsPlayerViewController () <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIImageView            *bgBlurImageView;
@property (nonatomic, strong) UIVisualEffectView     *bgBlurView;
@property (nonatomic, strong) UIView                 *grabberView;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, strong) UIView                 *artworkContainer;
@property (nonatomic, strong) UIImageView            *artworkImageView;
@property (nonatomic, strong) UILabel                *titleLabel;
@property (nonatomic, strong) UILabel                *elapsedLabel;
@property (nonatomic, strong) UILabel                *remainingLabel;
@property (nonatomic, strong) UISlider               *progressSlider;
@property (nonatomic, assign) BOOL                    isScrubbing;
@property (nonatomic, strong) UIButton               *prevButton;
@property (nonatomic, strong) UIButton               *playPauseButton;
@property (nonatomic, strong) UIButton               *nextButton;
@property (nonatomic, strong) UIButton               *repeatButton;
@property (nonatomic, strong) UIButton               *shuffleButton;
@property (nonatomic, strong) UITableView            *queueTable;
@property (nonatomic, strong) UIScrollView           *scrollView;
@property (nonatomic, strong) UIView                 *innerContent;
@property (nonatomic, strong) NSLayoutConstraint     *queueHeightConstraint;

// State
@property (nonatomic, assign) BOOL          isPlaying;
@property (nonatomic, assign) BOOL          repeatEnabled;
@property (nonatomic, assign) BOOL          shuffleEnabled;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, copy)   NSArray<NSString *> *queueTitles;
@property (nonatomic, copy)   NSArray<UIImage  *> *queueArtworks;
@property (nonatomic, assign) NSInteger             currentQueueIndex;

// Control stack — keep ref to update height if needed
@property (nonatomic, strong) UIStackView *controlStack;

@end

@implementation YTMDownloadsPlayerViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        // OverFullScreen avoids the dimming view that pageSheet uses,
        // which was causing the screen-dark-on-slider-touch bug.
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle   = UIModalTransitionStyleCoverVertical;
        self.queueTitles   = @[];
        self.queueArtworks = @[];
        self.currentQueueIndex = -1;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    [self buildBackground];
    [self buildCard];
    [self buildPanGesture];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.queueTable reloadData];
    [self scrollQueueToCurrentIfNeeded];
}

#pragma mark - Background

- (void)buildBackground {
    UIView *darkBase = [[UIView alloc] init];
    darkBase.backgroundColor = [UIColor colorWithRed:8/255.0 green:8/255.0 blue:8/255.0 alpha:1.0];
    darkBase.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:darkBase];

    self.bgBlurImageView = [[UIImageView alloc] init];
    self.bgBlurImageView.contentMode  = UIViewContentModeScaleAspectFill;
    self.bgBlurImageView.clipsToBounds = YES;
    self.bgBlurImageView.alpha = 0.3;
    self.bgBlurImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bgBlurImageView];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.bgBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.bgBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bgBlurView];

    for (UIView *v in @[darkBase, self.bgBlurImageView, self.bgBlurView]) {
        [NSLayoutConstraint activateConstraints:@[
            [v.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
            [v.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
            [v.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
            [v.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        ]];
    }
}

#pragma mark - Card + scroll

- (void)buildCard {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor colorWithRed:18/255.0 green:18/255.0 blue:18/255.0 alpha:0.96];
    card.layer.cornerRadius = 22;
    card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    card.clipsToBounds = YES;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:card];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor      constraintEqualToAnchor:self.view.topAnchor constant:56],
        [card.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
        [card.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    // Grabber
    self.grabberView = [[UIView alloc] init];
    self.grabberView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
    self.grabberView.layer.cornerRadius = 2.5;
    self.grabberView.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:self.grabberView];
    [NSLayoutConstraint activateConstraints:@[
        [self.grabberView.topAnchor     constraintEqualToAnchor:card.topAnchor constant:10],
        [self.grabberView.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [self.grabberView.widthAnchor   constraintEqualToConstant:36],
        [self.grabberView.heightAnchor  constraintEqualToConstant:5],
    ]];

    // ScrollView
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.bounces = YES;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:self.scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor      constraintEqualToAnchor:self.grabberView.bottomAnchor constant:8],
        [self.scrollView.bottomAnchor   constraintEqualToAnchor:card.bottomAnchor],
        [self.scrollView.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
    ]];

    // Inner content view (pins to scroll contentLayoutGuide, width to frameLayoutGuide)
    self.innerContent = [[UIView alloc] init];
    self.innerContent.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.innerContent];
    [NSLayoutConstraint activateConstraints:@[
        [self.innerContent.topAnchor      constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.innerContent.bottomAnchor   constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.innerContent.leadingAnchor  constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor],
        [self.innerContent.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor],
    ]];

    [self buildArtwork];
    [self buildTitle];
    [self buildProgress];
    [self buildControls];
    [self buildQueue];
}

#pragma mark - Artwork

- (void)buildArtwork {
    self.artworkContainer = [[UIView alloc] init];
    self.artworkContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.artworkContainer.layer.shadowColor   = [UIColor blackColor].CGColor;
    self.artworkContainer.layer.shadowOffset  = CGSizeMake(0, 14);
    self.artworkContainer.layer.shadowRadius  = kArtShadowRadius;
    self.artworkContainer.layer.shadowOpacity = kArtShadowOpacity;
    [self.innerContent addSubview:self.artworkContainer];

    self.artworkImageView = [[UIImageView alloc] init];
    self.artworkImageView.contentMode        = UIViewContentModeScaleAspectFill;
    self.artworkImageView.clipsToBounds      = YES;
    self.artworkImageView.layer.cornerRadius = kArtworkCornerRadius;
    self.artworkImageView.backgroundColor    = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.artworkImageView.tintColor          = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    self.artworkImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.artworkContainer addSubview:self.artworkImageView];

    CGFloat artSize = MIN(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height) - 80;

    [NSLayoutConstraint activateConstraints:@[
        [self.artworkContainer.topAnchor     constraintEqualToAnchor:self.innerContent.topAnchor constant:20],
        [self.artworkContainer.centerXAnchor constraintEqualToAnchor:self.innerContent.centerXAnchor],
        [self.artworkContainer.widthAnchor   constraintEqualToConstant:artSize],
        [self.artworkContainer.heightAnchor  constraintEqualToConstant:artSize],
        [self.artworkImageView.topAnchor     constraintEqualToAnchor:self.artworkContainer.topAnchor],
        [self.artworkImageView.bottomAnchor  constraintEqualToAnchor:self.artworkContainer.bottomAnchor],
        [self.artworkImageView.leadingAnchor  constraintEqualToAnchor:self.artworkContainer.leadingAnchor],
        [self.artworkImageView.trailingAnchor constraintEqualToAnchor:self.artworkContainer.trailingAnchor],
    ]];

    self.artworkContainer.transform = CGAffineTransformMakeScale(kArtPausedScale, kArtPausedScale);
}

#pragma mark - Title

- (void)buildTitle {
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.textColor              = [UIColor whiteColor];
    self.titleLabel.font                   = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    self.titleLabel.textAlignment          = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines          = 2;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor     = 0.7;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.innerContent addSubview:self.titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor     constraintEqualToAnchor:self.artworkContainer.bottomAnchor constant:28],
        [self.titleLabel.leadingAnchor  constraintEqualToAnchor:self.innerContent.leadingAnchor constant:28],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.innerContent.trailingAnchor constant:-28],
    ]];
}

#pragma mark - Progress

- (void)buildProgress {
    self.progressSlider = [[UISlider alloc] init];
    self.progressSlider.minimumTrackTintColor = [UIColor colorWithRed:30/255.0 green:150/255.0 blue:245/255.0 alpha:1.0];
    self.progressSlider.maximumTrackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.25];
    self.progressSlider.thumbTintColor        = [UIColor whiteColor];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressSlider addTarget:self action:@selector(sliderTouchBegan:) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(sliderTouchEnded:)
                  forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    [self.innerContent addSubview:self.progressSlider];

    self.elapsedLabel   = [self makeTimeLabel];
    self.remainingLabel = [self makeTimeLabel];
    self.elapsedLabel.textAlignment   = NSTextAlignmentLeft;
    self.remainingLabel.textAlignment = NSTextAlignmentRight;
    self.elapsedLabel.text   = @"0:00";
    self.remainingLabel.text = @"-0:00";
    [self.innerContent addSubview:self.elapsedLabel];
    [self.innerContent addSubview:self.remainingLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.progressSlider.topAnchor     constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
        [self.progressSlider.leadingAnchor  constraintEqualToAnchor:self.innerContent.leadingAnchor constant:24],
        [self.progressSlider.trailingAnchor constraintEqualToAnchor:self.innerContent.trailingAnchor constant:-24],
        [self.elapsedLabel.topAnchor       constraintEqualToAnchor:self.progressSlider.bottomAnchor constant:4],
        [self.elapsedLabel.leadingAnchor    constraintEqualToAnchor:self.progressSlider.leadingAnchor],
        [self.remainingLabel.topAnchor     constraintEqualToAnchor:self.progressSlider.bottomAnchor constant:4],
        [self.remainingLabel.trailingAnchor constraintEqualToAnchor:self.progressSlider.trailingAnchor],
    ]];
}

- (UILabel *)makeTimeLabel {
    UILabel *l = [[UILabel alloc] init];
    l.font      = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
    l.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}

#pragma mark - Controls

- (void)buildControls {
    self.shuffleButton   = [self btnWithSF:@"shuffle"       size:20];
    self.prevButton      = [self btnWithSF:@"backward.fill" size:28];
    self.playPauseButton = [self btnWithSF:@"play.fill"     size:36];
    self.nextButton      = [self btnWithSF:@"forward.fill"  size:28];
    self.repeatButton    = [self btnWithSF:@"repeat"        size:20];

    [self.shuffleButton   addTarget:self action:@selector(shuffleTapped)   forControlEvents:UIControlEventTouchUpInside];
    [self.prevButton      addTarget:self action:@selector(prevTapped)      forControlEvents:UIControlEventTouchUpInside];
    [self.playPauseButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.nextButton      addTarget:self action:@selector(nextTapped)      forControlEvents:UIControlEventTouchUpInside];
    [self.repeatButton    addTarget:self action:@selector(repeatTapped)    forControlEvents:UIControlEventTouchUpInside];

    self.controlStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.shuffleButton, self.prevButton, self.playPauseButton, self.nextButton, self.repeatButton
    ]];
    self.controlStack.axis         = UILayoutConstraintAxisHorizontal;
    self.controlStack.distribution = UIStackViewDistributionEqualSpacing;
    self.controlStack.alignment    = UIStackViewAlignmentCenter;
    self.controlStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.innerContent addSubview:self.controlStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.controlStack.topAnchor     constraintEqualToAnchor:self.elapsedLabel.bottomAnchor constant:20],
        [self.controlStack.leadingAnchor  constraintEqualToAnchor:self.innerContent.leadingAnchor constant:28],
        [self.controlStack.trailingAnchor constraintEqualToAnchor:self.innerContent.trailingAnchor constant:-28],
        [self.controlStack.heightAnchor  constraintEqualToConstant:64],
    ]];
}

- (UIButton *)btnWithSF:(NSString *)sfName size:(CGFloat)size {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:size];
    btn.tintColor = [UIColor whiteColor];
    [btn setImage:[[UIImage systemImageNamed:sfName withConfiguration:cfg]
                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
         forState:UIControlStateNormal];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    return btn;
}

#pragma mark - Queue section

- (void)buildQueue {
    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [self.innerContent addSubview:sep];

    UILabel *header = [[UILabel alloc] init];
    header.text      = @"Próximas reproduções";
    header.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    header.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.innerContent addSubview:header];

    self.queueTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.queueTable.backgroundColor = [UIColor clearColor];
    self.queueTable.separatorColor  = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    self.queueTable.separatorInset  = UIEdgeInsetsMake(0, 72, 0, 0);
    self.queueTable.scrollEnabled   = NO;   // outer scrollView handles scrolling
    self.queueTable.dataSource      = self;
    self.queueTable.delegate        = self;
    [self.queueTable registerClass:[YTMQueueCell class] forCellReuseIdentifier:@"QueueCell"];
    self.queueTable.translatesAutoresizingMaskIntoConstraints = NO;
    [self.innerContent addSubview:self.queueTable];

    self.queueHeightConstraint = [self.queueTable.heightAnchor constraintEqualToConstant:0];
    self.queueHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [sep.topAnchor        constraintEqualToAnchor:self.controlStack.bottomAnchor constant:28],
        [sep.leadingAnchor    constraintEqualToAnchor:self.innerContent.leadingAnchor],
        [sep.trailingAnchor   constraintEqualToAnchor:self.innerContent.trailingAnchor],
        [sep.heightAnchor     constraintEqualToConstant:0.5],
        [header.topAnchor     constraintEqualToAnchor:sep.bottomAnchor constant:16],
        [header.leadingAnchor  constraintEqualToAnchor:self.innerContent.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:self.innerContent.trailingAnchor constant:-16],
        [self.queueTable.topAnchor     constraintEqualToAnchor:header.bottomAnchor constant:8],
        [self.queueTable.leadingAnchor  constraintEqualToAnchor:self.innerContent.leadingAnchor],
        [self.queueTable.trailingAnchor constraintEqualToAnchor:self.innerContent.trailingAnchor],
        [self.queueTable.bottomAnchor  constraintEqualToAnchor:self.innerContent.bottomAnchor constant:-40],
    ]];
}

- (void)refreshQueueHeight {
    self.queueHeightConstraint.constant = (CGFloat)self.queueTitles.count * 60.0;
    [self.innerContent layoutIfNeeded];
}

- (void)scrollQueueToCurrentIfNeeded {
    if (self.currentQueueIndex > 0 && self.currentQueueIndex < (NSInteger)self.queueTitles.count) {
        NSIndexPath *ip = [NSIndexPath indexPathForRow:self.currentQueueIndex inSection:0];
        [self.queueTable scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionNone animated:NO];
    }
}

#pragma mark - UITableView (queue)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv  { return 1; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)self.queueTitles.count; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 60; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    YTMQueueCell *cell = [tv dequeueReusableCellWithIdentifier:@"QueueCell" forIndexPath:ip];
    NSString *title = self.queueTitles[ip.row];
    UIImage  *art   = (ip.row < (NSInteger)self.queueArtworks.count) ? self.queueArtworks[ip.row] : nil;
    [cell configureWithTitle:title artwork:art isCurrentTrack:(ip.row == self.currentQueueIndex) isPlaying:self.isPlaying];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    [self.delegate playerDidRequestJumpToIndex:ip.row];
}

#pragma mark - Pan gesture

- (void)buildPanGesture {
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    self.panGesture.delegate = self;
    [self.view addGestureRecognizer:self.panGesture];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g {
    if (g != self.panGesture) return YES;
    CGPoint vel = [(UIPanGestureRecognizer *)g velocityInView:self.view];
    return fabs(vel.y) > fabs(vel.x);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    // Only start dismiss when scrollView is scrolled to top
    if (self.scrollView.contentOffset.y > 2) return;
    CGFloat ty = MAX(0, [pan translationInView:self.view].y);

    switch (pan.state) {
        case UIGestureRecognizerStateChanged:
            self.view.transform = CGAffineTransformMakeTranslation(0, ty);
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat vy = [pan velocityInView:self.view].y;
            if (ty > 160 || vy > 900) {
                [self dismissAnimated];
            } else {
                [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0 options:0 animations:^{
                    self.view.transform = CGAffineTransformIdentity;
                } completion:nil];
            }
            break;
        }
        default: break;
    }
}

- (void)dismissAnimated {
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.view.transform = CGAffineTransformMakeTranslation(0, self.view.bounds.size.height);
    } completion:^(BOOL f) {
        self.view.transform = CGAffineTransformIdentity;
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

#pragma mark - Button actions

- (void)playPauseTapped { [self.delegate playerDidTogglePlayPause]; }
- (void)nextTapped      { [self.delegate playerDidRequestNext]; }
- (void)prevTapped      { [self.delegate playerDidRequestPrev]; }
- (void)repeatTapped    { [self.delegate playerDidToggleRepeat]; }
- (void)shuffleTapped   { [self.delegate playerDidToggleShuffle]; }
- (void)sliderTouchBegan:(UISlider *)s { self.isScrubbing = YES; }
- (void)sliderTouchEnded:(UISlider *)s {
    self.isScrubbing = NO;
    [self.delegate playerDidRequestSeekTo:s.value];
}

#pragma mark - Public API

- (void)updateWithTitle:(NSString *)title
                artwork:(nullable UIImage *)artwork
              isPlaying:(BOOL)isPlaying
          repeatEnabled:(BOOL)repeatEnabled
         shuffleEnabled:(BOOL)shuffleEnabled {

    self.isPlaying     = isPlaying;
    self.repeatEnabled = repeatEnabled;
    self.shuffleEnabled = shuffleEnabled;

    dispatch_async(dispatch_get_main_queue(), ^{
        self.titleLabel.text = title;

        UIImage *art = artwork ?: [UIImage systemImageNamed:@"music.note"];
        self.artworkImageView.image = art;
        self.bgBlurImageView.image  = art;

        // Play/pause icon – must force a fresh image to guarantee the button redraws
        UIImageSymbolConfiguration *ppCfg = [UIImageSymbolConfiguration configurationWithPointSize:36 weight:UIImageSymbolWeightRegular];
        NSString *ppName = isPlaying ? @"pause.fill" : @"play.fill";
        [self.playPauseButton setImage:nil forState:UIControlStateNormal];   // clear first
        [self.playPauseButton setImage:[[UIImage systemImageNamed:ppName withConfiguration:ppCfg]
                                        imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                              forState:UIControlStateNormal];

        // Artwork scale
        CGFloat scale = isPlaying ? kArtPlayingScale : kArtPausedScale;
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.3 options:0 animations:^{
            self.artworkContainer.transform = CGAffineTransformMakeScale(scale, scale);
        } completion:nil];

        // Repeat / shuffle tint
        UIColor *on = [UIColor colorWithRed:30/255.0 green:150/255.0 blue:245/255.0 alpha:1.0];
        self.repeatButton.tintColor  = repeatEnabled  ? on : [UIColor whiteColor];
        self.shuffleButton.tintColor = shuffleEnabled ? on : [UIColor whiteColor];

        [self.queueTable reloadData];
    });
}

- (void)updateProgress:(float)fraction
       elapsedSeconds:(NSTimeInterval)elapsed
      durationSeconds:(NSTimeInterval)duration {
    if (self.isScrubbing) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.duration = duration;
        self.progressSlider.value = fraction;
        self.elapsedLabel.text    = [self formatTime:elapsed];
        NSTimeInterval rem = MAX(0, duration - elapsed);
        self.remainingLabel.text  = [NSString stringWithFormat:@"-%@", [self formatTime:rem]];
    });
}

- (void)updateQueue:(NSArray<NSString *> *)titles
           artworks:(NSArray<UIImage *> *)artworks
       currentIndex:(NSInteger)currentIndex {
    self.queueTitles       = titles   ?: @[];
    self.queueArtworks     = artworks ?: @[];
    self.currentQueueIndex = currentIndex;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshQueueHeight];
        [self.queueTable reloadData];
    });
}

- (NSString *)formatTime:(NSTimeInterval)t {
    NSInteger s = (NSInteger)t % 60, m = (NSInteger)t / 60, h = m / 60;
    m %= 60;
    return h > 0 ? [NSString stringWithFormat:@"%ld:%02ld:%02ld",(long)h,(long)m,(long)s]
                 : [NSString stringWithFormat:@"%ld:%02ld",(long)m,(long)s];
}

@end
