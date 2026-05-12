#import "YTMDownloadsPlayerViewController.h"

static const CGFloat kArtworkCornerRadius = 16.0;
static const CGFloat kArtShadowRadius     = 24.0;
static const CGFloat kArtShadowOpacity    = 0.55;
static const CGFloat kArtPlayingScale     = 1.0;
static const CGFloat kArtPausedScale      = 0.82;

@interface YTMDownloadsPlayerViewController ()

// Background
@property (nonatomic, strong) UIImageView   *bgBlurImageView;
@property (nonatomic, strong) UIVisualEffectView *bgBlurView;

// Drag-to-dismiss
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;

// Artwork
@property (nonatomic, strong) UIView        *artworkContainer;
@property (nonatomic, strong) UIImageView   *artworkImageView;

// Labels
@property (nonatomic, strong) UILabel       *titleLabel;
@property (nonatomic, strong) UILabel       *elapsedLabel;
@property (nonatomic, strong) UILabel       *remainingLabel;

// Slider
@property (nonatomic, strong) UISlider      *progressSlider;
@property (nonatomic, assign) BOOL           isScrubbing;

// Buttons
@property (nonatomic, strong) UIButton      *prevButton;
@property (nonatomic, strong) UIButton      *playPauseButton;
@property (nonatomic, strong) UIButton      *nextButton;
@property (nonatomic, strong) UIButton      *repeatButton;
@property (nonatomic, strong) UIButton      *shuffleButton;
@property (nonatomic, strong) UIButton      *dismissButton;

// State
@property (nonatomic, assign) BOOL  isPlaying;
@property (nonatomic, assign) BOOL  repeatEnabled;
@property (nonatomic, assign) BOOL  shuffleEnabled;
@property (nonatomic, assign) NSTimeInterval duration;

@end

@implementation YTMDownloadsPlayerViewController

#pragma mark - Init

- (instancetype)init {
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationPageSheet;
        if (@available(iOS 15.0, *)) {
            // sheet config is set in viewDidLoad
        }
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithRed:10/255.0 green:10/255.0 blue:10/255.0 alpha:1.0];

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[UISheetPresentationControllerDetent.largeDetent];
            sheet.prefersGrabberVisible = YES;
            sheet.preferredCornerRadius = 24;
        }
    }

    [self buildBackground];
    [self buildDismissButton];
    [self buildArtwork];
    [self buildTitleLabel];
    [self buildProgressRow];
    [self buildControlButtons];
    [self buildPanGesture];
}

#pragma mark - Background blur

- (void)buildBackground {
    self.bgBlurImageView = [[UIImageView alloc] init];
    self.bgBlurImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.bgBlurImageView.clipsToBounds = YES;
    self.bgBlurImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view insertSubview:self.bgBlurImageView atIndex:0];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.bgBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.bgBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view insertSubview:self.bgBlurView atIndex:1];

    [NSLayoutConstraint activateConstraints:@[
        [self.bgBlurImageView.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [self.bgBlurImageView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bgBlurImageView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bgBlurImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bgBlurView.topAnchor           constraintEqualToAnchor:self.view.topAnchor],
        [self.bgBlurView.bottomAnchor        constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bgBlurView.leadingAnchor       constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bgBlurView.trailingAnchor      constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

#pragma mark - Dismiss button

- (void)buildDismissButton {
    self.dismissButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    [self.dismissButton setImage:[[UIImage systemImageNamed:@"chevron.down" withConfiguration:cfg]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                        forState:UIControlStateNormal];
    self.dismissButton.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
    self.dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.dismissButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    self.dismissButton.layer.cornerRadius = 14;
    [self.dismissButton addTarget:self action:@selector(dismissTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.dismissButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.dismissButton.topAnchor     constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.dismissButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.dismissButton.widthAnchor   constraintEqualToConstant:44],
        [self.dismissButton.heightAnchor  constraintEqualToConstant:28],
    ]];
}

#pragma mark - Artwork

- (void)buildArtwork {
    self.artworkContainer = [[UIView alloc] init];
    self.artworkContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.artworkContainer.layer.shadowColor   = [UIColor blackColor].CGColor;
    self.artworkContainer.layer.shadowOffset  = CGSizeMake(0, 12);
    self.artworkContainer.layer.shadowRadius  = kArtShadowRadius;
    self.artworkContainer.layer.shadowOpacity = kArtShadowOpacity;
    [self.view addSubview:self.artworkContainer];

    self.artworkImageView = [[UIImageView alloc] init];
    self.artworkImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.artworkImageView.clipsToBounds = YES;
    self.artworkImageView.layer.cornerRadius = kArtworkCornerRadius;
    self.artworkImageView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.artworkImageView.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    self.artworkImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.artworkContainer addSubview:self.artworkImageView];

    CGFloat artSize = MIN(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height) - 72;

    [NSLayoutConstraint activateConstraints:@[
        [self.artworkContainer.topAnchor     constraintEqualToAnchor:self.dismissButton.bottomAnchor constant:28],
        [self.artworkContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
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

- (void)buildTitleLabel {
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.textColor     = [UIColor whiteColor];
    self.titleLabel.font          = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.7;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor     constraintEqualToAnchor:self.artworkContainer.bottomAnchor constant:28],
        [self.titleLabel.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:28],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28],
    ]];
}

#pragma mark - Progress row

- (void)buildProgressRow {
    // Slider
    self.progressSlider = [[UISlider alloc] init];
    self.progressSlider.minimumTrackTintColor = [UIColor colorWithRed:30/255.0 green:150/255.0 blue:245/255.0 alpha:1.0];
    self.progressSlider.maximumTrackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.25];
    self.progressSlider.thumbTintColor        = [UIColor whiteColor];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressSlider addTarget:self action:@selector(sliderTouchBegan:) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(sliderTouchEnded:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
    [self.view addSubview:self.progressSlider];

    // Time labels
    self.elapsedLabel   = [self makeTimeLabel];
    self.remainingLabel = [self makeTimeLabel];
    self.elapsedLabel.textAlignment   = NSTextAlignmentLeft;
    self.remainingLabel.textAlignment = NSTextAlignmentRight;
    self.elapsedLabel.text   = @"0:00";
    self.remainingLabel.text = @"-0:00";
    [self.view addSubview:self.elapsedLabel];
    [self.view addSubview:self.remainingLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.progressSlider.topAnchor     constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
        [self.progressSlider.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.progressSlider.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [self.elapsedLabel.topAnchor     constraintEqualToAnchor:self.progressSlider.bottomAnchor constant:4],
        [self.elapsedLabel.leadingAnchor  constraintEqualToAnchor:self.progressSlider.leadingAnchor],
        [self.remainingLabel.topAnchor    constraintEqualToAnchor:self.progressSlider.bottomAnchor constant:4],
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

#pragma mark - Control buttons

- (void)buildControlButtons {
    self.shuffleButton   = [self makeButtonWithSFSymbol:@"shuffle"       size:20];
    self.prevButton      = [self makeButtonWithSFSymbol:@"backward.fill" size:28];
    self.playPauseButton = [self makeButtonWithSFSymbol:@"play.fill"     size:36];
    self.nextButton      = [self makeButtonWithSFSymbol:@"forward.fill"  size:28];
    self.repeatButton    = [self makeButtonWithSFSymbol:@"repeat"        size:20];

    [self.shuffleButton   addTarget:self action:@selector(shuffleTapped)   forControlEvents:UIControlEventTouchUpInside];
    [self.prevButton      addTarget:self action:@selector(prevTapped)      forControlEvents:UIControlEventTouchUpInside];
    [self.playPauseButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.nextButton      addTarget:self action:@selector(nextTapped)      forControlEvents:UIControlEventTouchUpInside];
    [self.repeatButton    addTarget:self action:@selector(repeatTapped)    forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.shuffleButton, self.prevButton, self.playPauseButton, self.nextButton, self.repeatButton
    ]];
    stack.axis         = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionEqualSpacing;
    stack.alignment    = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor     constraintEqualToAnchor:self.elapsedLabel.bottomAnchor constant:20],
        [stack.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:28],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28],
        [stack.heightAnchor  constraintEqualToConstant:64],
    ]];
}

- (UIButton *)makeButtonWithSFSymbol:(NSString *)sfName size:(CGFloat)size {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:size];
    btn.tintColor = [UIColor whiteColor];
    [btn setImage:[[UIImage systemImageNamed:sfName withConfiguration:symCfg]
                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
         forState:UIControlStateNormal];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    return btn;
}

#pragma mark - Pan to dismiss

- (void)buildPanGesture {
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    self.panGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
    [self.view addGestureRecognizer:self.panGesture];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGFloat ty = [pan translationInView:self.view].y;
    if (ty < 0) ty = 0;

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
                [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:0 animations:^{
                    self.view.transform = CGAffineTransformIdentity;
                } completion:nil];
            }
            break;
        }
        default: break;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return NO;
}

#pragma mark - Dismiss

- (void)dismissTapped { [self dismissAnimated]; }

- (void)dismissAnimated {
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.view.transform = CGAffineTransformMakeTranslation(0, self.view.bounds.size.height);
    } completion:^(BOOL finished) {
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

#pragma mark - Public update API

- (void)updateWithTitle:(NSString *)title
                artwork:(nullable UIImage *)artwork
              isPlaying:(BOOL)isPlaying
          repeatEnabled:(BOOL)repeatEnabled
         shuffleEnabled:(BOOL)shuffleEnabled {

    self.isPlaying      = isPlaying;
    self.repeatEnabled  = repeatEnabled;
    self.shuffleEnabled = shuffleEnabled;

    self.titleLabel.text = title;

    UIImage *displayArt = artwork ?: [UIImage systemImageNamed:@"music.note"];
    self.artworkImageView.image    = displayArt;
    self.bgBlurImageView.image     = displayArt;

    // Play/pause icon
    CGFloat ppSize = 36;
    UIImageSymbolConfiguration *ppCfg = [UIImageSymbolConfiguration configurationWithPointSize:ppSize];
    NSString *ppName = isPlaying ? @"pause.fill" : @"play.fill";
    [self.playPauseButton setImage:[[UIImage systemImageNamed:ppName withConfiguration:ppCfg]
                                     imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                          forState:UIControlStateNormal];

    // Artwork scale animation (like YTM)
    CGFloat targetScale = isPlaying ? kArtPlayingScale : kArtPausedScale;
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.3 options:0 animations:^{
        self.artworkContainer.transform = CGAffineTransformMakeScale(targetScale, targetScale);
    } completion:nil];

    // Repeat/shuffle highlight
    UIColor *activeColor = [UIColor colorWithRed:30/255.0 green:150/255.0 blue:245/255.0 alpha:1.0];
    self.repeatButton.tintColor  = repeatEnabled  ? activeColor : [UIColor whiteColor];
    self.shuffleButton.tintColor = shuffleEnabled ? activeColor : [UIColor whiteColor];
}

- (void)updateProgress:(float)fraction
       elapsedSeconds:(NSTimeInterval)elapsed
      durationSeconds:(NSTimeInterval)duration {
    if (self.isScrubbing) return;

    self.duration = duration;
    self.progressSlider.value = fraction;

    self.elapsedLabel.text   = [self formatTime:elapsed];
    NSTimeInterval remaining = MAX(0, duration - elapsed);
    self.remainingLabel.text = [NSString stringWithFormat:@"-%@", [self formatTime:remaining]];
}

- (NSString *)formatTime:(NSTimeInterval)t {
    NSInteger secs  = (NSInteger)t % 60;
    NSInteger mins  = (NSInteger)t / 60;
    NSInteger hours = mins / 60;
    mins = mins % 60;
    if (hours > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)mins, (long)secs];
    return [NSString stringWithFormat:@"%ld:%02ld", (long)mins, (long)secs];
}

@end
