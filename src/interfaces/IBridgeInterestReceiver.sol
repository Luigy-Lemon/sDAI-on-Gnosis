// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.18;

interface IBridgeInterestReceiver {
    function claim() external;

    function vaultAPY() external view returns (uint256);

    function previewClaimable() external view returns (uint256);
}
