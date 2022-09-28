// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;


interface IGobbleable {
    //TODO: Cast this

    function addGoo(uint256 gooAmount) external;
    function approve(address spender, uint256 id) external;
    function burnGooForPages(address user, uint256 gooAmount) external;
    function claimGobbler(bytes32[] memory proof) external returns (uint256 gobblerId);
    function gobble(uint256 gobblerId, address nft, uint256 id, bool isERC1155) external;
    function mintFromGoo(uint256 maxPrice, bool useVirtualBalance) external returns (uint256 gobblerId);

    function removeGoo(uint256 gooAmount) external;
    function safeTransferFrom(address from, address to, uint256 id) external;
}