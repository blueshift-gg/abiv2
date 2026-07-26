mod setup;

use {
    crate::setup::{setup, BASE_LAMPORTS},
    mollusk_svm::result::Check,
    solana_account::Account,
    solana_address::Address,
    solana_instruction::{AccountMeta, Instruction},
};

const PROGRAM_ID: Address = Address::from_str_const("dopp1erasm111111111111111111111111111111111");

/// Pinned admin pubkey: 0x22 * 28 followed by a grinded 0x00000000 tail.
const ADMIN: Address = Address::new_from_array([
    0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22,
    0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x00, 0x00, 0x00, 0x00,
]);

/// Build the 16-byte instruction data (`[sequence: u64, price: u64]`).
fn ix_data(sequence: u64, price: u64) -> Vec<u8> {
    let mut data = Vec::with_capacity(16);
    data.extend_from_slice(&sequence.to_le_bytes());
    data.extend_from_slice(&price.to_le_bytes());
    data
}

/// Build a doppler instruction with the fixed layout:
/// account[0] = admin (fee payer / tx 0, signer), account[1] = oracle (writable).
fn instruction(
    program_id: &Address,
    admin: Address,
    oracle: Address,
    oracle_data: [u8; 16],
    sequence: u64,
    price: u64,
) -> (Instruction, Vec<(Address, Account)>) {
    let mut oracle_account = Account::new(BASE_LAMPORTS, 16, program_id);
    oracle_account.data = oracle_data.to_vec();

    let accounts = vec![
        (admin, Account::new(BASE_LAMPORTS, 0, &Address::default())),
        (oracle, oracle_account),
    ];
    let account_metas = vec![
        AccountMeta {
            pubkey: admin,
            is_signer: true,
            is_writable: false,
        },
        AccountMeta {
            pubkey: oracle,
            is_signer: false,
            is_writable: true,
        },
    ];

    (
        Instruction {
            program_id: *program_id,
            accounts: account_metas,
            data: ix_data(sequence, price),
        },
        accounts,
    )
}

#[test]
fn test_oracle_update() {
    let oracle = Address::new_unique();
    let mollusk = setup(&PROGRAM_ID, "doppler-asm");

    // Oracle starts at sequence 0; the update carries sequence 1, price 0x3713.
    let (instruction, accounts) = instruction(&PROGRAM_ID, ADMIN, oracle, [0u8; 16], 1, 0x3713);

    let result =
        mollusk.process_and_validate_instruction(&instruction, &accounts, &[Check::success()]);

    let mut expected = Vec::with_capacity(16);
    expected.extend_from_slice(&1u64.to_le_bytes());
    expected.extend_from_slice(&0x3713u64.to_le_bytes());
    assert_eq!(result.get_account(&oracle).unwrap().data, expected);
}

#[test]
fn fail_wrong_admin() {
    let oracle = Address::new_unique();
    let mollusk = setup(&PROGRAM_ID, "doppler-asm");

    // Fee payer is not the pinned admin: the update must be rejected.
    let (instruction, accounts) =
        instruction(&PROGRAM_ID, Address::new_unique(), oracle, [0u8; 16], 1, 0x3713);

    let result = mollusk.process_and_validate_instruction(&instruction, &accounts, &[]);
    assert!(result.program_result.is_err());

    // The oracle data must be unchanged after the revert.
    assert_eq!(result.get_account(&oracle).unwrap().data, [0u8; 16]);
}

#[test]
fn fail_stale_sequence() {
    let oracle = Address::new_unique();
    let mollusk = setup(&PROGRAM_ID, "doppler-asm");

    // Oracle already at sequence 5; an update with sequence 5 is not greater.
    let mut stored = Vec::with_capacity(16);
    stored.extend_from_slice(&5u64.to_le_bytes());
    stored.extend_from_slice(&0x1111u64.to_le_bytes());
    let stored: [u8; 16] = stored.try_into().unwrap();

    let (instruction, accounts) = instruction(&PROGRAM_ID, ADMIN, oracle, stored, 5, 0x9999);

    let result = mollusk.process_and_validate_instruction(&instruction, &accounts, &[]);
    assert!(result.program_result.is_err());

    // The oracle data must be unchanged after the revert.
    assert_eq!(result.get_account(&oracle).unwrap().data, stored);
}
