pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// import "hardhat/console.sol";

// Use prefix "./" normally and "https://github.com/ogDAO/Governance/blob/master/contracts/" in Remix
import "./OGTokenInterface.sol";
import "./OGDTokenInterface.sol";
import "./SafeMath.sol";

/// @notice Optino Governance config
contract OptinoGovConfig {
    using SafeMath for uint;

    uint constant SECONDS_PER_YEAR = 10000; // Testing 24 * 60 * 60 * 365;

    OGTokenInterface public ogToken;
    OGDTokenInterface public ogdToken;
    uint public maxDuration = 10000 seconds; // Testing 365 days;
    uint public rewardsPerSecond = 150_000_000_000_000_000; // 0.15
    uint public collectRewardForFee = 5 * 10**16; // 5%, 18 decimals
    uint public collectRewardForDelay = 1 seconds; // Testing 7 days
    uint public proposalCost = 100_000_000_000_000_000_000; // 100 tokens assuming 18 decimals
    uint public proposalThreshold = 1 * 10**15; // 0.1%, 18 decimals
    uint public quorum = 2 * 10 ** 17; // 20%, 18 decimals
    uint public quorumDecayPerSecond = 4 * 10**17 / uint(60 * 60 * 24 * 365); // 40% per year, i.e., 0 in 6 months
    uint public votingDuration = 10 seconds; // 3 days;
    uint public executeDelay = 10 seconds; // 2 days;
    uint public rewardPool = 1_000_000 * 10**18;
    uint public totalVotes;

    event ConfigUpdated(string key, uint value);

    modifier onlySelf {
        require(msg.sender == address(this), "Not self");
        _;
    }

    constructor(OGTokenInterface _ogToken, OGDTokenInterface _ogdToken) {
        ogToken = _ogToken;
        ogdToken = _ogdToken;
    }

    function equalString(string memory s1, string memory s2) internal pure returns(bool) {
        return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }
    function setConfig(string memory key, uint value) external onlySelf {
        if (equalString(key, "maxDuration")) {
            maxDuration = value;
        } else if (equalString(key, "collectRewardForFee")) {
            collectRewardForFee = value;
        } else if (equalString(key, "collectRewardForDelay")) {
            collectRewardForDelay = value;
        } else if (equalString(key, "rewardsPerSecond")) {
            rewardsPerSecond = value;
        } else if (equalString(key, "proposalCost")) {
            proposalCost = value;
        } else if (equalString(key, "proposalThreshold")) {
            proposalThreshold = value;
        } else if (equalString(key, "quorum")) {
            quorum = value;
        } else if (equalString(key, "quorumDecayPerSecond")) {
            quorumDecayPerSecond = value;
        } else if (equalString(key, "votingDuration")) {
            votingDuration = value;
        } else if (equalString(key, "executeDelay")) {
            executeDelay = value;
        } else {
            revert("Invalid key");
        }
        emit ConfigUpdated(key, value);
    }
}

/// @notice Optino Governance. (c) The Optino Project 2020
// SPDX-License-Identifier: GPLv2
contract OptinoGov is ERC20, OptinoGovConfig {
    using SafeMath for uint;

    struct Account {
        uint64 duration;
        uint64 end;
        uint64 lastDelegated;
        uint64 lastVoted;
        uint balance;
        uint votes;
        uint delegatedVotes;
        address delegatee;
    }
    struct Proposal {
        uint start;
        address proposer;
        string description;
        address[] targets;
        uint[] values;
        string[] signatures;
        bytes[] data;
        uint forVotes;
        uint againstVotes;
        mapping(address => bool) voted;
        bool executed;
    }

    string _symbol = "OG";
    string _name = "Optino Governance";
    uint _totalSupply;
    mapping(address => Account) public accounts;
    mapping(address => mapping(address => uint)) allowed;

    uint public proposalCount;
    mapping(uint => Proposal) public proposals;

    event DelegateUpdated(address indexed oldDelegatee, address indexed delegatee, uint votes);
    event Committed(address indexed user, uint tokens, uint balance, uint duration, uint end, address delegatee, uint votes, uint rewardPool, uint totalVotes);
    event Collected(address indexed user, uint elapsed, uint reward, uint callerReward, uint rewardPool, uint end, uint duration);
    event Uncommitted(address indexed user, uint tokens, uint balance, uint duration, uint end, uint votes, uint rewardPool, uint totalVotes);
    event Proposed(address indexed proposer, uint oip, string description, address[] targets, uint[] value, bytes[] data, uint start);
    event Voted(address indexed user, uint oip, bool voteFor, uint forVotes, uint againstVotes);
    event Executed(address indexed user, uint oip);

    constructor(OGTokenInterface ogToken, OGDTokenInterface ogdToken) OptinoGovConfig(ogToken, ogdToken) {
    }

    function symbol() override external view returns (string memory) {
        return _symbol;
    }
    function name() override external view returns (string memory) {
        return _name;
    }
    function decimals() override external pure returns (uint8) {
        return 18;
    }
    function totalSupply() override external view returns (uint) {
        return _totalSupply.sub(accounts[address(0)].balance);
    }
    function balanceOf(address tokenOwner) override external view returns (uint balance) {
        return accounts[tokenOwner].balance;
    }
    function transfer(address to, uint tokens) override external returns (bool success) {
        require(tokens == 0, "Not implemented");
        accounts[msg.sender].balance = accounts[msg.sender].balance.sub(tokens);
        accounts[to].balance = accounts[to].balance.add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }
    function approve(address spender, uint tokens) override external returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }
    function transferFrom(address from, address to, uint tokens) override external returns (bool success) {
        require(tokens == 0, "Not implemented");
        accounts[from].balance = accounts[from].balance.sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        accounts[to].balance = accounts[to].balance.add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }
    function allowance(address tokenOwner, address spender) override external view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    function delegate(address delegatee) public {
        Account storage user = accounts[msg.sender];
        require(uint(user.lastVoted) + votingDuration < block.timestamp, "Cannot delegate after recent vote");
        address oldDelegatee = user.delegatee;
        if (user.delegatee != address(0)) {
            accounts[user.delegatee].delegatedVotes = accounts[user.delegatee].delegatedVotes.sub(user.votes);
        }
        user.delegatee = delegatee;
        user.lastDelegated = uint64(block.timestamp);
        if (user.delegatee != address(0)) {
            accounts[user.delegatee].delegatedVotes = accounts[user.delegatee].delegatedVotes.add(user.votes);
        }
        emit DelegateUpdated(oldDelegatee, delegatee, user.votes);
    }

    // Commit OGTokens for specified duration. Cannot shorten duration if there is an existing unexpired commitment
    function commit(uint tokens, uint duration) public {
        require(duration <= maxDuration, "duration too long");
        Account storage user = accounts[msg.sender];
        uint reward = 0;
        uint oldUserVotes = user.votes;
        if (user.balance > 0) {
            require(block.timestamp + duration >= user.end, "Cannot shorten duration");
            uint elapsed = block.timestamp.sub(uint(user.end).sub(uint(user.duration)));
            reward = elapsed.mul(rewardsPerSecond).mul(user.votes).div(totalVotes);
            if (reward > rewardPool) {
                reward = rewardPool;
            }
            if (reward > 0) {
                rewardPool = rewardPool.sub(reward);
                user.balance = user.balance.add(reward);
            }
            emit Collected(msg.sender, elapsed, reward, 0, rewardPool, user.end, user.duration);
        }
        require(ogToken.transferFrom(msg.sender, address(this), tokens), "OG transferFrom failed");
        user.balance = user.balance.add(tokens);
        user.duration = uint64(duration);
        user.end = uint64(block.timestamp.add(duration));
        user.votes = user.balance.mul(duration).div(SECONDS_PER_YEAR);
        totalVotes = totalVotes.sub(oldUserVotes).add(user.votes);
        if (user.delegatee != address(0)) {
            accounts[user.delegatee].delegatedVotes = accounts[user.delegatee].delegatedVotes.sub(oldUserVotes).add(user.votes);
        }
        if (reward > 0) {
            require(ogToken.mint(address(this), reward), "reward OG mint failed");
        }
        require(ogdToken.mint(msg.sender, tokens.add(reward)), "commitment + reward OGD mint failed");
        emit Committed(msg.sender, tokens, user.balance, user.duration, user.end, user.delegatee, user.votes, rewardPool, totalVotes);
    }

    function collectRewardFor(address tokenOwner) public {
        _collectReward(tokenOwner, false, 0);
    }
    function collectReward(bool commitRewards, uint duration) public {
        _collectReward(msg.sender, commitRewards, duration);
    }
    function _collectReward(address tokenOwner, bool commitRewards, uint duration) internal {
        Account storage user = accounts[tokenOwner];
        require(user.balance > 0);

        // Pay rewards for period = now - beginning = now - (end - duration)
        uint elapsed = block.timestamp.sub(uint(user.end).sub(uint(user.duration)));
        uint reward = elapsed.mul(rewardsPerSecond).mul(user.votes).div(totalVotes);
        uint callerReward = 0;
        if (reward > rewardPool) {
            reward = rewardPool;
        }
        if (reward > 0) {
            rewardPool = rewardPool.sub(reward);
            if (msg.sender != tokenOwner) {
                require(user.end + collectRewardForDelay < block.timestamp, "Account with delay not ended");
                callerReward = reward.mul(collectRewardForFee).div(10 ** 18);
                reward = reward.sub(callerReward);
            }
            uint oldUserVotes = user.votes;
            if (commitRewards) {
                user.balance = user.balance.add(reward);
                if (user.end < block.timestamp) {
                    user.end = uint64(block.timestamp);
                }
                if (duration > 0) {
                    require(duration <= maxDuration, "duration too long");
                    user.duration = uint64(duration);
                    user.end = uint64(block.timestamp.add(duration));
                } else {
                    user.duration = uint64(uint(user.end).sub(block.timestamp));
                }
                user.votes = user.balance.mul(uint(user.duration)).div(SECONDS_PER_YEAR);
                require(ogToken.mint(address(this), reward), "OG mint failed");
                require(ogdToken.mint(msg.sender, reward), "OGD mint failed");
            } else {
                user.duration = uint(user.end) <= block.timestamp ? 0 : uint64(uint(user.end).sub(block.timestamp));
                user.votes = user.balance.mul(uint(user.duration)).div(SECONDS_PER_YEAR);
                require(ogToken.mint(tokenOwner, reward), "OG mint failed");
            }
            totalVotes = totalVotes.sub(oldUserVotes).add(user.votes);
            if (user.delegatee != address(0)) {
                accounts[user.delegatee].delegatedVotes = accounts[user.delegatee].delegatedVotes.sub(oldUserVotes).add(user.votes);
            }
            if (callerReward > 0) {
                require(ogToken.mint(msg.sender, callerReward), "callerReward OG mint failed");
            }
        }
        emit Collected(msg.sender, elapsed, reward, callerReward, rewardPool, user.end, user.duration);
    }

    function uncommit(uint tokens) public {
        Account storage user = accounts[msg.sender];
        require(tokens <= user.balance, "Insufficient tokens");
        require(block.timestamp > user.end, "Account not ended");
        uint elapsed = block.timestamp.sub(uint(user.end).sub(uint(user.duration)));
        uint reward = elapsed.mul(rewardsPerSecond).mul(user.votes).div(totalVotes);
        if (reward > rewardPool) {
            reward = rewardPool;
        }
        if (reward > 0) {
            rewardPool = rewardPool.sub(reward);
        }
        totalVotes = totalVotes.sub(user.votes);
        if (user.delegatee != address(0)) {
            accounts[user.delegatee].delegatedVotes = accounts[user.delegatee].delegatedVotes.sub(user.votes);
        }
        user.balance = user.balance.sub(tokens);
        if (user.balance == 0) {
            user.duration = 0;
            user.end = 0;
            user.votes = 0;
        } else {
            // NOTE Rolling over remaining balance for previous duration
            user.end = uint64(block.timestamp.add(uint(user.duration)));
            user.votes = user.balance.mul(uint(user.duration)).div(SECONDS_PER_YEAR);
            totalVotes = totalVotes.add(user.votes);
            if (user.delegatee != address(0)) {
                accounts[user.delegatee].delegatedVotes = accounts[user.delegatee].delegatedVotes.add(user.votes);
            }
        }
        require(ogdToken.withdrawDividendsFor(msg.sender, msg.sender), "OGD withdrawDividendsFor failed");
        require(ogdToken.transferFrom(msg.sender, address(0), tokens), "OGD transfer failed");
        require(ogToken.transfer(msg.sender, tokens), "OG transfer failed");
        require(ogToken.mint(msg.sender, reward), "OG mint failed");
        emit Uncommitted(msg.sender, tokens, user.balance, user.duration, user.end, user.votes, rewardPool, totalVotes);
    }

    function propose(string memory description, address[] memory targets, uint[] memory values, bytes[] memory data) public returns(uint) {
        // require(accounts[msg.sender].votes >= totalVotes.mul(proposalThreshold).div(10 ** 18), "OptinoGov: Not enough votes to propose");

        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.start = block.timestamp;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.targets = targets;
        proposal.values = values;
        proposal.data = data;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        proposal.executed = false;

        // Proposal memory proposal = Proposal({
        //     start: block.timestamp,
        //     proposer: msg.sender,
        //     description: description,
        //     targets: [target],
        //     values: [value],
        //     data: [data],
        //     forVotes: 0,
        //     againstVotes: 0,
        //     executed: false
        // });

        // require(token.burnFrom(msg.sender, proposalCost), "OptinoGov: transferFrom failed");

        emit Proposed(msg.sender, proposalCount, description, proposal.targets, proposal.values, proposal.data, block.timestamp);
        return proposalCount;
    }

    // TODO
    function vote(uint oip, bool voteFor) public {
        uint start = proposals[oip].start;
        require(start != 0 && block.timestamp < start.add(votingDuration), "Voting closed");
        require(accounts[msg.sender].lastDelegated + votingDuration < block.timestamp, "Cannot vote after recent delegation");
        require(!proposals[oip].voted[msg.sender], "Already voted");
        if (voteFor) {
            proposals[oip].forVotes = proposals[oip].forVotes.add(accounts[msg.sender].votes);
        }
        else {
            proposals[oip].againstVotes = proposals[oip].forVotes.add(accounts[msg.sender].votes);
        }
        proposals[oip].voted[msg.sender] = true;

        accounts[msg.sender].lastVoted = uint64(block.timestamp);
        emit Voted(msg.sender, oip, voteFor, proposals[oip].forVotes, proposals[oip].againstVotes);
    }

    function voteWithSignatures(bytes32[] calldata signatures) external {
        // TODO
    }

    function execute(uint oip) public {
        Proposal storage proposal = proposals[oip];
        // require(proposal.start != 0 && block.timestamp >= proposal.start.add(votingDuration).add(executeDelay));

        // if (quorum > currentTime.sub(proposalTime).mul(quorumDecayPerWeek).div(1 weeks)) {
        //     return quorum.sub(currentTime.sub(proposalTime).mul(quorumDecayPerWeek).div(1 weeks));
        // } else {
        //     return 0;
        // }

        // require(proposal.forVotes >= totalVotes.mul(quorum).div(10 ** 18), "OptinoGov: Not enough votes to execute");
        proposal.executed = true;

        for (uint i = 0; i < proposal.targets.length; i++) {
            (bool success,) = proposal.targets[i].call{value: proposal.values[i]}(proposal.data[i]);
            require(success, "Execution failed");
        }

        emit Executed(msg.sender, oip);
    }

    receive () external payable {
        // TODO depositDividend(address(0), msg.value);
    }
}
