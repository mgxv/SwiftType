#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C++ wrapper around KenLM, exposed as a singleton.
///
/// Provides n-gram-based next-word prediction by scoring vocabulary words against
/// a context state built from preceding tokens.  Each call to
/// `nextWordPredictions:limit:` tokenizes the context, builds a KenLM state, scores
/// every vocabulary word, and returns the top-N most likely continuations.
///
/// The model is loaded lazily on the first call to `+shared`. Model files live at
/// `Resources/KenLM/{code}.binary` in the app bundle.  If the model file is absent,
/// `nextWordPredictions:limit:` returns an empty array gracefully.
///
/// Language switching (`setLanguage:`) unloads the current model and loads the binary
/// for the requested language code.  Called from `KenLMPredictor.refreshLanguage()`.
@interface KenLMBridge : NSObject

+ (instancetype)shared;

/// Returns up to `limit` next-word predictions for the given context string,
/// ranked by descending probability.
/// Returns an empty array if no model is loaded or the context is empty.
- (NSArray<NSString *> *)nextWordPredictions:(NSString *)context limit:(NSInteger)limit;

/// Switches to the model for the given BCP-47 base language code (e.g. "en", "de").
/// Unloads the current model and loads `Resources/KenLM/{code}.binary`.
/// No-op if the requested language matches the currently loaded model.
/// If the model file does not exist, the bridge enters an unloaded state and
/// `nextWordPredictions:limit:` will return empty arrays.
- (void)setLanguage:(NSString *)code;

/// Returns the BCP-47 base code of the currently loaded model, or nil if no model is loaded.
@property (nonatomic, readonly, nullable) NSString *currentLanguage;

@end

NS_ASSUME_NONNULL_END
