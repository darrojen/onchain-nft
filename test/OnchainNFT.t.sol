// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OnchainNFT} from "../src/OnchainNFT.sol";

contract OnchainNFTTest is Test {
    OnchainNFT nft;

    address owner = address(this);
    address user = address(0x123);

    function setUp() public {
        nft = new OnchainNFT();
    }

    function testDeployment() public {
        assertEq(nft.name(), "Darlington Onchain");
        assertEq(nft.symbol(), "DART");
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

    function testTokenURIRequiresMetadata() public {
        nft.mint(user);

        vm.expectRevert("Data not found");
        nft.tokenURI(0);
    }

    function testStoreAndRetrieveData() public {
        bytes memory data = bytes("Hello onchain");

        nft.saveData(
            "test",
            0,
            data
        );

        bytes memory retrieved = nft.getData("test");

        assertEq(
            keccak256(retrieved),
            keccak256(data)
        );
    }

    function testRawSVG() public {
        bytes memory svg = bytes(
            '<svg xmlns="http://www.w3.org/2000/svg"><rect width="100" height="100"/></svg>'
        );

        nft.saveData(
            "image",
            0,
            svg
        );

        assertEq(
            keccak256(bytes(nft.rawSVG())),
            keccak256(
                bytes(
                    string(
                        abi.encodePacked(
                            "data:image/svg+xml;base64,",
                            _base64(svg)
                        )
                    )
                )
            )
        );
    }

    function testTokenURI() public {
        bytes memory metadata = bytes(
            '{"name":"Darlington Onchain #0","description":"Fully onchain NFT."}'
        );

        nft.saveData(
            "metadata",
            0,
            metadata
        );

        nft.mint(user);

        string memory expected = string(
            abi.encodePacked(
                "data:application/json;base64,",
                _base64(metadata)
            )
        );

        assertEq(
            nft.tokenURI(0),
            expected
        );
    }

    function _base64(bytes memory data)
        internal
        pure
        returns (string memory)
    {
        bytes memory table =
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

        if (data.length == 0) {
            return "";
        }

        uint256 encodedLength =
            4 * ((data.length + 2) / 3);

        string memory result =
            new string(encodedLength);

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let dataPtr := data
                let endPtr := add(dataPtr, mload(data))
            }
            lt(dataPtr, endPtr)
            {
                dataPtr := add(dataPtr, 3)
            }
            {
                let input := mload(dataPtr)

                mstore8(
                    resultPtr,
                    mload(
                        add(
                            tablePtr,
                            and(
                                shr(18, input),
                                0x3F
                            )
                        )
                    )
                )

                resultPtr := add(resultPtr, 1);

                mstore8(
                    resultPtr,
                    mload(
                        add(
                            tablePtr,
                            and(
                                shr(12, input),
                                0x3F
                            )
                        )
                    )
                );

                resultPtr := add(resultPtr, 1);

                mstore8(
                    resultPtr,
                    mload(
                        add(
                            tablePtr,
                            and(
                                shr(6, input),
                                0x3F
                            )
                        )
                    )
                );

                resultPtr := add(resultPtr, 1);

                mstore8(
                    resultPtr,
                    mload(
                        add(
                            tablePtr,
                            and(input, 0x3F)
                        )
                    )
                );

                resultPtr := add(resultPtr, 1);
            }

            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d);
                mstore8(sub(resultPtr, 2), 0x3d);
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d);
            }
        }

        return result;
    }
}

