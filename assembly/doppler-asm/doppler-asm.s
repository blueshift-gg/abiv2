// ABIv2 port of doppler-asm (github.com/blueshift-gg/doppler-asm).
//
// Fixed layout: tx account 0 = admin (fee payer), tx account 1 = oracle
// (writable, [sequence: u64, price: u64]); instruction data = [sequence, price].
// If the admin matches the pinned pubkey and the incoming sequence beats the
// stored one, overwrite the oracle and return 0, else return 1.

.equ TX_ACCS, 0x500000000
.equ TX_ACC_KEY_0, 0x00
.equ TX_ACC_KEY_1, 0x08
.equ TX_ACC_KEY_2, 0x10
.equ TX_ACC_KEY_3, 0x18

// Account data payloads are strided by MAPPING_PAGE per tx index, so the oracle
// (tx account 1) payload is a compile-time constant.
.equ TX_ACCS_PAYLOAD, 0x800000000
.equ MAPPING_PAGE, 0x100000000
.equ ORACLE_DATA, TX_ACCS_PAYLOAD + MAPPING_PAGE

// Pinned admin pubkey (0x22 * 28 || 0x00000000, grinded tail).
.equ EXPECTED_ADMIN_KEY_0, 0x2222222222222222
.equ EXPECTED_ADMIN_KEY_1, 0x2222222222222222
.equ EXPECTED_ADMIN_KEY_2, 0x2222222222222222
// Negated: SBF has no sub-immediate and add32 rejects negative immediates.
.equ NEG_ADMIN_KEY_3, -0x22222222

.equ IX_SEQUENCE, 0x00
.equ IX_PRICE, 0x08
.equ ORACLE_SEQUENCE, 0x00
.equ ORACLE_PRICE, 0x08

.globl e

// r4 = instruction data ptr.
e:
  lddw r0, TX_ACCS
  lddw r1, ORACLE_DATA

  ldxdw r6, [r0+TX_ACC_KEY_0]
  lddw r9, EXPECTED_ADMIN_KEY_0
  jne r6, r9, abort
  ldxdw r7, [r0+TX_ACC_KEY_1]
  lddw r9, EXPECTED_ADMIN_KEY_1
  jne r7, r9, abort
  ldxdw r8, [r0+TX_ACC_KEY_2]
  lddw r9, EXPECTED_ADMIN_KEY_2
  jne r8, r9, abort
  ldxdw r0, [r0+TX_ACC_KEY_3]
  // Fold key word 3 to zero; r0 doubles as the success return value.
  add64 r0, NEG_ADMIN_KEY_3

  ldxdw r2, [r4+IX_SEQUENCE]
  ldxdw r3, [r1+ORACLE_SEQUENCE]
  jgt r2, r3, update

abort:
  mov32 r0, 0x1

update:
  stxdw [r1+ORACLE_SEQUENCE], r2
  ldxdw r2, [r4+IX_PRICE]
  stxdw [r1+ORACLE_PRICE], r2
  exit
