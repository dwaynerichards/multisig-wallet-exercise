pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "./MultiSignatureWallet.sol";

contract MultiSigWalletWithDailyLimit is MultiSignatureWallet {
    event DailyLimitChange(uint256 dailyLimit);
    event DayReset(uint256 time);

    uint256 public dailyLimit;
    uint256 public lastDay;
    uint256 public spentToday;

    constructor(
        address[] memory _owners,
        uint256 _required,
        uint256 _dailyLimit
    ) MultiSignatureWallet(_owners, _required) {
        _dailyLimit = dailyLimit;
    }

    function changeDailyLimit(uint256 _dailyLimit) public onlyWallet {
        _dailyLimit = dailyLimit;
        emit DailyLimitChange(_dailyLimit);
    }

    function executeTransaction(uint256 transactionId) public override notExecuted(transactionId) {
        bool isExecutable = isConfirmed(transactionId) && isUnderLimit(transactionId);
        if (isExecutable) {
            Transaction storage futureTx = idToTransactions[transactionId];
            futureTx.executed = true;
            (bool success, ) = futureTx.destination.call{value: futureTx.value}(futureTx.data);
            if (success) {
                spentToday += futureTx.value;
                emit Execution(transactionId);
            } else {
                futureTx.executed = false;
                emit ExecutionFailure(transactionId);
            }
        }
    }

    //reset sepnt today after 1day
    //check ig the time now is more than 24 hours past the lastDAy
    //ifso, set last day to now, reset sepnt today to O

    //if the amount plus spentToday is over limit, return false
    function isUnderLimit(uint256 amount) internal returns (bool) {
        uint256 timeNow = block.timestamp;
        if (timeNow > lastDay + 24 hours) {
            lastDay = timeNow;
            spentToday = 0;
            emit DayReset(timeNow);
        }
        uint256 totalSpent = amount + spentToday;
        if (totalSpent > dailyLimit) return false;
        return true;
    }
}
