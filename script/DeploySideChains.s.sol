// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "script/BaseSideChains.sol";

address constant BALANCER_GAUGE_CONTROLLER = 0xC128468b7Ce63eA702C1f104D55A2566b13D3ABD;

contract Balancer is BaseSideChains(BALANCER_GAUGE_CONTROLLER) {}

address constant FRAX_GAUGE_CONTROLLER = 0x3669C421b77340B2979d1A00a792CC2ee0FcE737;

contract Frax is BaseSideChains(FRAX_GAUGE_CONTROLLER) {}

address constant FXN_GAUGE_CONTROLLER = 0xe60eB8098B34eD775ac44B1ddE864e098C6d7f37;

contract Fxn is BaseSideChains(FXN_GAUGE_CONTROLLER) {}
