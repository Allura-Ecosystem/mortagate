# Ecosystem Relationships

Mortgate is independently cloneable and remains the canonical source for its product. Sibling systems are linked in both directions here: what Mortgate receives from each sibling and what Mortgate returns or preserves for that sibling.

| Sibling | Into Mortgate | Back from Mortgate | Failure/degraded behavior |
|---|---|---|---|
| [Allura Memory](https://github.com/Allura-Ecosystem/Allura_Memory) | Optional governed engineering context and evidence persistence under `group_id: allura-mortgage` | Mortgate supplies a product-scoped tenant boundary and factual outcome evidence; the employee skills never treat Memory as the audit | Product skills still work; memory-dependent harness actions report unavailable and do not invent receipts |
| [allura-plugins](https://github.com/Allura-Ecosystem/allura-plugins) | Future catalog discovery, packaging, and install surface | Mortgate supplies a pinned, generated export through [`catalog-export.json`](../catalog-export.json); fixes return upstream before regeneration | Use this standalone repository; the future package path is not presented as published |
| [Team RAM](https://github.com/Allura-Ecosystem/allura-team-ram) | Optional internal software-delivery harness and review lanes | Mortgate supplies repository policy, mortgage safety boundaries, validation commands, and release authority; Team RAM already documents its [Mortagate consumer boundary](https://github.com/Allura-Ecosystem/allura-team-ram/blob/main/docs/ecosystem-relationships.md#mortagate) | Work can continue manually; no Team RAM role gains mortgage or release authority |
| [Team Durham](https://github.com/Allura-Ecosystem/team-durham) | Optional brand strategy, production, accessibility, and QA | Mortgate supplies product truth, approved claims, compliance boundaries, and final brand/release approval | Use existing checked-in product language/assets; do not fabricate brand approval |

## Future generated package

The future destination is [`allura-plugins/packages/mortagate-cowork`](https://github.com/Allura-Ecosystem/allura-plugins/tree/main/packages/mortagate-cowork). Distribution is intentionally one-way at generation time:

```text
Mortgate source + pinned commit -> validated allowlist -> allura-plugins generated package
             ^                                             |
             +----------- fixes contributed upstream ------+
```

The destination must record source repository, exact source commit, contract version, and generation method. It is not another editable authority.

## Product authority

None of these relationships transfers credit-decision, mortgage-policy, tenant, data, or release authority away from Mortgate's approved human owners. Allura Memory remembers; allura-plugins distributes; Team RAM builds/reviews; Durham supports brand work; Mortgate owns this product contract.
