pragma solidity >= 0.6.2 < 0.7.0;
import "./Owned.sol";
import "./SafeMath.sol";
//代币的控制合约
contract Controlled is Owned {
    //使用SafeMath
    using SafeMath
    for uint256;
    //账户集合
    mapping(address =>uint256) public balanceOf;
    //持币地址 list
    mapping(uint256 =>address) public addrList;
    //addrlist 大小
    uint256 public addrListLength = 1;
    //address 是否是否存在list里 true=in,false=not in 
    mapping(address =>bool) public isInAddrList;
    //创世vip
    constructor() public {
        setExclude(msg.sender, true);
    }
    // 控制代币是否可以交易，true代表可以(exclude里的账户不受此限制，具体实现在下面的transferAllowed里)
    bool public transferEnabled = true;
    // 是否启用账户锁定功能，true代表启用
    bool public lockFlag = true;
    // 锁定的账户集合，address账户，bool是否被锁，true:被锁定，当lockFlag=true时，恭喜，你转不了账了，哈哈
    mapping(address =>bool) public locked;
    // 拥有特权用户，不受transferEnabled和lockFlag的限制，vip啊，bool为true代表vip有效
    mapping(address =>bool) public exclude;
    // 投票锁定功能，true代表锁定
    bool public voteLock = false;
    // 解质押锁定功能，true代表锁定
    mapping(address =>bool) public tokenPledgeLock;

    // 拥有社区管理特权用户，可以等同于owner的部分特权，发起投票，设置参数等等，管理vip，bool为true代表vip有效
    mapping(address =>bool) public communityLeaders;
    //销毁代币成功的事件
    event BurnTokenSuccess(address indexed _from, address indexed _to, uint256 _value);
    //控制合约 核心实现
    modifier isCommunityLeaders() {
        if (! (msg.sender == owner)) {
            require(communityLeaders[msg.sender], "msg.sender is not community leaders now!");
        }
        _;
    }
    //addrList排序
    function setAddrListAcs() public returns(bool _success) {
        for (uint256 i = 0; i < addrListLength - 1; i++) {
            for (uint256 j = 0; j < addrListLength - i - 1; j++) {
                if (balanceOf[addrList[j]] < balanceOf[addrList[j + 1]]) {
                    address tmp;
                    tmp = addrList[j];
                    addrList[j] = addrList[j + 1];
                    addrList[j + 1] = tmp;
                } else continue;
            }
        }
        return true;
    }
    //把持币地址加入到addrList列表
    function addAddressToAddrList(address _addr) internal {
        if (!isInAddrList[_addr]) {++addrListLength;
            addrList[(addrListLength - 1)] = _addr;
            isInAddrList[_addr] = true;
        }
        //   setAddrListAcs();
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