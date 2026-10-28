/** Page-specific entities, derived from the same public content as the portfolio. */
export function createStructuredData({ origin, profile, projects, applied, path, title, description }) {
  if (path === '/404.html') return null;
  const base = origin.replace(/\/$/, '');
  const absolute = value => new URL(value, `${base}/`).href;
  const personId = `${base}/#person`;
  const websiteId = `${base}/#website`;
  const pageUrl = absolute(path);
  const pageId = `${pageUrl}#webpage`;
  const person = {
    '@type': 'Person',
    '@id': personId,
    name: profile.name,
    honorificSuffix: profile.suffix,
    url: `${base}/`,
    jobTitle: profile.experience[0].role,
    description: "Analytics professional with 6+ years of experience across financial services, consumer goods, healthcare, and higher education.",
    sameAs: [profile.links.github, profile.links.linkedin],
    knowsAbout: ['Business intelligence', 'Data analytics', 'Applied AI', 'Data workflow automation'],
  };
  const website = {
    '@type': 'WebSite',
    '@id': websiteId,
    name: `${profile.name} | Analytics, Business Intelligence & Applied AI`,
    url: `${base}/`,
    inLanguage: 'en',
    publisher: { '@id': personId },
  };
  const projectRecords = [
    ...projects.map(project => ({
      slug: project.slug,
      title: project.title,
      summary: project.summary,
      tools: project.tools,
      label: project.label,
      workbooks: (project.workbooks ?? []).filter(workbook => workbook.tableauPublicUrl),
      images: project.slug === 'retail-tableau'
        ? ['tableau-overview-native.jpg', 'tableau-analytics-native.jpg', 'tableau-forecast-native.jpg']
        : project.images.map(image => image.file),
    })),
    {
      slug: 'real-estate-ai',
      title: applied.title,
      summary: applied.summary,
      tools: ['ChatGPT API', 'Workflow automation', 'Real estate'],
      label: 'Independent project',
      images: [],
    },
  ];
  const projectNode = project => {
    const url = absolute(`/projects/${project.slug}/`);
    return {
      '@type': 'CreativeWork',
      '@id': `${url}#project`,
      name: project.title,
      description: project.summary,
      url,
      author: { '@id': personId },
      mainEntityOfPage: path === '/' ? url : { '@id': pageId },
      inLanguage: 'en',
      genre: project.label,
      keywords: project.tools,
      ...(project.workbooks?.length ? {
        hasPart: project.workbooks.map(workbook => ({ '@id': `${workbook.tableauPublicUrl}#workbook` })),
      } : {}),
      ...(project.images.length ? {
        image: project.images.map(file => absolute(`/projects/coursework/${file}`)),
      } : {}),
    };
  };
  const publishedReports = project => (project.workbooks ?? []).map(workbook => ({
    '@type': 'CreativeWork',
    '@id': `${workbook.tableauPublicUrl}#workbook`,
    name: workbook.title,
    description: workbook.description,
    url: workbook.tableauPublicUrl,
    author: { '@id': personId },
    isPartOf: { '@id': `${absolute(`/projects/${project.slug}/`)}#project` },
    mainEntityOfPage: workbook.tableauPublicUrl,
    inLanguage: 'en',
    genre: project.label,
    isAccessibleForFree: true,
    encoding: {
      '@type': 'MediaObject',
      name: workbook.fileName,
      contentUrl: absolute(workbook.downloadUrl),
      encodingFormat: 'https://help.tableau.com/current/pro/desktop/en-us/save_savework_packagedworkbooks.htm',
    },
  }));
  const webpage = {
    '@type': path === '/' ? 'ProfilePage' : 'WebPage',
    '@id': pageId,
    url: pageUrl,
    name: title,
    description,
    inLanguage: 'en',
    isPartOf: { '@id': websiteId },
  };
  if (path === '/') {
    // Match the visible order: the three featured cards, then the two notebook cards.
    const order = ['retail-tableau', 'santander-classification', 'real-estate-ai', 'lendingclub-analysis', 'nutrition-regularization'];
    const ordered = order.map(slug => projectRecords.find(project => project.slug === slug));
    if (ordered.some(project => !project)) throw new Error('Missing portfolio project for structured data');
    webpage.mainEntity = { '@id': personId };
    // Generic ItemList markup triggers Google's carousel feature, whose supported
    // content types do not include these portfolio case studies.
    webpage.mentions = ordered.map(project => ({ '@id': `${absolute(`/projects/${project.slug}/`)}#project` }));
    return { '@context': 'https://schema.org', '@graph': [website, person, webpage, ...ordered.flatMap(project => [projectNode(project), ...publishedReports(project)])] };
  }
  const project = projectRecords.find(record => path === `/projects/${record.slug}/`);
  if (!project) throw new Error(`Missing structured data for page: ${path}`);
  webpage.mainEntity = { '@id': `${pageUrl}#project` };
  return { '@context': 'https://schema.org', '@graph': [website, person, webpage, projectNode(project), ...publishedReports(project)] };
}

/** Keep JSON data inside the script element even when future content contains HTML. */
export function serializeStructuredData(value) {
  return JSON.stringify(value).replace(/[<>&\u2028\u2029]/g, character => ({
    '<': '\\u003c', '>': '\\u003e', '&': '\\u0026', '\u2028': '\\u2028', '\u2029': '\\u2029',
  }[character]));
}
