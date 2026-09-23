# Retriever tool — proposed banner-first plan

## 1. Shared preprocessing — index design intent, editable parameters, components and usage roles

```mermaid
flowchart TD
    library["Template library: source, assets and render proofs"] --> inspect["Inspect each template and its customization behavior"]
    inspect --> identity["Template ID, source revision and asset dependencies"]
    inspect --> intent["Design intent and suitable content scenarios"]
    inspect --> customization["Intended customizations and supported transformations"]
    inspect --> parameters["Structured parameter schema: types, defaults and constraints"]
    inspect --> components["Components, composition slots and layout constraints"]
    inspect --> roles["Multiple usage roles per template"]
    roles --> roleValues["Scene transitions, component animations, background animations, backgrounds, text blocks, components and layouts"]
    identity --> catalog["Versioned template metadata linked to source and proofs"]
    intent --> catalog
    customization --> catalog
    parameters --> catalog
    components --> catalog
    roleValues --> catalog
    catalog --> embeddings["Embed design intent and use scenarios"]
    catalog --> metadata["Queryable metadata and complete source packages"]
    embeddings --> index[("Design-intent retrieval index")]
    metadata --> index
```

## 2. Shared bundle contract — each subagent submits one composed candidate containing the templates it used together

```mermaid
flowchart TD
    brief["Banner content, design brief, brand assets and target sizes"] --> plan["Shared scene order, content allocation and visual direction"]
    plan --> workers["N independent subagents; initial N = 1"]
    workers --> search["Each subagent explores K intent queries and multiple candidate templates"]
    search --> compose["Customize and compose templates into one complete candidate banner"]
    compose --> bundle["One submitted bundle per subagent"]
    bundle --> identity["Bundle ID, subagent ID and brief revision"]
    bundle --> manifest["Member template IDs and revisions, roles and scene mapping"]
    bundle --> source["Customized source, parameter values, assets and dependencies"]
    bundle --> proofs["Assembled scene renders and consistent storyboard preview"]
    bundle --> verification["Content coverage, target-size layout, timing and transition checks"]
    identity --> package["Complete bundle package"]
    manifest --> package
    source --> package
    proofs --> package
    verification --> package
    package --> selection["Compare complete composed bundles"]
    selection --> result["Selected bundle, source, renders and selection evidence"]
```

## 3. Strategy 1 — intent retrieval, subagent customization and VLM selection

```mermaid
flowchart TD
    request["Brief, assets, target sizes and shared scene plan"] --> queries
    index[("Design-intent index and template catalog")] --> retrieve

    subgraph workers["Each of N subagents; initial N = 1"]
        queries["Fan out K design-intent queries"] --> retrieve["Retrieve candidate templates for each query"]
        retrieve --> inspect["Reason over full metadata, original renders and source code"]
        inspect --> customize["Properly customize and compose multiple templates"]
        customize --> render["Render the assembled banner across scenes and target sizes"]
        render --> verify{"Content, layout and sequence checks pass?"}
        verify -->|"Yes"| bundle["Return one complete candidate bundle"]
        verify -->|"Repair allowance remains"| customize
        verify -->|"Exhausted"| failed["Return failure evidence"]
    end

    bundle --> candidates["Collect valid candidate bundles"]
    request --> judge["VLM compares brief fit, visual hierarchy and sequence cohesion"]
    candidates --> judge
    judge --> selection{"Usable candidate?"}
    selection -->|"Yes"| result["Return selected bundle, customized source and judgment"]
    selection -->|"No"| noResult["Return no usable bundle"]
    failed --> exhausted["If all subagents fail, return no usable bundle"]
```

## 4. Strategy 2 — add Jev relevance filtering and Mercury rough code customization

```mermaid
flowchart TD
    request["Brief, intended customizations, components and shared scene plan"] --> filter["Jev classifies template relevance"]
    catalog[("Template catalog and design-intent embeddings")] --> filter
    filter --> pool["Relevant and uncertain templates"]
    catalog -.->|"Small exploration bypass"| pool
    request --> queries
    pool --> retrieve

    subgraph workers["Each of N subagents; initial N = 1"]
        queries["Fan out K design-intent queries"] --> retrieve["Retrieve templates from the candidate pool"]
        retrieve --> mercury["Mercury performs fast rough code customization"]
        mercury --> rough["Render rough adaptations and record failures"]
        rough --> inspect["Inspect original metadata, code and renders alongside rough results"]
        inspect --> customize["Properly customize and compose selected templates"]
        customize --> render["Render and verify the assembled banner"]
        render --> verify{"Content, layout and sequence checks pass?"}
        verify -->|"Yes"| bundle["Return one complete candidate bundle"]
        verify -->|"Repair allowance remains"| customize
        verify -->|"Exhausted"| failed["Return failure evidence"]
    end

    bundle --> candidates["Collect valid candidate bundles"]
    request --> judge["VLM compares brief fit, hierarchy and sequence cohesion"]
    candidates --> judge
    judge --> result["Return selected bundle and judgment, or no usable bundle"]
    failed --> exhausted["If all subagents fail, return no usable bundle"]
```

## 5. Strategy 3 — add GPT Image composition, code reconstruction and final visual judging

```mermaid
flowchart TD
    request["Brief, assets, target sizes and shared scene plan"] --> build["Use Strategy 2 candidate construction through verified subagent bundles"]
    build --> candidates["Collect complete candidate bundles before final selection"]
    candidates --> previews["Pack consistent bundle storyboard previews within the image-input budget"]
    previews --> image["GPT Image 2.5 composes a preferred design for the content"]
    request --> image
    image --> concept["Generated visual concept or storyboard"]
    concept --> interpret["VLM identifies useful template members and visual changes"]
    candidates --> interpret
    interpret --> rebuild["Subagent reconstructs the proposed composition using template source"]
    rebuild --> render["Render and verify the reconstructed bundle"]
    render --> verify{"Content, layout and sequence checks pass?"}
    verify -->|"Repair allowance remains"| rebuild
    verify -->|"Yes"| judge["VLM compares reconstructed and original bundle renders against the brief"]
    verify -->|"Exhausted"| originals["Keep original valid bundles eligible"]
    originals --> judge
    candidates --> judge
    request --> judge
    judge --> result["Return the selected verified source bundle, renders and judgment"]
```

## 6. Strategy 4 — GPT Image generates its preferred design and the VLM matches it to an existing bundle

```mermaid
flowchart TD
    request["Brief, assets, target sizes and shared scene plan"] --> build["Use Strategy 2 candidate construction through verified subagent bundles"]
    build --> candidates["Collect one complete candidate bundle per subagent"]
    candidates --> previews["One labeled storyboard image per bundle with the same panel arrangement"]
    candidates --> packages[("Existing customized source packages keyed by bundle ID")]
    previews --> image["GPT Image 2.5: Pick and use the best template bundle for this content and generate an image of it"]
    request --> image
    image --> generated["Generated banner or storyboard image"]
    generated --> match["VLM identifies the closest input bundle by composition, hierarchy and scene structure"]
    previews --> match
    match --> report["Closest bundle ID, alternatives, matching features and visible differences"]
    report --> status{"Match status?"}
    status -->|"Clear"| result["Return matched existing bundle source, generated image and match report"]
    packages --> result
    status -->|"Ambiguous, hybrid or no clear match"| unresolved["Return nearest candidates and ambiguity for explicit resolution"]
    packages --> unresolved
    generated --> result
    generated --> unresolved
```

## 7. GPT Image input allocation — cap submitted previews and extra references at the configured endpoint limit

```mermaid
flowchart TD
    endpoint["Direct Images Edit API: up to 16 input images"] --> budget["N subagents times preview images per bundle plus extra reference images must fit the limit"]
    reference["Brand and asset reference images consume input slots"] --> budget
    budget --> fits{"All submitted images fit?"}
    fits -->|"Yes"| submit["Submit the complete labeled image set"]
    fits -->|"No"| reduce["Reduce configured subagents or preview images before candidate generation"]
    reduce --> budget
    endpoint --> example["One bundle storyboard per subagent and zero extra references permits up to 16 subagents"]
    endpoint -.-> docs["Source: OpenAI Images Edit API reference"]
    click docs "https://developers.openai.com/api/reference/resources/images/methods/edit" "OpenAI Images Edit API reference"
```

## 8. Non-blocking mode — the main agent builds normally and applies retrieved templates when available

```mermaid
flowchart TD
    request["Asset request and retrieval strategy 1, 2, 3 or 4"] --> main["Main agent follows its usual content and asset pipeline"]
    request -.->|"Launch asynchronously"| retriever["Retriever tool runs in an isolated candidate workspace"]
    main --> render["Build, render and validate the asset"]
    render --> available["Base asset available without waiting for retrieval"]
    retriever --> outcome{"Usable selected bundle returned?"}
    outcome -->|"Yes"| load["Load the current asset revision at a safe editing boundary"]
    available -.->|"Current revision"| load
    load --> customize["Main agent applies the returned bundle templates to the existing asset"]
    customize --> check["Render and validate a new revision"]
    check --> valid{"Content, layout and sequence checks pass?"}
    valid -->|"Yes"| updated["Publish the customized asset revision"]
    valid -->|"No"| retained["Retain the valid base asset and record refinement failure"]
    outcome -->|"Pending"| ongoing["Ordinary generation continues while retrieval runs"]
    outcome -->|"Failed or no usable bundle"| unchanged["Keep the ordinary asset result and retrieval status"]
    outcome -->|"Ambiguous match"| resolve["Resolve candidate choice separately; base generation continues"]
    resolve -->|"Bundle selected"| load
    resolve -->|"Unresolved"| unchanged
```

## 9. Blocking mode — the main agent waits for a usable bundle and builds content with its templates

```mermaid
flowchart TD
    request["Asset request and retrieval strategy 1, 2, 3 or 4"] --> retriever["Run retriever tool before asset construction"]
    retriever --> outcome{"Usable selected bundle returned?"}
    outcome -->|"Pending"| wait["Wait for retrieval; asset construction has not started"]
    outcome -->|"Yes"| load["Load selected template bundle, source, assets and constraints"]
    load --> build["Main agent builds the content using the selected bundle templates"]
    build --> render["Render and validate the complete asset"]
    render --> valid{"Content, layout and sequence checks pass?"}
    valid -->|"Yes"| result["Publish the template-based asset"]
    valid -->|"Repair allowance remains"| build
    valid -->|"Exhausted"| retry{"Retrieval retry allowance remains?"}
    outcome -->|"Failed or no usable bundle"| retry
    retry -->|"Yes"| retriever
    retry -->|"No"| blocked["Return blocked status and failure evidence; construction still requires templates"]
    outcome -->|"Ambiguous match"| resolve["Resolve which existing candidate bundle to use"]
    resolve -->|"Bundle selected"| load
    resolve -->|"Unresolved"| blocked
```
