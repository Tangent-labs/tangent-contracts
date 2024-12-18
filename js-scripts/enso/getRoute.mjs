export async function getRoute(fromAddress, receiver, tokenIn, amountIn, tokenOut, minAmountOut) {
    const chainId = 1;
    const routingStrategy = "router";
    const route = `https://api.enso.finance/api/v1/shortcuts/route?chainId=${chainId}&fromAddress=${fromAddress}&receiver=${receiver}&tokenIn=${tokenIn}&tokenOut=${tokenOut}&amountIn=${amountIn}&minAmountOut=${minAmountOut}&routingStrategy=${routingStrategy}`;
    const assembleResponse = await fetch(route, {
        method: "GET",
        headers: {
            Accept: "application/json",
            "Content-Type": "application/json",
            Authorization: "Bearer eec29bb2-af9c-47ba-8ef8-e2ef65848390",
        },
    }).catch((error) => {
        console.error(error);
    });
    const data = await assembleResponse.json();
    return data;
}
