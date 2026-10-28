# Arman Khachatryan | Analytics and applied AI portfolio

[Explore the live portfolio](https://arman-khachatryan-ai-analytics.homehub-ai.chatgpt.site) · [LinkedIn](https://www.linkedin.com/in/arman-khachatryan-2022/) · [GitHub profile](https://github.com/Arman-MSBA)

Selected independent coursework from New England College, organized around business questions, transparent evaluation, and inspectable outputs. Each project explains my contribution, methods, findings, and limitations.

## Projects

| Project | Evidence and methods | Explore |
| --- | --- | --- |
| Retail performance in Tableau | Two packaged workbooks with included extracts, eight dashboards, one story; KPIs, trends, clusters, forecast comparisons | [Workbooks and notes](projects/retail-tableau) · [Case study](https://arman-khachatryan-ai-analytics.homehub-ai.chatgpt.site/projects/retail-tableau/) |
| A fair classification comparison | Logistic regression, calibrated SVM, random forest, XGBoost; same fitting budget and evaluation customers | [Source and results](projects/santander-classification) · [Interactive evaluation](https://arman-khachatryan-ai-analytics.homehub-ai.chatgpt.site/projects/santander-classification/) |
| Six years of lending patterns | R data preparation and geographic analysis of LendingClub files from 2012 to 2017 | [Source and charts](projects/lendingclub-analysis) · [Case study](https://arman-khachatryan-ai-analytics.homehub-ai.chatgpt.site/projects/lendingclub-analysis/) |
| Nutrition prediction with regularization | LASSO, Ridge, Elastic Net; shared cross-validation folds and held-out evaluation | [Source and results](projects/nutrition-regularization) · [Case study](https://arman-khachatryan-ai-analytics.homehub-ai.chatgpt.site/projects/nutrition-regularization/) |

The classification project uses anonymized academic benchmark/course data. It is separate from my employment at Santander and was not deployed in bank systems.

## How to inspect or reproduce the work

Start with the README in the relevant project folder. Each explains the required input files, environment, execution order, saved aggregate results, and data limitations. The Tableau `.twbx` packages include Hyper extracts for viewing the saved dashboards. The analysis scripts and separate data-free Tableau `.twb` definitions use project-relative paths; obtain authorized source data separately before attempting a full run or a source refresh.

Raw CSV datasets, borrower-level records, row-level predictions, fitted models, assignment briefs, grades, and private machine paths are excluded. The Tableau packages include only their synthetic retail coursework extracts and written notes; they contain no employer data. The portfolio includes larger native Tableau screenshots with links to the original captures. The older embedded workbook thumbnails retain their native 192px size.

### Verification scope

- Six R source files passed syntax parsing in R 4.5.3.
- Saved aggregate model metrics were inspected and used to create comparison charts and the interactive evaluation view.
- Both sanitized Tableau XML files parse; dashboard/story inventory was checked against the final submitted workbooks. Both shareable `.twbx` packages opened in Tableau Public 2026.2 with their embedded data and populated charts.
- Full model training and Tableau source-data refresh were not repeated for this publication. Opening saved Tableau extracts does not establish forecast accuracy or business impact.

LASSO remains the nutrition model selected by cross-validation even though Ridge has slightly lower held-out RMSE. The classification case reports recall beside accuracy rather than presenting the headline accuracy as a deployment decision.

## Website

- [`site/`](site) is a portable snapshot of the published static website.
- [`website/`](website) contains its standalone generator, content, styles, scripts, and assets. Node.js 22 or newer is sufficient; no dependency installation is required for the build.

The homepage presents BI, machine learning, and applied AI together, and case studies lead with original project evidence. Both directories include JSON-LD structured data for the professional profile, website, and five project case studies, generated from the same public content as the pages. Both retail workbooks are published on Tableau Public; their case study includes verified online links, expandable interactive previews, self-contained workbook downloads, and three native dashboard captures.

```sh
cd website
node scripts/generate-portfolio.mjs
node scripts/serve-static.mjs
```

Open the printed local URL. The build writes to `website/dist/`. The live site is hosted separately on Sites, so pushing to this repository does not automatically change that deployment.

## More work

- [Real estate listing automation](https://arman-khachatryan-ai-analytics.homehub-ai.chatgpt.site/projects/real-estate-ai/): independent ChatGPT API work, described through public project evidence.
- [Passenger satisfaction analysis](https://github.com/Arman-MSBA/Passenger-Satisfication-Survey---Data-Exploratory-and-cleaning): collaborative Python coursework.
- [SQL projects](https://github.com/Arman-MSBA/SQL-Projects): airline database and guided international debt analysis.

Underlying datasets and third-party materials remain subject to their original terms. This repository does not grant a blanket license to course data.
