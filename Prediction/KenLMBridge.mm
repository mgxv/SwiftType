#import "KenLMBridge.h"
#import <os/log.h>

// KenLM requires KENLM_MAX_ORDER at compile time (must match the value used to build the library).
#ifndef KENLM_MAX_ORDER
#define KENLM_MAX_ORDER 6
#endif

// KenLM headers use std::binary_function, removed in C++17.
#define _LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION

#include <algorithm>
#include <queue>
#include <string>
#include <vector>

#include <lm/model.hh>

static os_log_t sLog;

/// Callback used during model load to enumerate the full vocabulary.
/// Passed via Config.enumerate_vocab; only lives for the duration of the Model constructor.
/// Per KenLM docs: "index starts at 0 and increases by 1 each time."
class VocabCollector : public lm::EnumerateVocab {
public:
    std::vector<std::string> words;
    std::vector<lm::WordIndex> indices;

    void Add(lm::WordIndex index, const StringPiece &str) override {
        std::string word(str.data(), str.length());
        // Skip the three KenLM special tokens.  Checking exact names rather than
        // a leading-'<' heuristic avoids accidentally filtering real vocabulary.
        if (word == "<s>" || word == "</s>" || word == "<unk>") return;
        if (word.empty()) return;
        // Skip words that don't start with a letter.  This filters punctuation,
        // numbers, and contraction fragments like 's, 't, 're from tokenized corpora.
        // UTF-8 multi-byte sequences (leading byte >= 0xC0) are letters (ä, ö, ü, etc.).
        unsigned char first = static_cast<unsigned char>(word[0]);
        if (!std::isalpha(first) && first < 0xC0) return;
        words.push_back(word);
        indices.push_back(index);
    }
};

/// A scored candidate for the priority queue.
struct ScoredWord {
    float score;
    size_t vocabIndex; // index into VocabCollector::words

    bool operator>(const ScoredWord &other) const {
        return score > other.score;
    }
};

@implementation KenLMBridge {
    lm::ngram::Model *_model;
    VocabCollector *_vocab;
    NSDictionary<NSString *, NSString *> *_truecaseMap;
    BOOL _ready;
    NSString *_currentLanguage;
}

+ (instancetype)shared {
    static KenLMBridge *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[KenLMBridge alloc] initPrivate];
    });
    return instance;
}

- (instancetype)initPrivate {
    self = [super init];
    if (!self) return nil;

    sLog = os_log_create("com.matthew.inputmethod.SwiftType", "KenLMBridge");
    _model = nullptr;
    _vocab = nullptr;
    _truecaseMap = nil;
    _ready = NO;
    _currentLanguage = nil;

    return self;
}

- (void)dealloc {
    [self unloadModel];
}

- (NSString *)currentLanguage {
    return _currentLanguage;
}

// MARK: - Model management

- (void)unloadModel {
    _ready = NO;
    _currentLanguage = nil;
    _truecaseMap = nil;
    if (_model) {
        delete _model;
        _model = nullptr;
    }
    if (_vocab) {
        delete _vocab;
        _vocab = nullptr;
    }
}

- (BOOL)loadModelForLanguage:(NSString *)code {
    [self unloadModel];

    NSBundle *bundle = [NSBundle mainBundle];
    NSString *modelPath = [bundle pathForResource:code ofType:@"binary" inDirectory:@"KenLM"];
    if (!modelPath) {
        os_log_error(sLog, "KenLM model not found for language '%{public}s'", code.UTF8String);
        return NO;
    }

    os_log(sLog, "Loading KenLM model: %{public}s", modelPath.UTF8String);

    try {
        _vocab = new VocabCollector();

        lm::ngram::Config config;
        // Enumerate vocabulary so we can score every word for next-word prediction.
        // The pointer is not retained after the constructor returns.
        config.enumerate_vocab = _vocab;
        // Silence progress bar and messages — we're a background IME, not a CLI tool.
        config.show_progress = false;
        config.messages = nullptr;
        // Use POPULATE_OR_LAZY for fast warm-up on small models (5–15 MB).
        // The OS will page in model data on first access; no upfront read penalty.
        config.load_method = util::POPULATE_OR_LAZY;

        _model = new lm::ngram::Model(modelPath.UTF8String, config);

        os_log(sLog, "KenLM model loaded — vocab size: %zu, order: %u",
               _vocab->words.size(), _model->Order());

        _ready = YES;
        _currentLanguage = [code copy];

        // Load truecase mapping (lowercase → most common cased form).
        // File format: TSV with one "lowercase\ttruecased" pair per line.
        [self loadTruecaseForLanguage:code];

        return YES;

    } catch (const std::exception &e) {
        os_log_error(sLog, "Failed to load KenLM model: %{public}s", e.what());
        [self unloadModel];
        return NO;
    }
}

// MARK: - Truecase

- (void)loadTruecaseForLanguage:(NSString *)code {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:code ofType:@"truecase" inDirectory:@"KenLM"];
    if (!path) {
        os_log(sLog, "No truecase file for '%{public}s' — predictions will be lowercase", code.UTF8String);
        _truecaseMap = nil;
        return;
    }

    NSError *error = nil;
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (!contents) {
        os_log_error(sLog, "Failed to read truecase file: %{public}@", error.localizedDescription);
        _truecaseMap = nil;
        return;
    }

    NSMutableDictionary<NSString *, NSString *> *map = [NSMutableDictionary dictionary];
    for (NSString *line in [contents componentsSeparatedByString:@"\n"]) {
        NSArray<NSString *> *parts = [line componentsSeparatedByString:@"\t"];
        if (parts.count == 2 && parts[0].length > 0 && parts[1].length > 0) {
            map[parts[0]] = parts[1];
        }
    }

    _truecaseMap = [map copy];
    os_log(sLog, "Loaded truecase map — %zu entries", (size_t)_truecaseMap.count);
}

/// Returns the truecased form of a lowercase word, or the word itself if no mapping exists.
- (NSString *)truecaseWord:(NSString *)word {
    if (!_truecaseMap) return word;
    NSString *mapped = _truecaseMap[word];
    return mapped ?: word;
}

// MARK: - Public API

- (void)setLanguage:(NSString *)code {
    if ([code isEqualToString:_currentLanguage]) return;

    if (code.length == 0) {
        os_log(sLog, "setLanguage called with empty code — unloading model");
        [self unloadModel];
        return;
    }

    [self loadModelForLanguage:code];
}

- (NSArray<NSString *> *)nextWordPredictions:(NSString *)context limit:(NSInteger)limit {
    if (!_ready || !_model || !_vocab || limit <= 0 || context.length == 0) {
        return @[];
    }

    // Tokenize context: split on whitespace, take last (order - 1) tokens.
    NSArray<NSString *> *allTokens = [context componentsSeparatedByCharactersInSet:
                                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    for (NSString *token in allTokens) {
        if (token.length > 0) [tokens addObject:[token lowercaseString]];
    }

    if (tokens.count == 0) return @[];

    // Keep only the last (order - 1) tokens for context.
    unsigned int order = _model->Order();
    NSUInteger contextLength = (order > 1) ? (order - 1) : 1;
    if (tokens.count > contextLength) {
        tokens = [[tokens subarrayWithRange:NSMakeRange(tokens.count - contextLength, contextLength)] mutableCopy];
    }

    const lm::ngram::Model &model = *_model;
    const lm::ngram::Vocabulary &vocab = model.GetVocabulary();

    // Build state from context tokens.
    //
    // Use NullContextState (not BeginSentenceState) as the starting point.
    // BeginSentenceState injects <s> into the context, biasing predictions toward
    // sentence-initial words.  For an IME predicting the next word mid-sentence,
    // NullContextState is correct — it represents "no prior context" and lets the
    // actual context tokens drive the prediction without a sentence-start bias.
    //
    // KenLM requires in_state and out_state to be different references
    // (&in_state != &out_state).  We alternate between two State variables.
    lm::ngram::State stateA, stateB;
    stateA = model.NullContextState();

    lm::ngram::State *in = &stateA;
    lm::ngram::State *out = &stateB;

    for (NSString *token in tokens) {
        lm::WordIndex wi = vocab.Index(token.UTF8String);
        // Use Score() instead of FullScore() — we only need the probability,
        // not ngram_length or extension info.  Score() is the recommended fast path.
        model.Score(*in, wi, *out);
        std::swap(in, out);
    }

    // `in` now points to the final state after all context tokens.

    // Score every vocabulary word and keep top-N using a min-heap.
    // Min-heap: the smallest score is at the top; we pop it when we find something better.
    // KenLM is optimized for fast trie/probing hash queries — scoring ~50–100K words
    // typically takes <10 ms on modern hardware.
    std::priority_queue<ScoredWord, std::vector<ScoredWord>, std::greater<ScoredWord>> minHeap;

    size_t vocabSize = _vocab->words.size();
    for (size_t i = 0; i < vocabSize; i++) {
        lm::WordIndex wi = _vocab->indices[i];
        // `out` is used as scratch space; we don't need the output state.
        float score = model.Score(*in, wi, *out);

        if ((NSInteger)minHeap.size() < limit) {
            minHeap.push({score, i});
        } else if (score > minHeap.top().score) {
            minHeap.pop();
            minHeap.push({score, i});
        }
    }

    // Extract results sorted by descending score.
    std::vector<ScoredWord> results;
    results.reserve(minHeap.size());
    while (!minHeap.empty()) {
        results.push_back(minHeap.top());
        minHeap.pop();
    }
    std::sort(results.begin(), results.end(), [](const ScoredWord &a, const ScoredWord &b) {
        return a.score > b.score;
    });

    NSMutableArray<NSString *> *predictions = [NSMutableArray arrayWithCapacity:results.size()];
    for (const auto &sw : results) {
        NSString *word = @(_vocab->words[sw.vocabIndex].c_str());
        word = [self truecaseWord:word];
        [predictions addObject:word];
    }

    return predictions;
}

@end
