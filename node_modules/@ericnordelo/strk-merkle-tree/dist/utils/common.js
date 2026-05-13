"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.paddedHex = void 0;
const bytes_1 = require("../bytes");
function paddedHex(value) {
    // Accept decimal strings, hex strings (with or without 0x), or numeric inputs.
    if (typeof value === 'string') {
        const str = value.trim();
        const isHex = str.startsWith('0x') || /[a-fA-F]/.test(str);
        const bigintValue = isHex ? BigInt(str.startsWith('0x') ? str : `0x${str}`) : BigInt(str);
        return (0, bytes_1.toHex)(bigintValue, { hexPad: 'left' });
    }
    return (0, bytes_1.toHex)(BigInt(value), { hexPad: 'left' });
}
exports.paddedHex = paddedHex;
//# sourceMappingURL=common.js.map