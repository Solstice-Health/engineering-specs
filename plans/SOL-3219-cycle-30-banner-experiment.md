# SOL-3219: Cycle 30 banner experiment results

**Ticket:** [SOL-3219](https://linear.app/solsticehealth/issue/SOL-3219)
**Date:** Friday, August 21, 2026
**Brands:** Lisraya, Ibsrela
**Environment:** [sanofi-sandbox](https://www.sanofi-sandbox.solsticehealth.co)
**Arms:** optimal manual brand rules vs Ari and Chandhru's automatic brand-setup pipeline (clustering)

Success metric: a list of what automatic brand-rule ingestion still needs to include to reach the optimal manually created rules.

---

## Results

### Lisraya

| Arm | Assets |
|---|---|
| Manual | [1](https://www.sanofi-sandbox.solsticehealth.co/home/assets/85caaee1-0a9c-477f-b8e6-51ea675cf3c4?view=content) · [2](https://www.sanofi-sandbox.solsticehealth.co/home/assets/42b85fbc-8e82-43c0-9882-175952457e88?view=content) · [3](https://www.sanofi-sandbox.solsticehealth.co/home/assets/e401db26-d833-4b0c-94a0-b2b27c74c5d2?view=content) |
| Automatic | [1](https://www.sanofi-sandbox.solsticehealth.co/home/assets/4245c17f-f848-47d8-8af9-1dcb07f30765?view=content) · [2](https://www.sanofi-sandbox.solsticehealth.co/home/assets/38cff9be-b5f2-4765-bf9d-e6c42a4f6880?view=content) · [3](https://www.sanofi-sandbox.solsticehealth.co/home/assets/e3a19fa0-9d28-43bc-ac49-d99ea7cc0087?view=content) |

### Ibsrela

| Arm | Assets |
|---|---|
| Manual | [1](https://www.sanofi-sandbox.solsticehealth.co/home/assets/d1dacb98-d0ff-4503-bd79-c63facf642aa?view=content) · [2](https://www.sanofi-sandbox.solsticehealth.co/home/assets/663d0e17-7e58-457f-9e02-6eb94ce91069?view=content) · [3](https://www.sanofi-sandbox.solsticehealth.co/home/assets/3717e3fa-adec-472f-9c21-e93c0a60d0f6?view=content) |
| Automatic | [1](https://www.sanofi-sandbox.solsticehealth.co/home/assets/52fd56dc-066f-4d81-ba90-58624891e6ce?view=content) · [2](https://www.sanofi-sandbox.solsticehealth.co/home/assets/97fe61e9-7191-4c87-b588-907c825d415d?view=content) · [3](https://www.sanofi-sandbox.solsticehealth.co/home/assets/299efefe-e37f-4b57-aff4-e36b47ca2602?view=content) |

---

## What automatic setup is missing

What current automatic brand-rule ingestion still needs to include to match the optimal manual rules.

### ISI

- ISI **content**
- ISI **container HTML snippet per dimension**, including footer contents (logos) and links
- ISI **scroll speed**

### Logo

- Placement and usage requirements: how big, which color to use when

### Backgrounds

- Backgrounds, ideally including placement on a **dim-by-dim** basis

### Animation examples

- Text entrances
- Number / statistic visualizations
- Text emphasis
- CTA behavior
- Scene transitions
- Misc. brand rules (e.g. restrictions on all text being visible at the same time)

### Type and chrome

- Custom font / hosted placement
- Scrim (gradient overlay for text visibility) design
- Text drop-shadow design

### Variety

The current optimal manual setup describes **when** to use things. Automatic rules end up following the same pattern over and over. Need variety explanation / encouragement so ingestion does not collapse to one formula.

---

## How to achieve the above

- Need prior approved HTMLs. That is where the real ISI chrome, logo placement, backgrounds, and animation live — a style guide will not have this.
- Mining the website for visualization code / animation snippets is valuable. Approved units often miss treatments the live site already has.
- Documentation on ISI container size / scroll speed is good to have and should be ingested if available. Without it the tray/rail and auto-scroll get guessed / are based on prior approved.
- We had an LLM generate a bunch of animation options (some from prior approved units, some from online research). A human then picked the best ones. That improved quality — dumping every option into the rules has limitations.
