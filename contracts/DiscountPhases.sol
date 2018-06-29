pragma solidity ^0.4.24;


import "./Staff.sol";


contract DiscountPhases is StaffUtil {

	event DiscountPhaseAdded(uint index, string name, uint8 percent, uint fromDate, uint toDate, uint timestamp, address byStaff);
	event DiscountPhaseRemoved(uint index, uint timestamp, address byStaff);

	struct DiscountPhase {
		uint8 percent;
		uint fromDate;
		uint toDate;
	}

	DiscountPhase[] public discountPhases;

	constructor(Staff _staffContract) StaffUtil(_staffContract) public {
	}

	function calculateBonusAmount(uint256 _purchasedAmount) public constant returns (uint256) {
		for (uint i = 0; i < discountPhases.length; i++) {
			if (now >= discountPhases[i].fromDate && now <= discountPhases[i].toDate) {
				return _purchasedAmount * discountPhases[i].percent / 100;
			}
		}
	}

	function addDiscountPhase(string _name, uint8 _percent, uint _fromDate, uint _toDate) public onlyOwnerOrStaff {
		require(bytes(_name).length > 0);
		require(_percent > 0);

		if (now > _fromDate) {
			_fromDate = now;
		}
		require(_fromDate < _toDate);

		for (uint i = 0; i < discountPhases.length; i++) {
			require(_fromDate > discountPhases[i].toDate || _toDate < discountPhases[i].fromDate);
		}

		uint index = discountPhases.push(DiscountPhase({percent : _percent, fromDate : _fromDate, toDate : _toDate})) - 1;

		emit DiscountPhaseAdded(index, _name, _percent, _fromDate, _toDate, now, msg.sender);
	}

	function removeDiscountPhase(uint _index) public onlyOwnerOrStaff {
		require(now < discountPhases[_index].toDate);
		delete discountPhases[_index];
		emit DiscountPhaseRemoved(_index, now, msg.sender);
	}
}
