// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGooStew {
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event DepositGobblers(address indexed owner, uint256 indexed stakingId, uint256[] gobblerIds, uint32 sumMultiples);
    event DepositGoo(address indexed owner, uint256 amount, uint256 shares);
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts
    );
    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount
    );
    event URI(string value, uint256 indexed id);

    function GOBBLER_STAKING_ID_START() external view returns (uint256);
    function GOO_SHARES_ID() external view returns (uint256);
    function MIN_GOO_SHARES_INITIAL_MINT() external view returns (uint256);
    function balanceOf(address, uint256) external view returns (uint256);
    function balanceOfBatch(address[] memory owners, uint256[] memory ids)
        external
        view
        returns (uint256[] memory balances);
    function deposit(uint256[] memory gobblerIds, uint256 gooAmount)
        external
        returns (uint256 gobblerStakingId, uint32 gobblerSumMultiples, uint256 gooShares);
    function gobblerStakingMap(uint256) external view returns (uint256 lastIndex);
    function isApprovedForAll(address, address) external view returns (bool);
    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        external
        returns (bytes4);
    function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4);
    function redeemGobblers(uint256 stakingId, uint256[] memory gobblerIds) external returns (uint256 gooAmount);
    function redeemGooShares(uint256 shares) external returns (uint256 gooAmount);
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
    function setApprovalForAll(address operator, bool approved) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function uri(uint256 id) external view returns (string memory);
}