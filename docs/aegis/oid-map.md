
# AEGIS OID Map

## Purpose
Object Identifiers (OIDs) in the AEGIS system uniquely identify and version global packs, domain‑specific packs, and `.1337` caches. The hierarchy ensures consistent referencing, seamless updates, and reliable merging of language/context resources across distributed AI deployments.

## Structure
- `0` — **Global Root (AEGIS Core)**
  - `0.1` — Global Interaction Rules Pack
  - `0.2` — Global Colorfulness/Register Policy Pack
- `1` — **Domain Root (1.x)** — industry/mission verticals (see table below)
- `2` — **Runtime Caches**
  - `2.1337` — Learned Local Cache (leet‑coded, dynamic slang/jargon per entity)

---

## Domain Roots (first 10)
> Reserve contiguous blocks for each domain. Sub‑OIDs (e.g., `1.0.1`) hold lexicon, templates, interaction rules, etc.

| OID  | Domain / Vertical              | Notes |
|------|--------------------------------|-------|
| **1.0** | Warehouse & Logistics           | Forklifts, picking, staging, shift ops |
| **1.1** | Construction                    | Site coordination, trades, safety briefings |
| **1.2** | Timber & Forestry               | Harvest ops, equipment dispatch, field safety |
| **1.3** | Maritime                        | Vessel ops, COLREGS, port integration |
| **1.4** | Aviation                        | ATC/flight crew phraseology, airport ops |
| **1.5** | Military & Defense              | Tactical comms, brevity, command protocols |
| **1.6** | Healthcare                      | Triage, clinical handoffs, bedside comms |
| **1.7** | Energy & Utilities              | Generation, transmission, field maintenance |
| **1.8** | Rail & Transit                  | Dispatch, wayside safety, yard operations |
| **1.9** | Public Safety (Fire/EMS/Police) | Incident command, mutual aid, dispatch |

---

## Example Allocations
| OID         | Description                               |
|-------------|-------------------------------------------|
| `0.1.1`     | Global safety language                    |
| `0.1.2`     | Global escalation phrases                 |
| `1.0.1`     | Warehouse forklift safety terms           |
| `1.0.2`     | Warehouse radio call slang                |
| `1.3.1`     | Maritime COLREGS templates                |
| `1.4.1`     | Aviation ATC standard phraseology         |
| `1.4.2`     | Aviation local airport procedures         |
| `1.5.1`     | Military brevity codes                    |
| `1.6.1`     | Healthcare SBAR handoff templates         |
| `2.1337.23` | Local slang additions (entity #23)        |

---

## Versioning
OIDs may include semantic version suffixes to track updates without breaking existing integrations. Example: `1.4.1-v2.0` refers to version 2.0 of the Aviation ATC standard phraseology pack. Pin deployments to version labels and keep prior versions available for rollback.

## Integration Notes
- **Merging:** Combine packs by traversing the hierarchy: Global (0.x) → Domain (1.x) → Local overrides → `.1337`. More specific layers override broader ones.
- **Conflict Resolution:** If two packs define the same sub‑OID, prefer the more specific (local over domain) or the higher version. Use manual review for overlapping semantics.
- **Extensibility:** Add new domains as `1.10+` with contiguous ranges; avoid renumbering. If renumbering is unavoidable, keep alias tables for deprecation windows.