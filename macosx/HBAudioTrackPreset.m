//
//  HBAudioEncoder.m
//  HandBrake
//
//  Created by Damiano Galassi on 30/07/14.
//
//

#import "HBAudioTrackPreset.h"
#include "hb.h"

#define DEFAULT_SAMPLERATE 48000

static void *HBAudioEncoderContex = &HBAudioEncoderContex;

@implementation HBAudioTrackPreset

- (instancetype)init
{
    self = [super init];
    if (self) {
        // defaults settings
        _encoder = HB_ACODEC_CA_AAC;
        _sampleRate = 0;
        _bitRate = 160;
        _mixdown = HB_AMIXDOWN_DOLBYPLII;

        // add a serie of observers to keep the tracks properties in a valid state.
        [self addObserver:self forKeyPath:@"encoder" options:0 context:HBAudioEncoderContex];
        [self addObserver:self forKeyPath:@"mixdown" options:0 context:HBAudioEncoderContex];
        [self addObserver:self forKeyPath:@"sampleRate" options:0 context:HBAudioEncoderContex];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == HBAudioEncoderContex)
    {
        // Validate the settings
        if ([keyPath isEqualToString:@"encoder"])
        {
            [self validateMixdown];
            [self validateBitrate];
        }
        else if ([keyPath isEqualToString:@"mixdown"] || [keyPath isEqualToString:@"sampleRate"])
        {
            [self validateBitrate];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -
#pragma mark Validation

/**
 *  Validates the mixdown property.
 */
- (void)validateMixdown
{
    if (!hb_mixdown_has_codec_support(self.mixdown, self.encoder))
    {
        self.mixdown = hb_mixdown_get_default(self.encoder, 0);
    }
}

- (void)validateBitrate
{
    int minBitRate = 0;
    int maxBitRate = 0;

    int sampleRate = self.sampleRate ? self.sampleRate : DEFAULT_SAMPLERATE;

    hb_audio_bitrate_get_limits(self.encoder, sampleRate, self.mixdown, &minBitRate, &maxBitRate);

    if (self.bitRate < minBitRate || self.bitRate > maxBitRate)
    {
        self.bitRate = maxBitRate;
    }
}

- (BOOL)mixdownEnabled
{
    BOOL retval = YES;

    if (self.mixdown == HB_AMIXDOWN_NONE)
    {
        // "None" mixdown (passthru)
        retval = NO;
    }

    return retval;
}

- (BOOL)bitrateEnabled
{
    BOOL retval = YES;

    int myCodecDefaultBitrate = hb_audio_bitrate_get_default(self.encoder, 0, 0);
    if (myCodecDefaultBitrate < 0)
    {
        retval = NO;
    }
    return retval;
}

- (BOOL)passThruDisabled
{
    BOOL retval = YES;

    if (self.encoder & HB_ACODEC_PASS_FLAG)
    {
        retval = NO;
    }

    return retval;
}

// Because we have indicated that the binding for the drc validates immediately we can implement the
// key value binding method to ensure the drc stays in our accepted range.
- (BOOL)validateDrc:(id *)ioValue error:(NSError *)outError
{
    BOOL retval = YES;

    if (nil != *ioValue)
    {
        if (0.0 < [*ioValue floatValue] && 1.0 > [*ioValue floatValue])
        {
            *ioValue = @(1.0);
        }
    }

    return retval;
}

// Because we have indicated that the binding for the gain validates immediately we can implement the
// key value binding method to ensure the gain stays in our accepted range.

- (BOOL)validateGain:(id *)ioValue error:(NSError *)outError
{
    BOOL retval = YES;

    if (nil != *ioValue)
    {
        if (0.0 < [*ioValue floatValue] && 1.0 > [*ioValue floatValue])
        {
            *ioValue = @(0.0);
        }
    }

    return retval;
}

- (void)dealloc
{
    // Remove the KVO observers before deallocing the instance.
    [self removeObserver:self forKeyPath:@"encoder"];
    [self removeObserver:self forKeyPath:@"mixdown"];
    [self removeObserver:self forKeyPath:@"sampleRate"];

    [super dealloc];
}

#pragma mark - Options

- (NSArray *)encoders
{
    NSMutableArray *encoders = [[NSMutableArray alloc] init];
    for (const hb_encoder_t *audio_encoder = hb_audio_encoder_get_next(NULL);
         audio_encoder != NULL;
         audio_encoder  = hb_audio_encoder_get_next(audio_encoder))
    {
        [encoders addObject:@(audio_encoder->name)];
    }
    return [encoders autorelease];
}

- (NSArray *)mixdowns
{
    NSMutableArray *mixdowns = [[NSMutableArray alloc] init];
    for (const hb_mixdown_t *mixdown = hb_mixdown_get_next(NULL);
         mixdown != NULL;
         mixdown  = hb_mixdown_get_next(mixdown))
    {
        if (hb_mixdown_has_codec_support(mixdown->amixdown, self.encoder))
        {
            [mixdowns addObject:@(mixdown->name)];
        }
    }
    return [mixdowns autorelease];
}

- (NSArray *)samplerates
{
    NSMutableArray *samplerates = [[NSMutableArray alloc] init];
    for (const hb_rate_t *audio_samplerate = hb_audio_samplerate_get_next(NULL);
         audio_samplerate != NULL;
         audio_samplerate  = hb_audio_samplerate_get_next(audio_samplerate))
    {
        [samplerates addObject:@(audio_samplerate->name)];
    }
    return [samplerates autorelease];
}

- (NSArray *)bitrates
{
    int minBitRate = 0;
    int maxBitRate = 0;

    // If the samplerate is "Auto" pass a fake sampleRate to get the bitrates
    int sampleRate = self.sampleRate ? self.sampleRate : DEFAULT_SAMPLERATE;

    hb_audio_bitrate_get_limits(self.encoder, sampleRate, self.mixdown, &minBitRate, &maxBitRate);

    NSMutableArray *bitrates = [[NSMutableArray alloc] init];
    for (const hb_rate_t *audio_bitrate = hb_audio_bitrate_get_next(NULL);
         audio_bitrate != NULL;
         audio_bitrate  = hb_audio_bitrate_get_next(audio_bitrate))
    {
        if (audio_bitrate->rate >= minBitRate && audio_bitrate->rate <= maxBitRate)
        {
            [bitrates addObject:@(audio_bitrate->name)];
        }
    }
    return [bitrates autorelease];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    NSSet *retval = nil;

    // Tell KVO to reaload the *enabled keyPaths
    // after a change to encoder.
    if ([key isEqualToString:@"bitrateEnabled"] ||
        [key isEqualToString:@"passThruDisabled"] ||
        [key isEqualToString:@"mixdownEnabled"])
    {
        retval = [NSSet setWithObjects:@"encoder", nil];
    }

    return retval;
}

@end

#pragma mark - Value Trasformers

@implementation HBEncoderTrasformer

+ (Class)transformedValueClass
{
    return [NSString class];
}

- (id)transformedValue:(id)value
{
    const char *name = hb_audio_encoder_get_name([value intValue]);
    if (name)
    {
        return @(name);
    }
    else
    {
        return nil;
    }
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)reverseTransformedValue:(id)value
{
    return @(hb_audio_encoder_get_from_name([value UTF8String]));
}

@end

@implementation HBMixdownTrasformer

+ (Class)transformedValueClass
{
    return [NSString class];
}

- (id)transformedValue:(id)value
{
    const char *name = hb_mixdown_get_name([value intValue]);
    if (name)
    {
        return @(name);
    }
    else
    {
        return nil;
    }
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)reverseTransformedValue:(id)value
{
    return @(hb_mixdown_get_from_name([value UTF8String]));
}

@end

@implementation HBSampleRateTrasformer

+ (Class)transformedValueClass
{
    return [NSString class];
}

- (id)transformedValue:(id)value
{
    const char *name = hb_audio_samplerate_get_name([value intValue]);
    if (name)
    {
        return @(name);
    }
    else
    {
        return nil;
    }
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)reverseTransformedValue:(id)value
{
    return @(hb_audio_samplerate_get_from_name([value UTF8String]));
}

@end

@implementation HBIntegerTrasformer

+ (Class)transformedValueClass
{
    return [NSString class];
}

- (id)transformedValue:(id)value
{
    return [value stringValue];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)reverseTransformedValue:(id)value
{
    return @([value intValue]);
}

@end
