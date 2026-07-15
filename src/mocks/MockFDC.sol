// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IFlareDataConnector} from "../DarkPoolOrchestrator.sol";

/// @notice Mock FDC for testnet/dev use. Owner manually flags deposits as
///         "verified" instead of relaying real BTC/XRP attestations.
///         Swap this out for the real FDC verifier before mainnet.
contract MockFDC is IFlareDataConnector {
    address public owner;
    mapping(bytes32 => bool) public verifiedDeposits;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Simulates an FDC relay: mark a deposit tx as verified.
    function mockVerifyDeposit(bytes32 txHash) external onlyOwner {
        verifiedDeposits[txHash] = true;
    }

    function verifyDeposit(bytes32 txHash, uint256 /* amount */, address /* depositor */)
        external
        view
        override
        returns (bool)
    {
        return verifiedDeposits[txHash];
    }
}
