// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

// defines a timeout
// allows a "PAUSER" role to stop processing of messages
// allows an "MANAGER" role to setup "PAUSER"
contract AcceptWithTimeout {
    uint256 public immutable timeoutInSeconds;

    address public immutable socket;
    address public immutable manager;

    bool public isActive;

    mapping(address => mapping(uint256 => bool)) isPauserPerIncomingChain;

    event NewPauser(address pauser, uint256 chain);
    event RemovedPauser(address pauser, uint256 chain);
    event Paused(address pauser, uint chain);

    modifier onlyManager() {
        require(msg.sender == manager, "can only be called by manager");
        _;
    }
    modifier onlyPauser(uint256 chain) {
        require(isPauserPerIncomingChain[msg.sender][chain], "address not set as pauser by manager");
        _;
    }

    // TODO: restrict the timeout durations to a few select options
    constructor(
        uint256 _timeout,
        address _socket,
        address _manager
    ) {
        timeoutInSeconds = _timeout;
        socket = _socket;
        manager = _manager;
    }

    function PreExecHook() external returns (bool) {
        require(isActive, "inactive verifier");

        // TODO make sure this can be called only by Socket
        // TODO fetch delivery time for the packet

        // check if enough packed has timeed out or not
        // delivery time + timeout

        // return true/false
        return true;
    }

    function Pause(uint256 chain) external onlyPauser(chain) {
        require(isActive, "already paused");
        isActive = false;
	emit Paused(msg.sender, chain);
    }

    function Activate() external onlyManager {
        require(!isActive, "already active");
        isActive = true;
    }

    function AddPauser(address _newPauser, uint256 _incomingChain) external onlyManager {
        require(!isPauserPerIncomingChain[_newPauser][_incomingChain], "Already set as pauser");
        isPauserPerIncomingChain[_newPauser][_incomingChain] = true;
        emit NewPauser(_newPauser, _incomingChain);
    }

    function RemovePauser(address _currentPauser, uint256 _incomingChain) external onlyManager {
        require(isPauserPerIncomingChain[_currentPauser][_incomingChain], "Pauser inactive already");
        isPauserPerIncomingChain[_currentPauser][_incomingChain] = false;
        emit RemovedPauser(_currentPauser, _incomingChain);
    }
}