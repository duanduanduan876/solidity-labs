// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract PaymentSplitter {
    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    uint256 public totalShares;
    uint256 public totalReleased;

    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;

    constructor(address[] memory payees, uint256[] memory shares) payable {
        require(payees.length == shares.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares[i]);
        }
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function deposit() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function totalReceived() public view returns (uint256) {
        return address(this).balance + totalReleased;
    }

    function shares(address account) public view returns (uint256) {
        return _shares[account];
    }

    function released(address account) public view returns (uint256) {
        return _released[account];
    }

    function releasable(address account) public view returns (uint256) {
        uint256 _totalReceived = address(this).balance + totalReleased;
        return (_totalReceived * _shares[account]) / totalShares - _released[account];
    }

    function release(address payable account) public virtual {
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");

        uint256 payment = releasable(account);
        require(payment != 0, "PaymentSplitter: account is not due payment");

        _released[account] += payment;
        totalReleased += payment;

        (bool success, ) = account.call{value: payment}("");
        require(success, "PaymentSplitter: payment failed");

        emit PaymentReleased(account, payment);
    }

    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
        totalShares += shares_;
        emit PayeeAdded(account, shares_);
    }
}