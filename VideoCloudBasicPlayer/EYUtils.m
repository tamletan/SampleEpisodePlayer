
#import "EYUtils.h"

@implementation UIViewController (EYUtils)
+ (instancetype)createFromXIB
{
    NSString* fileName = NSStringFromClass(self.class);
    if([NSBundle.mainBundle pathForResource:fileName ofType:@"nib"])
        return [self.alloc initWithNibName:fileName bundle:nil];
    
    return [self.alloc init];
}
@end
