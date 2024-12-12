# Curve Oracle attacks on price oracle

### Preambule

We want to price in dollar a stable coin in a stable LP that doesn't have a Chainlink Aggregator.

There are 2 types of price given by the LP contract:

- `last_price`, being the last price of the coin during the last trade.
- `price_oracle`, being an exponential moving average of the `last_price`.
  The bigger is `ma_time`, the more time it will be needed for `price_oracle` to reach `last_price`.

`last_price` is the most accurate price in time, however it's not safe to use it as it's not resilient to flash liqudity attacks we have so to use `price_oracle`.

There are 1M of tgUSD and 1M of USDC inside it.

### Scenario

A stable pool NG on curve with same parameters as the crvUSD-USDC is created.
