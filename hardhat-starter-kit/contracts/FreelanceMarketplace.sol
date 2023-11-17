// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract FreelanceMarketplace is
    ERC721,
    AutomationCompatible,
    VRFConsumerBaseV2
{
    /* Data Structures */
    struct Project {
        address freelancer;
        address client;
        string title;
        string description;
        uint256 reward;
        uint256 deadline;
        bool isCompleted;
    }

    struct Freelancer {
        address freelancerAddress;
        uint256 rating;
    }

    address private s_client =
        0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199; /* Clients */
    Freelancer[] private s_freelancers = [
        Freelancer(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 3),
        Freelancer(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 9),
        Freelancer(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, 10),
        Freelancer(0x90F79bf6EB2c4f870365E785982E1f101E93b906, 8),
        Freelancer(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65, 8)
    ];
    /* Freelancers */
    Project[] private s_projects = [
        Project(
            0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
            s_client,
            "Freelance-MarketPlace",
            "Very Nice Systummm!!",
            400,
            1704006849,
            false
        )
    ]; /* Projects */
    Freelancer[] private s_eliteFreelancers; /* Elite Freelancers */
    uint256 private constant AUDIT_THRESHOLD = 3;
    uint256 private constant ELITE_THRESHOLD = 9;
    uint256 private constant MAX_RATING = 10;
    uint256 private s_lastAuditTimeStamp;
    uint256 private s_lastEliteFreelancersTimeStamp;
    uint256 private s_tokenCounter;
    string public constant TOKEN_URI =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";
    Freelancer private s_recentWinner;

    /* Automation Variables */
    uint256 private immutable i_auditUpdateInterval;
    uint256 private immutable i_eliteFreelancersUpdateInterval;
    uint256 private s_lastTimeStamp;

    /* Chainlink Vrf Variables */
    uint64 private immutable i_subscriptionId;
    VRFCoordinatorV2Interface COORDINATOR;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /* Events */
    event RequestRandomness(uint256 indexed requestId);
    event Transfer(Freelancer indexed freelancer, uint256 indexed tokenId);

    constructor(
        uint256 auditUpdateInterval,
        uint256 eliteFreelancersUpdateInterval,
        uint64 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) ERC721("FreelanceMarketplace", "AK") {
        /* Initialise values */
        i_auditUpdateInterval = auditUpdateInterval;
        i_eliteFreelancersUpdateInterval = eliteFreelancersUpdateInterval;
        i_subscriptionId = subscriptionId;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        s_tokenCounter = 0;
    }

    function requestRandom() public returns (uint256 requestId) {
        requestId = COORDINATOR.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestRandomness(requestId);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 MOD = s_eliteFreelancers.length;
        uint256 randomIndex = randomWords[0] % MOD;
        uint256 newTokenId = s_tokenCounter;
        s_tokenCounter++;
        //Award NFT to random elite freelancer
        s_recentWinner = s_eliteFreelancers[randomIndex];
        _safeMint(
            s_eliteFreelancers[randomIndex].freelancerAddress,
            newTokenId
        );
        emit Transfer(s_eliteFreelancers[randomIndex], newTokenId);
    }

    function checkUpkeep(
        bytes calldata checkData
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (keccak256(checkData) == keccak256(hex"01")) {
            upkeepNeeded =
                (block.timestamp - s_lastAuditTimeStamp) >
                i_auditUpdateInterval;
        } else if (keccak256(checkData) == keccak256(hex"02")) {
            upkeepNeeded =
                (block.timestamp - s_lastEliteFreelancersTimeStamp) >
                i_eliteFreelancersUpdateInterval;
        }
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(bytes calldata performData) external override {
        if (keccak256(performData) == keccak256(hex"01")) {
            /* Perform Audit */
            for (
                uint256 freelancerIndex = 0;
                freelancerIndex < s_freelancers.length;
                freelancerIndex++
            ) {
                Freelancer memory freelancer = s_freelancers[freelancerIndex];
                if (freelancer.rating < AUDIT_THRESHOLD) {
                    /* Discard */
                    delete (s_freelancers[freelancerIndex]);
                    /* Emit event */
                }
            }
        } else if (keccak256(performData) == keccak256(hex"02")) {
            /* Pick the top performers */
            delete (s_eliteFreelancers);

            for (
                uint256 freelancerIndex = 0;
                freelancerIndex < s_freelancers.length;
                freelancerIndex++
            ) {
                if (s_freelancers[freelancerIndex].rating > ELITE_THRESHOLD) {
                    s_eliteFreelancers.push(s_freelancers[freelancerIndex]);
                }
            }
            // s_eliteFreelancers = eliteFreelancers;
            //generate random number
            uint256 requestId = requestRandom();
        }
    }

    /*Getter Functions */

    function getRecentWinner() public view returns (Freelancer memory) {
        return s_recentWinner;
    }

    function getFreeLancer(
        uint256 freelancerIndex
    ) public view returns (Freelancer memory) {
        return s_freelancers[freelancerIndex];
    }

    function getClient(uint256 clientIndex) public view returns (address) {
        return s_client;
    }

    function getEliteFreelancer(
        uint256 eliteFreelancerIndex
    ) public view returns (Freelancer memory) {
        return s_eliteFreelancers[eliteFreelancerIndex];
    }

    function getProject(
        uint256 projectIndex
    ) public view returns (Project memory) {
        return s_projects[projectIndex];
    }

    function getTokenUri() public view returns (string memory) {
        return TOKEN_URI;
    }
}
