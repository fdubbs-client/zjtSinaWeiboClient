//
//  FollowerVC.m
//  zjtSinaWeiboClient
//
//  Created by Jianting Zhu on 12-4-25.
//  Copyright (c) 2012年 ZUST. All rights reserved.
//

#import "FollowerVC.h"
#import "User.h"
#import "ProfileVC.h"
#import "WeiBoMessageManager.h"
#import "LPFriendCell.h"
#import "HHNetDataCacheManager.h"

@interface FollowerVC ()
-(void)getAvatars;
@end

@implementation FollowerVC
@synthesize userArr = _usersArr;
@synthesize userAvatarDic = _userAvatarDic;
@synthesize isFollowingViewController = _isFollowingViewController;
@synthesize followerCellNib = _followerCellNib;

-(void)dealloc
{
    self.userArr = nil;
    self.userAvatarDic = nil;
    self.followerCellNib = nil;
    
    [super dealloc];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = @"粉丝列表";
        self.tabBarItem.image = [UIImage imageNamed:@"second"];
        _isFollowingViewController = NO;
        _manager = [WeiBoMessageManager getInstance];
        _userAvatarDic = [[NSMutableDictionary alloc] initWithCapacity:0];
    }
    return self;
}

-(NSMutableDictionary*)userAvatarDic
{
    if (_userAvatarDic == nil) 
    {
        _userAvatarDic = [[NSMutableDictionary alloc] initWithCapacity:0];
    }
    return _userAvatarDic;
}

-(UINib*)followerCellNib
{
    if (_followerCellNib == nil) 
    {
        self.followerCellNib = [LPFriendCell nib];
    }
    return _followerCellNib;
}

- (id)cellForTableView:(UITableView *)tableView fromNib:(UINib *)nib {
    NSString *cellID = NSStringFromClass([LPFriendCell class]);
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (cell == nil) {
        NSLog(@"cell new");
        NSArray *nibObjects = [nib instantiateWithOwner:nil options:nil];
        cell = [nibObjects objectAtIndex:0];
    }
    else {
        [(LPBaseCell *)cell reset];
    }
    
    return cell;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSString *userID = [[NSUserDefaults standardUserDefaults] objectForKey:USER_STORE_USER_ID];
    
    if (_isFollowingViewController) {
        [_manager getFollowingUserList:[userID longLongValue] count:50 cursor:0];
    }
    else {
        [_manager getFollowedUserList:[userID longLongValue] count:50 cursor:0];
    }
    
    NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
    if (_isFollowingViewController) {
        [notifCenter addObserver:self selector:@selector(gotFollowingUserList:) name:MMSinaGotFollowingUserList object:nil];
    }
    else {
        [notifCenter addObserver:self selector:@selector(gotFollowedUserList:) name:MMSinaGotFollowedUserList object:nil];
    }
    [notifCenter addObserver:self selector:@selector(gotAvatar:) name:HHNetDataCacheNotification object:nil];
    [notifCenter addObserver:self selector:@selector(gotFollowResult:) name:MMSinaFollowedByUserIDWithResult object:nil];
    [notifCenter addObserver:self selector:@selector(gotUnfollowResult:) name:MMSinaUnfollowedByUserIDWithResult object:nil];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

-(void)viewWillDisappear:(BOOL)animated
{
   
    [super viewWillDisappear:animated];
}

- (void)viewDidUnload
{
    NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
    if (_isFollowingViewController) {
        [notifCenter removeObserver:MMSinaGotFollowingUserList];
    }
    else {
        [notifCenter removeObserver:MMSinaGotFollowedUserList];
    }
    [notifCenter removeObserver:self name:HHNetDataCacheNotification object:nil];
    [notifCenter removeObserver:self name:MMSinaFollowedByUserIDWithResult object:nil];
    [notifCenter removeObserver:self name:MMSinaUnfollowedByUserIDWithResult object:nil];
    
    [super viewDidUnload];
}

-(void)gotFollowingUserList:(NSNotification*)sender
{
    self.userArr = sender.object;
    [self.tableView reloadData];
    [self getAvatars];
}

-(void)gotFollowedUserList:(NSNotification*)sender
{
    self.userArr = sender.object;
    [self.tableView reloadData];
    [self getAvatars];
}

-(void)gotFollowResult:(NSNotification*)sender
{
    NSLog(@"sender.objet = %@",sender.object);
    NSDictionary *dic = sender.object;
    NSString *uid = [dic objectForKey:@"uid"];
    
    if (uid == nil) {
        return;
    }
    
    for (int i = 0;i<[_usersArr count];i++) {
        User *user = [_usersArr objectAtIndex:i];
        
        if (user.userId == [uid longLongValue]) 
        {
            user.following = YES;
            
            //reload table
            NSIndexPath *indexPath  = [NSIndexPath indexPathForRow:i inSection:0];
            NSArray     *arr        = [NSArray arrayWithObject:indexPath];
            [self.tableView reloadRowsAtIndexPaths:arr withRowAnimation:NO];
        }
    }
}

-(void)gotUnfollowResult:(NSNotification*)sender
{
    NSLog(@"sender.objet = %@",sender.object);
    NSDictionary *dic = sender.object;
    NSString *uid = [dic objectForKey:@"uid"];
    
    if (uid == nil) {
        return;
    }
    
    for (int i = 0;i<[_usersArr count];i++) {
        User *user = [_usersArr objectAtIndex:i];
        
        if (user.userId == [uid longLongValue]) 
        {
            user.following = NO;
            
            //reload table
            NSIndexPath *indexPath  = [NSIndexPath indexPathForRow:i inSection:0];
            NSArray     *arr        = [NSArray arrayWithObject:indexPath];
            [self.tableView reloadRowsAtIndexPaths:arr withRowAnimation:NO];
        }
    }
}

-(void)gotAvatar:(NSNotification*)sender
{
    NSDictionary * dic = sender.object;
    NSString * url          = [dic objectForKey:HHNetDataCacheURLKey];
    NSNumber *indexNumber   = [dic objectForKey:HHNetDataCacheIndex];
    NSInteger index         = [indexNumber intValue];
    NSData *data            = [dic objectForKey:HHNetDataCacheData];
    
    if (indexNumber == nil || index == -1) {
        NSLog(@"indexNumber = nil");
        return;
    }
    
    if (index >= [_usersArr count]) {
        NSLog(@"follow cell error ,index = %d,count = %d",index,[_usersArr count]);
        return;
    }
    
    User *user = [_usersArr objectAtIndex:index];
    
    //得到的是头像图片
    if ([url isEqualToString:user.profileImageUrl]) 
    {
        UIImage * image     = [UIImage imageWithData:data];
        user.avatarImage    = image;
        
        [_userAvatarDic setObject:image forKey:indexNumber];
    }
    
    //reload table
    NSIndexPath *indexPath  = [NSIndexPath indexPathForRow:index inSection:0];
    NSArray     *arr        = [NSArray arrayWithObject:indexPath];
    [self.tableView reloadRowsAtIndexPaths:arr withRowAnimation:NO];
}

-(void)getAvatars
{
    for(int i=0;i<[_usersArr count];i++)
    {
        User *user=[_usersArr objectAtIndex:i];
        
        //下载头像图片
        [[HHNetDataCacheManager getInstance] getDataWithURL:user.profileImageUrl withIndex:i];
    }
}

#pragma mark - Table view data source

//- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
//{
//#warning Potentially incomplete method implementation.
//    // Return the number of sections.
//    return 0;
//}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_usersArr count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = indexPath.row;
    LPFriendCell *cell = [self cellForTableView:tableView fromNib:self.followerCellNib];
    cell.lpCellIndexPath = indexPath;
    cell.delegate = self;
    
    if (row >= [_usersArr count]) {
        return cell;
    }
    
    User *user = [_usersArr objectAtIndex:row];
    cell.nameLabel.text = user.screenName;
    
    if (user.following == NO) {
        [cell.invitationBtn setTitle:@"关注" forState:UIControlStateNormal];
    }
    else {
        [cell.invitationBtn setTitle:@"取消关注" forState:UIControlStateNormal];
    }
    
    if ([_userAvatarDic count] <= row) {
        return cell;
    }
    NSNumber *indexNum = [NSNumber numberWithInt:indexPath.row];
    cell.headerView.image = [_userAvatarDic objectForKey:indexNum];
    
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 64;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = indexPath.row;
    User *user = [_usersArr objectAtIndex:row];
    
    ProfileVC *profile = [[ProfileVC alloc]initWithNibName:@"ProfileVC" bundle:nil];
    profile.userID = [NSString stringWithFormat:@"%lld",user.userId];
    profile.user = user;
    NSNumber *indexNum = [NSNumber numberWithInt:indexPath.row];
    profile.avatarImage = [_userAvatarDic objectForKey:indexNum];
    [self.navigationController pushViewController:profile animated:YES];
    [profile release];
}

-(void)lpCellDidClicked:(LPFriendCell*)cell
{
    NSInteger index = cell.lpCellIndexPath.row;
    
    if (index >= [_usersArr count]) {
        return;
    }
    
    User *user = [_usersArr objectAtIndex:index];
    
    if (user.following) {
        [_manager unfollowByUserID:user.userId];
    }
    else {
        [_manager followByUserID:user.userId];
    }
}

@end
