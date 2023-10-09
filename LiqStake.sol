pragma solidity >=0.8.0 <0.9.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
}

interface IToken {
    function transfer(address _to, uint256 _value) external returns(bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns(bool);
    function balanceOf(address _user) external view returns(uint256);
}

contract LiqStake {
	using SafeMath for uint256;

	struct User {
		uint256 id;
		address payable referrer;
		uint256 balance;
		uint256 stakeTime;
		uint256 lockBalance;
		uint256 lastLockTime;
		uint256 referCount;
		uint256 totalETHG;
		uint256 totalUSDT;
		uint256 lastFetchTime;
		bool teamFlag;
		uint256 lastTeamTime;
		uint256 referStaking;
	}

	address payable public blackHole;
	address public deployer;
	address public receiver;
	uint256 public START_TIME;
	uint256 public LAST_UPDATE_TIME;

	uint256 public memberCount = 0;
	uint256 public totalStaking = 0;

	uint256 public rewardETHG = 0;
	//uint256 public rewardUSDT = 0;
	uint256 public rewardTeamCount = 0;
	uint256 public rewardTotalStaking = 0;

	uint256 public rewardRatio = 500; //50%
	uint256 public rewardTeamRatio = 500; // 50%
	uint256 public memberBalanceCond = 100000 * (10 ** 18);
	uint256 public memberCountCond = 5;
	uint256 public memberStakingCond = 1000000 * (10 ** 18);
	uint256 public unStakeFee = 20;            // 20/1000

	IToken public usdt;

	uint256 public lastUserId = 2;
	uint256 public minStake = 100;  // temp-test
	uint256 public maxStake = 5000000;
	uint256 public oneDay = 86400;  // 3600 * 24
	uint256 public lockTime = 86400;

	mapping(address => User) public users;
	mapping(uint256 => address payable) public userIds;

	event EventRegister(address indexed addr, address indexed refer);
	event EventUnLock(address indexed addr, uint256 amount);
	event EventBurn(address indexed addr, uint256 amount);
	event EventFetchNormal(address indexed addr, uint256 amount);
	event EventFetchTeam(address indexed addr, uint256 amount);

	modifier onlyDeployer() {
        require(msg.sender == deployer, "Only Deployer");
        _;
    }

    constructor(address _receiver, address payable _god) public {
    	deployer = msg.sender;
    	//usdt = IToken(usdtAddress);
    	receiver = _receiver;

    	User memory user = User({
			id: 1,
			referrer: _god,
			balance: 0,
			stakeTime: 0,
			lockBalance: 0,
			lastLockTime: 0,
			referCount: 0,
			totalETHG: 0,
			totalUSDT: 0,
			lastFetchTime: 0,
			teamFlag: false,
			lastTeamTime: 0,
			referStaking: 0
		});

		users[_god] = user;
		userIds[1] = _god;
    }

    receive() external payable {

	}

	fallback() external payable {

	}

    function registration(address payable userAddress, uint256 userId) internal {
		require(userIds[userId] != address(0), "refer not exists");
		require(userAddress == msg.sender, "is myself");
		require(users[userAddress].id == 0, "user exists");
		User memory user = User({
			id: lastUserId,
			referrer: userIds[userId],
			balance: 0,
			stakeTime: 0,
			lockBalance: 0,
			lastLockTime: 0,
			referCount: 0,
			totalETHG: 0,
			totalUSDT: 0,
			lastFetchTime: 0,
			teamFlag: false,
			lastTeamTime: 0,
			referStaking: 0
		});
		users[userAddress] = user;
		userIds[lastUserId] = userAddress;
		lastUserId++;

		users[userIds[userId]].referCount++;

		emit EventRegister(userAddress, userIds[userId]);
	}

	function stake(uint256 referId) external payable {
		require(START_TIME > 0, "staking not opened");

		//updateParam();

		if(users[msg.sender].id == 0) {
			registration(payable(msg.sender), referId);
		}
		require(msg.value + users[msg.sender].balance >= minStake * (10 ** 18), "smaller than 10000");
		//require(msg.value + users[msg.sender].balance <= maxStake * (10 ** decimals), "bigger than 5000000");
		require(users[msg.sender].lockBalance == 0, "can't stake in locking");

		// contribution to team
		doTeamBuy(msg.sender, msg.value);

		users[msg.sender].balance += msg.value;
		users[msg.sender].lastFetchTime = block.timestamp;
		users[msg.sender].stakeTime = block.timestamp;

		totalStaking += msg.value;

		if(!users[msg.sender].teamFlag && users[msg.sender].balance >= memberBalanceCond && users[msg.sender].referStaking >= memberStakingCond) {
    		users[msg.sender].teamFlag = true;
    		users[msg.sender].lastTeamTime = block.timestamp;
    		memberCount++;
    	}
	}

	function doTeamBuy(address user, uint256 oldBal) internal {
    	address current = users[user].referrer;

    	users[current].referStaking += oldBal;

    	if(!users[current].teamFlag && users[current].balance >= memberBalanceCond && users[current].referStaking >= memberStakingCond) {
    		users[current].teamFlag = true;
    		users[current].lastTeamTime = block.timestamp;
    		memberCount++;
    	}
    }

    function doTeamQuit(address user) internal {
    	address current = users[user].referrer;
    	if(users[current].referStaking >= users[user].balance) {
    		users[current].referStaking -= users[user].balance;
		} else {
			users[current].referStaking = 0;
		}
		if(users[current].teamFlag && (users[current].balance < memberBalanceCond || users[current].referStaking < memberStakingCond)) {
			users[current].teamFlag = false;
			if(memberCount > 0) {
				memberCount--;
			}
		}
    }

	function unStake() external {
		require(START_TIME > 0, "staking not opened");
		require(users[msg.sender].id != 0, "user not registered");
		require(users[msg.sender].balance > 0, "balance should bigger than 0");

		// del contribution to team
		doTeamQuit(msg.sender);

		users[msg.sender].lockBalance = users[msg.sender].balance * (1000 - unStakeFee) / 1000;
		users[msg.sender].lastLockTime = block.timestamp;

		uint256 fee = users[msg.sender].balance * unStakeFee / 1000;
		users[msg.sender].balance = 0;

		blackHole.transfer(fee);

		if(users[msg.sender].teamFlag && (users[msg.sender].balance < memberBalanceCond || users[msg.sender].referStaking < memberStakingCond)) {
			users[msg.sender].teamFlag = false;
			if(memberCount > 0) {
				memberCount--;
			}
		}

		emit EventBurn(blackHole, fee);
		//totalBurned += fee;
	}

	function unlock() external {
		require(START_TIME > 0, "staking not opened");
		require(users[msg.sender].lockBalance > 0, "lock balance must > 0");
		require(block.timestamp - users[msg.sender].lastLockTime > lockTime, "lock in 12 hours");

		//updateParam();

		payable(msg.sender).transfer(users[msg.sender].lockBalance);

		emit EventUnLock(msg.sender, users[msg.sender].lockBalance);

		if(totalStaking > users[msg.sender].lockBalance) {
			totalStaking -= users[msg.sender].lockBalance;
		} else {
			totalStaking = 0;
		}

		users[msg.sender].lockBalance = 0;
		users[msg.sender].lastLockTime = 0;
	}


	function getInfo() external view returns(uint256, uint256, uint256, uint256, uint256) {
		return (memberCount, totalStaking, rewardETHG, rewardTotalStaking, rewardTeamCount);
	}

	function getFetchInfo(address _user) internal view returns(uint256, uint256) {
		uint256 _days = (block.timestamp - START_TIME) / oneDay;
		if(START_TIME + _days * oneDay < users[_user].lastFetchTime) {
			return (0, 0);
		}

		uint256 _rewardETHG = rewardETHG;
		uint256 _rewardTotalStaking = rewardTotalStaking;
		uint256 _rewardTeamCount = rewardTeamCount;

		uint256 _er = 0;
		uint256 _etr = 0;

    	if(START_TIME + _days * oneDay >= LAST_UPDATE_TIME) {
    		_rewardETHG = ((address(this).balance >= totalStaking) ? address(this).balance - totalStaking : 0);
    		_rewardTotalStaking = totalStaking;
    		_rewardTeamCount = memberCount;
    	}

		if(START_TIME + _days * oneDay < users[_user].stakeTime || _rewardTotalStaking == 0) {
			_er = 0;
		} else {
			_er = (_rewardETHG * rewardRatio * users[_user].balance / 1000) / _rewardTotalStaking;
		}

		if(START_TIME + _days * oneDay < users[_user].lastTeamTime || users[_user].teamFlag == false || _rewardTeamCount == 0) {
			_etr = 0;
		} else {
			_etr = (_rewardETHG * rewardTeamRatio / 1000) / _rewardTeamCount;
		}

		return (_er, _etr);
	}

	function getFetchInfoEx(address _user) external view returns(uint256, uint256) {
		uint256 _days = (block.timestamp - START_TIME) / oneDay;
		if(START_TIME + _days * oneDay < users[_user].lastFetchTime) {
			return (0, 0);
		}

		uint256 _rewardETHG = rewardETHG;
		uint256 _rewardTotalStaking = rewardTotalStaking;
		uint256 _rewardTeamCount = rewardTeamCount;

		uint256 _er = 0;
		uint256 _etr = 0;

		if(START_TIME + _days * oneDay >= LAST_UPDATE_TIME) {
    		_rewardETHG = ((address(this).balance >= totalStaking) ? address(this).balance - totalStaking : 0);
    		_rewardTotalStaking = totalStaking;
    		_rewardTeamCount = memberCount;
    	}

		if(START_TIME + _days * oneDay < users[_user].stakeTime || _rewardTotalStaking == 0) {
			_er = 0;
		} else {
			_er = (_rewardETHG * rewardRatio * users[_user].balance / 1000) / _rewardTotalStaking;
		}

		if(START_TIME + _days * oneDay < users[_user].lastTeamTime || users[_user].teamFlag == false || _rewardTeamCount == 0) {
			_etr = 0;
		} else {
			_etr = (_rewardETHG * rewardTeamRatio / 1000) / _rewardTeamCount;
		}

		return (_er,  _etr);
	}


	function updateParam() internal {
    	uint256 _days = (block.timestamp - START_TIME) / oneDay;
    	if(START_TIME + _days * oneDay >= LAST_UPDATE_TIME) {
    		//rewardUSDT = usdt.balanceOf(address(this));
    		rewardETHG = ((address(this).balance >= totalStaking) ? address(this).balance - totalStaking : 0);
    		rewardTotalStaking = totalStaking;
    		rewardTeamCount = memberCount;

    		LAST_UPDATE_TIME = block.timestamp;
    	}
    }

	function fetch() external {
		updateParam();
		(uint256 er, uint256 etr) = getFetchInfo(msg.sender);
		if(er > 0) {
			users[msg.sender].totalETHG += er;
			payable(msg.sender).transfer(er);
			emit EventFetchNormal(msg.sender, er);
		}

		if(etr > 0) {
			users[msg.sender].totalETHG += etr;
			payable(msg.sender).transfer(etr);
			emit EventFetchTeam(msg.sender, etr);
		}

		users[msg.sender].lastFetchTime = block.timestamp;

	}

    /////////// set
    function setDeployer(address _deployer) external onlyDeployer {
    	require(_deployer != address(0), "deployer can't be zero");
    	deployer = _deployer;
    }

    function setReceiver(address _receiver) external onlyDeployer {
    	require(_receiver != address(0), "receiver can't be zero");
    	receiver = _receiver;
    }

    function setStartTime(uint256 time) public onlyDeployer {
		START_TIME = time;
	}

	function setOneDay(uint256 _day) external onlyDeployer {
    	oneDay = _day;
    }

    function setLockTime(uint256 _time) external onlyDeployer {
    	lockTime = _time;
    }

    function setMinStake(uint256 v) public onlyDeployer {
 		minStake = v;
 	}

 	function setMaxStake(uint256 v) public onlyDeployer {
 		maxStake = v;
 	}

 	function setRewardRatio(uint256 r) public onlyDeployer {
 		rewardRatio = r;
 	}

 	function setRewardTeamRatio(uint256 r) public onlyDeployer {
 		rewardTeamRatio = r;
 	}

 	function setMemberBalanceCond(uint256 _m) public onlyDeployer {
 		memberBalanceCond = _m;
 	}

 	function setMemberCountCond(uint256 _m) public onlyDeployer {
 		memberCountCond = _m;
 	}

 	function setMemberStakingCond(uint256 _m) public onlyDeployer {
 		memberStakingCond = _m;
 	}

 	function setUnstakeFee(uint256 v) public onlyDeployer {
		unStakeFee = v;
	}

	function setBlackHole(address payable _black) public onlyDeployer {
 		blackHole = _black;
 	}
}
