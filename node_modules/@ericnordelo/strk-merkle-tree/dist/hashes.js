"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.standardNodeHash = exports.standardLeafHash = exports.poseidonNodeHash = exports.poseidonLeafHash = void 0;
const starknet_1 = require("starknet");
const bytes_1 = require("./bytes");
const serde_1 = require("./serde");
function poseidonLeafHash(types, value) {
    return (0, bytes_1.toHex)(starknet_1.hash.computePoseidonHashOnElements([starknet_1.hash.computePoseidonHashOnElements((0, serde_1.serialize)(types, value))]), {
        hexPad: 'left',
    });
}
exports.poseidonLeafHash = poseidonLeafHash;
function poseidonNodeHash(a, b) {
    const sorted = [a, b].sort(bytes_1.compare).map(x => (0, bytes_1.toHex)(x, { hexPad: 'left' }));
    return (0, bytes_1.toHex)(starknet_1.hash.computePoseidonHashOnElements(sorted).toString(), { hexPad: 'left' });
}
exports.poseidonNodeHash = poseidonNodeHash;
function standardLeafHash(types, value) {
    return (0, bytes_1.toHex)(starknet_1.hash.computePedersenHash(0, starknet_1.hash.computeHashOnElements((0, serde_1.serialize)(types, value))), { hexPad: 'left' });
}
exports.standardLeafHash = standardLeafHash;
function standardNodeHash(a, b) {
    const sorted = [a, b].sort(bytes_1.compare).map(x => (0, bytes_1.toHex)(x, { hexPad: 'left' }));
    return (0, bytes_1.toHex)(starknet_1.hash.computeHashOnElements(sorted).toString(), { hexPad: 'left' });
}
exports.standardNodeHash = standardNodeHash;
//# sourceMappingURL=hashes.js.map