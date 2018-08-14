pragma solidity ^0.4.24;

contract Project {

    struct Properties {
        uint goal;
        uint deadline;
        string title;
        address creator;
    }

    struct Contribution {
        uint amount;
        address contributor;
    }

    address public fundingHub;

    mapping (address => uint) public contributors;
    mapping (uint => Contribution) public contributions;

    uint public totalFunding;
    uint public contributionsCount;
    uint public contributorsCount;

    Properties public properties;

    event LogContributionReceived(address projectAddress, address contributor, uint amount);
    event LogPayoutInitiated(address projectAddress, address owner, uint totalPayout);
    event LogRefundIssued(address projectAddress, address contributor, uint refundAmount);
    event LogFundingGoalReached(address projectAddress, uint totalFunding, uint totalContributions);
    event LogFundingFailed(address projectAddress, uint totalFunding, uint totalContributions);

    event LogFailure(string message);

    modifier onlyFundingHub {
        require(fundingHub != msg.sender);
        _;
    }

    modifier onlyFunded {
        require(totalFunding < properties.goal);
        _;
    }

    function Project(uint _fundingGoal, uint _deadline, string _title, address _creator) {

        if (_fundingGoal <= 0) {
            emit LogFailure("Project funding goal must be greater than 0");
            revert();
        }

        if (block.number >= _deadline) {
            emit LogFailure("Project deadline must be greater than the current block");
            revert();
        }

        if (_creator == 0) {
            emit LogFailure("Project must include a valid creator address");
            revert();
        }

        fundingHub = msg.sender;

        properties = Properties({
            goal: _fundingGoal,
            deadline: _deadline,
            title: _title,
            creator: _creator
        });

        totalFunding = 0;
        contributionsCount = 0;
        contributorsCount = 0;
    }

    function getProject() returns (string, uint, uint, address, uint, uint, uint, address, address) {
        return (properties.title,
                properties.goal,
                properties.deadline,
                properties.creator,
                totalFunding,
                contributionsCount,
                contributorsCount,
                fundingHub,
                address(this));
    }

    function getContribution(uint _id) returns (uint, address) {
        Contribution storage c = contributions[_id];
        return (c.amount, c.contributor);
    }

    function fund(address _contributor) payable returns (bool successful) {

        if (msg.value <= 0) {
            emit LogFailure("Funding contributions must be greater than 0 wei");
            revert();
        }

        if (msg.sender != fundingHub) {
            emit LogFailure("Funding contributions can only be made through FundingHub contract");
            revert();
        }

        if (block.number > properties.deadline) {
            emit LogFundingFailed(address(this), totalFunding, contributionsCount);
            if (!_contributor.send(msg.value)) {
                emit LogFailure("Project deadline has passed, problem returning contribution");
                revert();
            }
            return false;
        }

        if (totalFunding >= properties.goal) {
            emit LogFundingGoalReached(address(this), totalFunding, contributionsCount);
            if (!_contributor.send(msg.value)) {
                emit LogFailure("Project deadline has passed, problem returning contribution");
               revert();
            }
            payout();
            return false;
        }

        uint prevContributionBalance = contributors[_contributor];

        Contribution storage c = contributions[contributionsCount];
        c.contributor = _contributor;
        c.amount = msg.value;

        contributors[_contributor] += msg.value;

        totalFunding += msg.value;
        contributionsCount++;

        if (prevContributionBalance == 0) {
            contributorsCount++;
        }

        emit LogContributionReceived(this, _contributor, msg.value);

        if (totalFunding >= properties.goal) {
            emit LogFundingGoalReached(address(this), totalFunding, contributionsCount);
            payout();
        }

        return true;
    }

    function payout() payable onlyFunded returns (bool successful) {
        uint amount = totalFunding;

        totalFunding = 0;

        if (properties.creator.send(amount)) {
            return true;
        } else {
            totalFunding = amount;
            return false;
        }

        return true;
    }

    function refund() payable returns (bool successful) {

        if (block.number < properties.deadline) {
            emit LogFailure("Refund is only possible if project is past deadline");
            revert();
        }

        if (totalFunding >= properties.goal) {
            emit LogFailure("Refund is not possible if project has met goal");
            revert();
        }

        uint amount = contributors[msg.sender];

        contributors[msg.sender] = 0;

        if (msg.sender.send(amount)) {
            emit LogRefundIssued(address(this), msg.sender, amount);
            return true;
        } else {
            contributors[msg.sender] = amount;
            emit LogFailure("Refund did not send successfully");
            return false;
        }
        return true;
    }

    function kill() public onlyFundingHub {
        selfdestruct(fundingHub);
    }

}
