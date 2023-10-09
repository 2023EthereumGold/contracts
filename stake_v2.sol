pragma solidity >=0.4.23 <0.6.0;

contract EthgStake {
	struct User {
		uint256 id;
		address payable referrer;
		uint256 balance;
		uint256 stakeTime;
		uint256 lastFetchTime;
		uint256 lockBalance;
		uint256 lastLockTime;
		uint256 refInterests;
		uint256 referCount;
		uint256 totalEarned;
		uint256 teamLevel;
		uint256 lastFetchTeamTime;
	}

	struct ZONE {
		address maxArea;
		uint256 maxAreaBuyed;
		uint256 totalAreaBuyed;
		uint256 totalAreaReward;
		uint256 currentAreaReward;
		mapping(address => uint256) areaBuyed;
	}

	uint256 public lastUserId = 2;
	address payable public owner;

	uint256 public constant decimals = 18;

	uint8   public maxUpper = 8;     // changed from 8 to 6

	uint256 public minStake = 100;  // temp-test
	uint256 public maxStake = 5000000;
	uint256 public oneDay = 86400;  // 3600 * 24
	uint256 public lockTime = 86400;
	uint256 public fixedInterest = 15;  // 0.15%

	uint256 public firstReferInterest = 225;  // 800/1000 -> 750/1000
	uint256 public secondReferInterest = 525;  // 20%

	uint256 public unStakeRatio = 980;         // 990 / 1000 
	uint256 public unStakeFee = 20;            // 5/1000

	mapping(uint256 => uint256) public TEAM_BUYED;
	mapping(uint256 => uint256) public TEAM_PERSONAL_BUYED;
	mapping(uint256 => uint256) public TEAM_REATIO;

	// uint256 public minStake = 1;
	// uint256 public maxStake = 20;
	// uint256 public oneDay = 600;
	// uint256 public lockTime = 600;
	// uint256 public fixedInterest = 30;  // 0.3%

	uint256 public totalStaking = 0;


	mapping(address => User) public users;
	mapping(address => ZONE) public zones;
	mapping(uint256 => address payable) public userIds;

	mapping(uint256 => uint256) public members; // teamlevel => count
	mapping(address => bool) public blackList; 

	// v4
	uint256 public rewardAll = 28080 * (10 ** decimals); // 178
	//uint256 public rewardAll = 100 * (10 ** decimals); // 1780000

	// ajust parameters
	uint256 public rewardRatioStake = 40;

	address public deployer;
	uint256 public startTime = 0;
	uint256 public totalBurned = 0;

	address payable public blackHole;

	event EventRegister(address indexed addr, address indexed refer);
	event EventFetchInterest(address indexed addr, uint256 amount);
	event EventFetchRefInterest(address indexed addr, uint256 amount);
	event EventFetchTeam(address indexed addr, uint256 amount);
	event EventFetchFee(address indexed addr, uint256 amount);
	event EventUnLock(address indexed addr, uint256 amount);
	event EventBurn(address indexed addr, uint256 amount);

	modifier onlyDeployer() {
        require(msg.sender == deployer, "Only Deployer");
        _;
    }

	constructor(address payable ownerAddress) public {
		deployer = msg.sender;

		TEAM_BUYED[1] = 50000 * (10 ** 18);
		TEAM_BUYED[2] = 100000 * (10 ** 18);
		TEAM_BUYED[3] = 200000 * (10 ** 18);
		TEAM_BUYED[4] = 500000 * (10 ** 18);
		TEAM_BUYED[5] = 1000000 * (10 ** 18);

		TEAM_PERSONAL_BUYED[1] = 5000 * (10 ** 18);
		TEAM_PERSONAL_BUYED[2] = 10000 * (10 ** 18);
		TEAM_PERSONAL_BUYED[3] = 20000 * (10 ** 18);
		TEAM_PERSONAL_BUYED[4] = 50000 * (10 ** 18);
		TEAM_PERSONAL_BUYED[5] = 100000 * (10 ** 18);

		// TEAM_BUYED[1] = 5 * (10 ** 18);
		// TEAM_BUYED[2] = 10 * (10 ** 18);
		// TEAM_BUYED[3] = 15 * (10 ** 18);
		// TEAM_BUYED[4] = 20 * (10 ** 18);
		// TEAM_BUYED[5] = 25 * (10 ** 18);

		// TEAM_PERSONAL_BUYED[1] = 1 * (10 ** 18);
		// TEAM_PERSONAL_BUYED[2] = 2 * (10 ** 18);
		// TEAM_PERSONAL_BUYED[3] = 3 * (10 ** 18);
		// TEAM_PERSONAL_BUYED[4] = 4 * (10 ** 18);
		// TEAM_PERSONAL_BUYED[5] = 5 * (10 ** 18);

		TEAM_REATIO[1] = 30; // 10% * 30%
		TEAM_REATIO[2] = 45; // 15% * 30%
		TEAM_REATIO[3] = 60; // 20% * 30%
		TEAM_REATIO[4] = 75; // 25% * 30%
		TEAM_REATIO[5] = 90; // 30% * 30%

		owner = ownerAddress;
		User memory user = User({
			id: 1,
			referrer: ownerAddress,
			balance: 0,
			stakeTime: 0,
			lastFetchTime: 0,
			lockBalance: 0,
			lastLockTime: 0,
			refInterests: 0,
			referCount: 0,
			totalEarned: 0,
			teamLevel: 0,
			lastFetchTeamTime: 0
		});

		users[ownerAddress] = user;
		userIds[1] = ownerAddress;

		zones[ownerAddress] = ZONE({
    		maxArea: address(0),
			maxAreaBuyed: 0,
			totalAreaBuyed: 0,
			totalAreaReward: 0,
			currentAreaReward: 0
    	});
	}

	function registration(address payable userAddress, uint256 userId) external {
		require(userIds[userId] != address(0), "refer not exists");
		require(userAddress == msg.sender, "is myself");
		require(users[userAddress].id == 0, "user exists");
		User memory user = User({
			id: lastUserId,
			referrer: userIds[userId],
			balance: 0,
			stakeTime: 0,
			lastFetchTime: 0,
			lockBalance: 0,
			lastLockTime: 0,
			refInterests: 0,
			referCount: 0,
			totalEarned: 0,
			teamLevel: 0,
			lastFetchTeamTime: 0
		});
		users[userAddress] = user;
		userIds[lastUserId] = userAddress;
		lastUserId++;

		users[userIds[userId]].referCount++;

		ZONE memory zone = ZONE({
			maxArea: address(0),
			maxAreaBuyed: 0,
			totalAreaBuyed: 0,
			totalAreaReward: 0,
			currentAreaReward: 0
		});
		zones[msg.sender] = zone;

		emit EventRegister(userAddress, userIds[userId]);
	}

	function stake() external payable {
		require(startTime > 0, "staking not opened");
		require(users[msg.sender].id != 0, "user not registered");
		require(msg.value + users[msg.sender].balance >= minStake * (10 ** decimals), "smaller than 10000");
		//require(msg.value + users[msg.sender].balance <= maxStake * (10 ** decimals), "bigger than 5000000");
		require(users[msg.sender].lockBalance == 0, "can't stake in locking");

		users[msg.sender].balance += msg.value;
		users[msg.sender].lastFetchTime = now;
		users[msg.sender].stakeTime = now;

		totalStaking += msg.value;
		// contribution to team
		doTeamBuy(msg.sender, msg.value);
	}

	function doTeamBuy(address user, uint256 buyed) internal {
    	address current = users[user].referrer;
    	address downer = user;
    	uint256 lastTeamLevel = 0;
    	for(uint256 i = 1; i <= maxUpper; i++) {
    		if(current == owner) {
    			break;
    		}

    		zones[current].areaBuyed[downer] += buyed;
    		zones[current].totalAreaBuyed += buyed;
    		if(zones[current].areaBuyed[downer] >= zones[current].maxAreaBuyed) {
    			zones[current].maxArea = downer;
    			zones[current].maxAreaBuyed = zones[current].areaBuyed[downer];
    		}

    		lastTeamLevel = users[current].teamLevel;
    		users[current].teamLevel = computeTeamLevel(current);

    		if(lastTeamLevel > 0 && members[lastTeamLevel] > 0) {
    			members[lastTeamLevel]--;
    		}
    		if(users[current].teamLevel > 0) {
    			members[users[current].teamLevel]++;
    		}

    		downer = current;
    		current = users[current].referrer;
    	}
    }

    function doTeamQuit(address user) internal {
    	address current = users[user].referrer;
    	address downer = user;
    	uint256 lastTeamLevel = 0;
    	for(uint256 i = 1; i <= maxUpper; i++) {
    		if(current == owner) {
    			break;
    		}

    		zones[current].areaBuyed[downer] = 
    			(zones[current].areaBuyed[downer] > users[user].balance) ? (zones[current].areaBuyed[downer] - users[user].balance) : 0;
    		zones[current].totalAreaBuyed =
    			(zones[current].totalAreaBuyed > users[user].balance) ? (zones[current].totalAreaBuyed - users[user].balance) : 0;

    		if(zones[current].maxArea == downer) {
    			zones[current].maxAreaBuyed = 
    				(zones[current].maxAreaBuyed > users[user].balance) ? (zones[current].maxAreaBuyed - users[user].balance) : 0;
    		}

    		lastTeamLevel = users[current].teamLevel;
    		users[current].teamLevel = computeTeamLevel(current);

    		if(lastTeamLevel > 0 && members[lastTeamLevel] > 0) {
    			members[lastTeamLevel]--;
    		}
    		if(users[current].teamLevel > 0) {
    			members[users[current].teamLevel]++;
    		}

    		downer = current;
    		current = users[current].referrer;
    	}
    }

	function unStake() external {
		require(startTime > 0, "staking not opened");
		require(users[msg.sender].id != 0, "user not registered");
		require(users[msg.sender].balance > 0, "balance should bigger than 0");

		// del contribution to team
		doTeamQuit(msg.sender);

		if(totalStaking > users[msg.sender].balance) {
			totalStaking -= users[msg.sender].balance;
		} else {
			totalStaking = 0;
		}

		//msg.sender.transfer(users[msg.sender].balance * 98 / 100);
		users[msg.sender].lockBalance = users[msg.sender].balance * unStakeRatio / 1000;
		users[msg.sender].lastLockTime = now;

		uint256 fee = users[msg.sender].balance * unStakeFee / 1000;
		users[msg.sender].balance = 0;

		blackHole.transfer(fee);
		emit EventBurn(blackHole, fee);
		//totalBurned += fee;
	}

	function unlock() external {
		require(startTime > 0, "staking not opened");
		require(users[msg.sender].lockBalance > 0, "lock balance must > 0");
		require(now - users[msg.sender].lastLockTime > lockTime, "lock in 12 hours");
		msg.sender.transfer(users[msg.sender].lockBalance);

		emit EventUnLock(msg.sender, users[msg.sender].lockBalance);

		users[msg.sender].lockBalance = 0;
		users[msg.sender].lastLockTime = 0;
	}


	function computeFirstInterest(address up, address down, uint256 reward) public view returns(uint256) {
		if(users[up].balance >= users[down].balance) {
			return reward * firstReferInterest / 1000;
		} else {
			return ((reward * users[up].balance * firstReferInterest) / users[down].balance) / 1000;
		}
	}

	function computeSecondInterest(address up, address down, uint256 reward) public view returns(uint256) {
		if(users[up].balance >= users[down].balance) {
			return reward * secondReferInterest / 1000;
		} else {
			return ((reward * users[up].balance * secondReferInterest) / users[down].balance) / 1000;
		}
	}

	function fetchInterest() external {
		require(startTime > 0, "staking not opened");
		require(users[msg.sender].id != 0, "user not registered");
		require(users[msg.sender].balance > 0, "balance should bigger than 0");
		require(now > users[msg.sender].lastFetchTime, "time condition");
		uint256 _days = (now - startTime) / oneDay;
		require(_days > 0, "the first day can't be fetch");
		require(startTime + _days * oneDay > users[msg.sender].lastFetchTime, "can only fetch once per day");
		require(!blackList[msg.sender], "abandon");

		uint256 fetchDays = (startTime + _days * oneDay - users[msg.sender].lastFetchTime) / oneDay;

		uint256 myInterest = computeInterests(msg.sender);
		msg.sender.transfer(myInterest);

		emit EventFetchInterest(msg.sender, myInterest);

		//users[msg.sender].totalInterests += myInterest;
		users[msg.sender].totalEarned += myInterest;
		users[msg.sender].lastFetchTime = now;

		// contribution to referrer
		if(users[msg.sender].referrer != owner) {
			uint256 fr = computeFirstInterest(users[msg.sender].referrer, msg.sender, myInterest);
			if(fr > 0) {
				users[users[msg.sender].referrer].refInterests += fr;
			}

			if(users[users[msg.sender].referrer].referrer != owner) {
				uint256 sr = computeSecondInterest(users[users[msg.sender].referrer].referrer, msg.sender, myInterest);
				if(sr > 0) {
					users[users[users[msg.sender].referrer].referrer].refInterests += sr;
				}
			}
		}

		// contribution to burned
		if(fetchDays > 1) {
			totalBurned += (myInterest * (fetchDays - 1));
		}
	}

	function fetchRef() external {
		require(startTime > 0, "staking not opened");
		require(users[msg.sender].id != 0, "user not registered");
		require(users[msg.sender].refInterests > 0, "refInterests should bigger than 0");
		require(!blackList[msg.sender], "abandon");

		msg.sender.transfer(users[msg.sender].refInterests);

		emit EventFetchRefInterest(msg.sender, users[msg.sender].refInterests);

		users[msg.sender].totalEarned += users[msg.sender].refInterests;
		users[msg.sender].refInterests = 0;
	}

	function fetchTeam() external {
		require(startTime > 0, "staking not opened");
		require(users[msg.sender].id != 0, "user not registered");
		require(now > users[msg.sender].lastFetchTeamTime, "time condition");
		uint256 _days = (now - startTime) / oneDay;
		require(_days > 0, "the first day can't be fetch");
		require(startTime + _days * oneDay > users[msg.sender].lastFetchTeamTime, "can only fetch once per day");
		require(!blackList[msg.sender], "abandon");

		uint256 result = computeTeam(msg.sender);
		require(result > 0, "must greater than 0");

		msg.sender.transfer(result);

		emit EventFetchTeam(msg.sender, result);

		users[msg.sender].totalEarned += result;
		//zones[msg.sender].currentAreaReward = 0;
		users[msg.sender].lastFetchTeamTime = now;
	}

	// 
	function computeInterests(address addr) public view returns(uint256) {
		//return users[addr].balance * fixedInterest / 10000;     // fixed 0.3%
		if(totalStaking > 0) {
			return (((rewardAll * rewardRatioStake) / 100) * users[addr].balance) / totalStaking;
		} else {
			return 0;
		}
	}

	function computeTeamLevel(address user) public view returns(uint256) {
		if(zones[user].totalAreaBuyed >= zones[user].maxAreaBuyed + TEAM_BUYED[5] && users[user].balance >= TEAM_PERSONAL_BUYED[5]) {
			return 5;
		} else if(zones[user].totalAreaBuyed >= zones[user].maxAreaBuyed + TEAM_BUYED[4] && users[user].balance >= TEAM_PERSONAL_BUYED[4]) {
			return 4;
		} else if(zones[user].totalAreaBuyed >= zones[user].maxAreaBuyed + TEAM_BUYED[3] && users[user].balance >= TEAM_PERSONAL_BUYED[3]) {
			return 3;
		} else if(zones[user].totalAreaBuyed >= zones[user].maxAreaBuyed + TEAM_BUYED[2] && users[user].balance >= TEAM_PERSONAL_BUYED[2]) {
			return 2;
		} else if(zones[user].totalAreaBuyed >= zones[user].maxAreaBuyed + TEAM_BUYED[1] && users[user].balance >= TEAM_PERSONAL_BUYED[1]) {
			return 1;
		} else {
			return 0;
		}
	}

	function computeTeam(address user) public view returns(uint256) {
		uint256 level = computeTeamLevel(user);
		if(level > 0 && members[level] > 0) {
			//return zones[user].currentAreaReward * TEAM_REATIO[level] / 1000;
			return ((rewardAll * TEAM_REATIO[level]) / 1000) / members[level];
		} else {
			return 0;
		}
	}

	// for web
	function stakingInfo(address addr) public view returns(uint256, uint256, uint256, uint256, uint256) {
		uint256 myInterest = 0;
		if(startTime > 0 && users[addr].balance > 0) {
			uint256 _days = (now - startTime) / oneDay;
			if(_days > 0 && startTime + _days * oneDay > users[addr].lastFetchTime) {
				myInterest = computeInterests(addr);
			}
		}
		return (totalStaking, totalBurned, myInterest, computeTeamLevel(addr), computeTeam(addr));
	}

	function myId(address addr) public view returns(uint256, uint256) {
		return (users[addr].id, users[addr].referCount);
	}

	function setStartTime(uint256 time) public onlyDeployer {
		startTime = time;
	}

	function setFixedInterests(uint256 v) public onlyDeployer {
		fixedInterest = v;
	}

	function setFirstReferInterests(uint256 v) public onlyDeployer {
		firstReferInterest = v;
	}

	function setSecondReferInterests(uint256 v) public onlyDeployer {
		secondReferInterest = v;
	}

	function setUnstakeFee(uint256 v) public onlyDeployer {
		unStakeFee = v;
	}

	function setUnstakeRatio(uint256 v) public onlyDeployer {
		unStakeRatio = v;
	}

	function setMaxUpper(uint8 v) public onlyDeployer {
		maxUpper = v;
	}

	function setRewardAll(uint256 v) public onlyDeployer {
		rewardAll = v;
	}

 	function setRewardRatioStake(uint256 v) public onlyDeployer {
 		rewardRatioStake = v;
 	}

 	function setMinStake(uint256 v) public onlyDeployer {
 		minStake = v;
 	}

 	function setMaxStake(uint256 v) public onlyDeployer {
 		maxStake = v;
 	}

 	function setOneDay(uint256 _days) public onlyDeployer {
 		oneDay = _days;
 	}

 	function setTeamBuyed(uint256 _star, uint256 _buy) public onlyDeployer {
 		TEAM_BUYED[_star] = _buy;
 	}

 	function setTeamRatio(uint256 _star, uint256 _ratio) public onlyDeployer {
 		TEAM_REATIO[_star] = _ratio;
 	}

 	function setTeamPersonalBuyed(uint256 _star, uint256 _buy) public onlyDeployer {
 		TEAM_PERSONAL_BUYED[_star] = _buy;
 	}

 	function setBlackHole(address payable _black) public onlyDeployer {
 		blackHole = _black;
 	}

 	function setLockTime(uint256 _lt) public onlyDeployer {
 		lockTime = _lt;
 	}

 	function setBlackList(address _a, bool _b) public onlyDeployer {
 		blackList[_a] = _b;
 	}

	function donate() external payable {
		//
	}

	/// import
	function importUser(uint256 id, address payable addr, address payable refer, uint256 refercount) public onlyDeployer{
		User memory user = User({
			id: id,
			referrer: refer,
			balance: 0,
			stakeTime: 0,
			lastFetchTime: 0,
			lockBalance: 0,
			lastLockTime: 0,
			refInterests: 0,
			referCount: refercount,
			totalEarned: 0,
			teamLevel: 0,
			lastFetchTeamTime: 0
		});
		users[addr] = user;
		userIds[id] = addr;
		if(lastUserId < id + 1) {
			lastUserId = id + 1;
		}
	}
}
