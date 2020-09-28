pragma experimental ABIEncoderV2;
pragma solidity >= 0.4.22 < 0.6.0;
import "./StandardToken.sol";
import "./Controlled.sol";

//12hours = 43200 S
//光伏代币
contract DGE is StandardToken,
Controlled {

	//账户集合
	mapping(address =>uint256) public balanceOf;
	//持币地址 list
	mapping(uint256 =>address) public addrList;
	//addrlist 大小
	uint256 addrListLength = 1;
	//address 是否是否存在list里 true=in,false=not in 
	mapping(address =>bool) isInAddrList;
	//向所有账户增发的，比例的基准总数量 初始值30万.单位为最小单位8位小数
	uint256 rebaseBaseAmount = 30000000000000;
	//向所有账户增发的比例 10，表示增发10%
	uint256 rebaseRate = 10;
	//初始值为12小时间隔 ，= 43200 s
	uint256 rebaseLessTime = 43200;
	//初始值区块 ，= 2019-01-01 12:00:00, 无穷大=锁定 ，小=开启
	uint256 rebaseFistBlocktime = 1546315200;
	mapping(address =>mapping(address =>uint256)) internal allowed;
	//销毁代币成功的事件
	event BurnTokenSuccess(address indexed _from, address indexed _to, uint256 _value);
	//控制合约 要求rebase12小时之后才能进行
	modifier rebaseTimeAllowed() {
		require((block.timestamp > rebaseFistBlocktime.add(rebaseLessTime)), "It's not time for Reabase yet!");
		_;
	}
	//初始化代币参数
	constructor(uint256 _initialAmount, string memory _tokenName, uint8 _decimalUnits, string memory _tokenSymbol) public {
		totalSupply = _initialAmount; //300万
		name = _tokenName;
		symbol = _tokenSymbol;
		decimals = _decimalUnits;
		balanceOf[msg.sender] = totalSupply;
		addrList[(addrListLength - 1)] = msg.sender;
	}
	//把持币地址加入到addrList列表
	function addAddressToAddrList(address _addr) internal {
		if (!isInAddrList[_addr]) {++addrListLength;
			addrList[(addrListLength - 1)] = _addr;
			isInAddrList[_addr] = true;
		}
	}
	// 获得向所有账户增发的，比例的基准总数量 初始值300000.单位为最小单位
	//获得向所有账户增发的比例 10，表示增发10% //获得初始值为12小时间隔 ，= 43200 s
	//获得初始值区块 ，= 2019-01-01 12:00:00, 无穷大=锁定 ，小=开启
	function getOtherRebaseInfo() public view isCommunityLeaders returns(uint256 _rebaseBaseAmount, uint256 _rebaseRate, uint256 _rebaseLessTime, uint256 _rebaseFistBlocktime) {
		return (rebaseBaseAmount, rebaseRate, rebaseLessTime, rebaseFistBlocktime);
	}
	//设置 向所有账户增发的，比例的基准总数量 ,初始值300000.单位为最小单位 
	//设置 向所有账户增发的比例 10，表示增发10%
	//初始值区块 无穷大=锁定 ，小=开启
	//初始值为12小时间隔
	function setRebaseArg(uint256 _rebaseBaseAmount, uint256 _rebaseRate, uint256 _rebaseFistBlocktime, uint256 _rebaseLessTime) public isCommunityLeaders returns(bool success) {
		rebaseBaseAmount = _rebaseBaseAmount;
		rebaseRate = _rebaseRate;
		rebaseFistBlocktime = _rebaseFistBlocktime;
		rebaseLessTime = _rebaseLessTime;
		return true;
	}
	//向所有持币地址，按比例增发代币
	function toAllAddressMintTokenAsRate() public onlyOwner rebaseTimeAllowed returns(bool success) {
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
	function toAllAddressBurnTokenAsRate() public onlyOwner rebaseTimeAllowed returns(bool success) {
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
	//增发代币
	function mintToken(address target, uint256 mintedAmount) public onlyOwner {
		balanceOf[target] = balanceOf[target].add(mintedAmount);
		totalSupply = totalSupply.add(mintedAmount);
		addAddressToAddrList(target);
		emit Transfer(address(0), owner, mintedAmount);
		emit Transfer(owner, target, mintedAmount);
	}
	//（销毁）减少代币，销毁该地址添加一定数量的代币，同样需要修改totalSupply代币总量值。
	function burnToken(address target, uint256 burnAmount) public onlyOwner transBalanceLessAvailable(target, burnAmount) {
		require(target != address(0), "ERC20: burn from the zero address");
		balanceOf[target] = balanceOf[target].sub(burnAmount);
		totalSupply = totalSupply.sub(burnAmount);
		addAddressToAddrList(target);
		emit BurnTokenSuccess(address(0), target, burnAmount);
	}
	//	//销毁的另一种形式，需要批准，A 批准 B 10个代币的转移权，B 可销毁 A 账户下10个代币，同时也要减少 A 对B 的批准转移数量。
	//	function burnFrom(address account, uint256 amount) public onlyOwner {
	//		burnToken(account, amount);
	//		_approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "ERC20: burn amount exceeds allowance"));
	//	}
	function transfer(address _to, uint256 _value) public transferAllowed(msg.sender) transBalanceLessAvailable(msg.sender, _value) returns(bool success) {
		//require(_to != address(0));
		require(_to != address(0), "ERC20: approve from the zero address");
		require(_value <= balanceOf[msg.sender]);
		balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);
		balanceOf[_to] = balanceOf[_to].add(_value);
		addAddressToAddrList(_to);
		emit Transfer(msg.sender, _to, _value);
		return true;
	}
	function transferFrom(address _from, address _to, uint256 _value) public transferAllowed(_from) transBalanceLessAvailable(_from, _value) returns(bool success) {
		//require(_to != address(0));
		require(_to != address(0), "ERC20: approve from the zero address");
		require(_value <= balanceOf[_from]);
		require(_value <= allowed[_from][msg.sender]);
		balanceOf[_from] = balanceOf[_from].sub(_value);
		balanceOf[_to] = balanceOf[_to].add(_value);
		allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
		addAddressToAddrList(_from);
		addAddressToAddrList(_to);
		emit Transfer(_from, _to, _value);
		return true;
	}
	//授权
	function approve(address _spender, uint256 _value) public transBalanceLessAvailable(msg.sender, _value) returns(bool success) {
		allowed[msg.sender][_spender] = _value;
		addAddressToAddrList(_spender);
		emit Approval(msg.sender, _spender, _value);
		return true;
	}
	//查看剩余授权数量代币
	function allowance(address _owner, address _spender) public view returns(uint256 remaining) {
		return allowed[_owner][_spender];
	}

	///
	//ballot
	struct Voter {
		uint256 weight; // this time don't use,weight is accumulated by delegation，
		bool voted; //if true ,that perpn already voted
		uint vote;
		address delegate;
	}
	struct Proposal {
		uint voteCount;
	}
	address public chairPerson;
	mapping(address =>Voter) voters;
	Proposal[] public proporsals;
	//投票发起时间点，所有地址持币值快照
	mapping(address =>uint256) balanceAtVoteTime;
	// 要求投票用户持币DGE > 一定数量 初始值=0；
	uint256 voteLessDGEAmount = 0;
	//控制合约 要求投票用户持币DGE > 一定数量 初始值=0；
	modifier voteRightLesDGEAmount() {
		require((balanceOf[msg.sender] >= voteLessDGEAmount), "There is no right to vote，the minimum amount of COINS is not reached!");
		_;
	}
	//投票发起时间点，所有地址持币值快照,所有地址Voter数据清零, 其他投票数据全部清零
	function voteWriteAllBalance() internal onlyOwner {
		proporsals.length = 0;
		for (uint i = 1; i <= addrListLength; i++) {
			uint256 nowVoteBalance = balanceOf[addrList[i]];
			balanceAtVoteTime[addrList[i]] = nowVoteBalance;
			voters[addrList[i]].weight = 0;
			voters[addrList[i]].voted = false;
			voters[addrList[i]].vote = 0;
			voters[addrList[i]].delegate = address(0);
		}
	}
	//发起投票
	function makeAVote(uint _numProposal) public isCommunityLeaders voteLockAllowed {
		chairPerson = msg.sender;
		voteWriteAllBalance();
		voters[chairPerson].weight = balanceAtVoteTime[chairPerson];
		proporsals.length = _numProposal;
	}
	//_weight,大小为币的数量，单位为最小单位
	function giveRightToVote(address to, uint256 _weight) public {
		require(msg.sender == chairPerson, "Only chairperson can give right to vote.");
		require(!voters[to].voted, "The voter already voted.");
		//	require(voters[to].weight == 0);
		//	voters[to].weight = _weight;
		balanceAtVoteTime[to] = balanceAtVoteTime[to].add(_weight);
	}
	//委托
	function delegate(address to) public voteRightLesDGEAmount {
		Voter storage sender = voters[msg.sender];
		require(!sender.voted, "you hava already voted");
		require(to != msg.sender);
		while (voters[to].delegate != address(0) && voters[to].delegate != msg.sender) {
			to = voters[to].delegate;
		}
		sender.voted = true;
		sender.delegate = to;
		Voter storage delegateTo = voters[to];
		if (delegateTo.voted) {
			proporsals[delegateTo.vote].voteCount = proporsals[delegateTo.vote].voteCount.add(balanceAtVoteTime[msg.sender]);
		} else {
			balanceAtVoteTime[to] = balanceAtVoteTime[to].add(balanceAtVoteTime[msg.sender]);
		}
	}
	//从数组0号开始
	function vote(uint proposal) public voteRightLesDGEAmount voteLockAllowed {
		Voter storage sender = voters[msg.sender];
		require(!sender.voted, "no right");
		sender.voted = true;
		sender.vote = proposal;
		proporsals[sender.vote].voteCount = proporsals[sender.vote].voteCount.add(balanceAtVoteTime[msg.sender]);
	}
	//目前获胜编号
	function winningProposal() public view returns(uint _winningProposal) {
		uint winningCount = 0;
		for (uint prop = 0; prop < proporsals.length; prop++) {
			if (winningCount < proporsals[prop].voteCount) {
				winningCount = proporsals[prop].voteCount;
				_winningProposal = prop;
			}
		}
	}
	//获胜者票数
	function winningCount(uint) view public returns(uint256) {
		uint _winningCount = 0;
		uint _winningProposal = 0;
		for (uint prop = 0; prop < proporsals.length; prop++) {
			if (_winningCount < proporsals[prop].voteCount) {
				_winningCount = proporsals[prop].voteCount;
				_winningProposal = prop;
			}
		}

		return proporsals[_winningProposal].voteCount.div(10 **uint256(decimals));
	}

	///
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

	///
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
		loa.length += 1;
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
		loa.length -= 1;
		LoanItemTimes[_userAddress] = LoanItemTimes[_userAddress].sub(1);
		return true;
	}
	// 显示用户贷款数据
	function showAddressLoanItem(address _userAddress) public view isCommunityLeaders returns(LoanItem[] memory) {
		LoanItem[] storage loa = loanUserDGEAmount[_userAddress];
		return loa;
	}
}