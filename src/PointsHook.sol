// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";

import {CampaignManagement} from "./CampaignManagement.sol";

contract PointsHook is BaseHook, CampaignManagement {
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

    address admin;
    mapping(address => mapping(address => bool)) public approvedLSTPool;

    constructor(IPoolManager _manager) BaseHook(_manager) {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: true,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function addApporvedLSTPool(
        address token0,
        address token1
    ) public onlyAdmin {
        approvedLSTPool[token0][token1] = true;
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, int128) {
        if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);

        if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);

        (uint48 id, address user) = abi.decode(hookData, (uint48, address));
        bool isSwap = true;

        bool isLSTPool = approvedLSTPool[Currency.unwrap(key.currency0)][
            Currency.unwrap(key.currency1)
        ];

        if (!isLSTPool) return (this.afterSwap.selector, 0);

        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
        uint256 pointsForSwap = ethSpendAmount / 5;

        _assignPoints(id, user, pointsForSwap, isSwap);

        return (this.afterSwap.selector, 0);
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {
        if (!key.currency0.isAddressZero())
            return (this.afterSwap.selector, delta);

        (uint48 id, address user) = abi.decode(hookData, (uint48, address));

        bool isSwap = false;

        bool isLSTPool = approvedLSTPool[Currency.unwrap(key.currency0)][
            Currency.unwrap(key.currency1)
        ];

        if (!isLSTPool) return (this.afterAddLiquidity.selector, delta);

        uint256 pointsForAddingLiquidity = uint256(int256(-delta.amount0()));

        _assignPoints(id, user, pointsForAddingLiquidity, isSwap);

        return (this.afterAddLiquidity.selector, delta);
    }
}
