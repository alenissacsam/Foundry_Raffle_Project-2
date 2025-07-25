-include .env

.PHONY: Deploy Deploy-Sepolia Coverage

install:
	@forge install cyfrin/foundry-devops
	@forge install smartcontractkit/chainlink-brownie-contracts
	@forge install transmissions11/solmate 
	@forge install foundry-rs/forge-std


deploy:
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(LOCAL_RPC_URL) \
	--private-key $(LOCAL_PRIVATE_KEY) --broadcast -vvv

deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) \
	--private-key $(SEPOLIA_PRIVATE_KEY) --broadcast \
	--verify --verifier blockscout --verifier-url https://eth-sepolia.blockscout.com/api/ -vvv

coverage:
	@forge coverage --report debug > coverage.txt

test:
	@forge test --fork-url $(LOCAL_RPC_URL)

test-sepolia:
	@forge test --fork-url $(SEPOLIA_RPC_URL)
