pragma solidity ^0.4.24;

import "./Project.sol";

contract FundingHub {

    address public owner;
    uint public numOfProjects;

    mapping (uint => address) public projects;

    event LogProjectCreated(uint id, string title, address addr, address creator);
    event LogContributionSent(address projectAddress, address contributor, uint amount);

    event LogFailure(string message);

    modifier onlyOwner {
        require(owner != msg.sender);
        _;
    }

    function FundingHub() {
        owner = msg.sender;
        numOfProjects = 0;
    }

    function createProject(uint _fundingGoal, uint _deadline, string _title) payable returns (Project projectAddress) {

        if (_fundingGoal <= 0) {
            emit LogFailure("Project funding goal must be greater than 0");
            revert();
        }

        if (block.number >= _deadline) {
           emit LogFailure("Project deadline must be greater than the current block");
            revert();
        }

        Project p = new Project(_fundingGoal, _deadline, _title, msg.sender);
        projects[numOfProjects] = p;
        emit LogProjectCreated(numOfProjects, _title, p, msg.sender);
        numOfProjects++;
        return p;
    }

    function contribute(address _projectAddress) payable returns (bool successful) {

        if (msg.value <= 0) {
            emit LogFailure("Contributions must be greater than 0 wei");
            revert();
        }

        Project deployedProject = Project(_projectAddress);

        if (deployedProject.fundingHub() == address(0)) {
            emit LogFailure("Project contract not found at address");
            revert();
        }

        if (deployedProject.fund.value(msg.value)(msg.sender)) {
            emit LogContributionSent(_projectAddress, msg.sender, msg.value);
            return true;
        } else {
            emit LogFailure("Contribution did not send successfully");
            return false;
        }
    }

}
