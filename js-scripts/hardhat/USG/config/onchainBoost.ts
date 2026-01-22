export type OnchainBoostContextConfig = {
    llamaNFT?: number;
    veCRV?: number;
    vlCVX?: number;
    veSDT?: number;
    veFXN?: number;
    vePENDLE?: number;
    veYFI?: number;
    sINV?: number;
    stRESOLV?: number;
    stRSUP?: number
}

// Each index of this array matches the index of the test user returned by hardhat with getSigners()
// If you want an user to have nothing, put an empty object
export const onchainBoostUserConfig: OnchainBoostContextConfig[] = [
    // User 0 
    {
        veCRV: 25_000,
        veFXN: 25,
    },
    // User 1
    {
        veCRV: 25_000,
        veFXN: 25,
    },
    // User 2
    {
        veCRV: 25_000,
        veFXN: 25,
    },
    // User3 
    {
        veCRV: 25_000,
        veFXN: 25,
    },
    // User 4 
    {
        veCRV: 25_000,
        veFXN: 25,
    },
    // User 5
    {
        veCRV: 25_000,
        veFXN: 25,
    },
]