pragma solidity >= 0.6.2 < 0.7.0;
import "./Owned.sol";

//dge方法授权
contract Authority is Owned {
    /**
    最高owner : 销毁 , 总锁
    治理权限1级(次高级) : 开关锁,增发销毁,修改权限
    治理权限2级(中级)(修改) : 发起投票,修改汇率
    治理权限3级 : 其他次重要权限
    治理权限4级(最低)(只读) : 查看信息
    */
    //1级别最高;1包含2,3;2包含3;
    mapping(address =>bool) public govenors1;
    mapping(address =>bool) public govenors2;
    mapping(address =>bool) public govenors3;
    mapping(address =>bool) public govenors4;
    //开关锁
    bool public ownersLock_open = true;
    bool public govenors1_open = true;
    bool public govenors2_open = true;
    bool public govenors3_open = true;
    bool public govenors4_open = true;

    //合约创建的时候执行，执行合约的人是第一个owner
    constructor() public {
        setGovenors1(msg.sender, true);
    }
    modifier onlyGovenors1() {
        require((govenors1[msg.sender]) && (govenors1_open) && (ownersLock_open), 'msg.sender no righte of govenors1');
        _; //do something
    }
    modifier onlyGovenors2() {
        require((govenors2[msg.sender]) && (govenors2_open) && (ownersLock_open), 'msg.sender no righte of govenors2');
        _; //do something
    }
    modifier onlyGovenors3() {
        require((govenors3[msg.sender]) && (govenors3_open) && (ownersLock_open), 'msg.sender no righte of govenors3');
        _; //do something
    }
    modifier onlyGovenors4() {
        require((govenors4[msg.sender]) && (govenors4_open) && (ownersLock_open), 'msg.sender no righte of govenors4');
        _; //do something
    }

    //set lock flage
    function setOwnersLock_open(bool _enable) public onlyOwner returns(bool _result) {
        ownersLock_open = _enable;
        return ownersLock_open;
    }
    function setGovenors1_open(bool _enable) public onlyOwner returns(bool _result) {
        govenors1_open = _enable;
        return govenors1_open;
    }
    function setGovenors2_open(bool _enable) public onlyGovenors1 returns(bool _result) {
        govenors2_open = _enable;
        return govenors2_open;
    }
    function setGovenors3_open(bool _enable) public onlyGovenors2 returns(bool _result) {
        govenors3_open = _enable;
        return govenors3_open;
    }
    function setGovenors4_open(bool _enable) public onlyGovenors3 returns(bool _result) {
        govenors4_open = _enable;
        return govenors4_open;
    }

    /////// set
    function setGovenors1(address _user, bool _enable) public onlyOwner returns(bool _result) {
        govenors1[_user] = _enable;
        govenors2[_user] = _enable;
        govenors3[_user] = _enable;
        govenors4[_user] = _enable;
        return govenors1[_user];
    }
    function setGovenors2(address _user, bool _enable) public onlyGovenors1 returns(bool _result) {
        govenors2[_user] = _enable;
        govenors3[_user] = _enable;
        govenors4[_user] = _enable;
        return govenors2[_user];
    }
    function setGovenors3(address _user, bool _enable) public onlyGovenors2 returns(bool _result) {
        govenors3[_user] = _enable;
        govenors4[_user] = _enable;
        return govenors3[_user];
    }
    function setGovenors4(address _user, bool _enable) public onlyGovenors3 returns(bool _result) {
        govenors4[_user] = _enable;
        return govenors4[_user];
    }
}