pragma solidity ^0.7.0;

// ----------------------------------------------------------------------------
// Dividend Paying Token
//
// NOTE: This token contract allows the owner to mint and burn tokens for any
// account, and is used for testing
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2019 of the Optino Project
//
// SPDX-License-Identifier: MIT
// ----------------------------------------------------------------------------

// import "Owned.sol";
/// @notice Ownership
contract Owned {
    bool initialised;
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    modifier onlyOwner {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function initOwned(address _owner) internal {
        require(!initialised, "Already initialised");
        owner = address(uint160(_owner));
        initialised = true;
    }
    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}


// import "SafeMath.sol";
/// @notice Safe maths
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a, "Add overflow");
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a, "Sub underflow");
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b, "Mul overflow");
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0, "Divide by 0");
        c = a / b;
    }
}


/// @notice ERC20 https://eips.ethereum.org/EIPS/eip-20 with optional symbol, name and decimals
interface ERC20 {
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// import "MintableTokenInterface.sol";
// ----------------------------------------------------------------------------
// MintableToken Interface = ERC20 + symbol + name + decimals + mint + burn
// + approveAndCall
// ----------------------------------------------------------------------------
interface MintableToken is ERC20 {
    function mint(address tokenOwner, uint tokens) external returns (bool success);
    function burn(address tokenOwner, uint tokens) external returns (bool success);
}


// ----------------------------------------------------------------------------
// DividendPayingToken = ERC20 + symbol + name + decimals + mint + burn
//                     + dividend payment
//
// NOTE: This token contract allows the owner to mint and burn tokens for any
// account, and is used for testing
// ----------------------------------------------------------------------------
contract DividendPayingToken is MintableToken, Owned {
    using SafeMath for uint;

    string _symbol;
    string  _name;
    uint8 _decimals;
    uint _totalSupply;

    uint _totalDividendPoints;
    uint _unclaimedDividends;

    address public dividendToken;

    uint public constant pointMultiplier = 10e18;

    struct Account {
      uint balance;
      uint lastDividendPoints;
    }
    mapping(address => Account) accounts;
    mapping(address => mapping(address => uint)) allowed;

    event LogInfo(string topic, uint number, bytes32 data, string note, address addr);

/*




function disburse(uint amount) {
  totalDividendPoints += (amount * pointsMultiplier / totalSupply);
  totalSupply += amount;
  unclaimedDividends += amount;
}*/



    function totalDividendPoints() public view returns (uint) {
        return _totalDividendPoints;
    }
    function unclaimedDividends() public view returns (uint) {
        return _unclaimedDividends;
    }

    function dividendsOwing(address account) public view returns (uint) {
        uint newDividendPoints = _totalDividendPoints - accounts[account].lastDividendPoints;
        return (accounts[account].balance * newDividendPoints) / pointMultiplier;
    }
    function updateAccount(address account) internal {
        uint owing = dividendsOwing(account);
        emit LogInfo("depositDividends: owing", owing, 0x0, "", account);
        if (owing > 0) {
            emit LogInfo("depositDividends: _unclaimedDividends before", _unclaimedDividends, 0x0, "", account);
            _unclaimedDividends = _unclaimedDividends.sub(owing);
            emit LogInfo("depositDividends: _unclaimedDividends after", _unclaimedDividends, 0x0, "", account);
            emit LogInfo("depositDividends: accounts[account].balance", accounts[account].balance, 0x0, "", account);
            accounts[account].balance = accounts[account].balance.add(owing);
            emit LogInfo("depositDividends: accounts[account].balance", accounts[account].balance, 0x0, "", account);
            emit LogInfo("depositDividends: accounts[account].lastDividendPoints before", accounts[account].lastDividendPoints, 0x0, "", account);
            accounts[account].lastDividendPoints = _totalDividendPoints;
             emit LogInfo("depositDividends: accounts[account].lastDividendPoints after", accounts[account].lastDividendPoints, 0x0, "", account);
        }
    }

    function depositDividends(address token, uint dividends) public {
        emit LogInfo("depositDividends: token", 0, 0x0, "", token);
        emit LogInfo("depositDividends: dividends", dividends, 0x0, "", address(0));
        emit LogInfo("depositDividends: pointMultiplier", pointMultiplier, 0x0, "", address(0));
        emit LogInfo("depositDividends: _totalSupply", _totalSupply, 0x0, "", address(0));
        _totalDividendPoints = _totalDividendPoints.add((dividends * pointMultiplier / _totalSupply));
        _unclaimedDividends = _unclaimedDividends.add(dividends);
        emit LogInfo("depositDividends: _totalDividendPoints", _totalDividendPoints, 0x0, "", address(0));
        emit LogInfo("depositDividends: _unclaimedDividends", _unclaimedDividends, 0x0, "", address(0));
        ERC20(token).transferFrom(msg.sender, address(this), dividends);
    }

    function withdrawDividends(address /*token*/) public returns (uint withdrawn) {
        updateAccount(msg.sender);
        withdrawn = 0;
    }

    constructor(string memory symbol, string memory name, uint8 decimals, address tokenOwner, uint initialSupply, address _dividendToken) {
        initOwned(msg.sender);
        _symbol = symbol;
        _name = name;
        _decimals = decimals;
        accounts[tokenOwner].balance = initialSupply;
        _totalSupply = initialSupply;
        emit Transfer(address(0), tokenOwner, _totalSupply);
        dividendToken = _dividendToken;
    }
    function symbol() override external view returns (string memory) {
        return _symbol;
    }
    function name() override external view returns (string memory) {
        return _name;
    }
    function decimals() override external view returns (uint8) {
        return _decimals;
    }
    function totalSupply() override external view returns (uint) {
        return _totalSupply.sub(accounts[address(0)].balance);
    }
    function balanceOf(address tokenOwner) override external view returns (uint balance) {
        return accounts[tokenOwner].balance;
    }
    function transfer(address to, uint tokens) override external returns (bool success) {
        updateAccount(msg.sender);
        updateAccount(to);
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
        updateAccount(from);
        updateAccount(to);
        accounts[from].balance = accounts[from].balance.sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        accounts[to].balance = accounts[to].balance.add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }
    function allowance(address tokenOwner, address spender) override external view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }
    function mint(address tokenOwner, uint tokens) override external onlyOwner returns (bool success) {
        accounts[tokenOwner].balance = accounts[tokenOwner].balance.add(tokens);
        _totalSupply = _totalSupply.add(tokens);
        emit Transfer(address(0), tokenOwner, tokens);
        return true;
    }
    function burn(address tokenOwner, uint tokens) override external onlyOwner returns (bool success) {
        accounts[tokenOwner].balance = accounts[tokenOwner].balance.sub(tokens);
        _totalSupply = _totalSupply.sub(tokens);
        emit Transfer(tokenOwner, address(0), tokens);
        return true;
    }
}
// ----------------------------------------------------------------------------
// End - Dividend Paying Token
// ----------------------------------------------------------------------------
