pragma solidity 0.4.18;

contract admined{
	address public admin;

	function admined() public{
		admin = msg.sender;
	}

	modifier onlyAdmin(){
		if(msg.sender!=admin)revert();
		_;
	}

	function transferAdminship(address newAdmin) public onlyAdmin{
		admin = newAdmin;
	}
}

contract GCoin{

	mapping (address => uint256) public balanceOf;
	mapping (address => mapping(address => uint256)) public allowance;

	string public standard = "GCoin v1.0";
	string public name;
	string public symbol;
	uint8 public  decimal;
	uint256 public totalSupply;
	event Transfer(address indexed from,address indexed to,uint256 value);

	function GCoin(uint256 initialSupply,string tokenName,string tokenSymbol,uint8 decimalUnits) public{
		balanceOf[msg.sender] = initialSupply;
		name = tokenName;
		symbol = tokenSymbol;
		decimal = decimalUnits;
		totalSupply = initialSupply;
	}

	function transfer(address _to,uint256 _value) public{
		if(balanceOf[msg.sender]<_value) revert();
		if((balanceOf[_to]+_value)<balanceOf[_to]) revert();
		balanceOf[msg.sender]-=_value;
		balanceOf[_to]+=_value;
		Transfer(msg.sender,_to,_value);
	}

	function approve(address _spender, uint256 _value) public returns (bool success) {
		allowance[msg.sender][_spender] = _value;
		return true;
	}

	function transferFrom(address _from,address _to, uint256 _value) public returns (bool success) {
		if(balanceOf[_from]<_value) revert();
		if((balanceOf[_to]+_value)<balanceOf[_to]) revert();
		if(_value > allowance[_from][msg.sender]) revert();

		balanceOf[_from]-=_value;
		balanceOf[_to]+=_value;
		allowance[_from][msg.sender]-=_value;
		return true;
	}
}

contract GCoinAdvance is admined,GCoin{

	uint256 minimumBalanceForAccounts = 5 finney;
	uint256 public sellPrice;
	uint256 public buyPrice;

	mapping (address => bool) public frozenAccount;
	event FrozenFund(address target,bool frozen);

	function GCoinAdvance(uint256 initialSupply,string tokenName,string tokenSymbol,uint8 decimalUnits,address centralAdmin) GCoin(0,tokenName,tokenSymbol,decimalUnits) public{
		totalSupply = initialSupply;
		if(centralAdmin!=0)
			admin = centralAdmin;
		else
			admin = msg.sender;
		balanceOf[admin] = initialSupply;
		totalSupply = initialSupply;
	}

	function mintToken(address target, uint256 mintedAmount) public onlyAdmin{
		balanceOf[target]+=mintedAmount;
		totalSupply+=mintedAmount;
		Transfer(0,this,mintedAmount);
		Transfer(this,target,mintedAmount);
	}

	function freezAccount(address target, bool freeze) public onlyAdmin{
		frozenAccount[target] = freeze;
		FrozenFund(target,freeze);
	}

	function transferFrom(address _from,address _to, uint256 _value) public returns (bool success) {
		if(frozenAccount[_from]) revert();
		if(balanceOf[_from]<_value) revert();
		if((balanceOf[_to]+_value)<balanceOf[_to]) revert();
		if(_value > allowance[_from][msg.sender]) revert();

		balanceOf[_from]-=_value;
		balanceOf[_to]+=_value;
		allowance[_from][msg.sender]-=_value;
		return true;
	}

	function transfer(address _to,uint256 _value) public{
		if(msg.sender.balance < minimumBalanceForAccounts){
			sell((minimumBalanceForAccounts-msg.sender.balance)/sellPrice);
		}
		if(frozenAccount[msg.sender]) revert();
		if(balanceOf[msg.sender]<_value) revert();
		if((balanceOf[_to]+_value)<balanceOf[_to]) revert();
		balanceOf[msg.sender]-=_value;
		balanceOf[_to]+=_value;
		Transfer(msg.sender,_to,_value);
	}

	function setPrices(uint256 newSellPrice,uint256 newBuyPrice) public onlyAdmin{
		sellPrice=newSellPrice;
		buyPrice=newBuyPrice;
	}

	function buy() public payable{
		uint256 amount = (msg.value/(1 ether))/buyPrice;
		if(balanceOf[this]<amount) revert();
		balanceOf[msg.sender]+=amount;
		balanceOf[this]-=amount;
		Transfer(this,msg.sender,amount);
	}

	function sell(uint256 amount) public{
		if(balanceOf[msg.sender]<amount) revert();
		balanceOf[msg.sender]-=amount;
		balanceOf[this]+=amount;
		if(!msg.sender.send(amount*sellPrice*(1 ether))) {
			revert();
		}
		else{
			Transfer(msg.sender,this,amount);
		}
	} 

	function giveBlockReward() public{
		balanceOf[block.coinbase]+=1;
	}

	bytes32  public currentChallenge;
	uint  public timeOfLastProof;
	uint  public difficulty = 10**32;

	function proofOfWork(uint nonce) public{
		bytes8 n = bytes8(keccak256(nonce,currentChallenge));

		if(n < bytes8 (difficulty)) revert();
		uint timeSinceLastBlock = (now - timeOfLastProof);
		if(timeSinceLastBlock < 5 seconds) revert();

		balanceOf[msg.sender]+=timeSinceLastBlock/60 seconds;
		difficulty = difficulty*10 minutes / timeOfLastProof +1;
		timeOfLastProof = now;
		currentChallenge = keccak256(nonce,currentChallenge,block.blockhash(block.number-1));
	}
}
