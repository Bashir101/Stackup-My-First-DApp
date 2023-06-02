// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract StackUp {
    enum PlayerQuestStatus {
        NOT_JOINED,
        JOINED,
        SUBMITTED
    }

    enum QuestStatus {
        OPEN,
        CLOSED,
        REVIEW,
        REJECTED,
        APPROVED
    }

    struct Quest {
        uint256 questId;               // Unique identifier for the quest
        uint256 numberOfPlayers;       // Number of players who joined the quest
        string title;                  // Title of the quest
        uint8 reward;                  // Reward points for completing the quest
        uint256 numberOfRewards;       // Number of available rewards for the quest
        uint256 startTime;             // Start time of the quest
        uint256 endTime;               // End time of the quest
        QuestStatus status;            // Current status of the quest
    }

    struct Submission {
        uint256 questId;               // ID of the quest the submission belongs to
        address player;                // Address of the player who made the submission
        string proof;                  // Proof submitted by the player
    }

    struct Campaign {
        uint256 campaignId;            // Unique identifier for the campaign
        string title;                  // Title of the campaign
        uint256[] questIds;            // Array of quest IDs associated with the campaign
    }

    address public admin;               // Address of the admin
    uint256 public nextQuestId;         // ID for the next quest
    uint256 public nextSubmissionId;    // ID for the next submission
    uint256 public nextCampaignId;      // ID for the next campaign
    mapping(uint256 => Quest) public quests;                  // Mapping of quest ID to Quest struct
    mapping(address => mapping(uint256 => PlayerQuestStatus)) public playerQuestStatuses;   // Mapping of player address and quest ID to PlayerQuestStatus enum
    mapping(uint256 => Submission) public submissions;         // Mapping of submission ID to Submission struct
    mapping(uint256 => Campaign) public campaigns;             // Mapping of campaign ID to Campaign struct

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can perform this action");
        _;
    }

    modifier questExists(uint256 questId) {
        require(quests[questId].questId != 0, "Quest does not exist");
        _;
    }

    modifier questOpen(uint256 questId) {
        require(quests[questId].status == QuestStatus.OPEN, "Quest is not open");
        _;
    }

    modifier questNotClosed(uint256 questId) {
        require(quests[questId].status != QuestStatus.CLOSED, "Quest is closed");
        _;
    }

    modifier questInProgress(uint256 questId) {
        require(
            quests[questId].status == QuestStatus.OPEN ||
                (quests[questId].status == QuestStatus.REVIEW && quests[questId].endTime > block.timestamp),
            "Quest is not in progress"
        );
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // Create a new quest
    function createQuest(
        string calldata title_,
        uint8 reward_,
        uint256 numberOfRewards_,
        uint256 startTime_,
        uint256 endTime_
    ) external onlyAdmin {
        quests[nextQuestId] = Quest({
            questId: nextQuestId,
            numberOfPlayers: 0,
            title: title_,
            reward: reward_,
            numberOfRewards: numberOfRewards_,
            startTime: startTime_,
            endTime: endTime_,
            status: QuestStatus.OPEN
        });
        nextQuestId++;
    }

    // Edit an existing quest
    function editQuest(
        uint256 questId,
        string calldata title_,
        uint8 reward_,
        uint256 numberOfRewards_,
        uint256 startTime_,
        uint256 endTime_
    ) external onlyAdmin questExists(questId) questNotClosed(questId) {
        Quest storage quest = quests[questId];
        quest.title = title_;
        quest.reward = reward_;
        quest.numberOfRewards = numberOfRewards_;
        quest.startTime = startTime_;
        quest.endTime = endTime_;
    }

    // Delete a quest
    function deleteQuest(uint256 questId) external onlyAdmin questExists(questId) questNotClosed(questId) {
        delete quests[questId];
    }

    // Allow a player to join a quest
    function joinQuest(uint256 questId) external questExists(questId) questOpen(questId) {
        require(
            playerQuestStatuses[msg.sender][questId] == PlayerQuestStatus.NOT_JOINED,
            "Player has already joined/submitted this quest"
        );

        playerQuestStatuses[msg.sender][questId] = PlayerQuestStatus.JOINED;
        quests[questId].numberOfPlayers++;
    }

    // Submit a quest by a player
    function submitQuest(uint256 questId, string calldata proof) external questExists(questId) questInProgress(questId) {
        require(
            playerQuestStatuses[msg.sender][questId] == PlayerQuestStatus.JOINED,
            "Player must first join the quest"
        );

        playerQuestStatuses[msg.sender][questId] = PlayerQuestStatus.SUBMITTED;

        nextSubmissionId++;
        submissions[nextSubmissionId] = Submission({
            questId: questId,
            player: msg.sender,
            proof: proof
        });

        quests[questId].status = QuestStatus.REVIEW;
    }

    // Review a submission and approve/reject it
    function reviewSubmission(uint256 submissionId, bool approved) external onlyAdmin {
        Submission storage submission = submissions[submissionId];
        Quest storage quest = quests[submission.questId];

        require(quest.status == QuestStatus.REVIEW, "Quest is not in the review phase");
        require(submissionId <= nextSubmissionId, "Invalid submission ID");

        if (approved) {
            quest.status = QuestStatus.APPROVED;
            // Perform reward distribution to the player
        } else {
            quest.status = QuestStatus.REJECTED;
        }
    }

    // Create a new campaign
    function createCampaign(string calldata title, uint256[] calldata questIds) external onlyAdmin {
        campaigns[nextCampaignId] = Campaign({
            campaignId: nextCampaignId,
            title: title,
            questIds: questIds
        });
        nextCampaignId++;
    }

    // Get the quest IDs associated with a campaign
    function getCampaignQuests(uint256 campaignId) external view returns (uint256[] memory) {
        return campaigns[campaignId].questIds;
    }

    // Get the total number of campaigns
    function getCampaignCount() external view returns (uint256) {
        return nextCampaignId;
    }
}