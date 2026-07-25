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
        console.log("MockFDC deployed at:"sed -i 's/DEPLOYMENT_PRIVATE_KEY=".*"/DEPLOYMENT_PRIVATE_KEY="0x271ae43ea6924a7f4138da8846cad9da2d814dc38ae33e1cf45d89da135b4ad6"/' /workspaces/duskflare/fce-extension/.envUint, address(mockFdc));

        DarkPoolOrchestrator orchestrator = new DarkPoolOrchestrator(
            address(mockFdc),
            enclavePlaceholder
        );
        console.log("DarkPoolOrchestrator deployed at:", address(orchestrator));

        vm.stopBroadcast();
    }
}
