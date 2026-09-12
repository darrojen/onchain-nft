// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Repository: https://github.com/darrojen/onchain-nft.git
// Commit: YOUR_COMMIT_HASH
// Testnet: Celo Sepolia
// Contract: https://sepolia.celoscan.io/address/0x8e49861863C9d51E9127F83Efa52c69f21981902
// Deployment transaction: https://sepolia.celoscan.io/tx/0xdb2e0ed984c7d20396b9d71eb320dc1121cce0ea434b07a274492d1a479b95ab
// Mint transaction: https://sepolia.celoscan.io/tx/0xc62ab4609bfd93d1994f332bfb3e8e4119137e86aaf73a45da3a55cbff4d2393

contract Base64 {
    string internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function encode(bytes memory data) public pure returns (string memory) {
        if (data.length == 0) {
            return "";
        }

        string memory table = TABLE;

        uint256 encodedLength = 4 * ((data.length + 2) / 3);

        string memory result = new string(encodedLength + 32);

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let dataPtr := data
                let endPtr := add(dataPtr, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                dataPtr := add(dataPtr, 3)

                let input := mload(dataPtr)

                mstore8(
                    resultPtr,
                    mload(add(tablePtr, and(shr(18, input), 0x3F)))
                )

                resultPtr := add(resultPtr, 1)

                mstore8(
                    resultPtr,
                    mload(add(tablePtr, and(shr(12, input), 0x3F)))
                )

                resultPtr := add(resultPtr, 1)

                mstore8(
                    resultPtr,
                    mload(add(tablePtr, and(shr(6, input), 0x3F)))
                )

                resultPtr := add(resultPtr, 1)

                mstore8(
                    resultPtr,
                    mload(add(tablePtr, and(input, 0x3F)))
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

            mstore(result, encodedLength)
        }

        return result;
    }
}

contract OnchainNFT is Base64 {
    string public constant name = "Darlington Onchain";
    string public constant symbol = "DART";

    address public owner;

    uint256 private _nextTokenId;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    struct ContractData {
        address rawContract;
        uint128 size;
        uint128 offset;
    }

    struct ContractDataPages {
        uint256 maxPageNumber;
        bool exists;
        mapping(uint256 => ContractData) pages;
    }

    mapping(string => ContractDataPages) internal _contractDataPages;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    event DataSaved(
        string indexed key,
        uint256 indexed page,
        address dataContract,
        uint256 size
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ------------------------------------------------------------
    // ERC-721
    // ------------------------------------------------------------

    function balanceOf(address account) public view returns (uint256) {
        require(account != address(0), "Zero address");
        return _balances[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];

        require(tokenOwner != address(0), "Token does not exist");

        return tokenOwner;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        pure
        returns (bool)
    {
        return interfaceId == 0x80ac58cd || interfaceId == 0x5b5e139f;
    }

    function mint(address to) external onlyOwner returns (uint256 tokenId) {
        require(to != address(0), "Zero address");

        tokenId = _nextTokenId;

        _nextTokenId++;

        _owners[tokenId] = to;
        _balances[to]++;

        emit Transfer(address(0), to, tokenId);
    }

    // ------------------------------------------------------------
    // Timidan-style bytecode storage
    // ------------------------------------------------------------

    function saveData(
        string memory key,
        uint256 pageNumber,
        bytes memory data
    ) external onlyOwner {
        require(data.length > 0, "Empty data");

        // EIP-170 runtime bytecode limit is 24,576 bytes.
        // We use 24,575 to stay safely below the limit.
        require(
            data.length <= 24575,
            "Data page too large"
        );

        /*
            Runtime storage contract:

            PUSH2 size
            PUSH1 0x0e
            PUSH1 0
            CODECOPY
            PUSH2 size
            PUSH1 0
            RETURN
        */

        bytes memory init = hex"610000600e6000396100006000f3";

        uint256 length = data.length;

        init[1] = bytes1(uint8(length >> 8));
        init[2] = bytes1(uint8(length));

        init[9] = bytes1(uint8(length >> 8));
        init[10] = bytes1(uint8(length));

        bytes memory creationCode = abi.encodePacked(
            init,
            data
        );

        address dataContract;

        assembly {
            dataContract := create(
                0,
                add(creationCode, 32),
                mload(creationCode)
            )
        }

        require(dataContract != address(0), "Storage deployment failed");

        ContractDataPages storage pages = _contractDataPages[key];

        if (pageNumber > pages.maxPageNumber) {
            pages.maxPageNumber = pageNumber;
        }

        pages.exists = true;

        pages.pages[pageNumber] = ContractData({
            rawContract: dataContract,
            size: uint128(data.length),
            offset: 0
        });

        emit DataSaved(
            key,
            pageNumber,
            dataContract,
            data.length
        );
    }

    function getSizeOfPages(string memory key)
        public
        view
        returns (uint256 totalSize)
    {
        ContractDataPages storage pages = _contractDataPages[key];

        if (!pages.exists) {
            return 0;
        }

        for (
            uint256 i = 0;
            i <= pages.maxPageNumber;
            i++
        ) {
            totalSize += pages.pages[i].size;
        }
    }

    function getData(string memory key)
        public
        view
        returns (bytes memory)
    {
        ContractDataPages storage pages = _contractDataPages[key];

        require(pages.exists, "Data not found");

        uint256 totalSize = getSizeOfPages(key);

        bytes memory result = new bytes(totalSize);

        uint256 currentPointer = 32;

        for (
            uint256 i = 0;
            i <= pages.maxPageNumber;
            i++
        ) {
            ContractData storage page = pages.pages[i];

            assembly {
                extcodecopy(
                    sload(add(page.slot, 0)),
                    add(result, currentPointer),
                    0,
                    sload(add(page.slot, 1))
                )
            }

            currentPointer += page.size;
        }

        return result;
    }

    function hasData(string memory key)
        public
        view
        returns (bool)
    {
        return _contractDataPages[key].exists;
    }

    // ------------------------------------------------------------
    // NFT metadata
    // ------------------------------------------------------------

    function tokenURI(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        require(
            _owners[tokenId] != address(0),
            "Token does not exist"
        );

        bytes memory metadata = getData("metadata");

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(metadata)
            )
        );
    }

    function rawSVG()
        public
        view
        returns (string memory)
    {
        bytes memory svg = getData("image");

        return string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(svg)
            )
        );
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {
        require(ownerOf(tokenId) == from, "Not owner");
        require(to != address(0), "Zero address");
        require(
            msg.sender == from,
            "Transfers not approved"
        );

        _owners[tokenId] = to;

        _balances[from]--;
        _balances[to]++;

        emit Transfer(from, to, tokenId);
    }
}