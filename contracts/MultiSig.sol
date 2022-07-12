// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract MultiSig {

    event Deposit(address indexed ender, uint256 amount);
    event Submit(uint256 indexed transactionId);
    event Approve(address indexed owner, uint256 indexed transactionId);
    event Revoke(address indexed owner, uint256 indexed transactionId);
    event Execute(uint256 indexed transactionId);

    address[] public owners;

    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public approved;

    uint256 public required;

    modifier onlyOwner {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier transactionExists(uint256 _transactionId) {
        require(_transactionId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notApproved(uint256 _transactionId) {
        require(!approved[_transactionId][msg.sender], "Transaction already approved");
        _;
    }

    modifier notExecuted(uint256 _transactionId) {
        require(!transactions[_transactionId].executed, "Transaction already executed");
        _;
    }

    struct Transaction {
        address to;
        uint256 amount;
        bytes data;
        bool executed;
    }

    Transaction[] public transactions;

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number of owners");
        for (uint256 i; i < _owners.length;) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner is not unique");
            isOwner[owner] = true;
            owners.push(owner);
            unchecked { i++; }
        }
        required = _required;
    }

    fallback() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(address _to, uint256 _amount, bytes calldata _data) external onlyOwner {
        transactions.push(Transaction({ to: _to, amount: _amount, data: _data, executed: false }));
        emit Submit(transactions.length - 1);
    }

    function approve(uint256 _transactionId) external onlyOwner transactionExists(_transactionId) notApproved(_transactionId) notExecuted(_transactionId) {
        approved[_transactionId][msg.sender] = true;
        emit Approve(msg.sender, _transactionId);
    }

    function _getApprovalCount(uint256 _transactionId) private view returns (uint256 count) {
        for (uint256 i; i < owners.length;) {
            if (approved[_transactionId][owners[i]]) {
                count += 1;
            }
            unchecked { i++; }
        }
    }

    function execute(uint256 _transactionId) external transactionExists(_transactionId) notExecuted(_transactionId) {
        require(_getApprovalCount(_transactionId) >= required, "Approvals less than required");
        Transaction storage transaction = transactions[_transactionId];
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.amount}(transaction.data);
        require(success, "Transaction failed");
        emit Execute(_transactionId);
    }

    function revoke(uint256 _transactionId) external onlyOwner transactionExists(_transactionId) notExecuted(_transactionId) {
        require(approved[_transactionId][msg.sender], "Transaction not approved");
        approved[_transactionId][msg.sender] = false;
        emit Revoke(msg.sender, _transactionId);
    }
}