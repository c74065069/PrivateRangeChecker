// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, ebool, euint32, externalEuint32 } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

/**
 * @title PrivateRangeChecker
 * @notice Encrypted range membership: checks if an encrypted euint32 x lies within [lower, upper).
 *         The bounds are public (plaintext), the input is encrypted, and the result is an ebool.
 * @dev Uses ONLY Zama's official Solidity library. No FHE operations in view/pure functions.
 */
contract PrivateRangeChecker is SepoliaConfig {
    /* ---------------- Ownable ---------------- */
    address public owner;
    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }

    /* ------------- Global bounds (optional) ------------- */
    uint32 public lowerBound;
    uint32 public upperBound;

    /* ------------- Last result handle (for convenience) ------------- */
    ebool private _last;

    /* ---------------- Events ---------------- */
    event BoundsUpdated(uint32 lower, uint32 upper);
    event RangeChecked(address indexed user, uint32 lower, uint32 upper, bytes32 resultHandle);

    constructor(uint32 lower, uint32 upper) {
        owner = msg.sender;
        _setBounds(lower, upper);
    }

    /**
     * @notice Library / UI version tag for sanity checks.
     */
    function version() external pure returns (string memory) {
        return "PrivateRangeChecker/1.0.0-sepolia";
    }

    /* ---------------- Owner ops ---------------- */

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero owner");
        owner = newOwner;
    }

    function setBounds(uint32 lower, uint32 upper) external onlyOwner {
        _setBounds(lower, upper);
    }

    function _setBounds(uint32 lower, uint32 upper) internal {
        require(lower < upper, "Invalid bounds");
        lowerBound = lower;
        upperBound = upper;
        emit BoundsUpdated(lower, upper);
    }

    /* ---------------- Core: x in [lower, upper) ---------------- */

    /**
     * @notice Check membership against the contract's global bounds.
     * @dev Result semantics: inRange = (x >= lowerBound) && (x < upperBound).
     * @param xExt  external handle for the encrypted euint32 to test
     * @param proof ZK attestation produced by the Relayer SDK
     * @return inRangeCt ciphertext handle of the ebool result
     */
    function checkInRange(externalEuint32 xExt, bytes calldata proof)
        external
        returns (ebool inRangeCt)
    {
        require(proof.length > 0, "Empty proof");

        // Deserialize and authenticate encrypted input
        euint32 x = FHE.fromExternal(xExt, proof);

        // Compare with PUBLIC bounds (lower inclusive, upper exclusive)
        ebool geLower = FHE.ge(x, FHE.asEuint32(lowerBound));
        ebool ltUpper = FHE.lt(x, FHE.asEuint32(upperBound));
        ebool inRange = FHE.and(geLower, ltUpper);

        // Persist + ACL
        _last = inRange;
        FHE.allowThis(_last);           // enable future reads (getters / next txs)
        FHE.allow(_last, msg.sender);   // allow caller to decrypt via userDecrypt(...)

        emit RangeChecked(msg.sender, lowerBound, upperBound, FHE.toBytes32(_last));
        return _last;
    }

    /**
     * @notice Same as {checkInRange} but with PER-CALL public bounds.
     * @dev Useful when ranges vary; validates lower < upper at call time.
     */
    function checkInRangeWithBounds(
        externalEuint32 xExt,
        uint32 lower,
        uint32 upper,
        bytes calldata proof
    ) external returns (ebool inRangeCt) {
        require(lower < upper, "Invalid bounds");
        require(proof.length > 0, "Empty proof");

        euint32 x = FHE.fromExternal(xExt, proof);

        ebool geLower = FHE.ge(x, FHE.asEuint32(lower));
        ebool ltUpper = FHE.lt(x, FHE.asEuint32(upper));
        ebool inRange = FHE.and(geLower, ltUpper);

        _last = inRange;
        FHE.allowThis(_last);
        FHE.allow(_last, msg.sender);

        emit RangeChecked(msg.sender, lower, upper, FHE.toBytes32(_last));
        return _last;
    }

    /* ---------------- Convenience getters ---------------- */

    /**
     * @notice Returns the last computed ebool handle.
     * @dev Anyone can obtain the handle; only those with ACL rights can decrypt.
     */
    function getLastResult() external view returns (ebool) {
        return _last;
    }

    /**
     * @notice Handle form of the last result for relayer.publicDecrypt.
     */
    function getLastResultHandle() external view returns (bytes32) {
        return FHE.toBytes32(_last);
    }

    /**
     * @notice Mark the last result as publicly decryptable (optional).
     * @dev Anyone can then call relayer.publicDecrypt(handle) off-chain.
     */
    function makeLastPublic() external {
        FHE.makePubliclyDecryptable(_last);
    }
}
