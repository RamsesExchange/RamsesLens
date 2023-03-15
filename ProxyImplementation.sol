// SPDX-License-Identifier: MIT
pragma solidity 0.8.17||0.6.12;


contract ProxyImplementation {
    bool public proxyStorageInitialized;
    constructor() public {}
    modifier checkProxyInitialized() {
        require(
            !proxyStorageInitialized,
            "Can only initialize proxy storage once"
        );
        proxyStorageInitialized = true;
        _;
    }
}