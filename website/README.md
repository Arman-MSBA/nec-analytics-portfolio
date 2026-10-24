# Portfolio website source

[View the published portfolio](https://arman-khachatryan-ai-analytics.homehub-ai.chatgpt.site).

This portable source matches the published version 5 redesign, synchronized from source commit `bc27a4d6eefe3731682e6fb413dfaa8e37f2fa9f`. The homepage presents business intelligence, machine learning, and applied AI together. Case studies begin with original artifacts and concise business questions, contributions, and findings. Career experience, learning, consulting capabilities, and the résumé remain available.

## Build and preview

Node.js 22 or newer is sufficient. The generator and preview server use Node's standard library; dependency installation is unnecessary.

```sh
cd website
node scripts/generate-portfolio.mjs
node scripts/serve-static.mjs
```

Open the printed local URL. The build writes `dist/`, which is ignored by Git. The repository's [`../site/`](../site/) directory is the corresponding ready-to-host snapshot. Serve that directory from a web root to resolve the root-relative links correctly.

## Editing

- Content and saved aggregate metrics are in `content/`.
- `scripts/generate-portfolio.mjs` creates the pages; `scripts/render-cases.mjs` owns the case-study templates.
- Styles and browser controls are in `static/styles.css` and `static/site.js`.
- `public/` contains the résumé, original charts, Tableau captures, and approved synthetic retail `.twbx` packages.
- [`DESIGN.md`](DESIGN.md) describes the presentation choices.

Keep coursework distinct from employment. Report saved results with their limitations, and reconcile career changes with confirmed source information. Native Tableau screenshots retain their original pixels; CSS crops the authoring interface for display and the original captures remain linked. Older embedded workbook thumbnails retain their native 192px size. Generated concept images are design references and are not project evidence.

The Tableau packages include only approved synthetic retail course extracts and written notes. Do not add other raw course datasets, employer records, borrower or patient records, access credentials, or private provenance files.

## Verification and publication

Rebuild after content changes. Check local links, project filters, mobile navigation, model metric switching, workbook downloads, and desktop/mobile layouts. Training models or refreshing Tableau source data is separate from editing presentation. Saved coursework outputs do not establish external validation or business impact.

The current portfolio provides static Tableau previews and self-contained workbook downloads. Interactive Tableau Public publication awaits the owner's desktop sign-in. Pushing this repository does not deploy the live Sites website; that deployment is managed separately. Hosting identity, access settings, and credentials are intentionally absent from this portable source.
