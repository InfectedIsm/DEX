//SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.15;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Bat is ERC20 {
  constructor() ERC20('DAI', 'Dai token') {}

  function faucet(address to, uint amount) external 
  {
    _mint(to, amount);
  }

}


