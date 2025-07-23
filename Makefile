include .env

.PHONY: Deploy Deploy-Sepolia Coverage

Deploy:
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(LOCAL_RPC_URL) \
	--private-key $(LOCAL_PRIVATE_KEY) --broadcast -vvv

Deploy-Sepolia:
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) \
	--private-key $(SEPOLIA_PRIVATE_KEY) 

Coverage:
	forge coverage --report debug > coverage.txt

Test:
	forge test --fork-url $(LOCAL_RPC_URL)

Test-Sepolia:
	forge test --fork-url $(SEPOLIA_RPC_URL)
