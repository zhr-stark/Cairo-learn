import { BytesLike, HexString } from './bytes';
import { ValueType } from './serde';
export type LeafHash<T> = (leaf: T) => HexString;
export type NodeHash = (left: BytesLike, right: BytesLike) => HexString;
export declare function poseidonLeafHash<T extends any[]>(types: ValueType[], value: T): HexString;
export declare function poseidonNodeHash(a: BytesLike, b: BytesLike): HexString;
export declare function standardLeafHash<T extends any[]>(types: ValueType[], value: T): HexString;
export declare function standardNodeHash(a: BytesLike, b: BytesLike): HexString;
//# sourceMappingURL=hashes.d.ts.map