# Evidence Metadata Contract

Shared by `loan-file-evidence-review`, `policy-replay-review`, and
`audit-packet-draft`. Satisfies control E-2 in
`my-project/_bmad-output/test/CONTROL-MATRIX.md`; the target field set is
specified in `microsoft-cowork/docs/CONNECTOR-ROADMAP.md` §4.

## Why this exists now, before a connector

A reviewer cannot act on a fact they cannot trace. Today the only provenance
available is what a conversation-supplied document carries on its face — a
filename and a page or section. A connector will later supply document hashes,
extraction versions, and freshness.

Fixing the *shape* now means the connector adds fields to an existing contract
instead of forcing a rewrite of every skill's output format.

## Fields

| Field | Source today | Source with a connector |
|---|---|---|
| `source system` | `conversation-upload` | System of record identifier |
| `document id` | Visible filename | Stable document ID |
| `document hash` | **unavailable** | Content hash from the vault |
| `page / section` | As cited in the document | Same, from extraction |
| `extraction version` | **unavailable** | Extractor version |
| `confidence` | **unavailable** | Extraction confidence |
| `freshness` | Date stated on the document, if any | Retrieval timestamp |

## Rendering

Report provenance in a single `Source` cell, most specific first:

```
conversation-upload · form-1003.txt · p.1
conversation-upload · paystub-2026-04-15.txt · earnings section
```

**Never render a field that is unavailable.** Do not emit `hash: n/a`,
`confidence: unknown`, or an empty column. An absent field must be absent, not
displayed as a null — a reviewer scanning for a hash must not find a placeholder
where a value would go.

When a connector supplies the fuller set, append fields in the table order above.

## Boundary

Provenance describes *where a fact came from*. It never implies the fact is
verified, the document is authentic, or the upload is a system of record. A
`document hash` proves content integrity only; it does not establish that the
document is genuine or current.
