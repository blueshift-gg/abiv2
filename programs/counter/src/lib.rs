//! A simple ABIv2 counter program.

#![no_std]
use abiv2::{
    account::Account, context::InstructionContext, entrypoint, error::ProgramError, ProgramResult,
};

entrypoint!(process_instruction);

pub fn process_instruction(
    _context: &InstructionContext,
    accounts: &[Account],
    _instruction_data: &[u8],
) -> ProgramResult {
    let [counter] = accounts else {
        abiv2::hint::cold_path();
        return Err(ProgramError::NotEnoughAccountKeys);
    };

    let counter = unsafe { &mut *counter.data_ptr().cast::<u64>() };

    *counter += 1;

    Ok(())
}
