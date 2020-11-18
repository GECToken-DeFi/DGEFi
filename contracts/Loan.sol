pragma experimental ABIEncoderV2;
pragma solidity >= 0.6.2 < 0.7.0;
import "./StandardToken.sol";
import "./Authority.sol";
import "./Controlled.sol";
//借贷
contract Loan is StandardToken,
Controlled,
Authority {
    //借款
    //借款功能，用户抵押任何资产后，我方打DGE给用户
    //借款数据记录，uint单位DGE，最小单位
    struct LoanItem {
        string guaranteeDec; //describle
        uint256 loanAmountDGE;
        uint256 loanTime; //unit s, 3个月等
        uint256 buytime; //购买的时间点
    }
    LoanItem[] loans;
    mapping(address =>LoanItem[]) loanUserDGEAmount;
    //此地址此币种用户借款条目数量
    mapping(address =>uint256) public LoanItemTimes;
    //借款抵押品质押率,单位为 10000倍，即 8000= 8000/10000=80%,大写
    mapping(string =>uint256) laonGuaranteeRate;
    //贷款产品，统一利率手续费 //uint256 loanTime; //unit s, 3个月等//uint256 loanPayRate; //用户付出的贷款利率
    mapping(uint256 =>uint256) productRate;
    //初始化代币参数
    constructor() public {}
    ///
    //设置借款抵押品质押率
    function setLaonGuaranteeRate(string memory _guaranteeName, uint256 _rate) public onlyOwner returns(bool success) {
        laonGuaranteeRate[_guaranteeName] = _rate;
        return true;
    }
    //以及贷款产品，统一利率手续费 
    function setLaonProductRate(uint256 _loanTime, uint256 _loanPayRate) public onlyOwner returns(bool success) {
        productRate[_loanTime] = _loanPayRate;
        return true;
    }
    // 获得借款抵押率
    function getLaonGuaranteeRate(string memory _guaranteeName) public view isCommunityLeaders returns(uint256) {
        return laonGuaranteeRate[_guaranteeName];
    }
    // 贷款产品，统一利率手续费
    function getProductRate(uint256 _loanTime) public view isCommunityLeaders returns(uint256) {
        return productRate[_loanTime];
    }
    //写入此次用户贷款的数据
    function writeToLoanItem(address _userAddress, string memory _guaranteeDec, uint256 _getDGEAmount, uint256 _loanTime) public onlyOwner returns(bool success) {
        LoanItem[] storage loa = loanUserDGEAmount[_userAddress];
        uint256 len = loa.length;
        //	loa.length += 1;
        loa.push();
        loa[len].guaranteeDec = _guaranteeDec;
        loa[len].loanAmountDGE = _getDGEAmount;
        loa[len].loanTime = _loanTime;
        loa[len].buytime = block.timestamp;
        LoanItemTimes[_userAddress] = LoanItemTimes[_userAddress].add(1);
        return true;
    }
    //用户还款后（即还DGE后），更新借款数据，锁定 //产品uint
    function payBackUpdateLoanItem(address _userAddress, uint256 _loanProductId) public onlyOwner returns(bool success) {
        require(block.timestamp > loanUserDGEAmount[_userAddress][_loanProductId].loanTime.add(loanUserDGEAmount[_userAddress][_loanProductId].buytime), "The redemption time has not come!");
        LoanItem[] storage loa = loanUserDGEAmount[_userAddress];
        uint256 len = loa.length;
        //现在逻辑暂时不用销毁 param add address burnAddress
        //uint256 burnDGEAmount =  loa[_loanProductId].loanAmountDGE;
        // burnToken(burnAddress,burnDGEAmount);
        loa[_loanProductId] = loa[len.sub(1)];
        //	loa.length -= 1;
        loa.pop();
        LoanItemTimes[_userAddress] = LoanItemTimes[_userAddress].sub(1);
        return true;
    }
    // 显示用户贷款数据
    function showAddressLoanItem(address _userAddress) public view isCommunityLeaders returns(LoanItem[] memory) {
        LoanItem[] storage loa = loanUserDGEAmount[_userAddress];
        return loa;
    }
}