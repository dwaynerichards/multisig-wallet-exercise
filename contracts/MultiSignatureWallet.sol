pragma solidity ^0.8.10;

contract MultiSignatureWallet {
    address[] public owners;
    uint256 public confirmationsRequired;
    uint256 public transactionCount;

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
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);

    /// @dev Fallback function allows to deposit ether.
    fallback() external payable {
        if (msg.value > 0) emit Deposit(msg.sender, msg.value);
    }

    receive() external payable {
        //msg.sender.tranfer(msg.value);
        revert("No call data supplied");
    }

    modifier validRequirment(uint256 ownerCount, uint256 confirmationsNeeded) {
        require(
            confirmationsNeeded < ownerCount && ownerCount > 0 && confirmationsNeeded > 0,
            "Confirmations needed Not Valid"
        );
        _;
    }

    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] memory _owners, uint256 _required)
        validRequirment(_owners.length, _required)
    {
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
    ) public returns (uint256 transactionId) {
        require(isOwner[msg.sender], "Only Contract owner may invoke");
        transactionId = addTransaction(destination, value, data);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    // verify that a transaction exists at the specified transactionId
    // mapping (uint transactionId => Transaction) public idToTransactions;
    //verify that the msg.sender has not already confirmed this transaction.
    // mapping (uint transactionID => mapping (address owner => bool)) public confirmations
    function confirmTransaction(uint256 transactionId) public returns (bool success) {
        require(confirmations[transactionId][msg.sender] == false, "Transaction already confirmed");
        require(isOwner[msg.sender], "Only Contract owner may invoke");
        require(
            idToTransactions[transactionId].destination != address(0),
            "Transaction does not exists"
        );
        executeTransaction(transactionId);
        return confirmations[transactionId][msg.sender] = true;
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return transactionId Returns transaction ID.
    function addTransaction(
        address destination,
        uint256 value,
        bytes memory data
    ) internal returns (uint256 transactionId) {
        //starting at 1 rather than 0;
        transactionId = transactionCount++;

        Transaction memory transaction = Transaction(false, destination, value, data);
        idToTransactions[transactionId] = transaction;
        emit Submission(transactionId);
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint256 transactionId) public {
        /* Transaction at the specified id has not already been executed.
         */
        require(idToTransactions[transactionId].executed == false, "Transaction already executed");
        //if confirmed, mutate state to true
        if (isConfirmed(transactionId)) {
            idToTransactions[transactionId].executed = true;
            Transaction storage executedTx = idToTransactions[transactionId];
            (bool success, ) = executedTx.destination.call{value: executedTx.value}(
                executedTx.data
            );

            if (success) emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                executedTx.executed = false;
            }
        }
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint256 transactionId) public {}

    /// @dev Returns _isConfirmed the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return _isConfirmed : Confirmation status.
    function isConfirmed(uint256 transactionId) internal view returns (bool _isConfirmed) {
        uint256 _owners = owners.length;
        uint256 ownerConfirmations;
        for (uint256 i = 0; i < _owners; i++) {
            bool ownerConfirmed = confirmations[transactionId][owners[i]];
            if (ownerConfirmed == true) ownerConfirmations++;
            if (ownerConfirmations == confirmationsRequired) return true;
        }
    }
}
