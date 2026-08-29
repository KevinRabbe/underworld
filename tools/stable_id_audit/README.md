# StableAddress / StableId Large-Corpus Audit

Development-only deterministic identity stress harness. It exercises the existing `StableAddress` factories and `StableId` derivation/parse contract without modifying identity production code.

## Corpus

Corpus revision:

```text
stable-id-audit-corpus-v1
```

The v1 corpus contains exactly **34,969 unique canonical addresses** spanning:
- underground regions;
- networks;
- root, child and multi-level lineage nodes;
- primary edges;
- entrances;
- entrance-anchor nodes;
- entrance-path edges;
- secondary connectors;
- special locations;
- generated child addresses;
- surface candidates.

Coordinates include positive, negative and large magnitudes through `±1,000,000`. Candidate slots include values from `0` through `1,000,000` within the current non-negative factory contract.

## Checks performed for every unique address

For each corpus case the auditor verifies:
1. the factory returns a non-null address;
2. canonical text is non-empty and unique within the corpus;
3. `StableAddress.parse(canonical_text)` reproduces the exact canonical address;
4. `StableId.from_address(address)` succeeds;
5. deriving the ID again from the parsed address reproduces exactly;
6. `StableId.parse(value)` reproduces the exact ID;
7. the parsed ID returns the original canonical address;
8. no distinct canonical address maps to an already-seen StableId value.

Primary-edge and secondary-connector endpoint reversal is also checked separately to prove endpoint ordering remains canonical and produces the same StableId.

## Output

The headless runner emits JSON and concise text reports containing:
- total/expected case count;
- case count by address family;
- reproduction-check count;
- endpoint-order-check count;
- collision count;
- complete failure list.

## Run locally

```bash
godot --headless --path . --script res://tools/stable_id_audit/run_stable_id_audit.gd -- \
  --out-dir=/tmp/underworld-stable-id-audit \
  --basename=stable_id_audit
```

A non-zero exit indicates an audit/export failure. If the audit discovers a production identity defect, fix it in a separate owning task rather than modifying the hashing/address schema inside ID-058.

## CI

`.github/workflows/stable-id-audit.yml` runs the full fixed corpus headlessly and uploads the JSON/text evidence. The workflow is intentionally triggered by changes to this tool, its workflow, or `worldgen/identity/**` so future identity changes are exercised against the larger corpus.
