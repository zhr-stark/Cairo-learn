use starknet::{ContractAddress, get_caller_address,};
use starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess,
StoragePointerWriteAccess,};


#[starknet::interface]
trait IERC20Contract<TState>{
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, user: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;

    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;

}

#[starknet::contract]
mod ERC20Contract{

    use super::{Map, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess, ContractAddress, get_caller_address};
    use starknet::event::EventEmitter; 
    use core::num::traits::Zero;

    #[storage]
    struct Storage{
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<ContractAddress, Map<ContractAddress, u256>>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, _name: felt252, _symbol: felt252, _total_supply: u256){
          let zero_address: ContractAddress = Zero::zero();
        self.name.write(_name);
        self.symbol.write(_symbol);
        self.total_supply.write(_total_supply);
        self.decimals.write(18);
        let owner = get_caller_address();
        self.balances.entry(owner).write(_total_supply);
        self.emit(Transfer{from: zero_address, to: owner, value: _total_supply});
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event{
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key] // Поле будет проиндексировано (аналог indexed в Solidity)
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        value: u256,
    }

    #[abi(embed_v0)]
    impl ERC20ContractImpl of super::IERC20Contract<ContractState>{


        fn name(self: @ContractState) -> felt252{
            self.name.read()
        }

        fn symbol(self: @ContractState) -> felt252{
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8{
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256{
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, user: ContractAddress) -> u256{
              let zero_address: ContractAddress = Zero::zero();
            assert(user != zero_address, 'address does not exist');
            self.balances.entry(user).read()
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256{
              let zero_address: ContractAddress = Zero::zero();
            assert(owner != zero_address && spender != zero_address, 'address does not exist');
            self.allowances.entry(owner).entry(spender).read()
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool{
              let zero_address: ContractAddress = Zero::zero();
            let caller = get_caller_address();
            let caller_balance = self.balances.entry(caller).read();
            assert(recipient != zero_address, 'address does not exist');
            assert(caller_balance >= amount, 'Insufficient funds');
            assert(amount > 0, 'amount must be over zero');
            let new_balance = caller_balance - amount;
            self.balances.entry(caller).write(new_balance);
            let recipient_balance = self.balances.entry(recipient).read() + amount;
            self.balances.entry(recipient).write(recipient_balance);
            self.emit(Transfer{from: caller, to: recipient, value: amount});
            return true;
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool{
              let zero_address: ContractAddress = Zero::zero();
            let caller = get_caller_address();
            assert(spender != zero_address, 'address does not exist');
            assert(amount > 0, 'amount must be over zero');
            self.allowances.entry(caller).entry(spender).write(amount);
            self.emit(Approval{owner: caller, spender: spender, value: amount});
            return true;
        }

       fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        let zero_address: ContractAddress = Zero::zero();
        assert(sender != zero_address && recipient != zero_address, 'address does not exist');
        let caller = get_caller_address();
        
        
        let allowed = self.allowances.entry(sender).entry(caller).read();
        assert(allowed >= amount, 'Not enough allowance');
        
        let sender_balance = self.balances.entry(sender).read();
        assert(sender_balance >= amount, 'Insufficient funds');
        
        self.balances.entry(sender).write(sender_balance - amount);
        self.balances.entry(recipient).write(self.balances.entry(recipient).read() + amount);
        self.allowances.entry(sender).entry(caller).write(allowed - amount);
        
        self.emit(Transfer { from: sender, to: recipient, value: amount });
         return true;
    }
        
    }
}