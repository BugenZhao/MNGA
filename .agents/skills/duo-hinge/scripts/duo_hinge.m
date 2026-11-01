// Runs inside the iPhone Duo simulator through `xcrun simctl spawn`.
//
//   duo_hinge get
//   duo_hinge set <degrees>
//
// `set` posts the vendor-defined HID event Device Hub's hinge slider sends, then waits
// until CoreMotion reports the new angle. Both are private interfaces, so expect this to
// need changes with new Xcode or runtime releases.
// Mechanism documented by https://github.com/artemnovichkov/hinge

#import <Foundation/Foundation.h>

#include <mach/mach_time.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

extern IOHIDEventRef IOHIDEventCreateVendorDefinedEvent(CFAllocatorRef, uint64_t, uint32_t usagePage, uint32_t usage,
                                                        uint32_t version, const uint8_t *data, CFIndex length,
                                                        uint32_t options);
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreateWithType(CFAllocatorRef, int type, CFDictionaryRef);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef, IOHIDEventRef);
extern CFDataRef IOCFSerialize(CFTypeRef, CFOptionFlags);

@interface CMAngle : NSObject
- (float)angleDegrees;
@end

@interface CMAngleManager : NSObject
+ (BOOL)isAvailable;
- (void)startAngleUpdatesToQueue:(NSOperationQueue *)queue handler:(void (^)(CMAngle *angle))handler;
- (void)stopAngleUpdates;
@end

static const CFTimeInterval kTimeout = 3;
// The simulator lands exactly on 0 and 180, but settles up to about 5 degrees short of an
// angle in between, on a side that depends on the direction of travel.
static const double kEndpointTolerance = 0.5;
static const double kIntermediateTolerance = 6;

static void sendAngle(double degrees) {
  IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreateWithType(NULL, 4, NULL);
  NSDictionary *payload = @{
    @"provider": @"com.apple.Virtualization.VirtualMachines",
    @"source": @"hinge-slider-control",
    @"type": @"range",
    @"value": @(degrees),
  };
  CFDataRef data = IOCFSerialize((__bridge CFTypeRef)payload, 1);
  IOHIDEventRef event = IOHIDEventCreateVendorDefinedEvent(NULL, mach_absolute_time(), 0xFF61, 0x5B, 0,
                                                           CFDataGetBytePtr(data), CFDataGetLength(data), 0);
  IOHIDEventSystemClientDispatchEvent(client, event);
  CFRelease(event);
  CFRelease(data);
}

// Calls `start`, then returns the first angle `accept` takes, or NAN on timeout.
static double observe(void (^start)(void), BOOL (^accept)(double)) {
  Class managerClass = NSClassFromString(@"CMAngleManager");
  if (!managerClass || ![managerClass isAvailable]) {
    fprintf(stderr, "duo_hinge: this simulator reports no hinge\n");
    return NAN;
  }
  CMAngleManager *manager = [[managerClass alloc] init];
  __block double found = NAN;
  [manager startAngleUpdatesToQueue:[NSOperationQueue new] handler:^(CMAngle *angle) {
    if (isnan(found) && accept(angle.angleDegrees)) found = angle.angleDegrees;
  }];
  if (start) start();
  CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + kTimeout;
  while (isnan(found) && CFAbsoluteTimeGetCurrent() < deadline) {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
  }
  [manager stopAngleUpdates];
  return found;
}

int main(int argc, char **argv) {
  @autoreleasepool {
    double result = NAN;
    if (argc == 2 && strcmp(argv[1], "get") == 0) {
      result = observe(nil, ^BOOL(double reported) { return YES; });
    } else if (argc == 3 && strcmp(argv[1], "set") == 0) {
      double target = fmin(fmax(atof(argv[2]), 0), 180);
      double tolerance = (target == 0 || target == 180) ? kEndpointTolerance : kIntermediateTolerance;
      result = observe(^{ sendAngle(target); }, ^BOOL(double reported) { return fabs(reported - target) <= tolerance; });
    } else {
      fprintf(stderr, "usage: duo_hinge get | duo_hinge set <degrees>\n");
      return 64;
    }
    if (isnan(result)) {
      fprintf(stderr, "duo_hinge: no matching hinge angle within %.0f s\n", kTimeout);
      return 1;
    }
    printf("%.1f\n", result);
    return 0;
  }
}
