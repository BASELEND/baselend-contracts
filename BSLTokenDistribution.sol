pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// BSLTokenDistribution
contract BSLTokenDistribution is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    uint256 public immutable startUnlockTime;
    uint256 public immutable fullUnlockTime;

    address public immutable BSLAddress;

    mapping(address => uint256) public userBSLCredit;
    mapping(address => uint256) public userBSLHarvested;

    event BSLHarvested(address sender, uint256 baseLendHarvest, uint currentUnlock, uint totalCredit);
    event SetBSLCredit(address sender, uint creditAmount);
    event TokenRecovery(address token, address recipient, uint amount);

    constructor(address _BSLAddress, uint _startUnlockTime, uint _fullUnlockTime) {
        require(_BSLAddress != address(0), "_BSLAddress != 0");
        require(block.timestamp < _startUnlockTime, "cannot set start block in the past!");
        require(_startUnlockTime < _fullUnlockTime, "end time must be after start time!");
    
        BSLAddress = _BSLAddress;
        startUnlockTime = _startUnlockTime;
        fullUnlockTime = _fullUnlockTime;
    }

    function harvestBSL() external nonReentrant {
        require(block.timestamp > startUnlockTime, "token distribution hasn't started yet!");
        require(userBSLHarvested[msg.sender] < userBSLCredit[msg.sender], "you have already harvested all your BSL!");

        uint currentOrEndTime = block.timestamp < fullUnlockTime ? block.timestamp : fullUnlockTime;

        uint totalCredit = userBSLCredit[msg.sender];

        uint currentUnlock = totalCredit * (currentOrEndTime - startUnlockTime) / (fullUnlockTime - startUnlockTime);

        uint harvest = currentUnlock - userBSLHarvested[msg.sender];

        if (harvest > 0) {
            userBSLHarvested[msg.sender] = currentUnlock;

            ERC20(BSLAddress).safeTransfer(msg.sender, harvest);
        }

        emit BSLHarvested(msg.sender, harvest, currentUnlock, totalCredit);
    }


    function setBSLCreditInfo(address recipient, uint256 creditAmount) external onlyOwner {
        require(block.timestamp < startUnlockTime, "can't edit claim list after emissions!");

        userBSLCredit[recipient] = creditAmount;
        
        emit SetBSLCredit(recipient, creditAmount);
    }

    function recoverToken(address tokenAddress, address recipient, uint256 recoveryAmount) external onlyOwner {
        require(block.timestamp < startUnlockTime, "can't take out tokens after emissions have started!");

        ERC20(tokenAddress).safeTransfer(recipient, recoveryAmount);
        
        emit TokenRecovery(tokenAddress, recipient, recoveryAmount);
    }
}