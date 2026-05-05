// Импортируем необходимые трейты (интерфейсы) для работы с хранилищем
use starknet::{ContractAddress, get_caller_address};
use starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess,
StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait,};


#[starknet::interface]
trait ISimpleStorage<TState> {
    fn set(ref self: TState, x: u128);
    fn get(self: @TState) -> u128;
    fn increment(ref self: TState);
    fn increase_by(self: @TState, amount: u128) -> u128;
    fn deposit(ref self: TState, amount: u128);
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u128);
    fn rollback(ref self: TState, index: u64);
    fn get_full_history(self: @TState, index: u64) -> SimpleStorage::AuditRecord;
}

#[starknet::contract]
mod SimpleStorage {
    // Подтягиваем импорты внутрь модуля контракта
    use super::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry,
   Vec, VecTrait, MutableVecTrait,};
    use super::{ContractAddress, get_caller_address};
    use starknet::event::EventEmitter;
    use starknet::get_block_timestamp;

    #[storage]
    struct Storage {
        // В Starknet переменные в Storage — это не просто ячейки, 
        // а указатели на места в дереве состояния
        stored_data: u128,
        owner: ContractAddress,
        balances: Map<ContractAddress, u128>,
        history: Vec<AuditRecord>,
        last_update: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u128) {
        self.stored_data.write(initial_value);
        let caller = get_caller_address();
        let now = get_block_timestamp();
        let struct_audit = AuditRecord { value: initial_value, author: caller, timestamp: now};
        self.history.push(struct_audit);
        self.owner.write(caller);
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

    #[derive(Drop, Serde, Copy, starknet::Store)]
       pub struct AuditRecord{
            value: u128,
            author: ContractAddress,
            timestamp: u64,
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

        fn increase_by(self: @ContractState, amount: u128) -> u128 {
            let current = self.stored_data.read();
            current + amount
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
            let history_struct = AuditRecord { 
                value: history_element.value.read(),
                author: history_element.author.read(),
                timestamp: now
                 };
            assert(history_element.value.read() != old_value, 'Already at this value');
            self.stored_data.write(history_element.value.read());
            self.history.push(history_struct);
            self.last_update.write(now);
            self.emit(DataChanged { old_value: old_value, new_value: history_struct.value });
        }
        
}}

#[cfg(test)]
mod tests {
    use super::SimpleStorage;
    // Здесь пишутся тесты, которые Scarb умеет запускать
}