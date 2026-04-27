// Импортируем необходимые трейты (интерфейсы) для работы с хранилищем
use starknet::{ContractAddress, get_caller_address};
use starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess};


#[starknet::interface]
trait ISimpleStorage<TState> {
    fn set(ref self: TState, x: u128);
    fn get(self: @TState) -> u128;
    fn increment(ref self: TState);
    fn increase_by(self: @TState, amount: u128) -> u128;
    fn deposit(ref self: TState, amount: u128);
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u128);
}

#[starknet::contract]
mod SimpleStorage {
    // Подтягиваем импорты внутрь модуля контракта
    use super::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry};
    use super::{ContractAddress, get_caller_address};
    use starknet::event::EventEmitter;

    #[storage]
    struct Storage {
        // В Starknet переменные в Storage — это не просто ячейки, 
        // а указатели на места в дереве состояния
        stored_data: u128,
        owner: ContractAddress,
        balances: Map<ContractAddress, u128>,

    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u128) {
        self.stored_data.write(initial_value);
        let deployer = get_caller_address();
        self.owner.write(deployer);
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

        fn set(ref self: ContractState, x: u128) {
            let owner = self.owner.read();
            let caller = get_caller_address();
            assert(owner == caller, 'Only owner can call this fn');
            let old = self.stored_data.read();
            // Теперь метод write доступен
            self.stored_data.write(x);
            self.emit(DataChanged { old_value: old, new_value: x });

        }

        fn get(self: @ContractState) -> u128 {
            // Теперь метод read доступен
            self.stored_data.read()
        }

        fn increment(ref self: ContractState){
            // читаем текущее число
            let current = self.stored_data.read();

            let next = current + 1;

            self.stored_data.write(next);
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

    }}

#[cfg(test)]
mod tests {
    use super::SimpleStorage;
    // Здесь пишутся тесты, которые Scarb умеет запускать
}