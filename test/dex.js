const { expectRevert } = require("@openzeppelin/test-helpers");
const { assertion } = require("@openzeppelin/test-helpers/src/expectRevert");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

const Dai = artifacts.require('mocks/Dai.sol');
const Bat = artifacts.require('mocks/Bat.sol');
const Rep = artifacts.require('mocks/Rep.sol');
const Zrx = artifacts.require('mocks/Zrx.sol');
const Dex = artifacts.require('Dex.sol');


contract('Dex', (accounts) => {

    // Initialization of the test //

    let dai, bat, rep, zrx;
    const [trader1, trader2] = [accounts[1],accounts[2]];
    
    //the map method takes each element of the array, and use it as a parameter for the function fromAscii
    const [DAI, BAT, REP, ZRX] = ['DAI', 'BAT', 'REP', 'ZRX']
    .map(ticker => web3.utils.fromAscii(ticker));

    beforeEach(async()=> {
        ([dai, bat, rep, zrx] = await Promise.all([
            Dai.new(),
            Bat.new(),
            Rep.new(),
            Zrx.new()           
        ]));
        //we do not use const keyword because it will be used in other functions
        dex = await Dex.new()
        await Promise.all([
            dex.addToken(DAI,dai.address),
            dex.addToken(BAT,bat.address),
            dex.addToken(REP,rep.address),
            dex.addToken(ZRX,zrx.address),
        ]);

        const amount = web3.utils.toWei('1000');
        const seedTokenBalance = async (token, trader) => {
            await token.faucet(trader, amount)
            await token.approve(
                dex.address,
                amount,
                {from: trader}
            );
        };

        await Promise.all(
            [dai, bat, rep, zrx].map(

                token => seedTokenBalance(token, trader1)
            )
        )

        await Promise.all(
            [dai, bat, rep, zrx].map(

                token => seedTokenBalance(token, trader2)
            )
        )
        });

        // Beginning of the tests  //
        it('should deposit tokens', async () => {
            const amount = web3.utils.toWei('100');
            await dex.deposit(
                amount,
                DAI,
                {from : trader1}
            );
            //parameters for a mapping are in the same order in j
            //solidity : traderBalances[trader][ticker]
            const balance = await dex.traderBalances(trader1,DAI);
            assert(balance.toString() === amount);
        });    
        
        it('should NOT deposit token if token does not exist', async () => {
            const amount = web3.utils.toWei('100');
            await expectRevert(
                dex.deposit(
                    amount,
                    web3.utils.fromAscii("NON EXISTING TOKEN"),
                    {from : trader1},
                ),  
                "this token does not exist"
            );
        });
    });
