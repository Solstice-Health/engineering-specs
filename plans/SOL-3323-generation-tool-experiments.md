# SOL-3323: Banner generation tool experiments

**Ticket:** [SOL-3323](https://linear.app/solsticehealth/issue/SOL-3323)

New tools the banner agent can call during generation.

**Test set:** Novocure, Lisraya, Ibsrela. 3 banners per tool. 4 dimensions per banner.

## What we're testing

1. **Background generation**
   On-the-fly creation of backgrounds, and adaptation of backgrounds for different aspect ratios.

2. **GIF creation**
   Convert an image into an animated background with a video model like h3.

3. **Text placement to complement an image**
   Open to various approaches for understanding how to best complement a subject with text.
	- SAM, rembg, etc.

## How

- One tool at a time. Same 3 banners × 4 sizes.
- Shared control: 3 without any of the tools.
- Score all 4 sizes on all 3 banners.

## Acceptance

Compare each tool's 3 banners × 4 sizes against the shared without-any-tools control.

## Done

12 total banners:
- 3 without any of the tools
- 3 with background generation
- 3 with GIF creation
- 3 with text placement

Based on these examples we will understand whether each tool improves quality and should be included in the agentic pipeline.
