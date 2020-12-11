pragma experimental ABIEncoderV2;
pragma solidity >= 0.6.2 < 0.7.0;
//pragma solidity >= 0.6.0;
//pragma solidity >= 0.4.22 < 0.6.0;
import "./StandardToken.sol";
import "./Controlled.sol";
import "./Authority.sol";

import "./Ballot.sol";
//import "./Loan.sol";
//import "./Pledge.sol";
import "./Rebase.sol";
//DGE代币
contract DGE is StandardToken,
Controlled,
Authority,
Ballot,
Rebase {
    mapping(address =>mapping(address =>uint256)) internal allowed;
    //初始化代币参数
    constructor(uint256 _initialAmount, string memory _tokenName, uint8 _decimalUnits, string memory _tokenSymbol) public {
        totalSupply = _initialAmount; //300万
        name = _tokenName;
        symbol = _tokenSymbol;
        decimals = _decimalUnits;
        balanceOf[msg.sender] = totalSupply;
        addrList[(addrListLength - 1)] = msg.sender;
    }

    function getBalanceOf(address _target) public view returns(uint256) {
        return balanceOf[_target];
    }
    //增发代币
    function mintToken(address target, uint256 mintedAmount) public onlyGovenors1 {
        balanceOf[target] = balanceOf[target].add(mintedAmount);
        totalSupply = totalSupply.add(mintedAmount);
        addAddressToAddrList(target);
        emit Transfer(address(0), owner, mintedAmount);
        emit Transfer(owner, target, mintedAmount);
    }
    //（销毁）减少代币，销毁该地址添加一定数量的代币，同样需要修改totalSupply代币总量值。
    function burnToken(address target, uint256 burnAmount) public onlyGovenors1 {
        require(target != address(0), "ERC20: burn from the zero address");
        require(balanceOf[target] >= burnAmount, "ERC20: burn amount insufficient");
        balanceOf[target] = balanceOf[target].sub(burnAmount);
        totalSupply = totalSupply.sub(burnAmount);
        emit BurnTokenSuccess(target, address(0), burnAmount);
    }
    //销毁的另一种形式，需要批准，A 批准 B 10个代币的转移权，B 可销毁 A 账户下10个代币，同时也要减少 A 对B 的批准转移数量。
    function burnFrom(address account, uint256 amount) public {
        require(amount <= allowed[account][msg.sender], "MyERROR: approve amount insufficient");
        burnToken(account, amount);
        allowed[account][msg.sender] = allowed[account][msg.sender].sub(amount);
    }
    function transfer(address _to, uint256 _value) public transferAllowed(msg.sender) returns(bool success) {
        //require(_to != address(0));
        require(_to != address(0), "ERC20: approve from the zero address");
        require(_value <= balanceOf[msg.sender]);
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        addAddressToAddrList(_to);
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