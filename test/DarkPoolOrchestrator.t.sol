// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DarkPoolOrchestrator} from "../src/DarkPoolOrchestrator.sol";
import {MockFDC} from "../src/mocks/MockFDC.sol";

contract DarkPoolOrchestratorTest is Test {
    DarkPoolOrchestrator orchestrator;
    MockFDC fdc;

    address owner = address(this);
    address enclave = address(0xE1);
    address traderA = address(0xA1);
    address traderB = address(0xB1);

    function setUp() public {
        fdc = new MockFDC();
        orchestrator = new DarkPoolOrchestrator(address(fdc), enclave);
    }

    function testSubmitAndSettleOrderPair() public {
        bytes32 txHashA = keccak256("btc-deposit-a");
        bytes32 txHashB = keccak256("xrp-deposit-b");

        fdc.mockVerifyDeposit(txHashA);
        fdc.mockVerifyDeposit(txHashB);

        vm.prank(traderA);
        bytes32 orderIdA = orchestrator.submitDarkOrder(
            txHashA,
            1 ether,
            DarkPoolOrchestrator.AssetType.BTC,
            DarkPoolOrchestrator.AssetType.XRP,
            bytes("encrypted-payload-a")
        );

        vm.prank(traderB);
        bytes32 orderIdB = orchestrator.submitDarkOrder(
            txHashB,
            1000 ether,
            DarkPoolOrchestrator.AssetType.XRP,
            DarkPoolOrchestrator.AssetType.BTC,
            bytes("encrypted-payload-b")
        );

        vm.prank(enclave);
        orchestrator.settleDarkOrders(orderIdA, orderIdB);

        DarkPoolOrchestrator.EncryptedOrder memory a = orchestrator.getOrder(orderIdA);
        DarkPoolOrchestrator.EncryptedOrder memory b = orchestrator.getOrder(orderIdB);

        assertEq(uint8(a.status), uint8(DarkPoolOrchestrator.OrderStatus.Settled));
        assertEq(uint8(b.status), uint8(DarkPoolOrchestrator.OrderStatus.Settled));
    }

    function testCannotSubmitWithoutVerifiedDeposit() public {
        bytes32 txHash = keccak256("unverified-deposit");
        vm.prank(traderA);
        vm.expectRevert("Invalid deposit proof");
        orchestrator.submitDarkOrder(
            txHash,
            1 ether,
            DarkPoolOrchestrator.AssetType.BTC,
            DarkPoolOrchestrator.AssetType.XRP,
            bytes("payload")
        );
    }

    function testOnlyEnclaveCanSettle() public {
        bytes32 txHashA = keccak256("btc-deposit-a2");
        bytes32 txHashB = keccak256("xrp-deposit-b2");
        fdc.mockVerifyDeposit(txHashA);
        fdc.mockVerifyDeposit(txHashB);

        vm.prank(traderA);
        bytes32 orderIdA = orchestrator.submitDarkOrder(
            txHashA, 1 ether, DarkPoolOrchestrator.AssetType.BTC, DarkPoolOrchestrator.AssetType.XRP, bytes("a")
        );
        vm.prank(traderB);
        bytes32 orderIdB = orchestrator.submitDarkOrder(
            txHashB, 1000 ether, DarkPoolOrchestrator.AssetType.XRP, DarkPoolOrchestrator.AssetType.BTC, bytes("b")
        );

        vm.expectRevert("Only FCC Enclave can execute");
        orchestrator.settleDarkOrders(orderIdA, orderIdB);
    }
}
