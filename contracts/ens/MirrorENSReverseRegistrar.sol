//SPDX-License-Identifier: BSD-2-Clause
pragma solidity 0.6.8;

import {IENS} from "./interfaces/IENS.sol";
import {IENSResolver} from "./interfaces/IENSResolver.sol";

/**
 * @title MirrorENSReverseRegister
 * Reference: https://github.com/ensdomains/ens/blob/master/contracts/ReverseRegistrar.sol
 */
contract MirrorENSReverseRegistrar {
    // namehash('addr.reverse')
    bytes32 public constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    address public ens;
    address public resolver;

    /**
     * @dev Constructor
     * @param ens_ The address of the ENS registry.
     * @param resolver_ The address of the default reverse resolver.
     */
    constructor(address ens_, address resolver_) public {
        ens = ens_;
        resolver = resolver_;

        // Assign ownership of the reverse record to our deployer
        MirrorENSReverseRegistrar oldRegistrar =
            MirrorENSReverseRegistrar(IENS(ens).owner(ADDR_REVERSE_NODE));
        if (address(oldRegistrar) != address(0x0)) {
            oldRegistrar.claim(msg.sender);
        }
    }

    /**
     * @dev Transfers ownership of the reverse ENS record associated with the
     *      calling account.
     * @param owner The address to set as the owner of the reverse record in ENS.
     * @return The ENS node hash of the reverse record.
     */
    function claim(address owner) public returns (bytes32) {
        return claimWithResolver(owner, address(0x0));
    }

    /**
     * @dev Transfers ownership of the reverse ENS record associated with the
     *      calling account.
     * @param owner The address to set as the owner of the reverse record in ENS.
     * @param resolver The address of the resolver to set; 0 to leave unchanged.
     * @return The ENS node hash of the reverse record.
     */
    function claimWithResolver(address owner, address resolver)
        public
        returns (bytes32)
    {
        bytes32 label = sha3HexAddress(msg.sender);
        bytes32 node = keccak256(abi.encodePacked(ADDR_REVERSE_NODE, label));
        address currentOwner = IENS(ens).owner(node);

        // Update the resolver if required
        if (resolver != address(0x0) && resolver != IENS(ens).resolver(node)) {
            // Transfer the name to us first if it's not already
            if (currentOwner != address(this)) {
                IENS(ens).setSubnodeOwner(
                    ADDR_REVERSE_NODE,
                    label,
                    address(this)
                );
                currentOwner = address(this);
            }
            IENS(ens).setResolver(node, resolver);
        }

        // Update the owner if required
        if (currentOwner != owner) {
            IENS(ens).setSubnodeOwner(ADDR_REVERSE_NODE, label, owner);
        }

        return node;
    }

    /**
     * @dev Sets the `name()` record for the reverse ENS record associated with
     * the calling account. First updates the resolver to the default reverse
     * resolver if necessary.
     * @param name The name to set for this address.
     * @return The ENS node hash of the reverse record.
     */
    function setName(string memory name) public returns (bytes32) {
        bytes32 node = claimWithResolver(address(this), resolver);
        IENSResolver(resolver).setName(node, name);
        return node;
    }

    /**
     * @dev Returns the node hash for a given account's reverse records.
     * @param addr The address to hash
     * @return The ENS node hash.
     */
    function node(address addr) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(addr))
            );
    }

    /**
     * @dev An optimised function to compute the sha3 of the lower-case
     *      hexadecimal representation of an Ethereum address.
     * @param addr The address to hash
     * @return ret The SHA3 hash of the lower-case hexadecimal encoding of the
     *         input address.
     */
    function sha3HexAddress(address addr) private pure returns (bytes32 ret) {
        addr;
        ret; // Stop warning us about unused variables
        assembly {
            let
                lookup
            := 0x3031323334353637383961626364656600000000000000000000000000000000

            for {
                let i := 40
            } gt(i, 0) {

            } {
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }

            ret := keccak256(0, 40)
        }
    }
}
