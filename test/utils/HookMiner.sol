// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

library HookMiner {
    uint256 constant HOOK_ADDRESS_MASK = uint160((1 << 14) - 1);

    // Returns the address that will result from deploying code via CREATE2 with the provided salt
    function computeAddress(
        address deployer,
        bytes32 salt,
        bytes32 bytecodeHash
    ) internal pure returns (address) {
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                hex"ff",
                                deployer,
                                salt,
                                bytecodeHash
                            )
                        )
                    )
                )
            );
    }

    // Returns the hash of the init code (creation code + no args) used by the hook
    function initcodeHash(
        bytes memory creationCode
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(creationCode));
    }

    // Returns a salt that will result in the provided address having the desired hooks
    function find(
        address deployer,
        bytes memory creationCode,
        uint160 targetFlags
    ) internal pure returns (bytes32) {
        bytes32 bytecodeHash = initcodeHash(creationCode);
        bytes32 salt = bytes32(0);
        while (true) {
            address hookAddress = computeAddress(deployer, salt, bytecodeHash);
            uint160 flags = uint160(
                uint256(uint160(hookAddress)) & HOOK_ADDRESS_MASK
            );
            if (flags == targetFlags) {
                return salt;
            }
            salt = bytes32(uint256(salt) + 1);
        }
    }
}
