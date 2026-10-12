import '../domain/coin.dart';

const _mockRows = <Map<String, dynamic>>[
  {'id':'btc-bitcoin','name':'Bitcoin','symbol':'BTC','rank':1,'price':67240.25,'marketCap':1325000000000,'volume':28500000000,'change':2.34,'circulating':19700000,'totalSupply':19700000,'maxSupply':21000000},
  {'id':'eth-ethereum','name':'Ethereum','symbol':'ETH','rank':2,'price':3520.18,'marketCap':422000000000,'volume':14200000000,'change':1.42,'circulating':120100000,'totalSupply':120100000,'maxSupply':0},
  {'id':'usdt-tether','name':'Tether','symbol':'USDT','rank':3,'price':1.0,'marketCap':112000000000,'volume':42000000000,'change':0.02,'circulating':112000000000,'totalSupply':112000000000,'maxSupply':0},
  {'id':'bnb-binance-coin','name':'BNB','symbol':'BNB','rank':4,'price':602.8,'marketCap':87500000000,'volume':1800000000,'change':-0.63,'circulating':145000000,'totalSupply':145000000,'maxSupply':200000000},
  {'id':'sol-solana','name':'Solana','symbol':'SOL','rank':5,'price':152.43,'marketCap':70500000000,'volume':2600000000,'change':4.81,'circulating':462000000,'totalSupply':579000000,'maxSupply':0},
  {'id':'xrp-xrp','name':'XRP','symbol':'XRP','rank':6,'price':0.5321,'marketCap':29500000000,'volume':850000000,'change':-1.12,'circulating':55500000000,'totalSupply':99900000000,'maxSupply':100000000000},
  {'id':'usdc-usd-coin','name':'USDC','symbol':'USDC','rank':7,'price':1.0,'marketCap':33000000000,'volume':2100000000,'change':0.01,'circulating':33000000000,'totalSupply':33000000000,'maxSupply':0},
  {'id':'ada-cardano','name':'Cardano','symbol':'ADA','rank':8,'price':0.4512,'marketCap':16000000000,'volume':320000000,'change':0.76,'circulating':35500000000,'totalSupply':45000000000,'maxSupply':45000000000},
  {'id':'doge-dogecoin','name':'Dogecoin','symbol':'DOGE','rank':9,'price':0.1624,'marketCap':23400000000,'volume':720000000,'change':3.17,'circulating':144000000000,'totalSupply':144000000000,'maxSupply':0},
  {'id':'trx-tron','name':'TRON','symbol':'TRX','rank':10,'price':0.112,'marketCap':9750000000,'volume':250000000,'change':-0.24,'circulating':87000000000,'totalSupply':87000000000,'maxSupply':0},
  {'id':'ton-toncoin','name':'Toncoin','symbol':'TON','rank':11,'price':6.82,'marketCap':17200000000,'volume':190000000,'change':1.88,'circulating':2520000000,'totalSupply':5100000000,'maxSupply':0},
  {'id':'avax-avalanche','name':'Avalanche','symbol':'AVAX','rank':12,'price':36.15,'marketCap':14200000000,'volume':280000000,'change':-2.11,'circulating':393000000,'totalSupply':444000000,'maxSupply':720000000},
];

List<Coin> buildMockCoins() => _mockRows.map(Coin.fromMock).toList();
