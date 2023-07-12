# Savings DAI on Gnosis Chain

A tokenized wrapper of the Interest collected from Token Bridge deposits in sDAI. Follows the ERC4626 Standard. Share to asset conversions are real-time even if the pot hasn't been dripped in a while. Please note this is sample code only and there is no official deploys. Feel free to deploy it yourself.

# xDAI Interest Receiver
WXDAI is moved into the sDAI vault contract using a continuous dripRate from BridgeInterestReceiver to avoid arbitrage abuse.
