mod erc20;
use starknet::{ContractAddress, get_caller_address,};
use starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess,
StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait,};

 #[derive(Drop, Serde, Copy, starknet::Store)]
       pub struct AuditRecord{
            value: u128,
            author: ContractAddress,
            timestamp: u64,
        }

#[starknet::interface]
trait ISimpleStorage<TState> {
    fn set(ref self: TState, x: u128);
    fn get(self: @TState) -> u128;
    fn increment(ref self: TState);
    fn deposit(ref self: TState, amount: u128);
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u128);
    fn rollback(ref self: TState, index: u64);
    fn get_full_history(self: @TState, index: u64) -> AuditRecord;
    fn set_with_proof(ref self: TState, x: u128, proof: Span<felt252>);
     fn balance_of(self: @TState, user_address: ContractAddress) -> u128;
}

#[starknet::contract]
mod SimpleStorage {
    // Подтягиваем импорты внутрь модуля контракта
    use super::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry,
   Vec, VecTrait, MutableVecTrait, AuditRecord};
    use super::{ContractAddress, get_caller_address};
    use starknet::event::EventEmitter;
    use starknet::get_block_timestamp;
    use core::poseidon::poseidon_hash_span;
    use core::num::traits::Zero;



    #[storage]
    struct Storage {
        // В Starknet переменные в Storage — это не просто ячейки, 
        // а указатели на места в дереве состояния
        stored_data: u128,
        owner: ContractAddress,
        balances: Map<ContractAddress, u128>,
        history: Vec<AuditRecord>,
        last_update: u64,
        merkle_root: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u128, _merkle_root: felt252) {
        self.stored_data.write(initial_value);
        let caller = get_caller_address();
        let now = get_block_timestamp();
        let struct_audit = AuditRecord { value: initial_value, author: caller, timestamp: now};
        self.history.push(struct_audit);
        self.owner.write(caller);
        let now = get_block_timestamp();
        self.last_update.write(now);
        self.merkle_root.write(_merkle_root);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DataChanged: DataChanged
    }

    #[derive(Drop, starknet::Event)]
    struct DataChanged {
        old_value: u128,
        new_value: u128,
    }

   

    #[abi(embed_v0)]
    impl SimpleStorageImpl of super::ISimpleStorage<ContractState> {

        fn get(self: @ContractState) -> u128 {
            // Теперь метод read доступен
            self.stored_data.read()
        }

        fn set(ref self: ContractState, x: u128) {
            let owner = self.owner.read();
            let caller = get_caller_address();
            assert(owner == caller, 'Only owner can call this fn');
            let old = self.stored_data.read();
            // Теперь метод write доступен
            let now = get_block_timestamp();
            assert(now - self.last_update.read() > 300, 'Cooldown active');
            let audit_record = AuditRecord { value: x, author: caller, timestamp: now };
            self.stored_data.write(x);
            self.history.push(audit_record);
            self.last_update.write(now);
            self.emit(DataChanged { old_value: old, new_value: x });
        }

        fn increment(ref self: ContractState){
            let owner = self.owner.read();
            let caller = get_caller_address();
            let now = get_block_timestamp();
            assert(owner == caller, 'Only owner can call this fn');
             assert(now - self.last_update.read() > 300, 'Cooldown active');
            // читаем текущее число
            let current = self.stored_data.read();

            let next = current + 1;
            let audit_record = AuditRecord { value: next, author: caller, timestamp: now };
            self.stored_data.write(next);
            self.history.push(audit_record);
            self.last_update.write(now);
            self.emit(DataChanged {old_value: current, new_value: next});
        }

        fn deposit(ref self: ContractState, amount: u128) {
            let caller = get_caller_address();
            
            // Читаем из Map точно так же: передаем ключ в скобках
            let current_balance = self.balances.entry(caller).read();
            
            // Записываем: ключ и новое значение
            self.balances.entry(caller).write(current_balance + amount);
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u128){
            let caller = get_caller_address();
            let caller_balance = self.balances.entry(caller).read();
            assert(caller_balance >= amount, 'Insufficient balance');
            let new_balance = caller_balance - amount;
            self.balances.entry(caller).write(new_balance);
            let recipient_balance = self.balances.entry(recipient).read() + amount;
            self.balances.entry(recipient).write(recipient_balance);
        }

        fn get_full_history(self: @ContractState, index: u64) -> AuditRecord{
            assert(index < self.history.len(), 'index does not exist');
            self.history.at(index).read()
        }

        fn rollback(ref self: ContractState, index: u64){
            let caller = get_caller_address();
            let owner = self.owner.read();
            let now = get_block_timestamp();
            assert(caller == owner, 'Only owner can call this fn');
            assert(now - self.last_update.read() > 300, 'Cooldown active');
            assert(index < self.history.len(), 'index does not exist');
            let old_value = self.stored_data.read();
            let history_element = self.history.at(index);
            assert(history_element.value.read() != old_value, 'Already at this value');
            let history_struct = AuditRecord { 
                value: history_element.value.read(),
                author: caller,
                timestamp: now
                 };
            self.stored_data.write(history_element.value.read());
            self.history.push(history_struct);
            self.last_update.write(now);
            self.emit(DataChanged { old_value: old_value, new_value: history_struct.value });
        }

        fn set_with_proof(ref self: ContractState, x: u128, proof: Span<felt252>){
            let caller = get_caller_address();
            let caller_felt: felt252 = caller.into();
            let mut current = caller_felt;
            let len = proof.len();
            let mut i = 0;

            while i < len {
                
                let proof_element = *proof.at(i); 
                 // * потому что at() возвращает ссылку

                 let current_u256: u256 = current.into();
                 let proof_u256: u256 = proof_element.into();
                
                // сортируем — меньшее это a, большее это b
                let (a, b) = if current_u256 <= proof_u256 {
                    (current, proof_element)
                } else {
                    (proof_element, current)
                };
                
                let mut arr: Array<felt252> = ArrayTrait::new();
                arr.append(a);
                arr.append(b);
                current = poseidon_hash_span(arr.span());
                
                i += 1;
            };
            assert(current == self.merkle_root.read(), 'Not in whitelist');
            let now = get_block_timestamp();
            let old = self.stored_data.read();

            self.stored_data.write(x);
            self.last_update.write(now);

            let audit_record = AuditRecord { value: x, author: caller, timestamp:  now};
            self.history.push(audit_record);
            self.emit(DataChanged {old_value: old, new_value: x});
        }

        fn balance_of(self: @ContractState, user_address: ContractAddress) -> u128{
            let zero_address: ContractAddress = Zero::zero();
            assert(user_address != zero_address, 'Address does not exist');
            self.balances.entry(user_address).read()
        }

        
}}

#[cfg(test)]
mod tests {
    // Импортируем Dispatcher — через него будем вызывать функции контракта
    use super::{ISimpleStorageDispatcher, ISimpleStorageDispatcherTrait};
    // Инструменты snforge для деплоя
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address,
    start_cheat_block_timestamp, stop_cheat_block_timestamp, start_cheat_caller_address_global, stop_cheat_caller_address_global,
    start_cheat_block_timestamp_global};
    use starknet::ContractAddress;

    const OWNER: felt252 = 0x12345;

    // Эта функция не тест — просто помощник
    // Деплоит контракт и возвращает Dispatcher
    fn deploy(initial_value: u128) -> ISimpleStorageDispatcher {
        let owner: ContractAddress = OWNER.try_into().unwrap();
        // 1. Объявляем контракт — находим его по имени
        let contract = declare("SimpleStorage").unwrap().contract_class();
        
        // 2. Собираем аргументы конструктора в массив
        // Наш конструктор: fn constructor(initial_value: u128, _merkle_root: felt252)
        // initial_value = то что передаём, merkle_root = 0 (для тестов не важен)
        let constructor_args = array![initial_value.into(), 0];
        
        start_cheat_caller_address_global(owner);
        // 3. Деплоим — получаем адрес контракта
        start_cheat_block_timestamp_global(800);
        let (address, _) = contract.deploy(@constructor_args).unwrap();
        stop_cheat_caller_address_global();

        // 4. Оборачиваем адрес в Dispatcher и возвращаем
        ISimpleStorageDispatcher { contract_address: address }
    }

    #[test] // ← говорим Cairo: это тест, запускай его через snforge test
    fn test_get_initial_value() {
        let contract = deploy(42);
        assert(contract.get() == 42, 'should be 42');
    }

    #[test]
    fn test_set_stored_data(){
        let contract = deploy(0);
        let owner: ContractAddress = OWNER.try_into().unwrap();
        assert(contract.get() == 0, 'should be 0');
        start_cheat_caller_address(contract.contract_address, owner);
        start_cheat_block_timestamp(contract.contract_address, 1500);
        contract.set(45);
        start_cheat_block_timestamp(contract.contract_address, 1900);
        assert(contract.get() == 45, 'should be 45');
        stop_cheat_block_timestamp(contract.contract_address);
        stop_cheat_caller_address(contract.contract_address);
    
    }

    #[should_panic(expected: 'Only owner can call this fn')]
    #[test]
    fn test_set_no_owner(){
        let contract = deploy(0);
        let another_felt : felt252 = 0x123123;
        let another_address: ContractAddress = another_felt.try_into().unwrap();
        start_cheat_caller_address(contract.contract_address, another_address);
        start_cheat_block_timestamp(contract.contract_address, 1000);
        contract.set(11);
    }

    #[should_panic(expected: 'Cooldown active')]
    #[test]
    fn test_cooldown(){
        let contract =  deploy(0);
        let owner: ContractAddress = OWNER.try_into().unwrap();
        start_cheat_caller_address(contract.contract_address, owner);
        start_cheat_block_timestamp(contract.contract_address, 1200);
        contract.set(22);
        assert(contract.get() == 22, 'should be 22');
        start_cheat_block_timestamp(contract.contract_address, 1300);
        contract.set(28);
        stop_cheat_caller_address(contract.contract_address);
        stop_cheat_block_timestamp(contract.contract_address);
    }

    #[test]
    fn test_deposit(){
        let contract = deploy(0);
        let another_felt : felt252 = 0x123123;
        let another_address: ContractAddress = another_felt.try_into().unwrap();
        start_cheat_caller_address(contract.contract_address, another_address);
        contract.deposit(1000);
        assert(contract.balance_of(another_address) == 1000, 'must be 1000');
        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_transfer(){
        let contract = deploy(0);
        let another_felt_0 : felt252 = 0x123123;
        let another_felt_1 : felt252 = 0x123321;
        let another_address_0: ContractAddress = another_felt_0.try_into().unwrap();
        let another_address_1: ContractAddress = another_felt_1.try_into().unwrap();
        start_cheat_caller_address(contract.contract_address ,another_address_0);
        contract.deposit(500);
        assert(contract.balance_of(another_address_0) == 500, 'must be 500');
        contract.transfer(another_address_1, 200);
        assert(contract.balance_of(another_address_0) == 300, 'must be 300');
        assert(contract.balance_of(another_address_1) == 200, 'must be 200');
        stop_cheat_caller_address(contract.contract_address);
    }

    #[should_panic(expected: 'Insufficient balance')]
    #[test]
    fn test_transfer_insufficient_balance(){
        let contract = deploy(0);
        let another_felt_0 : felt252 = 0x123123;
        let another_felt_1 : felt252 = 0x123321;
        let another_address_0: ContractAddress = another_felt_0.try_into().unwrap();
        let another_address_1: ContractAddress = another_felt_1.try_into().unwrap();
        start_cheat_caller_address(contract.contract_address ,another_address_0);
        contract.deposit(500);
        assert(contract.balance_of(another_address_0) == 500, 'must be 500');
        contract.transfer(another_address_1, 2000);
        stop_cheat_caller_address(contract.contract_address);
    }

    #[test]
    fn test_history(){
        let contract = deploy(10);
        assert(contract.get_full_history(0).value == 10, 'value must be 10');
        let owner: ContractAddress = OWNER.try_into().unwrap();
        start_cheat_caller_address(contract.contract_address, owner);
        start_cheat_block_timestamp(contract.contract_address, 1400);
        contract.set(20);
        assert(contract.get_full_history(1).value == 20, 'must be 20');
        assert(contract.get_full_history(0).author == owner && contract.get_full_history(1).author == owner, 'author must be owner');
        stop_cheat_caller_address(contract.contract_address);
        stop_cheat_block_timestamp(contract.contract_address);
    }

    #[test]
    fn test_rollback(){
        let contract = deploy(10);
        let owner: ContractAddress = OWNER.try_into().unwrap();
        start_cheat_caller_address(contract.contract_address, owner);
        start_cheat_block_timestamp(contract.contract_address, 1400);
        contract.set(20);
        start_cheat_block_timestamp(contract.contract_address, 1800);
        contract.set(30);
        start_cheat_block_timestamp(contract.contract_address, 2200);
        contract.rollback(0);
        assert(contract.get() == 10, 'must rollback to 10');
        stop_cheat_caller_address(contract.contract_address);
        stop_cheat_block_timestamp(contract.contract_address);
    }

    #[should_panic(expected: 'Already at this value')]
    #[test]
    fn test_rollback_already_at_value(){
        let contract = deploy(10);
        let owner: ContractAddress = OWNER.try_into().unwrap();
        start_cheat_caller_address(contract.contract_address, owner);
        start_cheat_block_timestamp(contract.contract_address, 1400);
        contract.set(20);
        start_cheat_block_timestamp(contract.contract_address, 1800);
        contract.rollback(1);
        stop_cheat_caller_address(contract.contract_address);
        stop_cheat_block_timestamp(contract.contract_address);
    }
}