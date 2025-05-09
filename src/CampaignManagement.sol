// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import {ERC20} from "solmate/src/tokens/ERC20.sol";

abstract contract CampaignManagement is ERC20 {
    event CampaignActived(uint48 id, bool);
    event CampaignDeactivated(uint48 id, bool);
    event PointsEarned(uint48 id, address usr, uint);

    address admin;
    mapping(uint48 id => Campaign) internal campaigns;
    mapping(uint48 id => mapping(address user => uint))
        public usrCampaignPoints;

    Campaign activeCampaign;

    struct Campaign {
        uint48 id;
        address creator;
        address baseToken; // incentive token
        uint32 startTime;
        uint32 endTime;
        bool isActive;
        uint16 swapPointsRate; // Basis points (2000 = 20%)
        uint16 lpPointsRate; // Basis points (10000 = 100%)
        uint256 maxSwapPoints;
        uint256 maxLpPoints;
        uint256 totalPointsDistributed;
    }

    modifier onlyAdmin(uint48 id) {
        require(campaigns[id].creator == admin, "NA");
        _;
    }

    constructor() ERC20("LstPointsToken", "LPT", 18) {}

    function _setAdmin(address n) internal {
        admin = n;
    }

    function _getAdmin() public view returns (address) {
        return admin;
    }

    function createCampaign(
        Campaign memory c
    ) public onlyAdmin(c.id) returns (Campaign memory) {
        require(!campaigns[c.id].isActive, "c_a");

        uint48 id = uint48(uint256(keccak256(abi.encode(c))));

        Campaign storage cm = campaigns[id];
        cm.id = c.id;
        cm.creator = admin;
        cm.startTime = c.startTime;
        cm.endTime = c.endTime;
        cm.isActive = c.isActive;
        cm.swapPointsRate = c.swapPointsRate;
        cm.lpPointsRate = c.lpPointsRate;
        cm.maxSwapPoints = c.maxSwapPoints;
        cm.maxLpPoints = c.maxLpPoints;

        return cm;
    }

    function toggleActive(uint48 id, bool toggle) external onlyAdmin(id) {
        if (toggle) {
            require(!campaigns[id].isActive);

            campaigns[id].isActive = toggle;
            activeCampaign = campaigns[id];
            emit CampaignActived(id, toggle);
        } else {
            require(campaigns[id].id == activeCampaign.id, "N_Id");
            require(campaigns[id].isActive, "Not Active");

            campaigns[id].isActive == toggle;

            emit CampaignDeactivated(id, toggle);
        }
    }

    function status() public view returns (bool) {
        return activeCampaign.isActive;
    }

    function _assignPoints(
        uint48 id,
        address usr,
        uint256 baseAmount,
        bool isSwap
    ) internal onlyAdmin(id) {
        if (usr == address(0)) return;

        Campaign storage campaign = campaigns[id];

        if (
            !campaign.isActive ||
            block.timestamp < campaign.startTime ||
            block.timestamp > campaign.endTime
        ) {
            return;
        }

        uint256 pointsEarned;
        if (isSwap) {
            pointsEarned = (baseAmount * campaign.swapPointsRate) / 10000;
            pointsEarned = pointsEarned > campaign.maxSwapPoints
                ? campaign.maxSwapPoints
                : pointsEarned;
        } else {
            pointsEarned = (baseAmount * campaign.lpPointsRate) / 10000;
            pointsEarned = pointsEarned > campaign.maxLpPoints
                ? campaign.maxLpPoints
                : pointsEarned;
        }

        if (pointsEarned > 0) {
            usrCampaignPoints[id][usr] += pointsEarned;
            _mint(usr, pointsEarned);
            campaign.totalPointsDistributed += totalSupply;
            emit PointsEarned(id, usr, pointsEarned);
        }
    }
}
