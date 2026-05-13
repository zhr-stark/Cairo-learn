import { HexString } from './bytes';
export type ValueType = 'felt252' | 'ContractAddress' | 'u8' | 'u16' | 'u32' | 'u64' | 'u128' | 'u256' | 'bool';
export declare function serialize(types: ReadonlyArray<ValueType>, values: ReadonlyArray<any>): Array<HexString>;
//# sourceMappingURL=serde.d.ts.map