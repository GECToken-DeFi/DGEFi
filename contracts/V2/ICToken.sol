pragma solidity >= 0.6.2 < 0.7.0;
interface ICToken {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    event BurnTokenSuccess(address indexed _from, address indexed _to, uint256 _value);

    function name() external view returns(string memory);
    function symbol() external view returns(string memory);
    function decimals() external view returns(uint8);
    function totalSupply() external view returns(uint);
    function balanceOf(address owner) external view returns(uint);
    function getRate() external view returns(uint256 _rate);
    function setRate(uint256 _rate) external  returns(bool _success);
    function getCTokenAddrInfos(uint256 _index, address _target) external view returns(uint256 _balanceOf, uint256 _creatTime, uint256 _rate);
    function getTypesCount(address _target) external view returns(uint256 _typesCount);
    function mintToken(address target, uint256 mintedAmount) external; //  public onlyGovenors1
    function burnToken(address target, uint256 burnAmount) external; // external   onlyGovenors1
    function burnFrom(address account, uint256 amount) external;
    function transfer(address _to, uint256 _value) external returns(bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns(bool success);
    function approve(address _spender, uint256 _value) external returns(bool success);
    function allowance(address _owner, address _spender) external view returns(uint256 remaining);
}