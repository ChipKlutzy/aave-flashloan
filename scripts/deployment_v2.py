from brownie import FlashloanV2, accounts, config, network, interface

# AAVE_LENDING_POOL_ADDRESS_PROVIDER = "0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5"

def token_Interface_and_Transfer(token_address, whale_address, contract_address, transfer_amount):
    Token = interface.IERC20(token_address)
    Symbol = Token.symbol()
    print(f"flashloan {Symbol} Balance : {Token.balanceOf(contract_address)}\n")
    print(f"{Symbol} Whale {Symbol} Balance : {Token.balanceOf(whale_address)}\n")

    Token.transfer(contract_address, transfer_amount, {'from': whale_address})
    print(f"flashloan {Symbol} Balance after transfer : {Token.balanceOf(contract_address)}\n")
    print(f"{Symbol} Whale {Symbol} Balance after transfer : {Token.balanceOf(whale_address)}\n")

    return Token


def main():
    """
    Deploy a `FlashloanV2` contract from `weth or dai whale account`.
    """

    weth_whale = accounts.at("0x06601571AA9D3E8f5f7CDd5b993192618964bAB5")
    wbtc_whale = accounts.at("0x218b95be3ed99141b0144dba6ce88807c4ad7c09") 
    dai_whale = accounts.at("0x4943b0C9959dcf58871A799dfB71becE0D97c9f4")

    wethAddr = config["networks"][network.show_active()]["weth"]
    wbtcAddr = config["networks"][network.show_active()]["wbtc"]
    daiAddr = config["networks"][network.show_active()]["dai"]

    print("Deploying Contract..........................\n")

    flashloan = FlashloanV2.deploy(
        config["networks"][network.show_active()]["aave_lending_pool_v2"],
        config["networks"][network.show_active()]["unirouter"],
        config["networks"][network.show_active()]["sushirouter"],
        {"from": wbtc_whale}
    )

    print(f"FlashloanV2 Contract Deployed @ {flashloan.address}\n")

    amount01 = 10 * 1e8
    WBTC = token_Interface_and_Transfer(wbtcAddr, wbtc_whale, flashloan.address, amount01)
    DAI = interface.IERC20(daiAddr)


    print("Calling LENDING_POOL.flashloan()..........................\n")
    flashloan.flashloan([config["networks"][network.show_active()]["wbtc"]], [amount01], {'from': wbtc_whale})

    print(f"Last flashloan {WBTC.symbol()} Balance : {WBTC.balanceOf(flashloan.address) / 1e8}\n")
    print(f"Last flashloan {DAI.symbol()} Balance : {DAI.balanceOf(flashloan.address) / 1e18}\n")

    return flashloan


    
