export async function getAssembleData(pathId, userAddr, receiver) {
    const assembleResponse = await fetch("https://api.odos.xyz/sor/assemble", {
        method: "POST",
        headers: {
            Accept: "application/json",
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            pathId,
            simulate: true,
            userAddr,
            receiver,
        }),
    });
    const data = await assembleResponse.json();
    return data;
}
