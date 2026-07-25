// ABIv2 Constants
.equ TX_ACCS, 0x500000000
.equ TX_ACC_SIZE, 0x58
.equ TX_ACC_DATA, 0x48

// Program Error
.equ NOT_ENOUGH_ACCOUNT_KEYS, 0xb00000000

// Counter Program Constants
.equ EXPECTED_NUM_ACCS, 0x01
.equ COUNTER_IX_ACC_IDX, 0x00
.equ COUNTER_ACC_DATA, 0x00

.globl e

e:
  // Check we have exactly 1 account
  jne r3, EXPECTED_NUM_ACCS, not_enough_account_keys
  // Load TX account idx from IX account idx
  ldxh r1, [r2+COUNTER_IX_ACC_IDX]
  // Calculate TX acc offset from TX acc idx
  mul64 r1, TX_ACC_SIZE
  // Prime acc data base offset
  lddw r2, TX_ACCS
  // Add TX acc offset
  add64 r1, r2
  // Deref TX acc data offset
  ldxdw r1, [r1+TX_ACC_DATA]
  // Load current counter value
  ldxdw r2, [r1+COUNTER_ACC_DATA]
  // Increment counter value
  add64 r2, 0x1
  // Write counter value back to account
  stxdw [r1+COUNTER_ACC_DATA], r2
return:
  exit

not_enough_account_keys:
  lddw r0, NOT_ENOUGH_ACCOUNT_KEYS
  ja return