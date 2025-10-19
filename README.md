# VoxNet

## Overview

VoxNet is a decentralized social media platform built in Clarity that enables censorship-resistant user interaction and monetized engagement. It supports features like user registration, following, posting, liking, tipping, and notifications, while maintaining a transparent and secure on-chain structure.

## Features

* **User Management**: Create, update, and manage user profiles with unique identifiers and optional avatars.
* **Social Graph**: Follow and unfollow users, track followers and following counts.
* **Content Creation**: Post text content with optional replies, visibility levels, and monetization settings.
* **Engagement System**: Like and unlike posts, track post interactions and statistics.
* **Monetization**: Send tips to users with optional post references and automatic platform fee deductions.
* **Notification System**: Generate and manage notifications for follows, likes, replies, tips, and mentions.
* **Admin Controls**: Adjust platform fees and minimum tip amounts.

## Data Structures

* **user-profiles**: Stores details about each user including bio, avatar, status, and tip settings.
* **follows**: Records follow relationships between users.
* **posts**: Contains post data such as author, content, visibility, monetization status, and engagement counts.
* **post-interactions**: Tracks likes and bookmarks per user per post.
* **notifications**: Holds user notifications for various activity types.

## Key Variables

* `next-post-id`: Tracks the next available post ID.
* `next-notification-id`: Tracks the next available notification ID.
* `platform-fee-percentage`: Platform service fee, default 2%.
* `fee-recipient`: Principal receiving platform fees.
* `max-post-length`: Defines the maximum allowed post content length.
* `min-tip-amount`: Sets the minimum tip threshold (1 STX default).

## Error Codes

* `ERR-NOT-FOUND (u404)`: Record not found.
* `ERR-UNAUTHORIZED (u401)`: Unauthorized access attempt.
* `ERR-INVALID-INPUT (u400)`: Invalid or malformed input data.
* `ERR-ALREADY-EXISTS (u409)`: Duplicate record detected.
* `ERR-FORBIDDEN (u403)`: Operation not permitted due to status restrictions.
* `ERR-INSUFFICIENT-FUNDS (u402)`: Insufficient STX balance.
* `ERR-INVALID-AMOUNT (u422)`: Invalid tip or transaction amount.

## Core Functions

* **register-user**: Registers a new user with profile details and initializes counts.
* **update-profile**: Allows users to modify display name, bio, and avatar.
* **follow-user / unfollow-user**: Manages follow relationships and updates follower counts.
* **create-post**: Publishes new posts with support for replies and visibility settings.
* **like-post / unlike-post**: Adds or removes a user’s like on a post and updates counters.
* **send-tip**: Sends a STX tip to another user or post author, deducting a platform fee.
* **mark-notification-read**: Marks notifications as read for the specified user.

## Private Function

* **create-notification**: Generates notifications for user actions with controlled content length.

## Admin Functions

* **update-platform-fee**: Updates the fee percentage charged per transaction (max 10%).
* **update-min-tip-amount**: Adjusts the minimum STX tipping threshold.

## Read-Only Functions

* **get-user-profile**: Returns user profile information.
* **get-post**: Retrieves a specific post’s details.
* **is-following**: Checks if one user follows another.
* **get-post-interaction**: Fetches user’s like and bookmark status for a post.
* **get-notification**: Fetches notification details by ID.
* **get-next-post-id / get-next-notification-id**: Returns the next ID counters.
* **get-platform-fee / get-min-tip-amount**: Returns current platform configurations.
* **get-contract-balance**: Shows total STX held by the contract.

## Validation Highlights

* Ensures unique user IDs and usernames.
* Enforces content length and visibility type constraints.
* Prevents self-follow, self-like, and self-tip actions.
* Verifies user and post active status before interaction.
* Protects against underflow during count decrements.

## Monetization Flow

1. A tipper initiates a `send-tip` transaction.
2. The contract validates sender balance, recipient status, and amount.
3. A 2% fee is deducted and transferred to the fee recipient.
4. The remaining amount is sent to the content creator.
5. The recipient’s total tips are updated and a notification is created.

## Initialization

* Fee recipient defaults to the contract deployer.
* Minimum tip set to 1 STX.
* All user accounts begin in “active” moderation status with tipping enabled.
