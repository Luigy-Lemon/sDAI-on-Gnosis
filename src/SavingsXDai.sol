// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import {IERC1271} from "openzeppelin/interfaces/IERC1271.sol";
import {Gnosis} from "./constants/Gnosis.sol";
import {IWXDAI} from "./interfaces/IWXDAI.sol";
import {ISavingsXDai} from "./interfaces/ISavingsXDai.sol";
import {IERC20Permit} from "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {EIP712} from "openzeppelin/utils/cryptography/EIP712.sol";
import {Nonces} from "openzeppelin/utils/Nonces.sol";

/// @title SavingsXDai
/// @notice See {ISavingsXDai}. WXDAI-backed ERC-4626 vault with EIP-2612 / ERC-1271 permit.
contract SavingsXDai is ERC4626, IERC20Permit, ISavingsXDai, EIP712, Nonces {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISavingsXDai
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /// @inheritdoc ISavingsXDai
    string public constant VERSION = "1";

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISavingsXDai
    IWXDAI public immutable wxdai = IWXDAI(Gnosis.WXDAI);

    /// @inheritdoc ISavingsXDai
    uint256 public immutable deploymentChainId;

    bytes32 private immutable _DOMAIN_SEPARATOR;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _ticker)
        ERC20(_name, _ticker)
        ERC4626(IERC20(address(wxdai)))
        EIP712(_name, "1")
    {
        deploymentChainId = block.chainid;
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(block.chainid);
    }

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISavingsXDai
    function permit(address owner, address spender, uint256 value, uint256 deadline, bytes memory signature) public {
        if (block.timestamp > deadline) revert ERC2612ExpiredSignature(deadline);
        if (owner == address(0)) revert InvalidOwner();

        uint256 nonce = _useNonce(owner);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                block.chainid == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(block.chainid),
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline))
            )
        );

        if (!_isValidSignature(owner, digest, signature)) revert ERC2612InvalidSigner(address(0), owner);

        _approve(owner, spender, value);
        emit Approval(owner, spender, value);
    }

    /// @inheritdoc IERC20Permit
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        permit(owner, spender, value, deadline, abi.encodePacked(r, s, v));
    }

    /// @notice Reverts; the vault does not accept native xDAI deposits.
    receive() external payable {
        revert NoXDaiDeposits();
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEW
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Permit
    function nonces(address owner) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /// @inheritdoc IERC20Permit
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Verifies a signature against `signer` using EOA ECDSA (when 65 bytes) with
    ///      a fallback to ERC-1271 for contract signers.
    function _isValidSignature(address signer, bytes32 digest, bytes memory signature) internal view returns (bool) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            if (signer == ecrecover(digest, v, r, s)) {
                return true;
            }
        }

        (bool success, bytes memory result) =
            signer.staticcall(abi.encodeWithSelector(IERC1271.isValidSignature.selector, digest, signature));
        return (success && result.length == 32 && abi.decode(result, (bytes4)) == IERC1271.isValidSignature.selector);
    }

    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name())),
                keccak256(bytes(VERSION)),
                chainId,
                address(this)
            )
        );
    }
}
