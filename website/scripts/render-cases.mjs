/** Render coursework case studies around the evidence and its interpretation. */
export function renderCase(project, index, context) {
  const {
    projects, esc, ext, asset, tags, link, repo,
    renderTableauView, explorer, validateWorkbook,
  } = context;
  const isTableau = project.slug === 'retail-tableau';
  const isClassification = project.slug === 'santander-classification';
  const isNutrition = project.slug === 'nutrition-regularization';
  const next = projects[(index + 1) % projects.length];
  const sourceUrl = `${repo}/tree/main/${project.repoPath}`;
  const notesUrl = `${repo}/blob/main/${project.repoPath}/README.md`;
  const workbooks = project.workbooks ?? [];

  for (const workbook of workbooks) {
    if (!/^\/downloads\/tableau\/[a-z0-9-]+\.twbx$/.test(workbook.downloadUrl)
      || workbook.downloadUrl.split('/').at(-1) !== workbook.fileName) {
      throw new Error(`Invalid packaged workbook download: ${workbook.downloadUrl}`);
    }
    validateWorkbook?.(workbook);
    if (workbook.tableauPublicUrl || workbook.embedUrl) {
      const publicUrl = new URL(workbook.tableauPublicUrl);
      const embedUrl = new URL(workbook.embedUrl);
      if ([publicUrl, embedUrl].some(url => url.protocol !== 'https:' || url.hostname !== 'public.tableau.com' || url.username || url.password)
        || !publicUrl.pathname.startsWith('/app/profile/arman.khachatryan3803/viz/')
        || !embedUrl.pathname.startsWith('/views/')
        || publicUrl.pathname.split('/viz/')[1] !== embedUrl.pathname.slice('/views/'.length)
        || embedUrl.searchParams.get(':embed') !== 'yes'
        || ![workbook.embedWidth, workbook.embedHeight].every(value => Number.isInteger(value) && value >= 600 && value <= 2000)) {
        throw new Error(`Invalid published Tableau view: ${workbook.title}`);
      }
    }
  }

  const downloadLink = (workbook, label, className = 'button secondary') =>
    `<a class="${className}" href="${esc(workbook.downloadUrl)}" download="${esc(workbook.fileName)}">${esc(label)}<span class="sr-only">: ${esc(workbook.title)}</span></a>`;

  const imageFigure = (image, className = 'case-figure', eager = false) => `
    <figure class="${className}">
      <a class="figure-original" href="${esc(asset(image.file))}" target="_blank" rel="noopener noreferrer" aria-label="Open full-size figure: ${esc(image.alt)}">
        <img src="${esc(asset(image.file))}" alt="${esc(image.alt)}" loading="${eager ? 'eager' : 'lazy'}">
      </a>
      <figcaption>${esc(image.caption)} · <a href="${esc(asset(image.file))}" target="_blank" rel="noopener noreferrer">View original<span class="sr-only"> figure (opens in a new tab)</span></a></figcaption>
    </figure>`;

  const nativeFigure = (id, title, description) => `
    <figure class="original-view">
      <h3>${esc(title)}</h3>
      ${renderTableauView(id)}
      <figcaption>${esc(description)} · <a href="${esc(asset(`tableau-${id}-native.jpg`))}" target="_blank" rel="noopener noreferrer">View original screenshot<span class="sr-only"> (opens in a new tab)</span></a></figcaption>
    </figure>`;

  const leadFigure = isTableau ? `
    <figure class="lead-figure">
      ${renderTableauView('overview', { loading: 'eager' })}
      <figcaption>Native screenshot from a validated workbook · synthetic course data · <a href="${esc(asset('tableau-overview-native.jpg'))}" target="_blank" rel="noopener noreferrer">View original screenshot<span class="sr-only"> (opens in a new tab)</span></a></figcaption>
    </figure>` : imageFigure(project.images[0], 'lead-figure', true);

  const actions = isTableau
    ? workbooks.map((workbook, workbookIndex) =>
      (workbook.tableauPublicUrl ? ext(workbook.tableauPublicUrl, `Module ${workbookIndex + 7} · Open online`, 'button primary') : '')
      + downloadLink(workbook, `Module ${workbookIndex + 7} · TWBX`, 'text-link')).join('')
      + ext(sourceUrl, 'View source on GitHub', 'text-link')
    : ext(sourceUrl, 'View source on GitHub', 'button primary')
      + ext(notesUrl, 'Reproduction notes', 'button secondary');

  const contribution = isTableau
    ? 'I built the views, calculations and dashboard layouts, then paired them with written interpretation of the course retail data.'
    : project.contribution;
  const result = isTableau
    ? 'Central leads sales at $44.57 million. Regional sales differ by about 1.4%, giving the category and time views useful context for a closer look.'
    : project.result;
  const limits = isTableau
    ? 'The supplied retail data are synthetic course exercises. Trend fits and clusters are exploratory. No future-period forecast accuracy or realized sales improvement is claimed. The screenshots document the saved views; the published workbooks can be explored on Tableau Public. The packaged downloads include embedded extracts; refreshing from the original course CSV files requires those source files.'
    : project.limits;

  const onlineWorkbooks = isTableau && workbooks.some(workbook => workbook.tableauPublicUrl) ? `
    <section class="online-workbooks" id="interactive-workbooks" aria-labelledby="interactive-heading">
      <h2 id="interactive-heading">Explore the dashboards online.</h2>
      <p>Open a workbook on Tableau Public or expand a view below. No account is needed. Use the filters and chart marks to explore the analysis. Full workbooks are also available as downloads below.</p>
      ${workbooks.filter(workbook => workbook.tableauPublicUrl).map(workbook => `
        <article class="online-workbook">
          <h3>${esc(workbook.title)}</h3>
          <p>${esc(workbook.description)}</p>
          ${ext(workbook.tableauPublicUrl, 'Open on Tableau Public', 'button secondary')}
          <details class="interactive-preview">
            <summary>Load interactive view<span class="sr-only">: ${esc(workbook.title)}</span></summary>
            <p class="embed-note">On a small screen, scroll across the view or open it on Tableau Public for more space.</p>
            <div class="tableau-embed" role="region" aria-label="${esc(workbook.title)} interactive dashboard, scroll horizontally if needed" tabindex="0" style="--tableau-width:${workbook.embedWidth}px;--tableau-height:${workbook.embedHeight}px">
              <iframe data-src="${esc(workbook.embedUrl)}" title="${esc(workbook.title)} interactive Tableau workbook" allowfullscreen></iframe>
            </div>
            <noscript><p>Open this workbook on Tableau Public to use its interactive view.</p></noscript>
          </details>
        </article>`).join('')}
    </section>` : '';

  const tableauGallery = isTableau ? `
    <section class="workbook-gallery" aria-labelledby="workbook-gallery-heading">
      <div class="section-heading compact-heading">
        <div><p class="section-label">Inside the workbooks</p><h2 id="workbook-gallery-heading">A closer look at the analysis.</h2></div>
        <p>Original dashboard captures show the work at a readable scale. Explore the interactive workbooks above or download the packaged files.</p>
      </div>
      ${nativeFigure('analytics', 'Retail analytics overview', 'Module 8 · original Tableau desktop screenshot · synthetic course data')}
      ${nativeFigure('forecast', 'Comparing forecast assumptions', 'Module 8 · original Tableau desktop screenshot · synthetic course data')}
    </section>
    <details class="saved-previews">
      <summary>Other saved workbook previews</summary>
      <p>Original 192 × 192 pixel thumbnails saved in the workbooks.</p>
      <div class="tableau-previews">${project.images.map(image => `
        <figure><img src="${esc(asset(image.file))}" width="192" height="192" loading="lazy" alt="${esc(image.alt)}"><figcaption>${esc(image.caption)}</figcaption></figure>`).join('')}
      </div>
    </details>` : '';

  const workbookDownloads = isTableau ? `
    <section class="workbook-downloads" aria-labelledby="workbook-heading">
      <h2 id="workbook-heading">Explore the original workbooks.</h2>
      <p>Embedded course data extracts were verified in Tableau Public 2026.2. Download a TWBX file to explore it in the Tableau desktop app.</p>
      <div class="workbook-grid">${workbooks.map(workbook => `
        <article class="workbook-card">
          <p class="workbook-format">Packaged workbook · TWBX</p>
          <h3>${esc(workbook.title)}</h3>
          <p>${esc(workbook.description)}</p>
          ${downloadLink(workbook, 'Download workbook')}
          <p class="workbook-filename">${esc(workbook.fileName)}</p>
        </article>`).join('')}
      </div>
    </section>` : '';

  const nutritionTable = isNutrition ? `
    <div class="table-scroll">
      <table>
        <caption>Selection used cross-validation. Test values describe held-out performance, in kcal/100g.</caption>
        <thead><tr><th scope="col">Technique</th><th scope="col">CV RMSE</th><th scope="col">Test RMSE</th><th scope="col">Selection</th></tr></thead>
        <tbody>
          <tr><th scope="row">LASSO</th><td>11.9552</td><td>14.4659</td><td>Selected by CV</td></tr>
          <tr><th scope="row">Ridge</th><td>12.0025</td><td>14.3998</td><td>Comparison</td></tr>
          <tr><th scope="row">Elastic Net</th><td>11.9557</td><td>14.4708</td><td>Comparison</td></tr>
        </tbody>
      </table>
    </div>` : '';

  return `<main id="main">
    <div class="shell case-shell wide-case">
      <a class="back-link" href="/#work">All projects</a>
      <section class="case-heading">
        <p class="project-context">${esc(project.categoryName)}<span>${esc(project.label)}</span></p>
        <h1>${esc(project.title)}</h1>
        <p class="case-lede">${esc(isTableau ? 'From headline KPIs to the regional and category patterns behind them.' : project.summary)}</p>
        ${tags(project.tools)}
        <div class="case-lead-actions">${actions}</div>
      </section>

      <section class="case-evidence" aria-label="Project evidence and contribution">
        ${leadFigure}
        <aside class="case-summary">
          <section class="summary-block"><h2>The question</h2><p>${esc(project.question)}</p></section>
          <section class="summary-block"><h2>My contribution</h2><p>${esc(contribution)}</p></section>
          <section class="summary-block"><h2>What it shows</h2><p>${esc(result)}</p></section>
        </aside>
      </section>

      ${onlineWorkbooks}

      <div class="case-body">
        ${isClassification ? '<p class="context-note">Independent NEC coursework on an anonymized competition dataset. This project is separate from my employment at Santander and was not deployed in bank systems.</p>' : ''}
        <div class="case-columns">
          <section><h2>How I approached it</h2><ul>${project.methods.map(method => `<li>${esc(method)}</li>`).join('')}</ul></section>
          <aside class="case-facts"><h2>At a glance</h2><dl>${project.facts.map(fact => `<dt>${esc(fact.label)}</dt><dd>${esc(fact.value)}</dd>`).join('')}</dl></aside>
        </div>
        ${isClassification ? explorer() : ''}
        ${tableauGallery}
        ${!isTableau ? project.images.slice(1).map(image => imageFigure(image)).join('') : ''}
        ${nutritionTable}
        <section class="case-takeaway">
          <h2>What I learned</h2><p>${esc(project.insight)}</p>
          <h3>Limits</h3><p>${esc(limits)}</p>
          <h3>A useful next step</h3><p>${esc(project.nextStep)}</p>
        </section>
        ${workbookDownloads}
      </div>
      <nav class="next-case" aria-label="Next project"><span>Explore another project</span><a href="${esc(link(next))}">${esc(next.title)}</a></nav>
    </div>
  </main>`;
}

/** Present the documented applied AI workflow without inventing a product UI. */
export function renderAppliedCase(context) {
  const { applied, profile, esc, ext, tags, aiWorkflow } = context;
  const globeUrl = 'https://www.bostonglobe.com/2023/07/10/business/locals-using-ai/';

  return `<main id="main">
    <div class="shell case-shell wide-case">
      <a class="back-link" href="/#work">All projects</a>
      <section class="case-heading">
        <p class="project-context">Applied AI<span>Independent project</span></p>
        <h1>${esc(applied.title)}</h1>
        <p class="case-lede">${esc(applied.headline)}</p>
        ${tags(['ChatGPT API', 'Workflow automation', 'Real estate'])}
        <div class="case-lead-actions">
          ${ext(profile.links.linkedin, 'Project background on LinkedIn', 'button primary')}
          ${ext(globeUrl, 'The Boston Globe feature · 2023', 'button secondary')}
        </div>
      </section>

      <section class="case-evidence" aria-label="Workflow and contribution">
        <figure class="lead-figure workflow-story">
          ${aiWorkflow()}
          <figcaption>Workflow overview based on the documented project.</figcaption>
        </figure>
        <aside class="case-summary">
          <section class="summary-block"><h2>The question</h2><p>${esc(applied.question)}</p></section>
          <section class="summary-block"><h2>My contribution</h2><p>${esc(applied.contribution)}</p></section>
          <section class="summary-block"><h2>Reported result</h2><p>The project connected AI-generated listing copy to a practical posting workflow. In my public summary, I reported less manual preparation and more daily inquiries. These benefits are self-reported.</p></section>
        </aside>
      </section>

      <div class="case-body">
        <section class="workflow-context">
          <h2>A specific task, connected to a workflow.</h2>
          <p>${esc(applied.summary)}</p>
          <ol class="workflow-steps">
            <li>Use property information as the input.</li>
            <li>Create a listing description through the ChatGPT API.</li>
            <li>Connect the description to the posting workflow.</li>
          </ol>
        </section>
        <section class="case-takeaway">
          <h2>What I would measure next</h2><p>${esc(applied.learning)}</p>
          <h3>Evidence and scope</h3><p>${esc(applied.limits)}</p>
        </section>
        <section class="case-contact">
          <h2>Have a workflow worth simplifying?</h2>
          <p>Start with the repetitive task, the information it needs and what a useful result would look like.</p>
          <a class="button primary" href="mailto:arman_khachatryan1@outlook.com?subject=AI%20workflow%20conversation">Discuss a project</a>
        </section>
      </div>
      <nav class="next-case" aria-label="Next project"><span>Explore another project</span><a href="/projects/santander-classification/">A fair classification comparison</a></nav>
    </div>
  </main>`;
}
