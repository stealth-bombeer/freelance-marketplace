// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

error FreelanceMarketplace__ClientNotFound(address clientAddress);
error FreelanceMarketplace__FreelancerNotFound(address freelancerAddress);
error FreelanceMarketplace__MissingDetails();
error FreelanceMarketplace__TranserFailed();

contract FreelanceMarketplace is VRFConsumerBaseV2 {
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
        address freelancer;
        address client;
        uint256 startTime;
        uint256 deadline;
        bool isTaken;
    }

    struct Request {
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

    event RequestCreated(address indexed client, address indexed freelancer);
    event PoolPrizeWinnerRequested(uint256 indexed requestId);
    event PoolPrizeWinnerPicked(address indexed winner);

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
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_callbackGaslimit = callbackGasLimit;
        i_gasLane = gasLane;
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
        emit ProfileComplete(
            msg.sender,
            githubURL,
            linkedInURL,
            email,
            profileHash
        );
    }

    function createRequest(address clientAddress) external {
        if (!s_freelancers[msg.sender]) {
            revert FreelanceMarketplace__FreelancerNotFound(msg.sender);
        }

        if (!s_clients[clientAddress]) {
            revert FreelanceMarketplace__ClientNotFound(clientAddress);
        }

        bool status = false;
        Request memory request = Request(msg.sender, clientAddress, status);
        s_freelancerRequests[msg.sender].push(request);
        s_clientRequests[clientAddress].push(request);

        emit RequestCreated(clientAddress, msg.sender);
    }

    function acceptRequest() external {}

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

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_elites.length;
        address winner = s_elites[winnerIndex];
        (bool success, ) = payable(winner).call{value: address(this).balance}(
            ""
        );

        if (!success) {
            revert FreelanceMarketplace__TranserFailed();
        }

        emit PoolPrizeWinnerPicked(winner);
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
}
