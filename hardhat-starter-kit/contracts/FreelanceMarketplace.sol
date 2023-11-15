// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

error FreelanceMarketplace__ClientNotFound(address clientAddress);
error FreelanceMarketplace__FreelancerNotFound(address freelancerAddress);

contract FreelanceMarketplace {
    /* Custom Declarations */
    struct Review {
        address client;
        address freelancer;
        string review;
        uint16 rating;
    }

    struct Profile {
        string githubProfile;
        string linkedInProfile;
        string email;
        string hash;
    }

    /* Events */
    event ThirdPartyServicesLinked(
        string indexed githubProfile,
        string linkedInProfile,
        string indexed emailId
    );

    event ReviewListed(
        address indexed freelancer,
        address indexed client,
        string review,
        uint16 rating
    );

    /* Recording freelancer address when they sign up */
    mapping(address => bool) private s_freelancers;
    /* Recording clients address when they sign up */
    mapping(address => bool) private s_clients;
    /* Mapping a freelancer address to his/her reviews */
    mapping(address => Review) private s_freelancerToReview;
    /* Mapping a freelancer address to his/her profile */
    mapping(address => Profile) private s_freelancerToProfile;

    function postReview(
        address freelancerAddress,
        string memory review,
        uint16 rating
    ) external {
        if (!s_clients[msg.sender]) {
            revert FreelanceMarketplace__ClientNotFound();
        }

        if (!s_freelancers[freelancerAddress]) {
            revert FreelanceMarketplace__FreelancerNotFound();
        }

        Review memory newReview = Review(
            msg.sender,
            freelancerAddresss,
            review,
            rating
        );
        emit ReviewListed(freelancer, msg.sender, review, rating);
    }

    function getProfile(
        address freelancer
    ) external view returns (Profile memory) {
        Profile memory profile = s_freelancerToProfile[freelancer];
        return profile;
    }
}
