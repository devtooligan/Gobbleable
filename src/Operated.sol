// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title The Operated contract
 * @notice Based on two-step Owned.sol
 */
contract Operated {

  address public operator;
  address private pendingOperator;

  event OperatorTransferRequested(
    address indexed from,
    address indexed to
  );
  event OperatorTransferred(
    address indexed from,
    address indexed to
  );

  constructor(address operator_) {
    operator = operator_;
  }

  /**
   * @dev Allows an operator to begin transferring operator to a new address,
   * pending.
   */
  function transferOperator(address _to)
    external
    onlyOperator()
  {
    pendingOperator = _to;

    emit OperatorTransferRequested(operator, _to);
  }

  /**
   * @dev Allows an operator transfer to be completed by the recipient.
   */
  function acceptOperator()
    external
  {
    require(msg.sender == pendingOperator, "Must be proposed operator");

    address oldOperator = operator;
    operator = msg.sender;
    pendingOperator = address(0);

    emit OperatorTransferred(oldOperator, msg.sender);
  }

  /**
   * @dev Reverts if called by anyone other than the contract operator.
   */
  modifier onlyOperator() {
    require(msg.sender == operator, "Only callable by operator");
    _;
  }

}
