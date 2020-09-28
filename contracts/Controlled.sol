pragma solidity >= 0.4.22 < 0.6.0;
import "./Owned.sol";

//代币的控制合约
contract Controlled is Owned {

	//创世vip
	constructor() public {
		setExclude(msg.sender, true);
	}

	// 控制代币是否可以交易，true代表可以(exclude里的账户不受此限制，具体实现在下面的transferAllowed里)
	bool public transferEnabled = true;

	// 是否启用账户锁定功能，true代表启用
	bool lockFlag = true;
	// 锁定的账户集合，address账户，bool是否被锁，true:被锁定，当lockFlag=true时，恭喜，你转不了账了，哈哈
	mapping(address =>bool) locked;
	// 拥有特权用户，不受transferEnabled和lockFlag的限制，vip啊，bool为true代表vip有效
	mapping(address =>bool) exclude;
	// 投票锁定功能，true代表锁定
	bool voteLock = true;
	// 解质押锁定功能，true代表锁定
	mapping(address =>bool) tokenPledgeLock;

	// 拥有社区管理特权用户，可以等同于owner的部分特权，发起投票，设置参数等等，管理vip，bool为true代表vip有效
	mapping(address =>bool) communityLeaders;
	//控制合约 核心实现
	modifier isCommunityLeaders() {
		if (! (msg.sender == owner)) {
			require(communityLeaders[msg.sender], "msg.sender is not community leaders now!");
		}
		_;
	}
	//设置社区管理vip用户 ，true代表是vip
	function setCommunityLeaders(address _addr, bool _enable) public onlyOwner returns(bool success) {
		communityLeaders[_addr] = _enable;
		return true;
	}
	// 查看是否管理vip地址 ,true代表是，false代表不是
	function showACommunityLeaders(address _userAddress) public view onlyOwner returns(bool success) {
		return communityLeaders[_userAddress];
	}
	//设置投票锁定值
	function addVoteLock(bool _enable) public onlyOwner returns(bool success) {
		voteLock = _enable;
		return true;
	}
	//设置投票锁定值
	function addTokenPledgeBlock(address _addr, bool _enable) public onlyOwner returns(bool success) {
		tokenPledgeLock[_addr] = _enable;
		return true;
	}
	//增发权利增加 事件
	//	event MinterAdded(address indexed account)
	//设置transferEnabled值
	function enableTransfer(bool _enable) public onlyOwner returns(bool success) {
		transferEnabled = _enable;
		return true;
	}
	//设置lockFlag值
	function disableLock(bool _enable) public onlyOwner returns(bool success) {
		lockFlag = _enable;
		return true;
	}
	// 把_addr加到锁定账户里，拉黑名单。。。
	function addLock(address _addr) public onlyOwner returns(bool success) {
		require(_addr != msg.sender);
		locked[_addr] = true;
		return true;
	}
	//设置vip用户
	function setExclude(address _addr, bool _enable) public onlyOwner returns(bool success) {
		exclude[_addr] = _enable;
		return true;
	}
	//解锁_addr用户
	function removeLock(address _addr) public onlyOwner returns(bool success) {
		locked[_addr] = false;
		return true;
	}
	//控制合约 核心实现
	modifier transferAllowed(address _addr) {
		if (!exclude[_addr]) {
			require(transferEnabled, "transfer is not enabeled now!");
			if (lockFlag) {
				require(!locked[_addr], "you are locked!");
			}
		}
		_;
	}
	//控制合约 投票权限
	modifier voteLockAllowed() {
		require(!voteLock, "Vote is Locked!");
		_;
	}
}