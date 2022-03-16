pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/utils/Counters.sol";

contract MultiSignatureWallet {
    //multiple owners needed to allow traansactions
    //function propose stransaction
    //function confirm or revoke transaction
    using Counters for Counters.Counter;
    address[] public owners;
    uint256 public confirmationsRequired;
    uint256 public transactionCount;
    Counters.Counter public transactions;

    mapping(address => bool) public isOwner;
    mapping(uint256 => Transaction) public idToTransactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    struct Transaction {
        bool executed;
        address destination;
        uint256 value;
        bytes data;
    }
    event Submission(uint256 indexed transactionId);
    event Deposit(address indexed sender, uint256 value);

    event Confirmation(address indexed owner, uint256 indexed transactionId);
    event RevokeConfirmation(uint256 indexed transactionId, address indexed owner);

    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);

    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event ConfirmationsChange(uint256 indexed confirmations);

    modifier validRequirement(uint256 ownerCount, uint256 confirmationsNeeded) {
        require(confirmationsNeeded < ownerCount && ownerCount > 0 && confirmationsNeeded > 0, "Confirmations needed Not Valid");
        _;
    }
    modifier onlyWallet() {
        require(msg.sender == address(this), "Only wallet may call this function");
        _;
    }
    modifier ownerExists(address _owner) {
        require(isOwner[_owner], "Only owner may call function");
        _;
    }
    modifier txNotConfirmed(uint256 txId) {
        require(confirmations[txId][msg.sender] == false, "Transaction previously confirmed");
        _;
    }

    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] memory _owners, uint256 _required) validRequirement(_owners.length, _required) {
        for (uint256 i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        confirmationsRequired = _required;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return transactionId Returns transaction ID.
    function submitTransaction(
        address destination,
        uint256 value,
        bytes memory data
    ) public ownerExists(msg.sender) returns (uint256 transactionId) {
        transactionId = _addTransaction(destination, value, data);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param _txId Transaction ID.
    // verify that a transaction exists at the specified transactionId
    // mapping (uint transactionId => Transaction) public idToTransactions;
    //verify that the msg.sender has not already confirmed this transaction.
    // mapping (uint transactionID => mapping (address owner => bool)) public confirmations
    function confirmTransaction(uint256 _txId) public ownerExists(msg.sender) txNotConfirmed(_txId) {
        require(idToTransactions[_txId].destination != address(0), "Transaction does not exists");
        confirmations[_txId][msg.sender] = true;
        emit Confirmation(msg.sender, _txId);
        executeTransaction(_txId);
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    modifier notExecuted(uint256 transactionId) {
        require(idToTransactions[transactionId].executed == false, "Transaction already executed");
        _;
    }

    function executeTransaction(uint256 transactionId) public notExecuted(transactionId) {
        //if confirmed, mutate state to true
        if (isConfirmed(transactionId)) {
            Transaction storage executedTx = idToTransactions[transactionId];
            executedTx.executed = true;
            (bool success, ) = executedTx.destination.call{value: executedTx.value}(executedTx.data);
            if (success) emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                executedTx.executed = false;
            }
        }
    }

    /// @dev Returns _isConfirmed the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return _isConfirmed : Confirmation status.
    function isConfirmed(uint256 transactionId) public view returns (bool _isConfirmed) {
        uint256 ownerConfirmations = getConfirmationCount(transactionId);
        if (ownerConfirmations >= confirmationsRequired) _isConfirmed = true;
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint256 transactionId) public {
        require(isOwner[msg.sender]);
        confirmations[transactionId][msg.sender] = false;
        emit RevokeConfirmation(transactionId, msg.sender);
    }

    /*
     *   Web3 Read only functions
     */
    function getConfirmationCount(uint256 _txId) public view returns (uint256 ownerConfirmations) {
        uint256 _owners = owners.length;
        for (uint256 i = 0; i < _owners; i++) {
            bool ownerConfirmed = confirmations[_txId][owners[i]];
            if (ownerConfirmed == true) ownerConfirmations++;
        }
        return ownerConfirmations;
    }

    /// @dev Returns array with owner addresses, which confirmed transaction.
    /// @param _txId Transaction ID.
    /// @return _confirmedOwners Returns array of owner addresses.
    function getOwnerConfirmations(uint256 _txId) public view returns (address[] memory _confirmedOwners) {
        require(_txId <= transactionCount, "Transaction inexistant");
        uint256 _confirmations = getConfirmationCount(_txId);
        _confirmedOwners = new address[](_confirmations);
        for (uint256 i = 0; i < owners.length; i++) {
            address owner = owners[i];
            bool didOwnerConfirm = confirmations[_txId][owner];
            uint256 ownerIndex = _confirmedOwners.length;
            if (didOwnerConfirm) _confirmedOwners[ownerIndex] = owner;
        }
    }

    /// @dev Fallback function allows to deposit ether.
    fallback() external payable {
        if (msg.value > 0) emit Deposit(msg.sender, msg.value);
    }

    receive() external payable {
        //msg.sender.tranfer(msg.value);
        revert("No call data supplied");
    }

    /*
     * Internal and wallet only functions
     */
    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return transactionId Returns transaction ID.
    function _addTransaction(
        address destination,
        uint256 value,
        bytes memory data
    ) internal returns (uint256 transactionId) {
        require(destination != address(0), "Flawed transaction destination");
        //starting at 1 rather than 0;
        transactions.increment();
        transactionId = transactions.current();
        Transaction memory transaction = Transaction(false, destination, value, data);
        idToTransactions[transactionId] = transaction;
        emit Submission(transactionId);
    }

    function replaceOwner(address _oldOwner, address _newOwner) public onlyWallet ownerExists(_oldOwner) {
        require(isOwner[_newOwner] == false, "Only new owners may be added");
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _oldOwner) {
                owners[i] = _newOwner;
                break;
            }
            isOwner[_oldOwner] = false;
            isOwner[_newOwner] = true;
            emit OwnerRemoval(_oldOwner);
            emit OwnerAddition(_newOwner);
        }
    }

    function changeMinConfirmations(uint256 _confirmations) public onlyWallet validRequirement(owners.length, _confirmations) {
        confirmationsRequired = _confirmations;
        emit ConfirmationsChange(_confirmations);
    }
}
