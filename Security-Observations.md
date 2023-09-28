## Audit comments
    1. Informational: Not the best practice to use the "approve exact amount" logic on permit. 

    2. Informational: In case the epoch ended without an increase of BridgeInterestReceiver balance, it is possible to just send 1 DAI to BridgeInterestReceiver and thus start an epoch without a real deposit of interest from the mainnet. This case will be resolved in the next epoch.

    3. Low: It is possible to block any claims in a specific block by "depositing 25000 DAI into sDAI", "calling the claim" and "withdrawing 25k back" at the start of the block. Very cheap griefing.

    4. Medium: In block n do a flashloan, go through (assets > _lastClaimDeposits + 25000 ether) and update _lastClaimDeposits value inflated by the flashloan. In block n+1... anyone can flash loan bypassing the check. Would have to restore _lastClaimDeposits value at each withdrawal from the sDAI vault.

### Informational Changes 

    1. No changes made. OZ applies the same functionality.
    2. Set the value to something significantly higher than 1 DAI - 1000 DAI as it is the reference minInterest claimed by the Bridge



## Observation on attacks and Potential solutions

### Flashloan Attack:
    The attack is obvious and simple. A malicious user can take advantage of Flashloans to deposit a large amount of funds into sDAI, claim the interest, and then withdraw back the sDAI already at the inflated price. 
    The attack profit = (Interest Claimed * Attackers sDAI / Total sDAI ) - Cost of Flashloan
    This attack is technically the reason why the Interest Receiver contract has been developed in the first place, as the bridge transaction of interest from mainnet could be easily front-run if it was simply injected into the sDAI vault. 
    This is a lesser version of this same problem.

A solution was created in which we track the amount of sDAI shares at every claim request and if a significant variation is noticed we can block it. But there was a problem.

### Griefing attack: 
    As mentioned in 3. If we try to limit claims based on the change in sDAI shares minted to detect abuse of flashloans the contract can be victim of a Griefing Attack in which claims can be blocked
    Additionally, an attacker can easily circumvent such a system by pre-claiming using a flashloan. And then simply front-run the next claim request using a flashloan again... effectively bypassing the sDAI shares minted check.

Thus, this protection mechanism against flashloaning has been found ineffective and removed. 
It has now been replaced by a "No Smart Contract" policy when it comes to claiming interest.

### tx.origin is not Enough:
    So applying a "No Smart Contract" can be done by using (tx.origin == msg.sender) but there's a problem!
    If we follow this route we make the Adapter contract unable to make claims on behalf of the users during the deposit and redeem interactions with the vault
    
A solution for this is to give the Adapter a special permission which turns it into the dedicated interface to claim from the receiver and apply the "No Smart Contract" policy there as well for claim requests
Disallowed claims in the functions with direct xDAI transfers to a receiver to avoid any attempts of reentrancy from another contract

**Relationship change:** Receiver becomes dependent on the Adapter & deployer holds the Claimer role until the Adapter is deployed and can be configured. 

### Things there is no fix for:
    A user with a lot of capital could apply the "flashloan strategy" by:
        -   waiting for the receiver to accumulate interest,
        -   minting a lot of sDAI... 
        -   claiming interest
        -   withdrawing and going on their way.
The only thing blocking this from happening regularly is for the token to be actively claimed by the multiple users and integrators.

An automated keeper is recommended if there's low frequency of claims.