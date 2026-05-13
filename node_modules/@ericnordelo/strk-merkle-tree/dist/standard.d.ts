import { BytesLike, HexString } from './bytes';
import { MultiProof } from './core';
import { MerkleTreeData, MerkleTreeImpl } from './merkletree';
import { MerkleTreeOptions } from './options';
import { ValueType } from './serde';
export interface StandardMerkleTreeData<T extends any[]> extends MerkleTreeData<T> {
    format: 'standard-v1';
    leafEncoding: ValueType[];
}
export declare class StandardMerkleTree<T extends any[]> extends MerkleTreeImpl<T> {
    protected readonly tree: HexString[];
    protected readonly values: StandardMerkleTreeData<T>['values'];
    protected readonly leafEncoding: ValueType[];
    protected constructor(tree: HexString[], values: StandardMerkleTreeData<T>['values'], leafEncoding: ValueType[]);
    static of<T extends any[]>(values: T[], leafEncoding: ValueType[], options?: MerkleTreeOptions): StandardMerkleTree<T>;
    static load<T extends any[]>(data: StandardMerkleTreeData<T>): StandardMerkleTree<T>;
    static verify<T extends any[]>(root: BytesLike, leafEncoding: ValueType[], leaf: T, proof: BytesLike[]): boolean;
    static verifyMultiProof<T extends any[]>(root: BytesLike, leafEncoding: ValueType[], multiproof: MultiProof<BytesLike, T>): boolean;
    dump(): StandardMerkleTreeData<T>;
}
//# sourceMappingURL=standard.d.ts.map