// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./interfaces/ISocket.sol";
import "./interfaces/IAccumulator.sol";
import "./interfaces/IDeaccumulator.sol";
import "./interfaces/IVerifier.sol";
import "./interfaces/IPlug.sol";
import "./interfaces/IHasher.sol";
import "./utils/AccessControl.sol";

contract Socket is ISocket, AccessControl(msg.sender) {
    enum MessageStatus {
        NOT_EXECUTED,
        SUCCESS,
        FAILED
    }

    uint256 private immutable _chainId;

    // localPlug => remoteChainId => OutboundConfig
    mapping(address => mapping(uint256 => OutboundConfig))
        public outboundConfigs;

    // localPlug => remoteChainId => InboundConfig
    mapping(address => mapping(uint256 => InboundConfig)) public inboundConfigs;

    // localPlug => remoteChainId => nonce
    mapping(address => mapping(uint256 => uint256)) private _nonces;

    // msgId => executorAddress
    mapping(uint256 => address) private executedPackedMessages;

    // msgId => message status
    mapping(uint256 => MessageStatus) private _messagesStatus;

    IHasher private _hasher;

    constructor(uint256 chainId_, address hasher_) {
        _setHasher(hasher_);
        _chainId = chainId_;
    }

    function setHasher(address hasher_) external onlyOwner {
        _setHasher(hasher_);
    }

    function outbound(uint256 remoteChainId_, bytes calldata payload_)
        external
        override
    {
        OutboundConfig memory config = outboundConfigs[msg.sender][
            remoteChainId_
        ];
        uint256 nonce = _nonces[msg.sender][remoteChainId_]++;
        uint256 msgId = (uint64(remoteChainId_) << 32) | nonce;
        bytes32 packedMessage = _hasher.packMessage(
            _chainId,
            msg.sender,
            remoteChainId_,
            config.remotePlug,
            msgId,
            payload_
        );

        IAccumulator(config.accum).addPackedMessage(packedMessage);
        emit MessageTransmitted(
            _chainId,
            msg.sender,
            remoteChainId_,
            config.remotePlug,
            msgId,
            payload_
        );
    }

    function execute(
        uint256 remoteChainId_,
        address localPlug_,
        uint256 msgId_,
        address remoteAccum_,
        uint256 packetId_,
        bytes calldata payload_,
        bytes calldata deaccumProof_
    ) external override {
        InboundConfig memory config = inboundConfigs[localPlug_][
            remoteChainId_
        ];

        if (executedPackedMessages[msgId_] != address(0))
            revert MessageAlreadyExecuted();
        executedPackedMessages[msgId_] = msg.sender;

        (bool isVerified, bytes32 root) = IVerifier(config.verifier).verifyRoot(
            remoteAccum_,
            remoteChainId_,
            packetId_
        );

        if (!isVerified) revert VerificationFailed();

        if (
            !IDeaccumulator(config.deaccum).verifyMessageInclusion(
                root,
                _hasher.packMessage(
                    remoteChainId_,
                    config.remotePlug,
                    _chainId,
                    localPlug_,
                    msgId_,
                    payload_
                ),
                deaccumProof_
            )
        ) revert InvalidProof();

        try IPlug(localPlug_).inbound(payload_) {
            _messagesStatus[msgId_] = MessageStatus.SUCCESS;
            emit Executed(true, "");
        } catch (bytes memory reason) {
            _messagesStatus[msgId_] = MessageStatus.FAILED;
            emit ExecutedBytes(false, reason);
        }
    }

    function setInboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address deaccum_,
        address verifier_
    ) external override {
        InboundConfig storage config = inboundConfigs[msg.sender][
            remoteChainId_
        ];
        config.remotePlug = remotePlug_;
        config.deaccum = deaccum_;
        config.verifier = verifier_;

        // TODO: emit event
    }

    function setOutboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address accum_
    ) external override {
        OutboundConfig storage config = outboundConfigs[msg.sender][
            remoteChainId_
        ];
        config.accum = accum_;
        config.remotePlug = remotePlug_;

        // TODO: emit event
    }

    function _setHasher(address hasher_) private {
        _hasher = IHasher(hasher_);
    }

    function chainId() external view returns (uint256) {
        return _chainId;
    }

    function hasher() external view returns (address) {
        return address(_hasher);
    }

    function getMessageStatus(uint256 msgId_)
        external
        view
        returns (MessageStatus)
    {
        return _messagesStatus[msgId_];
    }
}
