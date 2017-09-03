#import "ViewController.h"

#import "TestController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

- (IBAction) buttonGoomClicked:(id)sender {
    [self presentViewController:[[TestController alloc] init]
                       animated:YES
                     completion:nil];
    
    
}

- (IBAction) buttonProjectMClicked:(id)sender {

}

@end
