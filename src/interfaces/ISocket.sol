// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface ISocket {

    event BondAdded(
        address indexed signer,
        uint256 addAmount, // assuming native token
        uint256 newBond
    );

    event BondReduced(
        address indexed signer,
        uint256 reduceAmount,
        uint256 newBond
    );

    event Unbonded(
        address indexed signer,
        uint256 amount,
        uint256 claimTime
    );

    event BondClaimed(
        address indexed signer,
        uint256 amount
    );

    event BondClaimDelaySet(uint256 delay);

    event MinBondAmountSet(uint256 amount);

    error InvalidBondReduce();

    error UnbondInProgress();

    error ClaimTimeLeft();

    error InvalidSigner(address signer);

    function addBond() external payable;

    function reduceBond(uint256 amount) external;

    function unbondSigner() external;

    function claimBond() external;

    function outbound(
        uint256 remoteChainId,
        address remotePlug,
        bytes calldata payload
    ) external;
}