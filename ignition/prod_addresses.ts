
export const PROD_ADDRESSES = {
    DAO: "0x461B62CB3A7e9Df8f800aE058AE92F855F2c27Ca",
    FEE_TRESO: "0x536d4e9C0944dE2aC6657d610Aa99fA5e97Ce493",
    CONTROL_TOWER: "0xf3f7669dceed2f985815011c19ed68f667267215",
    USG: "0xb1c2db5d6ca03fce73dbd304d320bf76c55ae1b1",
    sUSG: "0xf17d6f98a5c6eaa99d149079984119e0a4ef6900",
    ZAPPING_PROXY: "0xa9e0021d8917c51f496823605d218d7e78719c99",
    USG_USDC: "0x97ba10115da528c113462ede9c20d7adc806d93f",
    USG_frxUSD: "0xefc056790bb19702b2164ec6ea6ba3ae01d81195",
    PAUSER: "0xe08c2512F87cF63fb7D2325EDd08aEC7920aC2f6",
    MARKET_VIEWER: "0x05aFEe1B483DdA7273be250f93219b607EA2477D",
    USG_ORACLE: "0x970b2f2cec66f92de81dae6af363d1d135dd2f97",
    PEG_KEEPER_REGULATOR: "0x887706612730b7a227f3bffd8c9a6e6c3cb3f19e",
    KEEPER_USDC: "0xf89615f75c8161dc185c03020240905f6b66bad9",
    KEEPER_frxUSD: "0x8a7f16508d1e8b48bdf36023f378cc04d9506d4e",

    IR_CALCULATOR: "0xB4e1d3bBd2843263d58B4D648C599512cea6e88b",
    REWARDS_ACCUMULATOR: "0x1461D76aA1C9c523398301D9174098c6D53ce639",
    MARKET_CREATOR: "0x214C8A1023B30032a2Eded109146658C6D6F2781",
    PENDLE_PT_ROUTER: "0x8b5aCE406E682A44afcC7bcab4f20bccb7cD2F52",

    MARKETS_IMPLEMENTATION: {
        CONVEX_CRV_LP_MARKET: "0x68e75bfc46fe4cd2eaa1ceb1fd68990916a0ebfb",
        CONVEX_FXN_LP_MARKET: "0xa6c6193abaf2f1b72ed251984d391eaac7c31e77",
        BASIC_ERC20_MARKET: "0xb10ec742bc530b4fd5484f6364993d9bd98642b8",
        CURVE_GAUGE_MARKET: "0xd7a63e1ffff888488db275189078282da8a4e638",
        STAKEDAO_VAULT_MARKET: "0xbce94d131b288590f1ef1f62622865ba1fa514e4",
    },

    MARKETS: {
        CURVE_GAUGE: {
            PYUSD_USDC: "0x4742a56668FBacbc11087f516C4b01ebc48F716f",
            RLUSD_USDC: '0xbffbd9c9ac1645285d017a69885304831e8b9b71',
        },
        STAKEDAO_VAULT: {
            frxUSD_sUSDS: '0xd2c7257efe28a1b1446904a371e3d51e1c2f7e0e',
            BOLD_USDC: '0xc9c80e8481c2b6f979afc155bc3f979cfad19c56',
            frxUSD_sDOLA: "0xd3d29a8752fc40d64a20bbc043147077570c1785",
            USDT_crvUSD: "0xaed9bcae0831caf4a45739ec7910cedf2ac5d9a1",
            frxUSD_scrvUSD: "0x5c996574270f439bfff5b7647ee92c1879d35a4b",
            eUSD_USDC: '0xa6069a4a53b564eb0a312e08f5af19ae2ba5d67e',
            reUSD_scrvUSD: '0x161d6fa48b0e0152763c3929a3813bd177fc099f',
            frxUSD_OUSD: '0x56dbc69208044748af4d33392e25fc9336f11931',
        },
        CONVEX_FXN: {
            reUSD_fxUSD: '0xa63ded87df22ee573567ad1dd87d0a71c8fcd380',
            fxUSD_USDC: '0x849cf82e0ebcfeab8270cc5a3ea3b26cd481b754'
        }
    },
    ORACLES: {
        REDSTONE_FALLBACK: {
            USDC: '0xe10885152b5c5d36fab30490e82339ea6482a4c3',
            USDT: '0xa3e8636213ec899e9ee6e94c1fdde8fae0ba1291',
            PYUSD: '0x01ddf74e6e27d73c12e16047dc78d0398b40ff88',
            USDe: "0x5d634da5e979155ae5f9bf6b56f451d69cb3df9b"

        },
        COIN_FROM_CURVE_LP_FALLBACK: {
            crvUSD: "0x31acd625f66a587fa77c7c7c603240377513ead7",
            RLUSD: "0x747582f3c12dd89219f788cdc152cfc9c7a54e16",
            USDS: "0xc866d0d6532db2d3904d91dc69b6279d1b4a0e0c"
        },
        CHAINLINK: {
            USDC: '0xfc3dff91fb8a7ac53f61d9d465d71d1b89e01fe4',
            USDT: '0x06acead7af9abe0b2a3b2e914b54c9368935b292',
            PYUSD: '0xcba777240d1a0bd66c8ff67544a054862687b6ef',
            crvUSD: '0x63f1715e46d9ce230f09a34c7d051ec0f738fe2b',
            RLUSD: '0x8ce9fb9a62dbae1cd8a3abbf5bf1e8b522d2f957',
            USDS: "0xe3adae98edd21c0b4a4c3e05e7e1136dad2163bd",
            USDe: '0xa3daa1d1e1fe2694db205eec4db7e89b2656c3f4'

        },
        COIN_FROM_CURVE_LP: {
            msUSD: '0x867df395cf6af1abf4dfbd41bed6967667d598b7',
            BOLD: "0x25605c9981bcdf2457791daf84514bacd15b6775",
            reUSD: "0x4cf9d48ea81ac25b3ca2577962ce93e15783523e",
            OUSD: "0x6094c7944ebca80324f8ea2fe1504904aceb4a28",
            fxUSD: "0x905f644ad88f98a42ed830746b2a96c3378deefb",
            DOLA: "0x0124b3e9a4477ac694b37fbf6314fb5d7ed0b074",
            frxUSD: "0x8aa49a3ba86ed4c9fe8fa787934d2f7860509859",
            eUSD: "0xa8c43f747f17181eef26753371f52b3bb61651be"

        },
        CURVE_LP_STABLE_DUO: {
            USDC_USDT: '0x0695758772db50a0aa0255afdb7535de23168542',
            PYUSD_USDC: '0xcf434527aefbc808e3e3400ab489a0e25c4af4ca',
            USDC_RLUSD: "0xd0879e35783a165965d5cd524fc9b0d1cf02b066",
            frxUSD_sUSDS: "0x3ccd01e66172b2c1b3c17f485b7f2987ae94da6a",
            BOLD_USDC: "0xf26b689da847db08f6bb3b3186fdf7eddb8e69c9",
            eUSD_USDC: "0xb8cc9e84941605f553004d188e31e2aeb4061fd2",
            reUSD_scrvUSD: "0xdb0fc4ae74fa8d8a1c3d31e6e9113dbc8b2c7daa",
            USDT_crvUSD: "0x5d34f650c779124676cd72922112a997a4173aef",
            frxUSD_OUSD: "0xe3e9628d2b047aa43ab08adc1b5bb059ca0b1268",
            frxUSD_sDOLA: "0x385b0c21d2f93a76468f8e074ede3ef6f8ff13ce",
            frxUSD_scrvUSD: "0xf31be70c9d9596b23088125345f044065b0bf886",
            USDC_fxUSD: "0x35c62ac45ddf3079e2daa0b8957862a1800920da",
            reUSD_fxUSD: "0x9f162292bc39f194a3ca87e39700293bd9aa710a"
        }

    }

}

