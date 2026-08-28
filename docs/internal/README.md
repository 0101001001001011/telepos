# Internal working notes are not published

Comments throughout the code cite paths under `docs/internal/` — design
specifications, implementation plans, the running project map, and the testing
notes. **Those files are not in this repository**, and their absence is
deliberate rather than an oversight.

They are Russian-language working material: the record of why decisions were
made, what was measured, and which findings were later retracted. They are kept
in the private development repository, are not maintained for readers, and
several entries describe work that has since been undone.

What that means when you meet such a citation: the comment above it is the
substance, and the path is provenance rather than a link. Nothing in this
repository depends on those files to build, test or run.

The documentation that *is* published lives one level up, in English:

| File | What it is |
| --- | --- |
| [`../ARCHITECTURE.md`](../ARCHITECTURE.md) | Layering rules, and what may import what |
| [`../system-architecture.md`](../system-architecture.md) | The governing document: topology, ownership, 155 invariants |
| [`../FEATURES.md`](../FEATURES.md) | What the product does today, and what it does not |
| [`../VISION.md`](../VISION.md) | What it is for — none of it built |
| [`../appliance.md`](../appliance.md) | The Linux appliance and how the two halves fit |

If a decision in the code looks arbitrary and the citation is not enough, open
an issue and ask. That question is welcome, and answering it usually improves
the published documentation.
