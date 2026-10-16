// SPDX-License-Identifier: MIT
// @dev This contract has been adapted to fit with foundry
pragma solidity ^0.8.0;

import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";

interface ERC677Receiver {
    function onTokenTransfer(address _sender, uint256 _value, bytes calldata _data) external;
}

contract LinkToken is ERC20 {
    uint256 private constant INITIAL_SUPPLY = 1_000_000e18; // 1,000,000 LINK
    uint8 private constant DECIMALS = 18;

    constructor() ERC20("LinkToken", "LINK", DECIMALS) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /// @dev Mock only: anyone can mint. Never use this on a real network.
    function mint(address to, uint256 value) external {
        _mint(to, value);
    }

    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);

    /**
     * @dev transfer token to a contract address with additional data if the recipient is a contract.
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     * @param _data The extra data to be passed to the receiving contract.
     */
    function transferAndCall(address _to, uint256 _value, bytes calldata _data) external virtual returns (bool) {
        transfer(_to, _value);
        emit Transfer(msg.sender, _to, _value, _data);
        if (_to.code.length > 0) {
            ERC677Receiver(_to).onTokenTransfer(msg.sender, _value, _data);
        }
        return true;
    }
}
