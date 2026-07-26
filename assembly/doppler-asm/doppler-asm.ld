/* Per-program linker script for the SBF v3 doppler.
 *
 * Mirrors the layout the `sbpfv3-solana-solana` rustc target emits, which the
 * rbpf loader validates strictly (solana-sbpf elf.rs):
 *   - .rodata at region 0 (0x0), marked PF_R
 *   - .text   at region 1 (0x100000000), marked PF_X (execute-only)
 *   - a trailing PT_NULL program header
 *   - no .dynamic / .dynsym / .dynstr / relocations
 *
 * The BYTE(0) forces a non-empty read-only segment so the PF_R program header
 * always exists (the loader expects rodata as the first header). Tune the
 * .rodata block here if this program grows constant data.
 */
/* Entry point symbol (defined in doppler-asm.s). Sets e_entry in the ELF header. */
ENTRY(e)

SECTIONS
{
  .text 0x100000000 : {
     *(.text*)
  } :text
  /DISCARD/ : {
      *(.rodata*)
      *(.data.rel.ro*)
      *(.comment*)
      *(.eh_frame*)
      *(*hash*)
      *(.bss*)
      *(.data*)
      *(.rel.dyn*)
      *(.dynamic)
      *(.symtab)
      *(.strtab)
      *(.dynsym)
      *(.dynstr)
    }
}

PHDRS
{
  text PT_LOAD FLAGS(1);   /* PF_X */
}
