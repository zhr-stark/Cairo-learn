"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.serialize = void 0;
const errors_1 = require("./utils/errors");
const common_1 = require("./utils/common");
function serialize(types, values) {
    if (types.length !== values.length) {
        (0, errors_1.throwError)('types/values length mismatch');
    }
    let ret = [];
    for (let i = 0; i < types.length; i++) {
        ret = ret.concat(...serialize_single(types[i], values[i]));
    }
    return ret;
}
exports.serialize = serialize;
function serialize_single(type, value) {
    switch (type) {
        case 'felt252':
        case 'ContractAddress':
        case 'u8':
        case 'u16':
        case 'u32':
        case 'u64':
        case 'u128':
            checkOverflow(value, type);
            return [(0, common_1.paddedHex)(value)];
        case 'u256':
            checkOverflow(value, type);
            value = (0, common_1.paddedHex)(value);
            value = BigInt(value);
            // return [low, high]
            return [value & BigInt('0xffffffffffffffffffffffffffffffff'), value >> BigInt(128)].map(bint => (0, common_1.paddedHex)(bint.toString(16)));
        case 'bool':
            return [value ? '0x01' : '0x00'];
        default:
            (0, errors_1.throwError)(`Unknown type '${type}' while serializing`);
    }
}
function checkOverflow(value, type) {
    value = BigInt(value);
    let max;
    switch (type) {
        case 'felt252':
        case 'ContractAddress':
            max = 2n ** 251n + 17n * 2n ** 192n;
            break;
        case 'u8':
            max = 255n;
            break;
        case 'u16':
            max = 2n ** 16n - 1n;
            break;
        case 'u32':
            max = 2n ** 32n - 1n;
            break;
        case 'u64':
            max = 2n ** 64n - 1n;
            break;
        case 'u128':
            max = 2n ** 128n - 1n;
            break;
        case 'u256':
            max = 2n ** 256n - 1n;
            break;
        default:
            (0, errors_1.throwError)(`Unknown type '${type}' while asserting range`);
    }
    if (value > max) {
        (0, errors_1.throwError)(`Value is too large for type ${type}`);
    }
}
//# sourceMappingURL=serde.js.map