pragma solidity ^0.8.10;

interface Interface {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function depositXDAI(address receiver) external payable returns (uint256);
    function interestReceiver() external view returns (address);
    function mint(uint256 shares, address receiver) external returns (uint256);
    function redeem(uint256 shares, address receiver) external returns (uint256);
    function redeemAll(address receiver) external returns (uint256);
    function redeemAllXDAI(address receiver) external payable returns (uint256);
    function sDAI() external view returns (address);
    function vaultAPY() external returns (uint256);
    function redeemXDAI(uint256 shares, address receiver) external payable returns (uint256);
    function withdraw(uint256 assets, address receiver) external returns (uint256);
    function withdrawXDAI(uint256 assets, address receiver) external payable returns (uint256);
    function wxdai() external view returns (address);
}
