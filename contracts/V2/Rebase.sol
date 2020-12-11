pragma experimental ABIEncoderV2;
//pragma solidity >= 0.4.22 < 0.6.0;
pragma solidity >= 0.6.2 < 0.7.0;
//pragma solidity >=0.6.0;
import "./StandardToken.sol";
import "./Authority.sol";
import "./Controlled.sol";
import "./IUniswapV2Pair.sol";
import "./ICToken.sol";
//12hours = 43200 S
//市场平衡
contract Rebase is StandardToken,
Controlled,
Authority {
    //使用SafeMath
    using SafeMath
    for uint256;
    //向所有账户增发的，比例的基准总数量 初始值30万.单位为最小单位8位小数
    uint256 public rebaseBaseAmount = 300000000000000000000000;
    //向所有账户增发的比例 10，表示增发10%
    uint256 public rebaseRate = 10;
    //初始值为12小时间隔 ，= 43200 s
    uint256 public rebaseLessTime = 120; //600;//43200;
    //初始值区块 ，= 2019-01-01 12:00:00, 无穷大=锁定 ，小=开启
    uint256 public rebaseFistBlocktime = 1546315200;

    //查询uniswap余量
    address public dgeUniswapPairAddr = 0x1efc9eFE96FD2c316EafcB71cc15819Bb72Ef8F3;
    //weth:usdt   //test dai
    address public wethUsdtUniswapPairAddr = 0x3642d35Fa8B29157ADB3bb3C44FA372eb40b28B2;
    // IDGE idge = IDGE(dgeContractAddr);
    uint256 public dgeUniswapPrice = 500000; //lastrebase,单位1000000倍 usdt
    uint256 public dgedecim = 1000000000000000000; //18个0
    uint256 public wethdecim = 1000000000000000000; //18个0
    uint256 public usdtdecim = 1000000000000000000; //18个0
    address public minerPoolAddr = 0x57125786a8bb5d36cF394C89665e356276219156;
    address public ctokenAddr = 0x6c70941732Ba474ee44566fBb05cB0744e7B4d7A;
    //uint 个,18ge0
    uint256 public liquidEthLeftAmountLast = 1000000000000000000000000;
    //rebase,启动比率,unit 1000000,900000=90 %
    uint256 public lessRebaseRate = 150000;
    //上次rebase dge的usdt价格,nit 1000000,
    uint256 public lessRebaseDgePriceInUsdt = 50000;

    //控制合约 要求rebase12小时之后才能进行
    modifier rebaseTimeAllowed() {
        require((block.timestamp > rebaseFistBlocktime.add(rebaseLessTime)), "It's not time for Reabase yet!");
        _;
    }
    //初始化代币参数
    constructor() public {}

    function setRebaseArg2(address _minerPoolAddr, address _ctokenAddr, uint256 _liquidEthLeftAmountLast, uint256 _lessRebaseRate, uint256 _lessRebaseDgePriceInUsdt, address _wethUsdtUniswapPairAddr) public onlyOwner returns(bool success) {
        minerPoolAddr = _minerPoolAddr;
        ctokenAddr = _ctokenAddr;
        liquidEthLeftAmountLast = _liquidEthLeftAmountLast;
        lessRebaseRate = _lessRebaseRate;
        lessRebaseDgePriceInUsdt = _lessRebaseDgePriceInUsdt;
        wethUsdtUniswapPairAddr = _wethUsdtUniswapPairAddr;
        return true;
    }
    function setCRateAndAddMinerAmount() internal returns(bool _success) {
        //设置ctoken,rate liquidEthLeftAmountLast
        (uint256 _reserve0, uint256 _reserve1, ) = getUniswapPrice(dgeUniswapPairAddr);
        (uint256 _reserve02, uint256 _reserve12, ) = getUniswapPrice(wethUsdtUniswapPairAddr);
        // uint256 dgewei =  _reserve1.div((_reserve0.div(dgedecim)));
        uint256 usdtwei = _reserve12.div((_reserve02.div(usdtdecim)));
        //uint usd
        uint256 ethDgeLiquidEthTotalMuch = _reserve1.div(usdtwei);
        //uint dge
        uint256 dgeMinerPoolLeft = balanceOf[minerPoolAddr];
        //单位10000000000倍,10 ge 0
        uint256 ctokenRate = dgeMinerPoolLeft.mul(10000000000).div(ethDgeLiquidEthTotalMuch).div(dgedecim);
        setCtokenRate(ctokenAddr, ctokenRate);

        //向矿池打一半币DGE
        if (_reserve0 < liquidEthLeftAmountLast) {
            uint256 halfdge = liquidEthLeftAmountLast.sub(_reserve0);
            balanceOf[minerPoolAddr] = balanceOf[minerPoolAddr].add(halfdge);
            totalSupply = totalSupply.add(halfdge);
            emit Transfer(address(0), owner, halfdge);
            emit Transfer(owner, minerPoolAddr, halfdge);

        } else if (_reserve0 > liquidEthLeftAmountLast) {
            uint256 halfdge = _reserve0.sub(liquidEthLeftAmountLast);
            balanceOf[minerPoolAddr] = balanceOf[minerPoolAddr].sub(halfdge);
            totalSupply = totalSupply.sub(halfdge);
            emit BurnTokenSuccess(minerPoolAddr, address(0), halfdge);
        } else {}

        liquidEthLeftAmountLast = _reserve0;
        return true;
    }

    //设置ctoken,rate
    function setCtokenRate(address _ctokenContractAddr, uint256 _rate) internal returns(bool _success) {
        ICToken ict = ICToken(_ctokenContractAddr);
        return ict.setRate(_rate); // external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    }
    //获得uniswap价格 0token,1weth
    function getUniswapPrice(address _dgeUniswapPairAddr) public view returns(uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        UniswapPair dgepair = UniswapPair(_dgeUniswapPairAddr); (_reserve0, _reserve1, _blockTimestampLast) = dgepair.getReserves(); // external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    }
    //获得uniswap价格,//?变化率 1000000倍
    function getUniswapPriceForUsdt() public view returns(uint256 _percent) { (uint256 _reserve0, uint256 _reserve1, ) = getUniswapPrice(dgeUniswapPairAddr); (uint256 _reserve02, uint256 _reserve12, ) = getUniswapPrice(wethUsdtUniswapPairAddr);

        uint256 dgewei = _reserve1.div((_reserve0.div(dgedecim)));
        uint256 usdtwei = _reserve12.div((_reserve02.div(usdtdecim)));
        //单位1000000倍
        return dgewei.mul(1000000).div(usdtwei);
    }
    //              //获得uniswap价格变化率 1000倍
    //     function getUniswapPriceForUsdtutile( uint256 _reserve0, uint256 _reserve1,  uint256 _reserve02, uint256 _reserve12 ) public view returns(uint256 _percent){
    //         uint256 dgewei =  _reserve1.div((_reserve0.div(dgedecim)));
    //         uint256 usdtwei =  _reserve12.div((_reserve02.div(usdtdecim)));
    //         //单位1000000倍
    //   return    dgewei.mul(1000000).div(usdtwei);
    //          }
    // 获得向所有账户增发的，比例的基准总数量 初始值300000.单位为最小单位
    //获得向所有账户增发的比例 10，表示增发10% //获得初始值为12小时间隔 ，= 43200 s
    //获得初始值区块 ，= 2019-01-01 12:00:00, 无穷大=锁定 ，小=开启
    function getOtherRebaseInfo() public view returns(uint256 _rebaseBaseAmount, uint256 _rebaseRate, uint256 _rebaseLessTime, uint256 _rebaseFistBlocktim, address _dgeUniswapPairAddr, uint256 _dgeUniswapPrice, uint256 _dgedecim, uint256 _wethdecim, uint256 _usdtdecim) {
        return (rebaseBaseAmount, rebaseRate, rebaseLessTime, rebaseFistBlocktime, dgeUniswapPairAddr, dgeUniswapPrice, dgedecim, wethdecim, usdtdecim);
    }
    //设置 向所有账户增发的，比例的基准总数量 ,初始值300000.单位为最小单位 
    //设置 向所有账户增发的比例 10，表示增发10%
    //初始值区块 无穷大=锁定 ，小=开启
    //初始值为12小时间隔
    function setRebaseArg(uint256 _rebaseBaseAmount, uint256 _rebaseRate, uint256 _rebaseFistBlocktime, uint256 _rebaseLessTime, address _dgeUniswapPairAddr, uint256 _dgeUniswapPrice, uint256 _dgedecim, uint256 _wethdecim, uint256 _usdtdecim) public onlyOwner returns(bool success) {
        rebaseBaseAmount = _rebaseBaseAmount;
        rebaseRate = _rebaseRate;
        rebaseFistBlocktime = _rebaseFistBlocktime;
        rebaseLessTime = _rebaseLessTime;
        dgeUniswapPairAddr = _dgeUniswapPairAddr;
        dgeUniswapPrice = _dgeUniswapPrice;
        dgedecim = _dgedecim;
        wethdecim = _wethdecim;
        usdtdecim = _usdtdecim;
        return true;
    }
    //开始rebase
    function startRebase() public rebaseTimeAllowed returns(bool success) {
        uint256 nowprices = getUniswapPriceForUsdt();
        if (nowprices >= lessRebaseDgePriceInUsdt) {
            return toAllAddressMintTokenAsRate();
        } else {
            return toAllAddressBurnTokenAsRate();
        }

    }
    //向所有持币地址，按比例增发代币
    function toAllAddressMintTokenAsRate() public rebaseTimeAllowed returns(bool success) {

        uint256 nowprice = getUniswapPriceForUsdt();
        uint256 difnow = 0;
        require(nowprice > lessRebaseDgePriceInUsdt, 'Rebase err :price up');
        if (nowprice > lessRebaseDgePriceInUsdt) {
            difnow = nowprice.sub(lessRebaseDgePriceInUsdt).mul(1000000).div(lessRebaseDgePriceInUsdt);
        } else {
            difnow = lessRebaseDgePriceInUsdt.sub(nowprice).mul(1000000).div(lessRebaseDgePriceInUsdt);
        }
        require(difnow > lessRebaseRate, 'Rebase err :lessRebaseRate is lower');

        //增发总数*100 最小单位
        uint256 totalrebaseRate = rebaseRate.mul(rebaseBaseAmount);
        //  uint256 totalrebaseRate = rebaseRate.mul(rebaseBaseAmount.mul(decimals)).div(totalSupply).div(100);
        // totalSupply=totalSupply.add(rebaseBaseAmount.mul(rebaseRate).div(100));
        uint256 newtotalSupply = totalSupply;
        for (uint i = 0; i < addrListLength; i++) {
            if (addrList[i] == minerPoolAddr) {
                continue;
            }
            uint256 addvalue = balanceOf[addrList[i]].mul(totalrebaseRate).div(totalSupply).div(100);
            balanceOf[addrList[i]] = balanceOf[addrList[i]].add(addvalue);
            newtotalSupply = newtotalSupply.add(addvalue);
        }
        totalSupply = newtotalSupply;
        rebaseFistBlocktime = block.timestamp;

        setCRateAndAddMinerAmount();

        lessRebaseDgePriceInUsdt = nowprice;

        return true;
    }
    //向所有持币地址，按比例通缩代币=销毁代币
    function toAllAddressBurnTokenAsRate() public rebaseTimeAllowed returns(bool success) {

        uint256 nowprice = getUniswapPriceForUsdt();
        uint256 difnow = 0;
        require(nowprice < lessRebaseDgePriceInUsdt, 'Rebase err :price down');
        if (nowprice > lessRebaseDgePriceInUsdt) {
            difnow = nowprice.sub(lessRebaseDgePriceInUsdt).mul(1000000).div(lessRebaseDgePriceInUsdt);
        } else {
            difnow = lessRebaseDgePriceInUsdt.sub(nowprice).mul(1000000).div(lessRebaseDgePriceInUsdt);
        }
        require(difnow > lessRebaseRate, 'Rebase err :lessRebaseRate is lower');

        //通缩总数*100 最小单位
        uint256 totalrebaseRate = rebaseRate.mul(rebaseBaseAmount);
        //  uint256 totalrebaseRate = rebaseRate.mul(rebaseBaseAmount.mul(decimals)).div(totalSupply).div(100);
        // totalSupply=totalSupply.add(rebaseBaseAmount.mul(rebaseRate).div(100));
        uint256 newtotalSupply = totalSupply;
        for (uint i = 0; i < addrListLength; i++) {
            if (addrList[i] == minerPoolAddr) {
                continue;
            }
            uint256 addvalue = balanceOf[addrList[i]].mul(totalrebaseRate).div(totalSupply).div(100);
            balanceOf[addrList[i]] = balanceOf[addrList[i]].sub(addvalue);
            newtotalSupply = newtotalSupply.sub(addvalue);
        }
        totalSupply = newtotalSupply;
        rebaseFistBlocktime = block.timestamp;

        setCRateAndAddMinerAmount();

        lessRebaseDgePriceInUsdt = nowprice;
        return true;
    }
}