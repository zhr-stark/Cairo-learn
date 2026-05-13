import { SimpleMerkleTree } from "@ericnordelo/strk-merkle-tree";
import { poseidonNodeHash } from "@ericnordelo/strk-merkle-tree/dist/hashes.js";
import { writeFileSync } from "fs";

const addresses = [
    "0x01634c88c51edb466066de7d74017f77212df2cec6f06d5d6864b31e620582d7",
    "0x01634c88c51edb466066de7d74017f77212df2cec6f06d5d6864b31e620582d1",
    "0x01634c88c51edb466066de7d74017f77212df2cec6f06d5d6864b31e620582d2",
    "0x01634c88c51edb466066de7d74017f77212df2cec6f06d5d6864b31e620582d3",
    "0x01634c88c51edb466066de7d74017f77212df2cec6f06d5d6864b31e620582d4",
    "0x01634c88c51edb466066de7d74017f77212df2cec6f06d5d6864b31e620582d5",
    "0x01634c88c51edb466066de7d74017f77212df2cec6f06d5d6864b31e620582d6",
    "0x025cfa49e49459bb1b9a569304bc4dd30036a88218c1febbbcc219d3a56c5b08",
    "0x01634c88c51edb466066de7d74017f77212df2cec6f06d5d6864b31e620582d9",
    "0x025cfa49e49459bb1b9a569304bc4dd30036a88218c1febbbcc219d3a56c5b09",
];

const tree = SimpleMerkleTree.of(addresses, { nodeHash: poseidonNodeHash });

console.log("Root:", tree.root);

const output = { root: tree.root, proofs: {} };

for (const [i, leaf] of tree.entries()) {
    const proof = tree.getProof(i);
    console.log(`Proof для ${leaf}:`, proof);
    output.proofs[leaf] = proof;
}

writeFileSync("whitelist.json", JSON.stringify(output, null, 2));
console.log("Сохранено в whitelist.json");