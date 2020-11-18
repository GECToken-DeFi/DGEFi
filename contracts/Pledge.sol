pragma experimental ABIEncoderV2;
pragma solidity >= 0.6.2 < 0.7.0;
import "./StandardToken.sol";
import "./Authority.sol";
import "./Controlled.sol";
//质押
contract Pledge is StandardToken,
Controlled,
Authority {
    //质押
    //用户质押其他币种后，增发DGE到用户对应地址，但为锁定状态，锁定币总量更新
    //解质押反向操作，解质押开始后，解质押锁定状态跟新为true锁定 pledge rate,tokenPledgeLock
    mapping(address =>mapping(string =>uint256)) tokenpledge;
    //DGE数量
    mapping(address =>mapping(string =>uint256)) tokenTDGEpledgeDGEAmount;
    //质押率,单位为 10000倍，即 8000= 8000/10000=80%,大写
    mapping(string =>uint256) tokenPledgeRate;
    //质押币种，所有地址总量
    mapping(string =>uint256) tokenPledgeTotalAmount;
    //质押后，新生成DGE，打入用户地址，但为锁定状态
    mapping(address =>uint256) tokenPledgeGetDGELockedAmount;
    //初始化代币参数
    constructor() public {}
    ///
    //控制合约 要求用户转账时，转账数量<总量-锁定量
    modifier transBalanceLessAvailable(address _from, uint256 _transAmount) {
        require((_transAmount) <= (balanceOf[_from].sub(tokenPledgeGetDGELockedAmount[_from])), "Transferability amount is insufficient!");
        _;
    }
    // 获得质押率
    function getTokenPledgeRate(string memory _tokenName) public view isCommunityLeaders returns(uint256) {
        return tokenPledgeRate[_tokenName];
    }
    ////	// 获得质押币种，所有地址总量
    function getTokenPledgeTotalAmount(string memory _tokenName) public view isCommunityLeaders returns(uint256) {
        return tokenPledgeTotalAmount[_tokenName];
    }
    // 获得质押后，新生成DGE，打入用户地址，但为锁定状态
    function getTokenPledgeGetDGELockedAmount(address _from) public view isCommunityLeaders returns(uint256) {
        return tokenPledgeGetDGELockedAmount[_from];
    }
    // 获得质押的DGE数量  tokenTDGEpledgeDGEAmount
    function getTokenTDGEpledgeDGEAmount(address _from, string memory _tokenName) public view isCommunityLeaders returns(uint256) {
        return tokenTDGEpledgeDGEAmount[_from][_tokenName];
    }
    // 获得质押的token  tokenpledge
    function getTokenpledge(address _from, string memory _tokenName) public view isCommunityLeaders returns(uint256) {
        return tokenpledge[_from][_tokenName];
    }
    //设置质押率
    function setTokenPledgeRate(string memory _tokenname, uint256 _tokenPledgeRate) public onlyOwner returns(bool success) {
        tokenPledgeRate[_tokenname] = _tokenPledgeRate;
        return true;
    }
    //_sameDGEAmount为同人民币价值的DGE数量
    function doPledge(address _userAddress, string memory tokenName, uint256 _tokenAmount, uint256 _sameDGEAmount) public onlyOwner returns(bool success) {
        tokenpledge[_userAddress][tokenName] = tokenpledge[_userAddress][tokenName].add(_tokenAmount);
        tokenPledgeTotalAmount[tokenName] = tokenPledgeTotalAmount[tokenName].add(_tokenAmount);
        doPledgeMintDGE(_userAddress, tokenName, _sameDGEAmount);
        return true;
    }
    //质押定向生成锁定的DGE
    function doPledgeMintDGE(address _userAddress, string memory tokenName, uint256 _sameDGEAmount) internal onlyOwner returns(bool success) {
        uint256 tokenaDGEddAmount = _sameDGEAmount.mul(tokenPledgeRate[tokenName]).div(10000);
        balanceOf[_userAddress] = balanceOf[_userAddress].add(tokenaDGEddAmount);
        //质押生成DGE锁定账户余额
        tokenPledgeGetDGELockedAmount[_userAddress] = tokenPledgeGetDGELockedAmount[_userAddress].add(tokenaDGEddAmount);
        //此种质押币总共兑换了多少DGE
        tokenTDGEpledgeDGEAmount[_userAddress][tokenName] = tokenTDGEpledgeDGEAmount[_userAddress][tokenName].add(tokenaDGEddAmount);
        totalSupply = totalSupply.add(tokenaDGEddAmount);
        addAddressToAddrList(_userAddress);
        emit Transfer(address(0), owner, tokenaDGEddAmount);
        emit Transfer(owner, _userAddress, tokenaDGEddAmount);
        return true;
    }
    //解质押 按用户当时质押币种，现在解质押数量占比多少 _tokenAmount为质押币种数量
    function withdrawPledge(address _userAddress, string memory tokenName, uint256 _tokenAmount) public onlyOwner returns(bool success) {
        require(!tokenPledgeLock[_userAddress]);
        require((_tokenAmount) < (tokenpledge[_userAddress][tokenName]), "Cancle pledge amount is insufficient!");
        tokenPledgeTotalAmount[tokenName] = tokenPledgeTotalAmount[tokenName].sub(_tokenAmount);
        withdrawPledgeBurnDGE(_userAddress, tokenName, _tokenAmount);
        return true;
    }
    //解除质押定向销毁锁定的DGE
    function withdrawPledgeBurnDGE(address _userAddress, string memory tokenName, uint256 _tokenAmount) internal onlyOwner returns(bool success) {
        //按此种币种，解质押的数量占此币种的比例，和此币种之前质押生成的DGE的量的比例，来销毁DGE。
        uint256 tokenaDGEBurnAmount = tokenTDGEpledgeDGEAmount[_userAddress][tokenName].mul(_tokenAmount).div(tokenpledge[_userAddress][tokenName]);
        //此地址此币种，质押总量更新
        tokenpledge[_userAddress][tokenName] = tokenpledge[_userAddress][tokenName].sub(_tokenAmount);
        balanceOf[_userAddress] = balanceOf[_userAddress].sub(tokenaDGEBurnAmount);
        //解除质押更新DGE锁定账户余额
        tokenPledgeGetDGELockedAmount[_userAddress] = tokenPledgeGetDGELockedAmount[_userAddress].sub(tokenaDGEBurnAmount);
        //本次解质押销毁了多少DGE
        tokenTDGEpledgeDGEAmount[_userAddress][tokenName] = tokenTDGEpledgeDGEAmount[_userAddress][tokenName].sub(tokenaDGEBurnAmount);
        totalSupply = totalSupply.sub(tokenaDGEBurnAmount);
        addAddressToAddrList(_userAddress);
        emit BurnTokenSuccess(address(0), _userAddress, tokenaDGEBurnAmount);
        return true;
    }
}