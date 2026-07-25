mod setup;

use {
    crate::setup::{run, setup, BASE_LAMPORTS},
    mollusk_svm::result::Check,
    solana_account::Account,
    solana_address::Address,
    solana_instruction::{error::InstructionError, AccountMeta, Instruction},
    solana_program_error::ProgramError,
};

const PROGRAM_ID: Address = Address::from_str_const("counter111111111111111111111111111111111111");

fn instruction(program_id: &Address, is_writable: bool) -> (Instruction, Vec<(Address, Account)>) {
    let counter = Address::new_unique();

    let accounts = vec![(
        counter,
        Account::new(BASE_LAMPORTS, size_of::<u64>(), program_id),
    )];
    let account_metas = vec![AccountMeta {
        pubkey: counter,
        is_signer: false,
        is_writable,
    }];

    (
        Instruction {
            program_id: *program_id,
            accounts: account_metas,
            data: vec![],
        },
        accounts,
    )
}

#[test]
fn test_counter() {
    let mollusk = setup(&PROGRAM_ID, "counter-asm");
    let (instruction, accounts) = instruction(&PROGRAM_ID, true);

    let (key, result) = run(&mollusk, &instruction, &accounts, &[Check::success()]);

    let account = result.get_account(&key);
    assert!(account.is_some());

    // The counter must have been incremented from 0 to 1.

    assert_eq!(&account.unwrap().data, 1u64.to_le_bytes().as_slice());
}

#[test]
fn fail_counter_with_readonly_account() {
    let mollusk = setup(&PROGRAM_ID, "counter-asm");
    let (instruction, accounts) = instruction(&PROGRAM_ID, false);

    let (key, result) = run(
        &mollusk,
        &instruction,
        &accounts,
        &[Check::instruction_err(
            InstructionError::ProgramFailedToComplete,
        )],
    );

    let account = result.get_account(&key);
    assert!(account.is_some());

    // The counter data should not have changed.

    assert_eq!(&account.unwrap().data, 0u64.to_le_bytes().as_slice());
}

#[test]
fn fail_counter_without_account() {
    let mollusk = setup(&PROGRAM_ID, "counter-asm");

    let instruction = Instruction {
        program_id: PROGRAM_ID,
        accounts: vec![],
        data: vec![],
    };

    mollusk.process_and_validate_instruction(
        &instruction,
        &[],
        &[Check::err(ProgramError::NotEnoughAccountKeys)],
    );
}
