## Launch scripts to the test node

- Go on the Rlx machine
- Check if the screen of the node is running `screen -ls`
  - If not open, `screen -R` to open a new one
    - Go in `hh_node`
  - If already open, `screen -R node` to go on the screen
    - Ctrl+C for killing the node
- Run `npm run hh-node` to run the node
- To exit the screen without killing the node : CTRL+A then D

---

Once the node runs runs the script you want by puting the correct config in your hardhat command ( --network tangent)

ex :
`npx hardhat run js-scripts/hardhat/dappSetup/run-setup-booster.ts --network tangent`
