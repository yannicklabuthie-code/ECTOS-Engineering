# ECTOS — QC02/QC03 Native Successor V77

This package contains the **versioned native PowerShell controllers and schemas** with the single updated authority bridge, not a production trust root. The original V48 bridge is retained unchanged.

## Engineering evidence
- Exact real Windows PowerShell 5.1 QC02 compilation PASS on isolated signed fixture.
- Exact real Windows PowerShell 5.1 QC03 tool fit PASS with 2 distinct signed fixture tools.
- Native negative tests: 4/4 fail closed for denied QC02 envelope, tampered QC03 subject, altered tool provenance and revoked QC02 approval.
- V77 native regression self-test PASS; universal issuer/bridge synthetic tests 8/8 with 2 and 22 tools.
- Production root unchanged; G00 and cloud untouched.

## Qualification boundary
All positive approvals used an ephemeral, **synthetic test-only signing identity** and isolated test policy; they never prove a real external requirements approval or independent QC qualification. The actual ECTOS MAIN admission and independent qualification are outstanding. The native controller code retains the same contract signature verification, revocation and tool-byte checks.

## Next required acceptance
1. Separate independent qualification role checks the exact V77 archive digest and repeats positives/negatives on a separate evidence authority.
2. MAIN reviews the exact versioned evidence and decides admission.
3. A subsequent governed deployment, if authorized, installs the admitted successor; live roots must remain separate from package.
