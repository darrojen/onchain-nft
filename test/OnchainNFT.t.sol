// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OnchainNFT} from "../src/OnchainNFT.sol";
import {Test} from "forge-std/Test.sol";

contract OnchainNFTTest is Test {
    OnchainNFT nft;

    address owner = address(this);
    address user = address(0x1234);

    function setUp() public {
        nft = new OnchainNFT();
    }

    function testOwner() public view {
        assertEq(nft.owner(), owner);
    }

    function testMint() public {
        uint256 tokenId = nft.mint(user);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(0), user);
        assertEq(nft.balanceOf(user), 1);
    }

    function testMultipleMints() public {
        uint256 firstToken = nft.mint(user);
        uint256 secondToken = nft.mint(user);

        assertEq(firstToken, 0);
        assertEq(secondToken, 1);

        assertEq(nft.ownerOf(0), user);
        assertEq(nft.ownerOf(1), user);
        assertEq(nft.balanceOf(user), 2);
    }

    function testSaveAndGetData() public {
        bytes memory testData = bytes("Hello Onchain");

        nft.saveData("test", 0, testData);

        assertTrue(nft.hasData("test"));

        bytes memory retrieved = nft.getData("test");

        assertEq(retrieved, testData);
        assertEq(nft.getSizeOfPages("test"), testData.length);
    }

    function testSVGData() public {
        bytes memory svg = bytes(
            '<svg xmlns="http://www.w3.org/2000/svg"><text>Hello</text></svg>'
        );

        nft.saveData("image", 0, svg);

        string memory result = nft.rawSVG();

        assertTrue(bytes(result).length > 0);

        bytes memory resultBytes = bytes(result);

        bytes memory prefix = bytes("data:image/svg+xml;base64,");

        assertTrue(_startsWith(resultBytes, prefix));
    }

    function testTokenURI() public {
        uint256 tokenId = nft.mint(user);

        bytes memory metadata = bytes(
            '{"name":"Darlington Onchain","description":"Fully onchain NFT","image":"data:image/svg+xml;base64,TEST"}'
        );

        nft.saveData("metadata", 0, metadata);

        string memory uri = nft.tokenURI(tokenId);

        bytes memory uriBytes = bytes(uri);
        bytes memory prefix = bytes("data:application/json;base64,");

        assertTrue(_startsWith(uriBytes, prefix));
    }

    function testSupportsERC721Interface() public view {
        assertTrue(nft.supportsInterface(0x80ac58cd));
    }

    function testSupportsMetadataInterface() public view {
        assertTrue(nft.supportsInterface(0x5b5e139f));
    }

    function testTransfer() public {
        nft.mint(user);

        vm.prank(user);
        nft.transferFrom(user, address(0x5678), 0);

        assertEq(nft.ownerOf(0), address(0x5678));
        assertEq(nft.balanceOf(user), 0);
        assertEq(nft.balanceOf(address(0x5678)), 1);
    }

    function _startsWith(
        bytes memory data,
        bytes memory prefix
    ) internal pure returns (bool) {
        if (data.length < prefix.length) {
            return false;
        }

        for (uint256 i = 0; i < prefix.length; i++) {
            if (data[i] != prefix[i]) {
                return false;
            }
        }

        return true;
    }
}
