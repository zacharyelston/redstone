 
# .1337 Learned Cache

## 1) Purpose
The **.1337 Learned Cache** is a local, rapidly updatable store of slang, jargon, abbreviations, and style cues observed in a specific environment (site, vessel, aircraft, unit). It lets an AI Worker *understand* evolving language immediately and, with guardrails, selectively *generate* it for authenticity and speed—without changing immutable safety policy.

## 2) How It Works (Overview)
1. **Observe**: The AI ingests transcripts (radio, intercom, chat) and operational text (tickets, shift notes).
2. **Detect candidates**: OOV terms and recurring n‑grams are flagged via regex + embedding outlier detection.
3. **Sense map**: Try to align to existing lexicon senses; if none, mark `new` with a provisional gloss.
4. **Score**: Update `count`, `speaker_diversity`, and `confidence = f(freq, diversity, recency)`.
5. **Safety gate**: Block redlined content (slurs, person‑directed insults). Soft‑mask profanity; allow situation‑directed only.
6. **Propose**: If thresholds met, add entry to `.1337` as `status=proposed`.
7. **Use**: Immediate for **understanding**; **generation** restricted until accepted (or high‑confidence, non‑safety contexts—see §6).
8. **Curate**: Ops reviewers accept/reject; accepted terms may be promoted into Local Overrides.
9. **Decay/Evict**: Exponential decay + LRU keep cache small and fresh.

## 3) Entry Schema (minimal)
```json
{
  "term": "hi-lo",
  "normalized": "forklift",
  "kind": "alias|acronym|phrase|style",
  "senses": ["forklift_std"],
  "examples": ["Hi-lo requested in zone C."],
  "source": "radio|transcript|ticket|badge:42",
  "first_seen": "2025-08-09T10:12:05Z",
  "last_seen": "2025-08-09T11:03:22Z",
  "count": 17,
  "speaker_diversity": 5,
  "confidence": 0.86,
  "toxicity": 0.00,
  "status": "proposed|accepted|rejected",
  "locale": "en-US",
  "style": ["warehouse","day-shift"],
  "notes": "Synonym of forklift"
}
```

## 4) Example Entries (mixed domains)
| Term              | Meaning                               | Tone/Context | Example Use                                        |
|-------------------|---------------------------------------|--------------|----------------------------------------------------|
| **Watch your six**| Be alert, check behind you            | cautionary   | "Watch your six—pallet coming through."           |
| **Ramp hot**      | High activity/danger on ramp          | urgent       | "Ramp hot, keep clear."                           |
| **Blue juice**    | Aircraft lavatory fluid               | informational| "We’re low on blue juice before next departure."  |
| **Deadhead**      | Crew repositioning without passengers | neutral      | "Two pilots are deadheading on this leg."         |
| **Tow motor**     | Local slang for forklift              | neutral      | "Tow motor needed in zone C."                     |

## 5) Thresholds & Defaults
- `min_count = 5`
- `min_speaker_diversity = 3`
- `confidence_threshold_propose = 0.75`
- `confidence_threshold_generate = 0.90` *(if not accepted; non‑safety channels only)*
- `half_life_days = 14` *(exponential decay)*
- `max_cache_terms = 200` *(LRU + decay eviction)*

## 6) Generation vs Understanding
- **Understanding:** High‑confidence aliases and phrases are always used to interpret input.
- **Generation:** Allowed only when *either*:
  - `status = accepted`, **or**
  - `confidence ≥ 0.90` **and** channel is internal **and** message is non‑safety.
- **Never generate** person‑directed insults or slurs. Situation‑directed profanity follows core policy.

## 7) Merge Order at Runtime
`Global Pack` → `Domain Pack` → `Local Overrides` → `.1337 (top‑K high‑confidence)`

## 8) Storage Layout
**Redis (hot path)**
```
aegis:jargon:1337:<entity_id>   # JSON array of entries
```

**Postgres (durable mirror)**
```sql
CREATE TABLE learned_jargon (
  entity_id TEXT,
  term TEXT,
  normalized TEXT,
  kind TEXT,
  senses TEXT[],
  examples TEXT[],
  source TEXT,
  first_seen TIMESTAMPTZ,
  last_seen TIMESTAMPTZ,
  count INT,
  speaker_diversity INT,
  confidence DOUBLE PRECISION,
  toxicity DOUBLE PRECISION,
  status TEXT,
  locale TEXT,
  style TEXT[],
  notes TEXT
);
```

## 9) API Sketch
**GET** `/v1/1337/:entity_id?topK=8` → returns top‑K high‑confidence terms.  
**POST** `/v1/1337/:entity_id/propose` → `{term, normalized, kind, senses[], example}`.  
**POST** `/v1/1337/:entity_id/accept` → `{term}` (promotes to `accepted`).  
**POST** `/v1/1337/:entity_id/reject` → `{term}` (adds to do‑not‑learn list for 90 days).  
**POST** `/v1/1337/:entity_id/evict` → `{term}`.

## 10) Metrics & Review
- **Daily**: auto‑propose candidates crossing thresholds.  
- **Weekly**: ops review to accept/promote or reject/evict.  
- **Monthly**: export snapshot for audit; reconcile Redis ↔ Postgres.  
- Track: adoption rate, comprehension lift, incident/latency deltas, false‑positive learn rate.

## 11) Admin Ops
- **Reset cache** per entity (keep durable mirror).  
- **Fork cache** to sibling entity (e.g., Warehouse‑B from Warehouse‑A).  
- **Promote** accepted entries into Local Overrides (immutable bundle on next build).

## 12) Safety Gates
- Hard‑ban: slurs/protected‑class terms (redline DFA).  
- Person‑directed insults → auto‑reject.  
- Situation‑directed profanity allowed per severity gates in Core policy.  
- Interactive messages always pass through interaction‑FSM before emission.

## 13) Failure Modes & Fallbacks
- **Redis miss** → fallback to S3/OCI bundle; continue without `.1337`.  
- **Postgres down** → continue; queue durable writes.  
- **High toxicity spike** → freeze generation from `.1337`; understanding only.  
- **Drift alert** (rapid slang change) → throttle proposes; require manual review.

## 14) Security & Privacy
- Strip PII from examples where possible; store badge IDs as hashed tokens.  
- Sign bundle and verify at load.  
- Role‑based control for accept/reject operations; full audit trail in Telemetry.

## 15) Testing Checklist
- Candidate detection unit tests (OOV + n‑gram).  
- Redline DFA rejects.  
- Interaction FSM compliance on generated outputs.  
- Merge‑order determinism across Global/Domain/Local/.1337.  
- Decay/eviction under load; vector lookup correctness if used.