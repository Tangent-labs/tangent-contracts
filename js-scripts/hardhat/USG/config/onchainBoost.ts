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
        llamaNFT: 2,
        veCRV: 25_000,
        vlCVX: 500_000,
        veSDT: 15_000,
        veFXN: 25,
        vePENDLE: 150,
        veYFI: 10,
        sINV: 100,
        stRESOLV: 150,
        stRSUP: 200
    },
    // User 1
    {
        vlCVX: 500_000,
        veYFI: 10,
        stRESOLV: 150,
    },
    // User 2
    {
        sINV: 12
    },
    // User3 
    {

    },
    // User 4 
    {
        vlCVX: 500,
        llamaNFT: 1,
        stRESOLV: 100
    }
]