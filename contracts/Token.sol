pragma solidity ^0.4.15;

import './interfaces/ERC20Interface.sol';
import './utils/SafeMath.sol';

/**
 * @title Token
 * @dev Contract that implements ERC20 token standard
 * Is deployed by `Crowdsale.sol`, keeps track of balances, etc.
 */

contract Token is ERC20Interface {
    /// total amount of tokens
    uint256 public totalSupply;

    address owner;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Burn(address indexed _who, uint256 _value);

    struct Approve {
        address spender;
        uint256 amountApproved;
    }

    struct Balance {
        uint256 balance;
        uint256 totalApproved;
    }

    modifier OwnerOnly() {
        if (msg.sender == owner) {_;}
    }

    mapping(address => Balance) private balances;
    mapping(address => Approve[]) private approvals;

    function Token(uint256 _totalSupply) {
        owner = msg.sender;
        totalSupply = _totalSupply;
        balances[msg.sender].balance = _totalSupply;
    }

    function mint(uint256 balance) OwnerOnly() {
        totalSupply = SafeMath.add(totalSupply, balance);
        balances[msg.sender].balance = SafeMath.add(balances[msg.sender].balance, balance);
    }

    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner].balance;
    }

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _value) returns (bool success) {
        if (balances[msg.sender].balance < SafeMath.add(balances[msg.sender].totalApproved, _value)) {
            Transfer(msg.sender, _to, 0);
            return false;
        }

        balances[msg.sender].balance = SafeMath.sub(balances[msg.sender].balance, _value);
        balances[_to].balance = SafeMath.add(balances[_to].balance, _value);

        Transfer(msg.sender, _to, _value);
        return true;
    }

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        // if (balances[_from].balance < _value) {
        //     Transfer(_from, _to, 0);
        //     return false;
        // }

        Approve[] storage approvalArray = approvals[_from];

        for (uint s = 0; s < approvalArray.length; s++) {
            if (approvalArray[s].spender == msg.sender) {
                if (approvalArray[s].amountApproved < _value) {
                    Transfer(_from, _to, 0);
                    return false;
                }

                // Transfer
                approvalArray[s].amountApproved = SafeMath.sub(approvalArray[s].amountApproved, _value);
                balances[_from].totalApproved = SafeMath.sub(balances[_from].totalApproved, _value);
                balances[_from].balance = SafeMath.sub(balances[_from].balance, _value);
                balances[_to].balance = SafeMath.add(balances[_to].balance, _value);

                Transfer(_from, _to, _value);
                return true;
            }
        }

        // approval not found
        Transfer(_from, _to, 0);
        return false;
    }

    /// @notice `msg.sender` approves `_spender` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of tokens to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _value) returns (bool success) {
        if (msg.sender == _spender) {
            Approval(msg.sender, _spender, 0);
            return false;
        }

        if (balances[msg.sender].balance < SafeMath.add(balances[msg.sender].totalApproved, _value)) {
            Approval(msg.sender, _spender, 0);
            return false;
        }

        Approve[] storage approvalArray = approvals[msg.sender];
        bool done = false;
        for (uint s = 0; s < approvalArray.length; s++) {
            if (approvalArray[s].spender == _spender) {
                approvalArray[s].amountApproved = SafeMath.add(approvalArray[s].amountApproved, _value);
                done = true;
                break;
            }
        }

        if (!done) {
            approvalArray.push(Approve(_spender, _value));
        }

        balances[msg.sender].totalApproved = SafeMath.add(balances[msg.sender].totalApproved, _value);
        Approval(msg.sender, _spender, _value);
        return true;
    }

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spend
    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        uint256 ret = 0;

        Approve[] storage approvalArray = approvals[_owner];
        for (uint s = 0; s < approvalArray.length; s++) {
            if (approvalArray[s].spender == _spender) {
                ret = approvalArray[s].amountApproved;
                break;
            }
        }

        return ret;
    }

    function burn(uint256 _value) returns (bool success) {
        // Can only burn the remaining tokens not approved to anyone
        if (SafeMath.sub(balances[msg.sender].balance, balances[msg.sender].totalApproved) < _value) {
            return false;
        }

        balances[msg.sender].balance = SafeMath.sub(balances[msg.sender].balance, _value);
        totalSupply = SafeMath.sub(totalSupply, _value);

        Burn(msg.sender, _value);
        return true;
    }

    function refund(address _from, uint256 _value) OwnerOnly() returns (bool success) {
        // Can only take out the remaining tokens not approved to anyone
        if (SafeMath.sub(balances[_from].balance, balances[_from].totalApproved) < _value) {
            Transfer(_from, msg.sender, 0);
            return false;
        }

        balances[_from].balance = SafeMath.sub(balances[_from].balance, _value);
        balances[msg.sender].balance = SafeMath.add(balances[msg.sender].balance, _value);

        Transfer(_from, msg.sender, _value);
        return true;
    }

}
