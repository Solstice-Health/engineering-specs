

## Checklist

1. **Upgrade GSAP**
   - Switch out GSAP to v3, work through issues that come up from the switch.

2. **Convert text to images**
   - For non-Google fonts, convert text to images via the actions menu.

3. **Image compression**
   - Compression to hit a specific size of the package.

4. **Compatibility agent v1**
   - First pass at an agent that will review and edit a banner ad based on requirements for a given platform
	   - Drop down allows user to select platform to deploy on, compatability agent has access to the above tools (and potentially others) to achieve compatablity with the platform. Prompt would include requirements regarding click tags, maximum package size, etc.

## Done

- GSAP v3, issues from the switch worked through
- non-Google fonts convert to images
- Compression tool created
- compatibility agent can convert fonts, achieve file size, detect clickTags, and dimension failures
