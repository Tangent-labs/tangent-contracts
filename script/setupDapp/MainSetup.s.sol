import "forge-std/Script.sol"; // Import du module Foundry pour les scripts

contract MainSetup {
    address public user0 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public user1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public user2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address public user3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address public user4 = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    address public user5 = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
    address public user6 = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;
    address public user7 = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955;
    address public user8 = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    address public user9 = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    address public user10 = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

    uint256 public pk0 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 public pk1 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    UsersPK[] public pkUsers;

    struct UsersPK {
        address user;
        uint256 pk;
    }

    constructor() {
        pkUsers.push(UsersPK({user: user0, pk: pk0}));
    }
}
