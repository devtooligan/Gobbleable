// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Utilities} from "art-gobblers/test/utils/Utilities.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdError} from "forge-std/Test.sol";
import {ArtGobblers, FixedPointMathLib} from "art-gobblers/src/ArtGobblers.sol";
import {Goo} from "art-gobblers/src/Goo.sol";
import {Pages} from "art-gobblers/src/Pages.sol";
import {RandProvider} from "art-gobblers/src/utils/rand/RandProvider.sol";
import {ChainlinkV1RandProvider} from "art-gobblers/src/utils/rand/ChainlinkV1RandProvider.sol";
import {LinkToken} from "art-gobblers/test/utils/mocks/LinkToken.sol";
import {VRFCoordinatorMock} from "lib/chainlink/contracts/src/v0.8/mocks/VRFCoordinatorMock.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {MockERC1155} from "solmate/test/utils/mocks/MockERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {fromDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";
import {Gobbleable} from "../src/Gobbleable.sol";
import {IArtGobblers} from "../src/IArtGobblers.sol";
import {IGooStew} from "../src/IGooStew.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {GooStew} from "lib/goostew/src/GooStew.sol";

/// @notice Unit test for Art Gobbler Contract.
contract ArtGobblersTest is Test {
    using LibString for uint256;

    Utilities internal utils;
    address payable[] internal users;

    ArtGobblers internal gobblers;
    VRFCoordinatorMock internal vrfCoordinator;
    LinkToken internal linkToken;
    Goo internal goo;
    Pages internal pages;
    RandProvider internal randProvider;
    GooStew internal stew;

    bytes32 private keyHash;
    uint256 private fee;

    uint256[] ids;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorMock(address(linkToken));

        //gobblers contract will be deployed after 4 contract deploys, and pages after 5
        address gobblerAddress = utils.predictContractAddress(address(this), 4);
        address pagesAddress = utils.predictContractAddress(address(this), 5);

        randProvider = new ChainlinkV1RandProvider(
            ArtGobblers(gobblerAddress),
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            fee
        );

        goo = new Goo(
            // Gobblers:
            utils.predictContractAddress(address(this), 1),
            // Pages:
            utils.predictContractAddress(address(this), 2)
        );

        gobblers = new ArtGobblers(
            keccak256(abi.encodePacked(users[0])),
            block.timestamp,
            goo,
            Pages(pagesAddress),
            address(0x0),
            address(0x0),
            randProvider,
            "base",
            ""
        );

        pages = new Pages(block.timestamp, goo, address(0xBEEF), gobblers, "");

        stew = new GooStew(address(gobblers), address(goo));
    }

    /*//////////////////////////////////////////////////////////////
                               FEEDING ART
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that gobblers can't eat other gobblers
    function testCantFeedGobblers() public {
        address user = users[0];
        mintGobblerToAddress(user, 2);
        vm.startPrank(user);
        vm.expectRevert(ArtGobblers.Cannibalism.selector);
        gobblers.gobble(1, address(gobblers), 2, true);
        vm.stopPrank();
    }

    /// @notice Test that gobblers can eat other gobblers via Gobbleable
    function testCanFeedGobbleables() public {
        address user = users[0];
        mintGobblerToAddress(user, 2);
        Gobbleable gobbleable = new Gobbleable(
            IERC20(address(goo)),
            IGooStew(address(0)),
            IArtGobblers(address(gobblers)),
            1,
            user,
            0
        );

        vm.startPrank(user);
        gobblers.approve(address(gobbleable), 1);
        gobbleable.wrap();
        gobblers.gobble(2, address(gobbleable), 1, false);
        vm.stopPrank();
    }

    function testGooStew() public {
        address user = users[0];
        mintGobblerToAddress(user, 2);
        Gobbleable gobbleable = new Gobbleable(
            IERC20(address(goo)),
            IGooStew(address(stew)),
            IArtGobblers(address(gobblers)),
            1,
            user,
            0
        );

        vm.startPrank(user);
        gobblers.approve(address(gobbleable), 1);
        gobbleable.wrap();
        gobblers.gobble(2, address(gobbleable), 1, false);
        gobbleable.gooStewDeposit(0);
        gobbleable.gooStewRedeemGobbler();
        vm.stopPrank();
    }

    function testRetrieveGoo() public {
        address user = users[0];
        mintGobblerToAddress(user, 2);
        Gobbleable gobbleable = new Gobbleable(
            IERC20(address(goo)),
            IGooStew(address(stew)),
            IArtGobblers(address(gobblers)),
            1,
            user,
            0
        );

        mintGooToAddress(address(gobbleable));
        vm.startPrank(user);
        gobblers.approve(address(gobbleable), 1);
        gobbleable.wrap();
        gobbleable.retrieveGoo(1, user);
        vm.stopPrank();
    }

    function testMintFromGoo() public {
        address user = users[0];
        mintGobblerToAddress(user, 2);
        Gobbleable gobbleable = new Gobbleable(
            IERC20(address(goo)),
            IGooStew(address(stew)),
            IArtGobblers(address(gobblers)),
            1,
            user,
            0
        );

        mintGooToAddress(address(gobbleable));

        vm.startPrank(user);
        gobblers.approve(address(gobbleable), 1);
        gobbleable.wrap();

        address owner = gobbleable.owner();

        gobbleable.mintFromGoo(type(uint256).max, false);
        vm.stopPrank();

        assertEq(gobblers.balanceOf(owner), 2);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint a number of gobblers to the given address
    function mintGobblerToAddress(address addr, uint256 num) internal {
        for (uint256 i; i < num; ++i) {
            vm.startPrank(address(gobblers));
            goo.mintForGobblers(addr, gobblers.gobblerPrice());
            vm.stopPrank();

            uint256 gobblersOwnedBefore = gobblers.balanceOf(addr);

            vm.prank(addr);
            gobblers.mintFromGoo(type(uint256).max, false);

            assertEq(gobblers.balanceOf(addr), gobblersOwnedBefore + 1);
        }
    }

    /// @notice Mint an amount of goo to the given address
    function mintGooToAddress(address addr) internal {
        vm.startPrank(address(gobblers));
        goo.mintForGobblers(addr, gobblers.gobblerPrice());
        vm.stopPrank();
    }
}
