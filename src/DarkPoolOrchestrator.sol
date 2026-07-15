// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFlareDataConnector {
    /// @notice Verifies an external deposit (BTC/XRP) was relayed via Flare's FDC
    function verifyDeposit(bytes32 txHash, uint256 amount, address depositor) external view returns (bool);
}

/// @title DarkPoolOrchestrator
/// @notice Public coordination layer for a cross-chain dark pool (BTC/XRP).
///         Order matching and settlement signing happen off-chain inside the
///         FCC TEE enclave; this contract only tracks order state and gates
///         who is allowed to call settleDarkOrders().
contract DarkPoolOrchestrator {
    // ---------------------------------------------------------------------
    // Ownership (minimal inline implementation, no external deps required)
    // ---------------------------------------------------------------------
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ---------------------------------------------------------------------
    // Core state
    // ---------------------------------------------------------------------
    IFlareDataConnector public fdc;
    address public fccEnclaveAddress;

    enum AssetType { BTC, XRP }
    enum OrderStatus { Open, Settled, Cancelled }

    struct EncryptedOrder {
        address trader;
        AssetType depositAsset;
        AssetType receiveAsset;
        bytes32 depositTxHash;
        bytes encryptedPayload; // hidden volume, min price, destination address
        OrderStatus status;
        uint256 submittedAt;
    }

    mapping(bytes32 => EncryptedOrder) public orders;
    mapping(bytes32 => bool) public usedDepositTxHashes; // prevents deposit-hash replay across orders

    event OrderSubmitted(bytes32 indexed orderId, address indexed trader, AssetType depositAsset, AssetType receiveAsset);
    event OrderSettled(bytes32 indexed orderIdA, bytes32 indexed orderIdB);
    event OrderCancelled(bytes32 indexed orderId, address indexed trader);
    event EnclaveAddressUpdated(address indexed previousEnclave, address indexed newEnclave);
    event FdcUpdated(address indexed previousFdc, address indexed newFdc);

    modifier onlyEnclave() {
        require(msg.sender == fccEnclaveAddress, "Only FCC Enclave can execute");
        _;
    }

    constructor(address _fdc, address _fccEnclave) {
        require(_fdc != address(0) && _fccEnclave != address(0), "Zero address");
        owner = msg.sender;
        fdc = IFlareDataConnector(_fdc);
        fccEnclaveAddress = _fccEnclave;
    }

    // ---------------------------------------------------------------------
    // Admin
    // ---------------------------------------------------------------------
    function setEnclaveAddress(address _fccEnclave) external onlyOwner {
        require(_fccEnclave != address(0), "Zero address");
        emit EnclaveAddressUpdated(fccEnclaveAddress, _fccEnclave);
        fccEnclaveAddress = _fccEnclave;
    }

    function setFdc(address _fdc) external onlyOwner {
        require(_fdc != address(0), "Zero address");
        emit FdcUpdated(address(fdc), _fdc);
        fdc = IFlareDataConnector(_fdc);
    }

    // ---------------------------------------------------------------------
    // Trader-facing
    // ---------------------------------------------------------------------

    /// @notice Submit a dark order once the deposit has been proven via FDC.
    /// @param depositTxHash The tx hash of the BTC/XRP deposit into the PMW.
    /// @param depositAmount The amount deposited, passed to FDC for verification.
    /// @param _depositAsset Asset the trader deposited.
    /// @param _receiveAsset Asset the trader wants to receive.
    /// @param _encryptedPayload Encrypted (volume, min price, destination address),
    ///        decryptable only inside the FCC enclave.
    function submitDarkOrder(
        bytes32 depositTxHash,
        uint256 depositAmount,
        AssetType _depositAsset,
        AssetType _receiveAsset,
        bytes calldata _encryptedPayload
    ) external returns (bytes32 orderId) {
        require(_depositAsset != _receiveAsset, "Deposit and receive asset must differ");
        require(!usedDepositTxHashes[depositTxHash], "Deposit tx already used");
        require(_encryptedPayload.length > 0, "Empty payload");
        require(fdc.verifyDeposit(depositTxHash, depositAmount, msg.sender), "Invalid deposit proof");

        usedDepositTxHashes[depositTxHash] = true;

        orderId = keccak256(abi.encodePacked(msg.sender, depositTxHash, block.timestamp, block.prevrandao));

        orders[orderId] = EncryptedOrder({
            trader: msg.sender,
            depositAsset: _depositAsset,
            receiveAsset: _receiveAsset,
            depositTxHash: depositTxHash,
            encryptedPayload: _encryptedPayload,
            status: OrderStatus.Open,
            submittedAt: block.timestamp
        });

        emit OrderSubmitted(orderId, msg.sender, _depositAsset, _receiveAsset);
    }

    /// @notice Trader can cancel an unmatched order. Actual fund return happens
    ///         off-chain (enclave refunds from the PMW) once it observes this event.
    function cancelOrder(bytes32 orderId) external {
        EncryptedOrder storage order = orders[orderId];
        require(order.trader == msg.sender, "Not your order");
        require(order.status == OrderStatus.Open, "Order not open");
        order.status = OrderStatus.Cancelled;
        emit OrderCancelled(orderId, msg.sender);
    }

    // ---------------------------------------------------------------------
    // Enclave-facing
    // ---------------------------------------------------------------------

    /// @notice Called by the FCC Enclave once a blind match is computed and
    ///         settlement transactions have already been signed and broadcast.
    function settleDarkOrders(bytes32 orderIdA, bytes32 orderIdB) external onlyEnclave {
        EncryptedOrder storage a = orders[orderIdA];
        EncryptedOrder storage b = orders[orderIdB];

        require(a.status == OrderStatus.Open, "Order A not open");
        require(b.status == OrderStatus.Open, "Order B not open");
        require(a.depositAsset == b.receiveAsset && b.depositAsset == a.receiveAsset, "Assets do not cross-match");

        a.status = OrderStatus.Settled;
        b.status = OrderStatus.Settled;

        emit OrderSettled(orderIdA, orderIdB);
    }

    // ---------------------------------------------------------------------
    // View helpers
    // ---------------------------------------------------------------------
    function getOrder(bytes32 orderId) external view returns (EncryptedOrder memory) {
        return orders[orderId];
    }
}
