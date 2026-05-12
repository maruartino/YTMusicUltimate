#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

NS_ASSUME_NONNULL_BEGIN

@protocol YTMDownloadsPlayerDelegate <NSObject>
- (void)playerDidRequestNext;
- (void)playerDidRequestPrev;
- (void)playerDidRequestSeekTo:(float)fraction;
- (void)playerDidTogglePlayPause;
- (void)playerDidToggleRepeat;
- (void)playerDidToggleShuffle;
- (void)playerDidRequestJumpToIndex:(NSInteger)index;
@end

@interface YTMDownloadsPlayerViewController : UIViewController

@property (nonatomic, weak, nullable) id<YTMDownloadsPlayerDelegate> delegate;

/// Sync playback state (title, art, playing/repeat/shuffle)
- (void)updateWithTitle:(NSString *)title
                artwork:(nullable UIImage *)artwork
              isPlaying:(BOOL)isPlaying
             repeatMode:(NSInteger)repeatMode
         shuffleEnabled:(BOOL)shuffleEnabled;

/// Sync scrubber — call from time observer
- (void)updateProgress:(float)fraction
       elapsedSeconds:(NSTimeInterval)elapsed
      durationSeconds:(NSTimeInterval)duration;

/// Sync queue list
- (void)updateQueue:(NSArray<NSString *> *)titles
           artworks:(NSArray<UIImage *> *)artworks
       currentIndex:(NSInteger)currentIndex;

/// Dismiss with animation
- (void)dismissAnimated;

@end

NS_ASSUME_NONNULL_END
