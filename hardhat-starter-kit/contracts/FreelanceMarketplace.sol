// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

error FreelanceMarketplace__ClientNotFound(address clientAddress);
error FreelanceMarketplace__FreelancerNotFound(address freelancerAddress);
error FreelanceMarketplace__MissingDetails();
error FreelanceMarketplace__TranserFailed();
error FreelanceMarketplace__UpkeepNotNeeded();

contract FreelanceMarketplace is
    VRFConsumerBaseV2,
    ERC721,
    ChainlinkClient,
    ConfirmedOwner,
    AutomationCompatibleInterface
{
    /* Custom Declarations */
    struct Review {
        address client;
        address freelancer;
        string review;
        uint16 rating;
    }

    struct Profile {
        string githubURL;
        string linkedInURL;
        string email;
        string profileHash;
    }

    struct Project {
        uint256 projectId;
        address freelancer;
        address client;
        uint256 startTime;
        uint256 deadline;
        bool isTaken;
    }

    struct Request {
        uint256 requestId;
        address freelancer;
        address client;
        bool taken;
    }

    /* Events */
    event ProfileComplete(
        address indexed freelancer,
        string indexed githubURL,
        string indexed linkedInURL,
        string email,
        string profileHash
    );

    event ReviewListed(
        address indexed client,
        address indexed freelancer,
        string review,
        uint256 rating
    );

    event ProjectInitialised(
        address indexed client,
        address indexed freelancer
    );

    event RequestCreated(
        address indexed client,
        address indexed freelancer,
        uint256 indexed requestId
    );

    event PoolPrizeWinnerRequested(uint256 indexed requestId);
    event PoolPrizeWinnerPicked(address indexed winner);
    event NftMinted(address indexed buyer, uint256 indexed tokenId);
    event RequestName(uint256 indexed requestId, string indexed name);
    /* State Variables */
    /* Recording freelancer address when they sign up */
    mapping(address => bool) private s_freelancers;
    /* Recording clients address when they sign up */
    mapping(address => bool) private s_clients;
    /* Mapping a freelancer address to his/her profile */
    mapping(address => Profile) private s_freelancerToProfile;
    /* Keep track of the projects undertaken by each freelancer */
    mapping(address => Project[]) private s_freelancerToProject;
    /* Keep track of the projects issued by each client */
    mapping(address => Project[]) private s_clientToProject;
    /* Keep track of the reviews sent by each client */
    mapping(address => Review[]) private s_clientToReview;
    /* Keep track of the requests sent by a freelancer */
    mapping(address => Request[]) private s_freelancerRequests;
    /* Keep track of the requests received by a client */
    mapping(address => Request[]) private s_clientRequests;
    /* Keep track of the collateral put up by each client */
    mapping(address => uint256) private s_freelancerBalances;
    /* Keep track of all the projects */
    Project[] private s_projects;
    /* Keep track of top performers */
    address payable[] public s_elites;
    /* Keep track of the recent pool prize winner */
    address private s_recentWinner;
    /* TOKEN_URIS */
    string[3] private s_dogTokenURI;
    uint256 private s_tokenCounter;
    string public s_recentCommitMessage;
    uint256 private i_updateInterval;
    uint256 private s_lastTimestamp;

    /* Chainlink VRF Variables */
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGaslimit;
    uint32 private constant NUM_WORDS = 1;

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        string[3] memory dogTokenURI
        uint256 updateInterval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721("Freelance", "FMP") {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_callbackGaslimit = callbackGasLimit;
        i_gasLane = gasLane;
        s_dogTokenURI = dogTokenURI;
        s_tokenCounter = 0;
        i_updateInterval = updateInterval

        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId = "7d80a6386ef543a3abb52817f6707e3b";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

     function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > i_updateInterval;
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded,) = checkUpkeep("")
        if(!upkeepNeeded){
            revert FreelanceMarketplace__UpkeepNotNeeded()
        }

        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        // Set the URL to perform the GET request on
        req.add(
            "get",
            "https://api.github.com/repos/adwaitmandge/freelance-marketplace/commits"
        );

        req.add("path", "0,message"); // Chainlink nodes 1.0.0 and later support this format

        // Sends the request
        return sendChainlinkRequest(req, fee);
        // We don't use the performData in this example. The performData is generated by the Automation Node's call to your checkUpkeep function
    }

    /**
     * Receive the response in the form of uint256
     */
    function fulfill(
        bytes32 _requestId,
        string memory _recentCommitMessage
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestName(_requestId, _recentCommitMessage);
        s_recentCommitMessage = _recentCommitMessage;
    }

    ///////////////////////////
    //// Main functions //////
    ///////////////////////////

    function createReview(
        address freelancerAddress,
        string memory review,
        uint16 rating
    ) external {
        if (!s_clients[msg.sender]) {
            revert FreelanceMarketplace__ClientNotFound(msg.sender);
        }

        if (!s_freelancers[freelancerAddress]) {
            revert FreelanceMarketplace__FreelancerNotFound(freelancerAddress);
        }

        Review memory newReview = Review(
            msg.sender,
            freelancerAddress,
            review,
            rating
        );
        s_clientToReview[msg.sender].push(newReview);

        emit ReviewListed(msg.sender, freelancerAddress, review, rating);
    }

    function createProfile(
        string memory githubURL,
        string memory linkedInURL,
        string memory email,
        string memory profileHash
    ) external {
        if (
            bytes(githubURL).length == 0 ||
            bytes(linkedInURL).length == 0 ||
            bytes(email).length == 0 ||
            bytes(profileHash).length == 0
        ) {
            revert FreelanceMarketplace__MissingDetails();
        }

        Profile memory profile = Profile(
            githubURL,
            linkedInURL,
            email,
            profileHash
        );

        s_freelancerToProfile[msg.sender] = profile;

        /* Mint NFT with a predefined TOKEN_URI */
        // _safeMint(msg.sender, s_tokenCounter);
        // s_tokenCounter = s_tokenCounter + 1;
        // emit NftMinted(msg.sender, s_tokenCounter);

        emit ProfileComplete(
            msg.sender,
            githubURL,
            linkedInURL,
            email,
            profileHash
        );
    }

    function createRequest(address clientAddress, uint256 projectId) external {
        if (!s_freelancers[msg.sender]) {
            revert FreelanceMarketplace__FreelancerNotFound(msg.sender);
        }

        if (!s_clients[clientAddress]) {
            revert FreelanceMarketplace__ClientNotFound(clientAddress);
        }

        /* Project ID should exist */

        bool status = false;
        Project memory project = s_projects[projectId];
        Request memory request = Request(
            block.timestamp,
            msg.sender,
            clientAddress,
            status
        );
        s_freelancerRequests[msg.sender].push(request);
        s_clientRequests[clientAddress].push(request);

        emit RequestCreated(clientAddress, msg.sender, request.requestId);
    }

    function acceptRequest(Request memory request) external {
        // Client will accept the request of the freelancer
        // Reward the freelancer with a NFT
        uint256 requestId = request.requestId;
        address freelancer = request.freelancer;
        for (uint256 i = 0; i < s_freelancerRequests[freelancer].length; i++) {
            if (s_freelancerRequests[i].requestId == requestId) {
                s_freelancerRequests[i].status = true;
            }
        }
    }

    function projectSubmission() external {
        // Assign a special NFT for project Submission
    }

    function requestRandomWinner() external {
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGaslimit,
            NUM_WORDS
        );

        emit PoolPrizeWinnerRequested(requestId);
    }

    // Get the winner of the pool prize
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_elites.length;
        address winner = s_elites[winnerIndex];
        (bool success, ) = payable(winner).call{value: address(this).balance}(
            ""
        );

        emit PoolPrizeWinnerPicked(winner);
        s_recentWinner = winner;

        if (!success) {
            revert FreelanceMarketplace__TranserFailed();
        }

        _safeMint(winner, s_tokenCounter);
        s_tokenCounter = s_tokenCounter + 1;
        emit NftMinted(winner, s_tokenCounter);
    }

    /////////////////////////
    //// View / Pure  //////
    ///////////////////////

    function getProfile(
        address freelancerAddress
    ) external view returns (Profile memory) {
        Profile memory profile = s_freelancerToProfile[freelancerAddress];
        return profile;
    }

    function getClientReview(
        address clientAddress
    ) external view returns (Review[] memory) {
        Review[] memory allReviews = s_clientToReview[clientAddress];
        return allReviews;
    }

    function getFreelancerProjects(
        address freelancerAddress
    ) external view returns (Project[] memory) {
        Project[] memory allProjects = s_freelancerToProject[freelancerAddress];
        return allProjects;
    }

    function getNumRequestsFreelancer(
        address freelancerAddress
    ) external view returns (uint256) {
        if (!s_freelancers[freelancerAddress]) {
            revert FreelanceMarketplace__FreelancerNotFound(freelancerAddress);
        }

        return s_freelancerRequests[freelancerAddress].length;
    }

    function getNumRequestsClient(
        address clientAddress
    ) external view returns (uint256) {
        if (!s_clients[clientAddress]) {
            revert FreelanceMarketplace__ClientNotFound(clientAddress);
        }

        return s_clientRequests[clientAddress].length;
    }

    function getFreelancerBalance(
        address freelancerAddress
    ) external view returns (uint256) {
        if (!s_freelancers[msg.sender]) {
            revert FreelanceMarketplace__FreelancerNotFound(freelancerAddress);
        }
        return s_freelancerBalances[freelancerAddress];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
