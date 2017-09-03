#import "ViewController.h"

#import "GoomViewController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

- (IBAction) buttonGoomClicked:(id)sender {
    [self presentViewController:[[GoomViewController alloc] init]
                       animated:YES
                     completion:nil];
    
    
}

- (IBAction) buttonProjectMClicked:(id)sender {
    
}

@end
