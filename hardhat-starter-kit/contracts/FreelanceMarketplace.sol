// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

error FreelanceMarketplace__ClientNotFound(address clientAddress);
error FreelanceMarketplace__FreelancerNotFound(address freelancerAddress);
error FreelanceMarketplace__MissingDetails();

contract FreelanceMarketplace {
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
    /* Keep track of all the projects */
    Project[] private s_projects;

    function postReview(
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

        Request memory request = Request(msg.sender, clientAddress);
        s_freelancerRequests[msg.sender].push(request);
        s_clientRequests[clientAddress].push(request);
        emit RequestCreated(clientAddress, msg.sender);
    }

    /* View / Pure Functions */
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

    function getNumRequestsFreelancer() external view returns (uint256) {
        if (!s_freelancers[msg.sender]) {
            revert FreelanceMarketplace__FreelancerNotFound(msg.sender);
        }

        return s_freelancerRequests[msg.sender].length;
    }

    function getNumRequestsClient() external view returns (uint256) {
        if (!s_clients[msg.sender]) {
            revert FreelanceMarketplace__ClientNotFound(msg.sender);
        }

        return s_clientRequests[msg.sender].length;
    }

    // function removeFreelancer(address freelancer) {
    // }
}
