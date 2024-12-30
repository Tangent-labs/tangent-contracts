export async function getQuote(tokenIn, amountIn, tokenOut) {
    const chainId = 1;
    const routingStrategy = "router";

    const route = `https://api.enso.finance/api/v1/shortcuts/quote?chainId=${chainId}&tokenIn=${tokenIn}&tokenOut=${tokenOut}&amountIn=${amountIn}&routingStrategy=${routingStrategy}`;
    const quoteZapResponse = await fetch(route, {
        method: "GET",
        headers: {
            Accept: "application/json",
            "Content-Type": "application/json",
            Authorization: "Bearer eec29bb2-af9c-47ba-8ef8-e2ef65848390",
        },
    });
    const json = await quoteZapResponse.json();
    return json;
}
