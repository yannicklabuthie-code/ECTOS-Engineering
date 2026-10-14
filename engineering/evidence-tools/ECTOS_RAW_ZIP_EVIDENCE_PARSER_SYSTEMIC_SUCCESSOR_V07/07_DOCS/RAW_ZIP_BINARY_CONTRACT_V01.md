# ECTOS Raw ZIP Binary Contract V01

TOOL_ID=ECTOS_RAW_ZIP_EVIDENCE_PARSER
VERSION=2.0.0

## Binary invariants
- ZIP multibyte integers are little-endian.
- Reads are range-checked before access.
- Arithmetic is overflow-checked before offset/length use.
- Raw bytes are authoritative evidence.
- Host endianness is never a ZIP semantic.
- Local headers, central-directory headers, EOCD, ZIP64 EOCD/locator, data descriptors, extra fields and comments are parsed from raw bytes.
- Unknown extra-field IDs are preserved as raw bytes.
- UTF-8 is strict when general-purpose bit 11 is set; otherwise CP437 is used without locale fallback.
- Multi-disk ZIP is unsupported in V01 and fails closed.
- EOCD search window is at most 65,557 bytes.
- Any unclassified bytes after EOCD+comment fail closed.

## No substitution
`System.IO.Compression.ZipArchive` may not be used as a substitute for raw structural parsing. The implementation may use .NET byte/stream/crypto primitives only.

## Raw / decoded / normalized separation
Raw filename bytes, decoded filename, and normalized path are separate evidence values. Raw DOS timestamps and derived datetime representations must remain separate. Normalization never overwrites raw evidence.

## Input mutation
The parser captures input size/SHA before parse and revalidates after parse. A change fails with `RZP_INPUT_CHANGED_DURING_PARSE`.
