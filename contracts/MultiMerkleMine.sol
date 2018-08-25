pragma solidity ^0.4.24;

import "./MerkleMine.sol";
import "zeppelin/contracts/token/ERC20.sol";
import "zeppelin/contracts/math/SafeMath.sol";
import "./BytesUtil.sol";


/**
 * @title MultiMerkleMine
 * @dev The MultiMerkleMine contract is purely a convenience wrapper around an existing MerkleMine contract deployed on the blockchain.
 */
contract MultiMerkleMine {
    using SafeMath for uint256;

    /**
     * @dev Generates token allocations for multiple recipients. Generation period must be started.
     * @param _merkleMineContract Address of the deployed MerkleMine contract
     * @param _recipients Array of recipients
     * @param _merkleProofs Proofs for respective recipients constructed in the format: 
     *       [proof_1_size, proof_1, proof_2_size, proof_2, ... , proof_n_size, proof_n]
     */
    function multiGenerate(address _merkleMineContract, address[] _recipients, bytes _merkleProofs) public {
        MerkleMine mine = MerkleMine(_merkleMineContract);
        ERC20 token = ERC20(mine.token());

        require(
            block.number >= mine.callerAllocationStartBlock(),
            "caller allocation period has not started"
        );
        
        uint256 initialBalance = token.balanceOf(this);
        bytes[] memory proofs = new bytes[](_recipients.length);

        // Counter to keep track of position in `_merkleProofs` byte array
        uint256 i = 0;
        // Counter to keep track of index of each extracted Merkle proof
        uint256 j = 0;

        // Extract proofs
        while(i < _merkleProofs.length){
            uint256 proofSize = uint256(BytesUtil.readBytes32(_merkleProofs, i));

            require(
                proofSize % 32 == 0,
                "proof size must be a multiple of 32"
            );

            proofs[j] = BytesUtil.substr(_merkleProofs, i + 32, proofSize);

            i = i + 32 + proofSize;
            j++;
        }

        require(
            _recipients.length == j,
            "number of recipients != number of proofs"
        );

        for (uint256 k = 0; k < _recipients.length; k++) {
            // If recipient's token allocation has not been generated, generate the token allocation
            // Else, continue to the next recipient
            if (!mine.generated(_recipients[k])) {
                mine.generate(_recipients[k], proofs[k]);
            }
        }

        uint256 newBalanceSinceAllocation = token.balanceOf(this);
        uint256 callerTokensGenerated = newBalanceSinceAllocation.sub(initialBalance);

        // Transfer caller's portion of tokens generated by this function call 
        if (callerTokensGenerated > 0) {
            require(token.transfer(msg.sender, callerTokensGenerated));
        }
    }
}