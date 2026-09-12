// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {OnchainNFT} from "../src/OnchainNFT.sol";

contract DeployAndMint is Script {
    uint256 constant CHUNK_SIZE = 24575;

    function run() external returns (OnchainNFT nft) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        nft = new OnchainNFT();

        bytes memory svg = vm.readFileBinary(
            "assets/image.svg"
        );

        string memory svgBase64 = _base64(svg);

        string memory metadata = string(
            abi.encodePacked(
                '{"name":"Darlington Onchain #0",',
                '"description":"A fully onchain SVG NFT.",',
                '"image":"data:image/svg+xml;base64,',
                svgBase64,
                '"}'
            )
        );

        bytes memory metadataBytes = bytes(metadata);

        _upload(
            nft,
            "image",
            svg
        );

        _upload(
            nft,
            "metadata",
            metadataBytes
        );

        nft.mint(vm.addr(privateKey));

        vm.stopBroadcast();
    }

    function _upload(
        OnchainNFT nft,
        string memory key,
        bytes memory data
    ) internal {
        uint256 page = 0;

        for (
            uint256 start = 0;
            start < data.length;
            start += CHUNK_SIZE
        ) {
            uint256 remaining = data.length - start;

            uint256 length = remaining > CHUNK_SIZE
                ? CHUNK_SIZE
                : remaining;

            bytes memory chunk = new bytes(length);

            for (uint256 i = 0; i < length; i++) {
                chunk[i] = data[start + i];
            }

            nft.saveData(
                key,
                page,
                chunk
            );

            page++;
        }
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

                resultPtr := add(resultPtr, 1)

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
                )

                resultPtr := add(resultPtr, 1)

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
                )

                resultPtr := add(resultPtr, 1)

                mstore8(
                    resultPtr,
                    mload(
                        add(
                            tablePtr,
                            and(input, 0x3F)
                        )
                    )
                )

                resultPtr := add(resultPtr, 1)
            }

            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}