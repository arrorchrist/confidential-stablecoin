// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint64, externalEuint64 } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

/// @title Confidential Stablecoin — Encrypted balances & transfers with FHEVM
contract ConfidentialStablecoin is SepoliaConfig {
    string public name = "Confidential USD";
    string public symbol = "cUSD";
    uint8 public immutable decimals = 6;

    address public owner;
    uint64 public totalSupplyPlain;

    // encrypted balances
    mapping(address => euint64) private _balances;

    // optional allow-list (KYC gating)
    mapping(address => bool) public isAllowed;

    event Mint(address indexed to, uint64 amount);
    event Transfer(address indexed from, address indexed to, uint64 executed);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyAllowed(address user) {
        require(isAllowed[user], "not allowed");
        _;
    }

    constructor() {
        owner = msg.sender;
        isAllowed[msg.sender] = true;
    }

    /// @notice Add/remove addresses to the allow list
    function setAllowed(address user, bool allowed) external onlyOwner {
        isAllowed[user] = allowed;
    }

    /// @notice Read encrypted balance (caller can decrypt if allowed by policy)
    function balanceOf(address user) external view returns (euint64) {
        return _balances[user];
    }

    /// @notice Mint plaintext amount to recipient (owner only, for demo)
    function mint(address to, uint64 amount) external onlyOwner onlyAllowed(to) {
        // add amount to encrypted balance
        euint64 enc = FHE.add(_balances[to], FHE.asEuint64(amount));
        _balances[to] = enc;

        // allow decryption & contract updates
        FHE.allowThis(_balances[to]);
        FHE.allow(_balances[to], to);

        totalSupplyPlain += amount;
        emit Mint(to, amount);
    }

    /// @notice Confidential transfer using encrypted amount + ZKPoK
    /// Fail-closed: if amount > sender balance, executed = 0 (no leak)
    function transfer(
        address to,
        externalEuint64 encryptedAmount,
        bytes calldata proof
    ) external onlyAllowed(msg.sender) onlyAllowed(to) returns (euint64 executed) {
        // cast & verify input proof
        euint64 amount = FHE.fromExternal(encryptedAmount, proof);

        // check if sender has enough balance (encrypted compare)
        euint64 canSend = FHE.select(
            FHE.le(amount, _balances[msg.sender]),
            amount,
            FHE.asEuint64(0)
        );

        // update encrypted balances
        _balances[msg.sender] = FHE.sub(_balances[msg.sender], canSend);
        _balances[to] = FHE.add(_balances[to], canSend);

        // permissions
        FHE.allowThis(_balances[msg.sender]);
        FHE.allowThis(_balances[to]);
        FHE.allow(_balances[msg.sender], msg.sender);
        FHE.allow(_balances[to], to);

        emit Transfer(msg.sender, to, 0); // event does not expose amount
        return canSend;
    }
}
