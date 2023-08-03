// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.20;

import "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import "./interfaces/IBridgeInterestReceiver.sol";
import {IWXDAI} from "./interfaces/IWXDAI.sol";
import {IERC20Permit} from "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {EIP712} from "openzeppelin/utils/cryptography/EIP712.sol";
import {Nonces} from "openzeppelin/utils/Nonces.sol";


interface IERC1271 {
    function isValidSignature(
        bytes32,
        bytes memory
    ) external view returns (bytes4);
}

contract GnosisSavingsDAI is ERC4626, IERC20Permit, EIP712, Nonces{

    IBridgeInterestReceiver immutable public interestReceiver;
    IWXDAI public immutable wxdai = IWXDAI(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);

     // --- EIP712 niceties ---
    uint256 public immutable deploymentChainId;
    bytes32 private immutable _DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    string  public constant VERSION  = "1";
    
    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    /**
     * @dev Set the underlying asset contract. This must be an ERC20-compatible contract (ERC20 or ERC777).
     */
    constructor(address interestReceiver_, string memory _name, string memory _ticker) ERC20(_name, _ticker) ERC4626(IERC20(address(wxdai))) EIP712(_name, "1") {
        interestReceiver = IBridgeInterestReceiver(interestReceiver_);
        deploymentChainId = block.chainid;
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(block.chainid);
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");
        interestReceiver.claim();
        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);
        return shares;
    }

    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        require(shares <= maxMint(receiver), "ERC4626: mint more than max");
        interestReceiver.claim();

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");
        interestReceiver.claim();

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");
        interestReceiver.claim();

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    function depositXDAI(address receiver) public virtual payable returns (uint256) {
        uint256 assets = msg.value;
        interestReceiver.claim();
        uint256 shares = previewDeposit(assets);
        wxdai.deposit{value:assets}();
        _deposit(address(this), receiver, assets, shares);
        return shares;
    }

    function withdrawXDAI(uint256 assets, address receiver, address owner) public virtual payable returns (uint256) {
        interestReceiver.claim();
        uint256 shares = withdraw(assets, address(this), owner);
        wxdai.withdraw(assets);
        (bool sent, ) = receiver.call{value: assets}("");
        require(sent, "Failed to send Ether");
        return shares;
    }

    receive() external payable {
        require (msg.sender == address(wxdai),"No xDAI deposits");
    }

    // --- Approve by signature ---

    function _isValidSignature(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) internal view returns (bool) {
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

        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeWithSelector(IERC1271.isValidSignature.selector, digest, signature)
        );
        return (success &&
            result.length == 32 &&
            abi.decode(result, (bytes4)) == IERC1271.isValidSignature.selector);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes memory signature
    ) public {
        require(block.timestamp <= deadline, "SavingsDai/permit-expired");
        require(owner != address(0), "SavingsDai/invalid-owner");

        uint256 nonce = _useNonce(owner);

        bytes32 digest =
            keccak256(abi.encodePacked(
                "\x19\x01",
                block.chainid == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(block.chainid),
                keccak256(abi.encode(
                    PERMIT_TYPEHASH,
                    owner,
                    spender,
                    value,
                    nonce,
                    deadline
                ))
            ));

        require(_isValidSignature(owner, digest, signature), "SavingsDai/invalid-permit");

        _approve(owner, spender, value);
        emit Approval(owner, spender, value);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        permit(owner, spender, value, deadline, abi.encodePacked(r, s, v));
    }
    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
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
