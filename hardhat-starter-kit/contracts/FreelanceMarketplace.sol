// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract FreelanceMarketplace {
    struct Project {
        address freelancer;
        address client;
        uint256 rating;
    };

    struct Freelancer {
        address freelancerAddress;
        uint256 rating;
        address[] clients;
    };

    struct Client {
        address clientAddress;
        Project[] projects;
    };

    Client[] private s_clients = []; /* Clients */
    Freelancer[] private s_freelancers =[];  /* Freelancers */
    Project[] external s_projects = []; /* Projects */
    Freelancer[] private s_eliteFreelancers[]; /* Elite Freelancers */
    uint256 private constant AUDIT_THRESHOLD = 2;
    uint256 private constant ELITE_THRESHOLD = 4;
    uint256 private constant MAX_RATING = 5;


    /* Automation Variables */
    uint256 private immutable i_auditUpdateInterval;
    uint256 private immutable i_eliteFreelancersUpdateInterval;
    uint256 private s_lastTimeStamp;

    constructor(uint256 updateInterval) {
        /* Initialise values */
        i_updateInterval = updateInterval;
    }


     function checkUpkeepForAudit(
        bytes calldata checkData 
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if(keccak256(checkData) == keccak256(hex'01')){
            upkeepNeeded = (block.timestamp - lastTimeStamp) > i_updateInterval;
        }
        else if(keccak256(checkData) == keccak256(hex'02')){
            upkeepNeeded = (block.timestamp - lastTimeStamp) > i_eliteFreelancersUpdateInterval;
        }
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeepForAudit(bytes calldata performData) external override {
        if(keccak256(performData) == keccak256(hex'01')) {
            /* Perform Audit */
            for(uint256 freelancerIndex = 0; freelancerIndex < s_freelancers.length; freelancerIndex ++) {
                Freelancer memory freelancer = s_freelancers[freelancerIndex];
                if(freelancer.rating < AUDIT_THRESHOLD) {
                    /* Discard */
                    delete (s_freelancers[freelancerIndex]);
                    /* Emit event */
                }
            }
        }
        else if(keccak256(performData) == keccak256(hex'02')) {
            /* Pick the top performers */
            Freelancer[] memory eliteFreelancers;
            for(uint256 freelancerIndex = 0; freelancerIndex < s_freelancers.length; freelancerIndex ++) {
                if(s_freelancers[freelancerIndex].rating > ELITE_THRESHOLD) {
                    eliteFreelancer.push(s_freelancers[freelancerIndex]);
                }
            }
    
            s_eliteFreelancers = eliteFreelancers;
        }

    }


}
