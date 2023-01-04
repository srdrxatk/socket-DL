// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../utils/AccessControl.sol";
import "../../utils/ReentrancyGuard.sol";

import "../../interfaces/INotary.sol";
import "../../interfaces/ICapacitor.sol";
import "../../interfaces/ISignatureVerifier.sol";

abstract contract NativeBridgeNotary is
    INotary,
    AccessControl,
    ReentrancyGuard
{
    address public remoteNotary;
    uint256 private immutable _chainSlug;
    ISignatureVerifier public signatureVerifier;

    // capacitorAddr|chainSlug|packetId
    mapping(uint256 => bytes32) private _remoteRoots;

    event UpdatedRemoteNotary(address remoteNotary);
    error InvalidSender();

    modifier onlyRemoteCapacitor() virtual {
        _;
    }

    constructor(
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteNotary_
    ) AccessControl(msg.sender) {
        _chainSlug = chainSlug_;
        signatureVerifier = ISignatureVerifier(signatureVerifier_);

        remoteNotary = remoteNotary_;
    }

    function updateRemoteNotary(address remoteNotary_) external onlyOwner {
        remoteNotary = remoteNotary_;
        emit UpdatedRemoteNotary(remoteNotary_);
    }

    function _sendMessage(
        uint256[] calldata bridgeParams,
        uint256 packetId,
        bytes32 root
    ) internal virtual;

    /// @inheritdoc INotary
    function seal(
        address capacitorAddress_,
        uint256[] calldata bridgeParams,
        bytes calldata signature_
    ) external payable override nonReentrant {
        // compiler fix
        uint256 remoteChainSlug = 0;

        (bytes32 root, uint256 packetCount) = ICapacitor(capacitorAddress_)
            .sealPacket();

        uint256 packetId = _getPacketId(
            capacitorAddress_,
            _chainSlug,
            packetCount
        );
        _sendMessage(bridgeParams, packetId, root);

        address attester = signatureVerifier.recoverSigner(
            remoteChainSlug,
            packetId,
            root,
            signature_
        );

        if (!_hasRole(_attesterRole(remoteChainSlug), attester))
            revert InvalidAttester();
        emit PacketVerifiedAndSealed(
            attester,
            capacitorAddress_,
            packetId,
            signature_
        );
    }

    /// @inheritdoc INotary
    function attest(
        uint256 packetId_,
        bytes32 root_,
        bytes calldata
    ) external override onlyRemoteCapacitor {
        _attest(packetId_, root_);
    }

    function _attest(uint256 packetId_, bytes32 root_) internal {
        if (_remoteRoots[packetId_] != bytes32(0)) revert AlreadyAttested();
        _remoteRoots[packetId_] = root_;

        emit PacketProposed(packetId_, root_);
        emit PacketAttested(msg.sender, packetId_);
    }

    /**
     * @notice updates root for given packet id
     * @param packetId_ id of packet to be updated
     * @param newRoot_ new root
     */
    function updatePacketRoot(
        uint256 packetId_,
        bytes32 newRoot_
    ) external onlyOwner {
        bytes32 oldRoot = _remoteRoots[packetId_];
        _remoteRoots[packetId_] = newRoot_;

        emit PacketRootUpdated(packetId_, oldRoot, newRoot_);
    }

    /// @inheritdoc INotary
    function getPacketStatus(
        uint256 packetId_
    ) external view override returns (PacketStatus status) {
        return
            _remoteRoots[packetId_] == bytes32(0)
                ? PacketStatus.NOT_PROPOSED
                : PacketStatus.PROPOSED;
    }

    /// @inheritdoc INotary
    function getPacketDetails(
        uint256 packetId_
    ) external view override returns (PacketStatus, uint256, uint256, bytes32) {
        bytes32 root = _remoteRoots[packetId_];
        PacketStatus status = root == bytes32(0)
            ? PacketStatus.NOT_PROPOSED
            : PacketStatus.PROPOSED;

        return (status, 0, 0, root);
    }

    /**
     * @notice returns the attestations received by a packet
     */
    function getAttestationCount(uint256) external view returns (uint256) {
        return 1;
    }

    /**
     * @notice returns the remote root for given `packetId_`
     * @param packetId_ packed id
     */
    function getRemoteRoot(
        uint256 packetId_
    ) external view override returns (bytes32) {
        return _remoteRoots[packetId_];
    }

    /**
     * @notice adds an attester for `remoteChainSlug_` chain
     * @param remoteChainSlug_ remote chain slug
     * @param attester_ attester address
     */
    function grantAttesterRole(
        uint256 remoteChainSlug_,
        address attester_
    ) external onlyOwner {
        if (_hasRole(_attesterRole(remoteChainSlug_), attester_))
            revert AttesterExists();

        _grantRole(_attesterRole(remoteChainSlug_), attester_);
    }

    /**
     * @notice removes an attester from `remoteChainSlug_` attester list
     * @param remoteChainSlug_ remote chain slug
     * @param attester_ attester address
     */
    function revokeAttesterRole(
        uint256 remoteChainSlug_,
        address attester_
    ) external onlyOwner {
        if (!_hasRole(_attesterRole(remoteChainSlug_), attester_))
            revert AttesterNotFound();

        _revokeRole(_attesterRole(remoteChainSlug_), attester_);
    }

    function _attesterRole(uint256 chainSlug_) internal pure returns (bytes32) {
        return bytes32(chainSlug_);
    }

    /**
     * @notice returns the current chain slug
     */
    function chainSlug() external view returns (uint256) {
        return _chainSlug;
    }

    /**
     * @notice updates signatureVerifier_
     * @param signatureVerifier_ address of Signature Verifier
     */
    function setSignatureVerifier(
        address signatureVerifier_
    ) external onlyOwner {
        signatureVerifier = ISignatureVerifier(signatureVerifier_);
        emit SignatureVerifierSet(signatureVerifier_);
    }

    function _getPacketId(
        address capacitorAddr_,
        uint256 chainSlug_,
        uint256 packetCount_
    ) internal pure returns (uint256 packetId) {
        packetId =
            (chainSlug_ << 224) |
            (uint256(uint160(capacitorAddr_)) << 64) |
            packetCount_;
    }

    function _getChainSlug(
        uint256 packetId_
    ) internal pure returns (uint256 chainSlug_) {
        chainSlug_ = uint32(packetId_ >> 224);
    }
}