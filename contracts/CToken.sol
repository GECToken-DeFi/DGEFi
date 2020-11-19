//pragma experimental ABIEncoderV2;
pragma solidity >= 0.6.2 < 0.7.0;
import "./StandardToken.sol";
import "./Controlled.sol";
import "./Authority.sol";
//ctoken利息凭证代币
contract CToken is StandardToken,
Controlled,
Authority {
    mapping(address =>mapping(address =>uint256)) internal allowed;
    //销毁代币成功的事件
    event BurnTokenSuccess(address indexed _from, address indexed _to, uint256 _value);
    //初始化代币参数
    constructor(uint256 _initialAmount, string memory _tokenName, uint8 _decimalUnits, string memory _tokenSymbol) public {
        totalSupply = _initialAmount; //0
        name = _tokenName;
        symbol = _tokenSymbol;
        decimals = _decimalUnits;
        balanceOf[msg.sender] = totalSupply;
        addrList[(addrListLength - 1)] = msg.sender;
    }
    // 	uint256[] creatTimes;//创建时间,数组,时间顺序排列
    // 	uint256 creatTimeslength=0;
    //此地址此用户ctoken种类数
    mapping(address =>uint256) public typesCount; //从1开始
    //此地址此用户ctoken种类数的index,对应的时间，从1开始
    mapping(address =>mapping(uint256 =>cTokenOneInfo)) public cTokenAddrInfos;

    struct cTokenOneInfo {
        uint256 balanceOf;
        uint256 creatTime; //创建时间
        uint256 rate; //生成时的利率,单位为 1,000,000倍，即 5000= 5000/1000000=0.005%,大写
    }
    uint256 rate = 273; //最终返利计算时,乘以参数(5*10**(-8)),实时利率,//生成时的利率,单位为 1,000,000倍，即 5000= 5000/1000000=0.005%,大写
    function getName() public view returns(string memory) {
        return name;
    }
    function getSymbol() public view returns(string memory) {
        return symbol;
    }
    function getDecimals() public view returns(uint8) {
        return decimals;
    }
    function getTotalSupply() public view returns(uint) {
        return totalSupply;
    }
    function getBalanceOf(address _target) public view returns(uint256) {
        return balanceOf[_target];
    }
    function setRate(uint256 _rate) public onlyGovenors1 returns(bool _success) {
        rate = _rate;
        return true;
    }
    //查询当前利率
    function getRate() public view returns(uint256 _rate) {
        return rate;
    }
    //查询用户持币利率信息,index查询,index start 1;
    function getCTokenAddrInfos(uint256 _index, address _target) public view returns(uint256 _balanceOf, uint256 _creatTime, uint256 _rate) {
        return (cTokenAddrInfos[_target][_index].balanceOf, cTokenAddrInfos[_target][_index].creatTime, cTokenAddrInfos[_target][_index].rate);
    }
    //查询用户持币利率种类个数
    function getTypesCount(address _target) public view returns(uint256 _typesCount) {
        return typesCount[_target];
    }
    //带利率的销毁代币
    function _burnCoinWithRate(address target, uint256 burnAmount) internal {
        uint256 leftcount = burnAmount;
        uint256 removeNum = 0; //
        uint256 typecount = typesCount[target];
        for (uint i = 1; i <= typecount; i++) {
            if (leftcount >= cTokenAddrInfos[target][i].balanceOf) {
                leftcount = leftcount - cTokenAddrInfos[target][i].balanceOf;
                removeNum += 1;
                continue;
            } else {
                cTokenAddrInfos[target][i].balanceOf -= leftcount;
                break;
            }
        }
        for (uint256 index = removeNum; index > 0; index--) {
            // if (index >= typecount) ;
            for (uint m = index; m < typecount; m++) {
                cTokenAddrInfos[target][m] = cTokenAddrInfos[target][m + 1];
            }
            typecount--;
            typesCount[target] -= 1;
        }
    }

    //发送代币,带利率
    function _transferCoinWithRate(address _from, address _to, uint256 _value) internal transferAllowed(msg.sender) {
        uint256 leftcount = _value;
        uint256 removeNum = 0; //
        uint256 typecount = typesCount[_from];
        for (uint k = 1; k <= typecount; k++) {
            if (leftcount >= cTokenAddrInfos[_from][k].balanceOf) {
                _transferWithRateIndexOne(_from, k, _to, cTokenAddrInfos[_from][k].balanceOf);
                leftcount = leftcount - cTokenAddrInfos[_from][k].balanceOf;
                removeNum += 1;
                //  continue;
            } else {
                cTokenAddrInfos[_from][k].balanceOf -= leftcount;
                //          uint256    leftcount2 =  cTokenAddrInfos[_from][k].balanceOf-leftcount ;
                _transferWithRateIndexOne(_from, k, _to, leftcount);
                break;
            }
        }
        for (uint256 index = removeNum; index > 0; index--) {
            // if (index >= typecount) ;
            for (uint m = index; m < typecount; m++) {
                cTokenAddrInfos[_from][m] = cTokenAddrInfos[_from][m + 1];
            }
            typecount--;
            typesCount[_from] -= 1;
        }
    }

    //计算添加工具，thisOneTime比较的时间，_to添加进的地址，_from从哪个地址添加
    function _transferWithRateIndexOne(address _from, uint256 k, address _to, uint256 _value) internal transferAllowed(msg.sender) {
        uint256 typecount_to = typesCount[_to];
        uint256 thisOneTime = cTokenAddrInfos[_from][k].creatTime;
        if (typecount_to == 0) {
            cTokenAddrInfos[_to][1].balanceOf = _value;
            cTokenAddrInfos[_to][1].creatTime = thisOneTime;
            cTokenAddrInfos[_to][1].rate = cTokenAddrInfos[_from][k].rate;
            typesCount[_to] += 1;
        } else {
            for (uint i = 1; i <= typecount_to; i++) {
                //小，则插入i位置
                if (thisOneTime < cTokenAddrInfos[_to][i].creatTime) {
                    for (uint j = typecount_to; j >= i; j--) {
                        cTokenAddrInfos[_to][j + 1] = cTokenAddrInfos[_to][j];
                    }
                    cTokenAddrInfos[_to][i].balanceOf = _value;
                    cTokenAddrInfos[_to][i].creatTime = thisOneTime;
                    cTokenAddrInfos[_to][i].rate = cTokenAddrInfos[_from][k].rate;
                    typesCount[_to] += 1;

                    break;
                } else if (thisOneTime == cTokenAddrInfos[_to][i].creatTime) {
                    cTokenAddrInfos[_to][i].balanceOf += _value;
                    break;
                } else {
                    if (i == (typecount_to)) {
                        cTokenAddrInfos[_to][i + 1].balanceOf = _value;
                        cTokenAddrInfos[_to][i + 1].creatTime = thisOneTime;
                        cTokenAddrInfos[_to][i + 1].rate = cTokenAddrInfos[_from][k].rate;
                        typesCount[_to] += 1;
                        break;
                    }
                }
            }
        }
    }

    //删除k值
    function _deleteRateIndexK(address _from, uint256 k) internal transferAllowed(msg.sender) {
        uint256 typecount = typesCount[_from];
        //	    require(k<=typecount,'index can not bigger than typesCount size');
        for (uint m = k; m < typecount; m++) {
            cTokenAddrInfos[_from][m] = cTokenAddrInfos[_from][m + 1];
        }
        typesCount[_from] -= 1;
    }
    //带利率的增发代币
    function _mintCoinWithRate(address target, uint256 mintedAmount) internal {
        uint256 nowtime = block.timestamp;
        uint256 typecount = typesCount[target] + 1;
        typesCount[target] += 1;
        cTokenAddrInfos[target][typecount].balanceOf = mintedAmount;
        cTokenAddrInfos[target][typecount].creatTime = nowtime;
        cTokenAddrInfos[target][typecount].rate = rate;
    }

    //增发代币
    function mintToken(address target, uint256 mintedAmount) public onlyGovenors1 {
        balanceOf[target] = balanceOf[target].add(mintedAmount);
        totalSupply = totalSupply.add(mintedAmount);
        addAddressToAddrList(target);
        _mintCoinWithRate(target, mintedAmount);
        emit Transfer(address(0), owner, mintedAmount);
        emit Transfer(owner, target, mintedAmount);
    }
    //带利率,（销毁）减少代币，销毁该地址添加一定数量的代币，同样需要修改totalSupply代币总量值。
    function burnToken(address target, uint256 burnAmount) public onlyGovenors1 {
        require(target != address(0), "ERC20: burn from the zero address");
        require(balanceOf[target] >= burnAmount, "ERC20: burn amount insufficient");
        balanceOf[target] = balanceOf[target].sub(burnAmount);
        totalSupply = totalSupply.sub(burnAmount);
        _burnCoinWithRate(target, burnAmount);
        emit BurnTokenSuccess(target, address(0), burnAmount);
    }
    //销毁的另一种形式，需要批准，A 批准 B 10个代币的转移权，B 可销毁 A 账户下10个代币，同时也要减少 A 对B 的批准转移数量。
    function burnFrom(address account, uint256 amount) public {
        require(amount <= allowed[account][msg.sender], "MyERROR: approve amount insufficient");
        burnToken(account, amount);
        allowed[account][msg.sender] = allowed[account][msg.sender].sub(amount);
        _burnCoinWithRate(account, amount);
    }
    function transfer(address _to, uint256 _value) public transferAllowed(msg.sender) returns(bool success) {
        //require(_to != address(0));
        require(_to != address(0), "ERC20: approve from the zero address");
        require(_value <= balanceOf[msg.sender]);
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        addAddressToAddrList(_to);
        _transferCoinWithRate(msg.sender, _to, _value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    function transferFrom(address _from, address _to, uint256 _value) public transferAllowed(_from) returns(bool success) {
        //require(_to != address(0));
        require(_to != address(0), "ERC20: approve from the zero address");
        require(_value <= balanceOf[_from]);
        require(_value <= allowed[_from][msg.sender]);
        balanceOf[_from] = balanceOf[_from].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        addAddressToAddrList(_to);
        _transferCoinWithRate(_from, _to, _value);
        emit Transfer(_from, _to, _value);
        return true;
    }
    //授权
    function approve(address _spender, uint256 _value) public returns(bool success) {
        allowed[msg.sender][_spender] = _value;
        addAddressToAddrList(_spender);
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    //查看剩余授权数量代币
    function allowance(address _owner, address _spender) public view returns(uint256 remaining) {
        return allowed[_owner][_spender];
    }
}
