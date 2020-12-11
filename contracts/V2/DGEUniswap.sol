pragma solidity >= 0.6.2 < 0.7.0;
import "./SafeMath.sol";
import "./IDGE.sol";
import "./ICToken.sol";
import "./IUniswapV2Router02.sol";
import "./IERC20.sol";
//import "./Address.sol";
import "./Authority.sol";
//DGE通过uniswap交易获利ctoken的合约
contract DGEUniswap is Authority {
    //初始化代币参数
    constructor() public payable {}
    //使用SafeMath
    using SafeMath
    for uint256;
    ///
    //uniswaop <-> ctoken
    // rinkeby:
    address public zhuAddr1 = 0xf46639dd2F44F1732e402af5ad290f65B1e91b4c;
    address public zhuAddr2 = 0x1ECd69D1a623811593D90a20a81CEB1e388eE562;
    address public zhuAddr3 = 0x1054c99a7f38eeF1672E82D11C6ED33AEECaaC42;
    address public zhuAddr4 = 0x4777dfc99F75F598F84f49F2B6D00e55C9bF6D75;
    address public zhuAddr5 = 0x57125786a8bb5d36cF394C89665e356276219156;
    address public zhuAddr6 = 0x1ECd69D1a623811593D90a20a81CEB1e388eE562;
    address public zhuAddr7 = 0x1ECd69D1a623811593D90a20a81CEB1e388eE562;

    address public ctokenAddr = 0xC3D208923737573B0E1E8E173e89A20BC7DD21b1;

    address public weth = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

    address public dgeContractAddr1 = 0x2fa6f6Cb787a445C11669be58A215B9495e23492;
    address public dgeContractAddr2 = 0x7836940Da5ba9c992DeB2d9A1f3b09fc76c4750E;

    address public dgeContractAddr = 0x2fa6f6Cb787a445C11669be58A215B9495e23492;

    address public exPairsCtokenAddr = 0xC3D208923737573B0E1E8E173e89A20BC7DD21b1;
    address public uniswapV2Router02Addr = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 public miniDealineTime = 120; //600; //10分钟
    uint256 public mydeadline = 2000000000;

    //地址 ETH,DAI等有多少参与了平台uniswap ,大写, uint256为eth等的数量
    mapping(address =>mapping(string =>uint256)) public dgeWebExAmountT1;
    //地址 ETH,DAI等参与了平台uniswap ,得到多少ctoken,大写, uint256为ctoken的数量
    mapping(address =>mapping(string =>uint256)) public dgeWebExAmountT2;
    //币种列表,币合约地址 大写
    mapping(address =>string) public coinName;

    //用户参与eth等的数量
    function getdgeWebExAmountT1(address _addr, string memory _ethdaiusdt) public view returns(uint256 _ethdaiusdtAmount) {

        return dgeWebExAmountT1[_addr][_ethdaiusdt];
    }
    //用户参与获得的ctoken数量
    function getdgeWebExAmountT2(address _addr, string memory _ethdaiusdt) public view returns(uint256 _ethdaiusdtAmount) {

        return dgeWebExAmountT2[_addr][_ethdaiusdt];
    }

    //user 赎回之前平台购买的eth,DAI等,ctoken=>dge(all in dege)
    function withdrowUserETHorDai(address _tokenIndex, uint256 _ctokenAmount) public returns(uint256[] memory _withdrawAmount) {
        require(dgeWebExAmountT1[msg.sender][coinName[_tokenIndex]] > 0);
        require(dgeWebExAmountT2[msg.sender][coinName[_tokenIndex]] > 0);
        require(dgeWebExAmountT2[msg.sender][coinName[_tokenIndex]] >= _ctokenAmount);
        require(_ctokenAmount > 0);

        uint256 allEthDaiUsdtAmount = dgeWebExAmountT1[msg.sender][coinName[_tokenIndex]];
        uint256 allCtokenAmount = dgeWebExAmountT2[msg.sender][coinName[_tokenIndex]];
        uint256 leftCtokenAmount = allCtokenAmount.sub(_ctokenAmount);
        // uint256 letfEthDaiUsdtAmount = (uint256(10000).mul(leftCtokenAmount)).div(allCtokenAmount).mul(allEthDaiUsdtAmount).div(1000);
        uint256 letfEthDaiUsdtAmount = (uint256(10000000).mul(leftCtokenAmount)).mul(allEthDaiUsdtAmount).div(allCtokenAmount).div(10000000);

        dgeWebExAmountT1[msg.sender][coinName[_tokenIndex]] = letfEthDaiUsdtAmount;
        dgeWebExAmountT2[msg.sender][coinName[_tokenIndex]] = leftCtokenAmount;

        IDGE idge = IDGE(dgeContractAddr);
        if (utilCompareInternal(coinName[_tokenIndex], "ETH")) {
            address[] memory path;
            path = new address[](2);
            path[0] = dgeContractAddr1;
            path[1] = _tokenIndex;
            uint[] memory amounts = myswapExactTokensForETHforWhithdraw(_ctokenAmount, path[0], path[1]);
            //打eth
            //   require(msg.sender != address(0));
            //  msg.sender.transfer(amounts[1]);
            //打本金,换算成dge打
            idge.transfer(msg.sender, amounts[0]);
            //打利息dge
            payEarningDGE(amounts[0]);

            return amounts;
        } else {
            address[] memory path;
            path = new address[](2);
            path[0] = dgeContractAddr1;
            path[1] = _tokenIndex;
            uint[] memory amounts = myswapExactTokensForTokensforWhithdraw(path[0], path[1], _ctokenAmount);
            //打Dai等
            require(msg.sender != address(0));
            IERC20 ierc20 = IERC20(_tokenIndex);
            ierc20.transfer(msg.sender, amounts[0]);
            //  msg.sender.transfer(amounts[1]);
            //打利息dge
            payEarningDGE(amounts[0]);
            return amounts;
        }
    }

    //打币dge,按利息打
    function payEarningDGE(uint256 _dgeAmount) internal returns(bool _success) {
        //打利息dge
        IDGE idge = IDGE(dgeContractAddr);
        //uint256 _value = payEarningDgeAllRateToSender(_dgeAmount).mul(_ethDaiAmount).mul(5).mul(_ethDaiAmount).div(_dgeAmount).div(100000000);
        uint256 _value = payEarningDgeAllRateToSender(_dgeAmount).mul(_dgeAmount).mul(5).div(100000000).div(10000000000);
        return idge.transfer(msg.sender, _value);
    }
    // 1 token to token
    function myswapExactTokensForTokens(address _addr1, address _addr2, uint amountIn) public returns(uint[] memory _amounts) {
        uint amountOutMin = 1;
        // address _addr1,address _addr2,
        address[] memory path;
        path = new address[](2);
        path[0] = _addr1;
        path[1] = _addr2;

        //IERC20 ierc20 = IERC20(_tokenIndex);
        //  IDGE idge1 = IDGE(dgeContractAddr1);
        //  idge1.approve(uniswapV2Router02Addr, amountIn);
        //  IDGE idge2 = IDGE(dgeContractAddr2);
        IERC20 ierc201 = IERC20(_addr1);
        ierc201.approve(uniswapV2Router02Addr, amountIn);

        //    IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        //   uint256 amountADesired = uniswpair.getAmountsOut(amountIn, path)[1];
        //   ierc202.approve(uniswapV2Router02Addr, amountADesired);
        uint[] memory amounts = _swapExactTokensForTokens(amountIn, amountOutMin, path, zhuAddr1, mydeadline);
        mintBurnCtoken(path, amounts);

        address addrthis = address(this);
        address payable payaddrthis = address(uint160(addrthis));
        require(ierc201.allowance(msg.sender, payaddrthis) >= amountIn, "ierc201.allowance(msg.sender, payaddrthis) is insufficient");
        ierc201.transferFrom(msg.sender, payaddrthis, amountIn);

        IERC20 ierc202 = IERC20(_addr2);
        if (path[1] != dgeContractAddr) {
            ierc202.transfer(msg.sender, amounts[1]);
        }

        return amounts;
    }
    // 2 token to token
    function myswapTokensForExactTokens(address _addr1, address _addr2, uint amountOut) public returns(uint[] memory _amounts) {
        uint amountInMax = 1000000000000000000000000000;
        address[] memory path;
        path = new address[](2);
        path[0] = _addr1;
        path[1] = _addr2;

        //IERC20 ierc20 = IERC20(_tokenIndex);
        // IDGE idge1 = IDGE(path[0]);
        IERC20 ierc201 = IERC20(path[0]);

        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        uint256 amountADesired = uniswpair.getAmountsIn(amountOut, path)[0];
        // uint256 amountADesired = uniswpair.getAmountsOut(amountIn, path)[1];
        //    uint256 amountADesired = getDge1ExDge2Amount(amountOut)[0];
        ierc201.approve(uniswapV2Router02Addr, amountADesired);
        //   IERC20 ierc202 = IERC20(path[1]);
        //   ierc202.approve(uniswapV2Router02Addr, amountOut);
        uint[] memory amounts = _swapTokensForExactTokens(amountOut, amountInMax, path, zhuAddr1, mydeadline);
        mintBurnCtoken(path, amounts);

        address addrthis = address(this);
        address payable payaddrthis = address(uint160(addrthis));
        require(ierc201.allowance(msg.sender, payaddrthis) >= amountADesired, "ierc201.allowance(msg.sender, payaddrthis) is insufficient");
        ierc201.transferFrom(msg.sender, payaddrthis, amountADesired);

        IERC20 ierc202 = IERC20(_addr2);
        if (path[1] != dgeContractAddr) {
            ierc202.transfer(msg.sender, amounts[1]);
        }

        return amounts;
    }
    //3 eth to token
    //3 putin exact eth , getout tokens
    function myswapExactETHForTokens(address _addr1, address _addr2) public payable returns(uint[] memory _amounts) {
        uint amountOutMin = 1;
        address[] memory path;
        path = new address[](2);
        path[0] = _addr1;
        path[1] = _addr2;

        //IERC20 ierc20 = IERC20(_tokenIndex);
        //  IERC20 ierc201 = IERC20(path[1]);
        //   IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        //  uint256 amountDge1Desired = uniswpair.getAmountsOut(msg.value, path)[1];
        // ierc201.approve(uniswapV2Router02Addr, amountDge1Desired);
        uint[] memory amounts = _swapExactETHForTokens(amountOutMin, path, zhuAddr1, mydeadline);
        mintBurnCtoken(path, amounts);

        IERC20 ierc202 = IERC20(_addr2);
        if (path[1] != dgeContractAddr) {
            ierc202.transfer(msg.sender, amounts[1]);
        }

        return amounts;
    }
    //4 swapTokensForExactETH
    //4 swapTokensForExactETH  //path = dge1:eth,so user send token ,get eth amount out  , dge1 => eth ok
    function myswapTokensForExactETH(address _addr1, address _addr2, uint amountOut) public payable returns(uint[] memory _amounts) {
        uint amountInMax = 10000000000000000000000000000;
        // address _addr1,address _addr2,
        address[] memory path;
        path = new address[](2);
        path[0] = _addr1;
        path[1] = _addr2;

        //IERC20 ierc20 = IERC20(_tokenIndex);
        IERC20 ierc201 = IERC20(path[0]);

        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        uint256 amountDge1Desired = uniswpair.getAmountsIn(amountOut, path)[0];

        ierc201.approve(uniswapV2Router02Addr, amountDge1Desired);
        uint[] memory amounts = _swapTokensForExactETH(amountOut, amountInMax, path, zhuAddr1, mydeadline);
        mintBurnCtoken(path, amounts);

        address addrthis = address(this);
        address payable payaddrthis = address(uint160(addrthis));
        require(ierc201.allowance(msg.sender, payaddrthis) >= amountDge1Desired, "ierc201.allowance(msg.sender, payaddrthis) is insufficient");
        ierc201.transferFrom(msg.sender, payaddrthis, amountDge1Desired);
        msg.sender.transfer(amountOut);

        return amounts;
    }
    //5  swapExactTokensForETH  //path = dge1:eth,so user send token ,get eth amount out  , dge1 => eth ok
    function myswapExactTokensForETH(uint amountIn, address _addr1, address _addr2) public returns(uint[] memory _amounts) {
        uint amountOutMin = 1;
        // address _addr1,address _addr2,
        address[] memory path;
        path = new address[](2);
        path[0] = _addr1;
        path[1] = _addr2;

        //IERC20 ierc20 = IERC20(_tokenIndex);
        IERC20 ierc201 = IERC20(path[0]);

        ierc201.approve(uniswapV2Router02Addr, amountIn);
        uint[] memory amounts = _swapExactTokensForETH(amountIn, amountOutMin, path, zhuAddr1, mydeadline);
        mintBurnCtoken(path, amounts);

        address addrthis = address(this);
        address payable payaddrthis = address(uint160(addrthis));
        require(ierc201.allowance(msg.sender, payaddrthis) >= amountIn, "ierc201.allowance(msg.sender, payaddrthis) is insufficient");
        ierc201.transferFrom(msg.sender, payaddrthis, amountIn);
        msg.sender.transfer(amounts[1]);

        return amounts;
    }
    //6  swapETHForExactTokens  //path = eth:dge1,so user send value ,get dge1 amount out  , eth=>dge1 ok  no
    function myswapETHForExactTokens(uint amountOut, address _addr1, address _addr2) public payable returns(uint[] memory _amounts) {
        address[] memory path;
        path = new address[](2);
        path[0] = _addr1;
        path[1] = _addr2;
        //  uint[] memory amounts = _swapETHForExactTokens(  amountOut,  path,   zhuAddr1,   mydeadline);
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        uint[] memory amounts = uniswpair.swapETHForExactTokens.value(msg.value)(amountOut, path, zhuAddr1, mydeadline);
        mintBurnCtoken(path, amounts);

        IERC20 ierc202 = IERC20(_addr2);
        if (path[1] != dgeContractAddr) {
            ierc202.transfer(msg.sender, amounts[1]);
        }

        return amounts;
    }

    //dge网站赎回
    //  function myRemoveLiquidityETH(address token, uint _ethAmount, uint _tokenAmount, uint amountTokenMin, uint amountETHMin) public returns(uint256 _amountCt, uint _amountToken, uint _amountETH) { 
    //      (uint amountToken, uint amountETH) = _removeLiquidityETH(token, _ethAmount * _tokenAmount, amountTokenMin, amountETHMin, msg.sender, mydeadline);
    //      uint256 amountCt = amountToken / 2;
    //      _burnToken(msg.sender, amountCt);
    //     dgeWebExAmountT1[msg.sender]['ETH'] -= amountETH;
    //     dgeWebExAmountT2[msg.sender]['ETH'] -= amountCt;
    //     return (amountCt, amountToken, amountETH);
    //  }
    //设置币种列表,大写
    function setCoinName(address _index, string memory _name) public onlyGovenors1 returns(bool _success) {
        coinName[_index] = _name;
        return true;
    }
    function getCoinName(address _index) public view returns(string memory _name) {
        return coinName[_index];
    }
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public view returns(uint amountOut) {
        return _getAmountOut(amountIn, reserveIn, reserveOut);
    }
    //eth:dge1, give ctoken ok ban
    //  function myaddLiquidityETHBackCtoken(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to) public payable returns(uint256 _amountCt, uint _amountToken, uint _amountETH, uint _liquidity) { 
    //      (uint amountToken, uint amountETH, uint liquidity) = myaddLiquidityETH(token, amountTokenDesired, amountTokenMin, amountETHMin, to);
    //       uint256 amountCt = amountToken / 2;
    //      _mintCtoken(msg.sender, amountCt);
    //      dgeWebExAmountT1[msg.sender]['ETH'] = msg.value;
    //      dgeWebExAmountT2[msg.sender]['ETH'] = amountCt;
    //      return (amountCt, amountToken, amountETH, liquidity);
    //  }
    //eth ok ban
    //  function myaddLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to) public payable returns(uint amountToken, uint amountETH, uint liquidity) {
    //     IDGE idge1 = IDGE(dgeContractAddr1);
    //     idge1.approve(uniswapV2Router02Addr, amountTokenDesired);
    //     return _addLiquidityETH(token, amountTokenDesired, amountTokenMin, amountETHMin, to, mydeadline);
    // }
    //dage1:dge2 ,give ctoken ok ban
    //  function myAddLiquidityBackCtokn(uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to) public returns(uint _amountCt, uint _amountA, uint _amountB, uint _liquidity) { (uint amountA, uint amountB, uint liquidity) = myAddLiquidity(amountADesired, amountBDesired, amountAMin, amountBMin, to);
    //     uint256 amountCt = amountB / 2;
    //     _mintCtoken(msg.sender, amountCt);
    //     dgeWebExAmountT1[msg.sender][coinName[dgeContractAddr1]] = amountA;
    //     dgeWebExAmountT2[msg.sender][coinName[dgeContractAddr2]] = amountCt;
    //     return (amountCt, amountA, amountB, liquidity);
    //  }
    //dge1:dge2 pairs ok ban
    // function myAddLiquidity(uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to) public returns(uint _amountA, uint _amountB, uint _liquidity) {
    //     IDGE idge1 = IDGE(dgeContractAddr1);
    //    IDGE idge2 = IDGE(dgeContractAddr2);
    //    idge1.approve(uniswapV2Router02Addr, amountADesired);
    //    idge2.approve(uniswapV2Router02Addr, amountBDesired); (uint amountA, uint amountB, uint liquidity) = _addLiquidity(dgeContractAddr1, dgeContractAddr2, amountADesired, amountBDesired, amountAMin, amountBMin, to, mydeadline);
    //    return (amountA, amountB, liquidity);
    //  }
    //设置交易对ADDr
    function setAddrs(address _zhuAddr1, address _zhuAddr2, address _zhuAddr3, address _zhuAddr4, address _zhuAddr5, address _zhuAddr6, address _zhuAddr7) public onlyGovenors1 returns(bool _success) {
        zhuAddr1 = _zhuAddr1;
        zhuAddr2 = _zhuAddr2;
        zhuAddr3 = _zhuAddr3;
        zhuAddr4 = _zhuAddr4;
        zhuAddr5 = _zhuAddr5;
        zhuAddr6 = _zhuAddr6;
        zhuAddr7 = _zhuAddr7;
        return true;
    }
    //设置交易对ADDr
    function setAddrs2(address _ctokenAddr, address _weth, address _dgeContractAddr1, address _dgeContractAddr2, address _dgeContractAddr, address _exPairsCtokenAddr, address _uniswapV2Router02Addr, uint256 _miniDealineTime, uint256 _mydeadline) public onlyGovenors1 returns(bool _success) {
        ctokenAddr = _ctokenAddr;
        weth = _weth;
        dgeContractAddr1 = _dgeContractAddr1;
        dgeContractAddr2 = _dgeContractAddr2;
        dgeContractAddr = _dgeContractAddr;
        exPairsCtokenAddr = _exPairsCtokenAddr;
        uniswapV2Router02Addr = _uniswapV2Router02Addr;
        miniDealineTime = _miniDealineTime;
        mydeadline = _mydeadline;
        return true;
    }

    //utils
    //1  swapExactTokensForTokens  //path = dge1:dge2,so user send dge1 amount ,get dge2 amount out , dge1=>dge2 ok
    function _swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] memory path, address to, uint deadline) internal returns(uint[] memory amounts) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        return uniswpair.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
    }
    //2  swapTokensForExactTokens  //path =  dge1:dge2, so user want get dge2 amount ,get dge1 need amount , dge1=>dge2 ok
    function _swapTokensForExactTokens(uint amountOut, uint amountInMax, address[] memory path, address to, uint deadline) internal returns(uint[] memory amounts) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        return uniswpair.swapTokensForExactTokens(amountOut, amountInMax, path, to, deadline);
    }
    //3  swapExactETHForTokens   //path = eth:dge1,so user send value ,get dge1 amount out  , eth=>dge1 ok
    function _swapExactETHForTokens(uint amountOutMin, address[] memory path, address to, uint deadline) internal returns(uint[] memory amounts) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        return uniswpair.swapExactETHForTokens.value(msg.value)(amountOutMin, path, to, deadline);
    }
    //4  swapTokensForExactETH  //path = dge1:eth,so user send token ,get eth amount out  , dge1 => eth ok
    function _swapTokensForExactETH(uint amountOut, uint amountInMax, address[] memory path, address to, uint deadline) internal returns(uint[] memory amounts) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        return uniswpair.swapTokensForExactETH(amountOut, amountInMax, path, to, deadline);
    }
    //5  swapExactTokensForETH  //path = dge1:eth,so user send token ,get eth amount out  , dge1 => eth ok
    function _swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] memory path, address to, uint deadline) internal returns(uint[] memory amounts) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        return uniswpair.swapExactTokensForETH(amountIn, amountOutMin, path, to, deadline);
    }

    //6  swapETHForExactTokens  //path = eth:dge1,so user send value ,get dge1 amount out  , eth=>dge1 ok
    function _swapETHForExactTokens(uint amountOut, address[] memory path, address to, uint deadline) public payable returns(uint[] memory amounts) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        return uniswpair.swapETHForExactTokens(amountOut, path, to, deadline);
    }
    //path = _dgeContractAddr1:::_dgeContractAddr1N ,  _dgeContractAddr1=存入币种.... _dgeContractAddr1N=换出币种
    function mintBurnCtoken(address[] memory _dgeContractAddr1, uint[] memory _dge1Amount) internal returns(bool _success) {
        //销毁ctoken
        if (_dgeContractAddr1[0] == dgeContractAddr) {
            _burnToken(msg.sender, _dge1Amount[0]);
            dgeWebExAmountT1[msg.sender][coinName[_dgeContractAddr1[1]]] -= _dge1Amount[1];
            dgeWebExAmountT2[msg.sender][coinName[_dgeContractAddr1[1]]] -= _dge1Amount[0];
        } else if (_dgeContractAddr1[1] == dgeContractAddr) {
            _mintCtoken(msg.sender, _dge1Amount[1]);
            dgeWebExAmountT1[msg.sender][coinName[_dgeContractAddr1[0]]] += _dge1Amount[0];
            dgeWebExAmountT2[msg.sender][coinName[_dgeContractAddr1[0]]] += _dge1Amount[1];
        } else {}
        return true;
    }
    //pay dge shouyi to user,return totalrate ;
    function payEarningDgeAllRateToSender(uint256 _dge1Amount) public view returns(uint256 _rateAll) {
        ICToken ict = ICToken(ctokenAddr); (uint256 _typesCount) = ict.getTypesCount(msg.sender);
        //1000 * (74390.8362 / 72000) * 0.72 * （5*10-8）* 5760 = 0.21 USD = 0.2975 DGE
        uint256 totalAmount = 0;
        uint256 totalrateAmount = 0;
        uint256 leftAmount = _dge1Amount;
        for (uint i = 1; i <= _typesCount; i++) { (uint256 _balanceOf, uint256 _creatTime, uint256 _rate) = ict.getCTokenAddrInfos(i, msg.sender);
            if (leftAmount >= _balanceOf) {
                leftAmount -= _balanceOf;
                totalAmount += _balanceOf;
                totalrateAmount += _balanceOf.mul(_rate).mul(10000000000).mul((block.timestamp.sub(_creatTime))).div(31536000);
            } else {
                totalAmount += leftAmount;
                totalrateAmount += leftAmount.mul(_rate).mul(10000000000).mul((block.timestamp.sub(_creatTime))).div(31536000);
            }
        }
        uint256 rateAll = totalrateAmount.div(totalAmount).div(10000000000);
        return rateAll;
    }

    function utilCompareInternal(string memory a, string memory b) internal pure returns(bool) {
        if (bytes(a).length != bytes(b).length) {
            return false;
        }
        for (uint i = 0; i < bytes(a).length; i++) {
            if (bytes(a)[i] != bytes(b)[i]) {
                return false;
            }
        }
        return true;
    }

    // eth:dge2 pairs, @_ethAmount = input eth amount, return @_amounts = get dge1 amount
    function getEthExDgeAmount(uint256 _ethAmount) public view returns(uint[] memory _dgeAmounts) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        address[] memory path;
        path = new address[](2);
        path[0] = weth;
        path[1] = dgeContractAddr1;
        return uniswpair.getAmountsOut(_ethAmount, path);
    }
    // eth:dge2 pairs, @_dgeAmount = can get dge1 amount, return @_ethAmounts = need eth amount
    function getDgeEXEthAmount(uint256 _dgeAmount) public view returns(uint[] memory _ethAmounts) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        address[] memory path;
        path = new address[](2);
        path[0] = weth;
        path[1] = dgeContractAddr1;
        return uniswpair.getAmountsIn(_dgeAmount, path);
    }
    // dge1:dge2 pairs,
    //@_dge1Amount = input dge1 amount, return @_dge2Amounts = get dge2 amount
    function getDge1ExDge2Amount(uint256 _dge1Amount) public view returns(uint[] memory _dge2Amounts) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        address[] memory path;
        path = new address[](2);
        path[0] = dgeContractAddr1;
        path[1] = dgeContractAddr2;
        return uniswpair.getAmountsOut(_dge1Amount, path);
    }
    // dge1:dge2 pairs,
    //@_dge2mount = can get dge2 amount, return @_dge1Amounts = need dge1 amount
    function getDge2EXDge1Amount(uint256 _dge2Amount) public view returns(uint[] memory _dge1Amounts) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        address[] memory path;
        path = new address[](2);
        path[0] = dgeContractAddr1;
        path[1] = dgeContractAddr2;
        return uniswpair.getAmountsIn(_dge2Amount, path);
    }
    function _getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal view returns(uint amountOut) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        return uniswpair.getAmountOut(amountIn, reserveIn, reserveOut);
    }
    function _addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) internal returns(uint _amountA, uint _amountB, uint _liquidity) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        return uniswpair.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline);
    }
    function _addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) public payable returns(uint amountToken, uint amountETH, uint liquidity) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        return uniswpair.addLiquidityETH.value(msg.value)(token, amountTokenDesired, amountTokenMin, amountETHMin, to, deadline);
    }
    function _removeLiquidityETH(address token, uint liquidity, uint amountTokenMin, uint amountETHMin, address to, uint deadline) internal returns(uint amountToken, uint amountETH) {
        IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        return uniswpair.removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    //向当前合约账户转账
    function _transferETHToThisContractByValue() public payable {
        address addrthis = address(this);
        address payable payaddrthis = address(uint160(addrthis));
        payaddrthis.transfer(msg.value);
    }
    //发送ctoken
    function _mintCtoken(address target, uint256 mintedAmount) internal {
        ICToken ict = ICToken(ctokenAddr);
        ict.mintToken(target, mintedAmount);
    }
    function _burnToken(address target, uint256 burnAmount) internal {
        ICToken ict = ICToken(ctokenAddr);
        ict.burnToken(target, burnAmount);
    }

    function approveToken(address token, uint amountTokenDesired) internal returns(bool _success) {
        IDGE idge1 = IDGE(token);
        return idge1.approve(uniswapV2Router02Addr, amountTokenDesired);
    }
    function dgeTransferFrom(address token, uint amountTokenDesired) public payable returns(bool _success) {
        IDGE idge1 = IDGE(token);
        //transfer dge1 to this contractaddr
        address addrthis = address(this);
        address payable payaddrthis = address(uint160(addrthis));
        return idge1.transferFrom(msg.sender, payaddrthis, amountTokenDesired);
    }
    event EFunction(address, uint);
    receive() external payable {
        emit EFunction(msg.sender, msg.value);
    }
    //withdraw util
     function myswapExactTokensForETHforWhithdraw(uint amountIn, address _addr1, address _addr2) internal returns(uint[] memory _amounts) {
        uint amountOutMin = 1;
        // address _addr1,address _addr2,
        address[] memory path;
        path = new address[](2);
        path[0] = _addr1;
        path[1] = _addr2;

        //IERC20 ierc20 = IERC20(_tokenIndex);
        IERC20 ierc201 = IERC20(path[0]);

        ierc201.approve(uniswapV2Router02Addr, amountIn);
        uint[] memory amounts = _swapExactTokensForETH(amountIn, amountOutMin, path, zhuAddr1, mydeadline);
        mintBurnCtoken(path, amounts);

        // address addrthis = address(this);
        // address payable payaddrthis = address(uint160(addrthis));
        // require(ierc201.allowance(msg.sender, payaddrthis) >= amountIn, "ierc201.allowance(msg.sender, payaddrthis) is insufficient");
        // ierc201.transferFrom(msg.sender, payaddrthis, amountIn);
        // msg.sender.transfer(amounts[1]);

        return amounts;
    }
     function myswapExactTokensForTokensforWhithdraw(address _addr1, address _addr2, uint amountIn) internal returns(uint[] memory _amounts) {
        uint amountOutMin = 1;
        // address _addr1,address _addr2,
        address[] memory path;
        path = new address[](2);
        path[0] = _addr1;
        path[1] = _addr2;

        //IERC20 ierc20 = IERC20(_tokenIndex);
        //  IDGE idge1 = IDGE(dgeContractAddr1);
        //  idge1.approve(uniswapV2Router02Addr, amountIn);
        //  IDGE idge2 = IDGE(dgeContractAddr2);
        IERC20 ierc201 = IERC20(_addr1);
        ierc201.approve(uniswapV2Router02Addr, amountIn);

        //    IUniswapV2Router02 uniswpair = IUniswapV2Router02(uniswapV2Router02Addr);
        //   uint256 amountADesired = uniswpair.getAmountsOut(amountIn, path)[1];
        //   ierc202.approve(uniswapV2Router02Addr, amountADesired);
        uint[] memory amounts = _swapExactTokensForTokens(amountIn, amountOutMin, path, zhuAddr1, mydeadline);
        mintBurnCtoken(path, amounts);

        // address addrthis = address(this);
        // address payable payaddrthis = address(uint160(addrthis));
        // require(ierc201.allowance(msg.sender, payaddrthis) >= amountIn, "ierc201.allowance(msg.sender, payaddrthis) is insufficient");
        // ierc201.transferFrom(msg.sender, payaddrthis, amountIn);

        // IERC20 ierc202 = IERC20(_addr2);
        // if (path[1] != dgeContractAddr) {
        //     ierc202.transfer(msg.sender, amounts[1]);
        // }

        return amounts;
    }
    //bak function ,withdraw ,ctoken to eth + dge ok
    //  //user 赎回之前平台购买的eth,DAI等,ctoken=>eth,Dai
    //    function withdrowUserETHorDai(address _tokenIndex, uint256 _ctokenAmount) public returns(uint256[] memory _withdrawAmount) {
    //        require(dgeWebExAmountT1[msg.sender][coinName[_tokenIndex]] > 0);
    //        require(dgeWebExAmountT2[msg.sender][coinName[_tokenIndex]] > 0);
    //        require(_ctokenAmount > 0);
    //        if (utilCompareInternal(coinName[_tokenIndex], "ETH")) {
    //            address[] memory path;
    //            path = new address[](2);
    //            path[0] = dgeContractAddr1;
    //            path[1] = _tokenIndex;
    //            uint[] memory amounts = myswapExactTokensForETH(_ctokenAmount, path[0], path[1]);
    //            //打eth
    //            require(msg.sender != address(0));
    //            msg.sender.transfer(amounts[1]);
    //            //打利息dge
    //            payEarningDGE(amounts[0], amounts[1]);
    //            return amounts;
    //        } else {
    //            address[] memory path;
    //            path = new address[](2);
    //            path[0] = dgeContractAddr1;
    //            path[1] = _tokenIndex;
    //            uint[] memory amounts = myswapExactTokensForTokens(path[0], path[1], _ctokenAmount);
    //            //打Dai等
    //            require(msg.sender != address(0));
    //            IERC20 ierc20 = IERC20(_tokenIndex);
    //            ierc20.transfer(msg.sender, amounts[1]);
    //            //  msg.sender.transfer(amounts[1]);
    //            //打利息dge
    //            payEarningDGE(amounts[0], amounts[1]);
    //            return amounts;
    //        }
    //    }
    //

}