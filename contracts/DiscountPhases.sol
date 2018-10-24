pragma solidity ^0.4.24;


import "./Staff.sol";
import "./StaffUtil.sol";
import "./Crowdsale.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";


contract DiscountPhases is StaffUtil {
	using SafeMath for uint256;

	address public crowdsale;
	modifier onlyCrowdsale() {
		require(msg.sender == crowdsale);
		_;
	}
	function setCrowdsale(Crowdsale _crowdsale) external onlyOwner {
		require(crowdsale == address(0));
		require(_crowdsale.staffContract() == staffContract);
		crowdsale = _crowdsale;
	}

	event DiscountPhaseAdded(uint index, string name, uint8 percent, uint fromDate, uint toDate, uint lockDate, uint timestamp, address byStaff);
	event DiscountPhaseBonusApplied(uint index, uint purchaseId, uint256 bonusAmount, uint timestamp);
	event DiscountPhaseBonusCanceled(uint index, uint purchaseId, uint256 bonusAmount, uint timestamp);
	event DiscountPhaseDiscontinued(uint index, uint timestamp, address byStaff);

	struct DiscountPhase {
		uint8 percent;
		uint fromDate;
		uint toDate;
		uint lockDate;
		bool discontinued;
	}

	DiscountPhase[] public discountPhases;

	mapping(address => mapping(uint => InvestorPurchaseBonus)) public investorPurchaseBonus;

	struct InvestorPurchaseBonus {
		bool exists;
		uint discountId;
		uint256 bonusAmount;
	}

	constructor(Staff _staffContract) StaffUtil(_staffContract) public {
	}

	function getBonus(address _investor, uint _purchaseId, uint256 _purchaseAmount, uint _discountId) public onlyCrowdsale returns (uint256) {
		uint256 bonusAmount = calculateBonusAmount(_purchaseAmount, _discountId);
		if (bonusAmount > 0) {
			investorPurchaseBonus[_investor][_purchaseId].exists = true;
			investorPurchaseBonus[_investor][_purchaseId].discountId = _discountId;
			investorPurchaseBonus[_investor][_purchaseId].bonusAmount = bonusAmount;
			emit DiscountPhaseBonusApplied(_discountId, _purchaseId, bonusAmount, now);
		}
		return bonusAmount;
	}

	function getBlockedBonus(address _investor, uint _purchaseId) public constant returns (uint256) {
		InvestorPurchaseBonus storage purchaseBonus = investorPurchaseBonus[_investor][_purchaseId];
		if (purchaseBonus.exists && discountPhases[purchaseBonus.discountId].lockDate > now) {
			return investorPurchaseBonus[_investor][_purchaseId].bonusAmount;
		}
	}

	function cancelBonus(address _investor, uint _purchaseId) public onlyCrowdsale {
		InvestorPurchaseBonus storage purchaseBonus = investorPurchaseBonus[_investor][_purchaseId];
		if (purchaseBonus.bonusAmount > 0) {
			emit DiscountPhaseBonusCanceled(purchaseBonus.discountId, _purchaseId, purchaseBonus.bonusAmount, now);
		}
		delete (investorPurchaseBonus[_investor][_purchaseId]);
	}

	function calculateBonusAmount(uint256 _purchasedAmount, uint _discountId) public constant returns (uint256) {
		if (discountPhases.length <= _discountId) {
			return 0;
		}
		if (now >= discountPhases[_discountId].fromDate && now <= discountPhases[_discountId].toDate && !discountPhases[_discountId].discontinued) {
			return _purchasedAmount.mul(discountPhases[_discountId].percent).div(100);
		}
	}

	function addDiscountPhase(string _name, uint8 _percent, uint _fromDate, uint _toDate, uint _lockDate) public onlyOwnerOrStaff {
		require(bytes(_name).length > 0);
		require(_percent > 0 && _percent <= 100);
		require(_fromDate < _toDate);
		uint index = discountPhases.push(DiscountPhase(_percent, _fromDate, _toDate, _lockDate, false)) - 1;
		emit DiscountPhaseAdded(index, _name, _percent, _fromDate, _toDate, _lockDate, now, msg.sender);
	}

	function discontinueDiscountPhase(uint _index) public onlyOwnerOrStaff {
		require(now < discountPhases[_index].toDate);
		require(!discountPhases[_index].discontinued);
		discountPhases[_index].discontinued = true;
		emit DiscountPhaseDiscontinued(_index, now, msg.sender);
	}
}
