pragma solidity >= 0.6.2 < 0.7.0;
//设置代币控制合约的管理员
contract Owned {
    // modifier(条件)，表示必须是权力所有者才能do something，类似administrator的意思
    modifier onlyOwner() {
        require(msg.sender == owner);
        _; //do something
    }
    //权力所有者
    address public owner;
    //合约创建的时候执行，执行合约的人是第一个owner
    constructor() public {
        owner = msg.sender;
    }
    //新的owner,初始为空地址，类似null
    address newOwner = address(0);

    //更换owner成功的事件
    event OwnerUpdate(address _prevOwner, address _newOwner);
    //现任owner把所有权交给新的owner(需要新的owner调用acceptOwnership方法才会生效)
    function changeOwner(address _newOwner) public onlyOwner {
        require(_newOwner != owner);
        newOwner = _newOwner;
    }
    //新的owner接受所有权,权力交替正式生效
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnerUpdate(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}