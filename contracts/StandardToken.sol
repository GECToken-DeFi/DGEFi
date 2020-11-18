pragma solidity >= 0.6.2 < 0.7.0;
import "./SafeMath.sol";
contract StandardToken {
	//使用SafeMath
	using SafeMath for uint256;
	//代币名称
	string public name;
	//代币缩写
	string public symbol;
	//代币小数位数(一个代币可以分为多少份)
	uint8 public  decimals;
	//代币总数
	uint256 public totalSupply;
// 	//交易的发起方(谁调用这个方法，谁就是交易的发起方)把_value数量的代币发送到_to账户
// 	function transfer(address _to, uint256 _value) public returns (bool success);
// 	//从_from账户里转出_value数量的代币到_to账户
// 	function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
// 	//交易的发起方把_value数量的代币的使用权交给_spender，然后_spender才能调用transferFrom方法把我账户里的钱转给另外一个人
// 	function approve(address _spender, uint256 _value) public returns (bool success);
// 	//查询_spender目前还有多少_owner账户代币的使用权
// 	function allowance(address _owner, address _spender) public view returns (uint256 remaining);
	//转账成功的事件
	event Transfer(address indexed _from, address indexed _to, uint256 _value);
	//使用权委托成功的事件
	event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}