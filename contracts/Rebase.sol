pragma experimental ABIEncoderV2;
//pragma solidity >= 0.4.22 < 0.6.0;
pragma solidity >= 0.6.2 < 0.7.0;
//pragma solidity >=0.6.0;
import "./StandardToken.sol";
import "./Authority.sol";
import "./Controlled.sol";
//12hours = 43200 S
//市场平衡
contract Rebase is StandardToken,
Controlled,
Authority {
    //向所有账户增发的，比例的基准总数量 初始值30万.单位为最小单位8位小数
    uint256 rebaseBaseAmount = 30000000000000;
    //向所有账户增发的比例 10，表示增发10%
    uint256 rebaseRate = 10;
    //初始值为12小时间隔 ，= 43200 s
    uint256 rebaseLessTime = 43200;
    //初始值区块 ，= 2019-01-01 12:00:00, 无穷大=锁定 ，小=开启
    uint256 rebaseFistBlocktime = 1546315200;
    //控制合约 要求rebase12小时之后才能进行
    modifier rebaseTimeAllowed() {
        require((block.timestamp > rebaseFistBlocktime.add(rebaseLessTime)), "It's not time for Reabase yet!");
        _;
    }
    //初始化代币参数
    constructor() public {}
    // 获得向所有账户增发的，比例的基准总数量 初始值300000.单位为最小单位
    //获得向所有账户增发的比例 10，表示增发10% //获得初始值为12小时间隔 ，= 43200 s
    //获得初始值区块 ，= 2019-01-01 12:00:00, 无穷大=锁定 ，小=开启
    function getOtherRebaseInfo() public view returns(uint256 _rebaseBaseAmount, uint256 _rebaseRate, uint256 _rebaseLessTime, uint256 _rebaseFistBlocktime) {
        return (rebaseBaseAmount, rebaseRate, rebaseLessTime, rebaseFistBlocktime);
    }
    //设置 向所有账户增发的，比例的基准总数量 ,初始值300000.单位为最小单位 
    //设置 向所有账户增发的比例 10，表示增发10%
    //初始值区块 无穷大=锁定 ，小=开启
    //初始值为12小时间隔
    function setRebaseArg(uint256 _rebaseBaseAmount, uint256 _rebaseRate, uint256 _rebaseFistBlocktime, uint256 _rebaseLessTime) public onlyGovenors1 returns(bool success) {
        rebaseBaseAmount = _rebaseBaseAmount;
        rebaseRate = _rebaseRate;
        rebaseFistBlocktime = _rebaseFistBlocktime;
        rebaseLessTime = _rebaseLessTime;
        return true;
    }
    //向所有持币地址，按比例增发代币
    function toAllAddressMintTokenAsRate() public onlyGovenors1 rebaseTimeAllowed returns(bool success) {
        //增发总数*100 最小单位
        uint256 totalrebaseRate = rebaseRate.mul(rebaseBaseAmount);
        //  uint256 totalrebaseRate = rebaseRate.mul(rebaseBaseAmount.mul(decimals)).div(totalSupply).div(100);
        // totalSupply=totalSupply.add(rebaseBaseAmount.mul(rebaseRate).div(100));
        uint256 newtotalSupply = totalSupply;
        for (uint i = 0; i < addrListLength; i++) {
            uint256 addvalue = balanceOf[addrList[i]].mul(totalrebaseRate).div(totalSupply).div(100);
            balanceOf[addrList[i]] = balanceOf[addrList[i]].add(addvalue);
            newtotalSupply = newtotalSupply.add(addvalue);
        }
        totalSupply = newtotalSupply;
        rebaseFistBlocktime = block.timestamp;
        return true;
    }
    //向所有持币地址，按比例通缩代币=销毁代币
    function toAllAddressBurnTokenAsRate() public onlyGovenors1 rebaseTimeAllowed returns(bool success) {
        //通缩总数*100 最小单位
        uint256 totalrebaseRate = rebaseRate.mul(rebaseBaseAmount);
        //  uint256 totalrebaseRate = rebaseRate.mul(rebaseBaseAmount.mul(decimals)).div(totalSupply).div(100);
        // totalSupply=totalSupply.add(rebaseBaseAmount.mul(rebaseRate).div(100));
        uint256 newtotalSupply = totalSupply;
        for (uint i = 0; i < addrListLength; i++) {
            uint256 addvalue = balanceOf[addrList[i]].mul(totalrebaseRate).div(totalSupply).div(100);
            balanceOf[addrList[i]] = balanceOf[addrList[i]].sub(addvalue);
            newtotalSupply = newtotalSupply.sub(addvalue);
        }
        totalSupply = newtotalSupply;
        rebaseFistBlocktime = block.timestamp;
        return true;
    }
}