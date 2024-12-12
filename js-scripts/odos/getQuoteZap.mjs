export async function getQuoteZap(tokenIn, amountIn, tokenOut, userAddr) {
  const quoteZapResponse = await fetch("https://api.odos.xyz/sor/quote/v2 ", {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      chainId: 1,
      compact: true,
      gasPrice: 20,
      inputTokens: [
        {
          tokenAddress: tokenIn,
          amount: amountIn,
        },
      ],
      outputTokens: [
        {
          tokenAddress: tokenOut,
          proportion: 1,
        },
      ],
      referralCode: 0,
      slippageLimitPercent: 20,
      sourceBlacklist: [],
      sourceWhitelist: [],
      userAddr,
    }),
  });

  return await quoteZapResponse.json();
}
