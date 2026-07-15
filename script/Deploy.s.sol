// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DarkPoolOrchestrator} from "../src/DarkPoolOrchestrator.sol";
import {MockFDC} from "../src/mocks/MockFDC.sol";

/// @dev Deploys MockFDC + DarkPoolOrchestrator to Coston2.
///      Run with:
///      forge script script/Deploy.s.sol --rpc-url coston2 --broadcast --verify -vvvv
contract DeployScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // For the enclave address: on real deployment this is the FCC
        // enclave's attested signing address. Until you have that, deploy
        // with the deployer itself as a placeholder so you can test
        // settleDarkOrders() locally, then call setEnclaveAddress() later.
        address enclavePlaceholder = deployer;

        vm.startBroadcast(deployerKey);

        MockFDC mockFdc = new MockFDC();
        console.log("MockFDC deployed at:", address(mockFdc));

        DarkPoolOrchestrator orchestrator = new DarkPoolOrchestrator(
            address(mockFdc),
            enclavePlaceholder
        );
        console.log("DarkPoolOrchestrator deployed at:", address(orchestrator));

        vm.stopBroadcast();
    }
}
