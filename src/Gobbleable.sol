// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import {ArtGobblers} from "art-gobblers/ArtGobblers.sol";
import {IArtGobblers} from "./IArtGobblers.sol";
import {IGooStew} from "./IGooStew.sol";
import {Operated} from "./Operated.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";

/*

                                                 _.------.
                                                /         \_
                                             . |  O    O   |
                                            -  |  .vvvvv.  |\
                                               /  | . ' |  | \
                                            , /   `^^^^^'  /  \
                                            ./  /| ' | ,   |  /
                                           /   / |   ,     \_/
                                           \  /  |        /
                        888      888      88`'   |  _     |     888      888
                        888      888      888    '-' `-'-'|     888      888
                        888      888      888                   888      888
       .d88b.   .d88b.  88888b.  88888b.  888  .d88b.   8888b.  88888b.  888  .d88b.
      d88P"88b d88""88b 888 "88b 888 "88b 888 d8P  Y8b     "88b 888 "88b 888 d8P  Y8b
      888  888 888  888 888  888 888  888 888 88888888 .d888888 888  888 888 88888888
      Y88b 888 Y88..88P 888 d88P 888 d88P 888 Y8b.     888  888 888 d88P 888 Y8b.
       "Y88888  "Y88P"  88888P"  88888P"  888  "Y8888  "Y888888 88888P"  888  "Y8888
           888
      Y8b d88P
       "Y88P"

*/
/// @title Gobbleable
/// @author devtooligan
///
/// @notice This contract wraps an ArtGobblers nft ("Gobbler") in a distortion field, allowing it to be
/// gobbled by another Gobbler -- thereby circumventing their vow against Cannibalism().
///
/// @dev As part of the process, a Goo Discharge Portal (GDP) is implanted in the Gobbler allowing the owner
/// to retain control of the Gobbler even after it's been gobbled.  Using the GDP, the owner can  manage virtual
/// goo balance, gobble other nft's, and stake with Goo Stew, even after it's been gobbled and is sitting in the
/// belly of another Gobbler.
contract Gobbleable is Operated {
    // ArtGobblers
    IArtGobblers public immutable gobblers;
    uint256 public immutable id;
    address public owner;

    // Goo
    IERC20 public immutable goo;

    // GooStew
    IGooStew public immutable goostew;
    uint256 public gobblerStakingId; // state var

    // Errors
    error InvalidActionForGobbleableGobbler();

    // Events
    event Gobbled();
    event GooMorning();

    modifier unwrapped() {
        require(owner == address(0), "ALREADY WRAPPED");
        _;
    }

    constructor(
        IERC20 goo_,
        IGooStew goostew_,
        IArtGobblers gobblers_,
        uint256 id_,
        address operator_,
        uint256 gooamount
    ) Operated(operator_) {
        goo = goo_;
        gobblers = gobblers_;
        goostew = goostew_;
        id = id_;
        if (gooamount > 0) {
            goo_.transferFrom(msg.sender, address(this), gooamount);
        }
    }

    /// @dev Wraps Gobbler in distortion field allowing it to be gobbled by other Gobblers
    function wrap() external onlyOperator unwrapped {
        gobblers.safeTransferFrom(operator, address(this), id);
        goo.approve(owner, type(uint256).max); //approve max to address(0)? maybe it should be address(this)?
        goo.approve(address(goostew), type(uint256).max);
        goo.approve(address(gobblers), type(uint256).max);
        gobblers.approve(address(goostew), id);
        owner = gobblers.ownerOf(id); //the owner is this contract. ln 122 says this shouldn't be the case. set this to the operator? maybe its the owner before its transferred to this contract?
        emit GooMorning();
    }

    /* GOO DISCHARGE PORTAL FUNCTIONS
     ******************************************************************************************************************/

    function addGoo(uint256 gooAmount) external onlyOperator {
        return gobblers.addGoo(gooAmount);
    }

    function gobble(
        address nft,
        uint256 nftId,
        bool isERC1155
    ) external onlyOperator {
        return gobblers.gobble(id, nft, nftId, isERC1155);
    }

    function gooBalance() external view returns (uint256) {
        return gobblers.gooBalance(address(this));
    }

    function ownerOf(uint256 id_) external returns (address) {
        if (id == id_) {
            return owner;
        }
    }

    // @dev mints new gobbler and transfers to owner, this contract cannot own multiple gobblers
    function mintFromGoo(uint256 maxPrice, bool useVirtualBalance) external onlyOperator returns (uint256 gobblerId) {
        uint256 newGobblerId = gobblers.mintFromGoo(maxPrice, useVirtualBalance);
        gobblers.safeTransferFrom(address(this), owner, newGobblerId); //transfers to this contract since the contract is the owner.
    }

    function removeGoo(uint256 gooAmount) external onlyOperator {
        return gobblers.removeGoo(gooAmount);
    }

    /// @dev this transfers goo tokens out of this contract
    function retrieveGoo(uint256 gooAmount, address to) external onlyOperator {
        goo.transfer(to, gooAmount); //prevent transfers to this contract?
    }

    /// @dev this fn is used by ArtGobblers.gobble() when being gobbled by another Gobbler.
    function transferFrom(
        address from,
        address to,
        uint256 id_
    ) external {
        //looks like anyone can call this outside of the ArtGobble Contract potentially trapping the gobblealble
        require(id_ == id && from == operator && to == address(gobblers), "ONLY ARTGOBBLERS");
        owner = to; // address(gobblers)
        emit Gobbled();
    }

    /* GOOSTEW FUNCTIONS
     ******************************************************************************************************************/

    /// @dev deposit goo and gobbler into goostew
    function gooStewDeposit(uint256 amount)
        external
        returns (
            uint256 gobblerStakingId_,
            uint32 gobblerSumMultiples,
            uint256 gooShares
        )
    {
        if (amount > 0) {
            goo.transferFrom(msg.sender, address(this), amount);
        }
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        (gobblerStakingId_, gobblerSumMultiples, gooShares) = goostew.deposit(ids, amount);
        gobblerStakingId = gobblerStakingId_;
    }

    function gooStewRedeemGooShares(uint256 shares) external returns (uint256 gooAmount) {
        return goostew.redeemGooShares(shares);
    }

    function gooStewRedeemGobbler() external returns (uint256 gooAmount) {
        uint256[] memory gobblerIds = new uint256[](1);
        gobblerIds[0] = id;
        return goostew.redeemGobblers(gobblerStakingId, gobblerIds);
    }

    /* DISABLED FUNCTIONS
     ******************************************************************************************************************/
    function approve(address spender, uint256 id_) external {
        revert InvalidActionForGobbleableGobbler();
    }

    /// @dev To gobble, use function "gobble(address nft, uint256 id_, bool isERC1155) external"
    function gobble(
        uint256 gobblerId,
        address nft,
        uint256 id_,
        bool isERC1155
    ) external {
        revert InvalidActionForGobbleableGobbler();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id_,
        bytes memory data
    ) external {
        revert InvalidActionForGobbleableGobbler();
    }

    function setApprovalForAll(address operator, bool approved) external {
        revert InvalidActionForGobbleableGobbler();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id_
    ) external {
        revert InvalidActionForGobbleableGobbler();
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    fallback() external {
        // Any ArtGobblers functions not listed above will be called from this fallback fn,
        // including tokenURI() and other view functions.
        address gobblers_ = address(gobblers);
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch space at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let success := call(gas(), gobblers_, 0, 0, calldatasize(), 0, 0)

            // copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch success
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
