# Retail performance and visual analytics in Tableau

Two independent Visual Analytics coursework workbooks by Arman Khachatryan at New England College.
The first translates daily sales, profit and order data into interactive views and
a KPI scorecard; the second compares trend models, distributions, clusters and forecasts.

## Workbook walkthrough

**Retail performance (Module 7)** contains Analytical Overview, Interactive Insights
and KPI Scorecard dashboards, plus a four-point Retail Performance Story. Worksheets cover regional sales, category profit,
monthly trends, sales against a selected-region target, YTD sales and profit,
profit ratio and order volume. Filters, a parameter and dashboard actions support exploration.

**Retail analytics (Module 8)** contains Trend Model Comparison, Forecast Comparison
Retail Analytics Overview, Distribution Findings and Cluster Findings dashboards. Worksheets compare linear, exponential
and polynomial fits, profit distributions, four clusters, and automatic versus
custom seasonal forecasts. The saved workbook includes written interpretation.

## Available artifacts

Explore the published overview dashboards in your browser, without signing in:

- [Retail performance — Module 7 on Tableau Public](https://public.tableau.com/app/profile/arman.khachatryan3803/viz/retail-performance/AnalyticalOverview)
- [Retail analytics — Module 8 on Tableau Public](https://public.tableau.com/app/profile/arman.khachatryan3803/viz/retail-analytics_17931048231660/ERetailAnalyticsOverview)

Download a packaged workbook to open the dashboards with their saved data:

- [Retail performance — Module 7](workbooks/retail-performance.twbx)
- [Retail analytics — Module 8](workbooks/retail-analytics.twbx)

The `.twbx` packages include Hyper extracts of the synthetic daily retail course
data and written notes. They are self-contained: opening the saved dashboards
does not require the original CSV files or access to a private file path. Open
them in Tableau Desktop or Tableau Desktop Public Edition. Refreshing from the
original CSVs is a separate operation and requires those source files.

The `.twb` XML definitions remain available in `workbooks/` for source inspection.
Those data-free files require reconnection before they can display the dashboards;
use the `.twbx` packages for viewing. Private local paths and connection credentials
have been removed from the public copies.

[Read the portfolio case study](https://arman-khachatryan-ai-analytics.homehub-ai.chatgpt.site/projects/retail-tableau/)
for the business questions, findings, limitations, and expandable interactive previews.
A GitHub file preview does not run Tableau; use the published Tableau Public links
above or download a packaged workbook to explore the saved views in the desktop app.

The `figures/` images are genuine embedded workbook thumbnails at their saved
resolution, not new dashboard captures. They are useful as previews, not detailed screenshots.

## Interpretation and limits

The supplied daily retail data are course exercises. They are not verified business
operations or evidence of revenue improvement. A fitted trend or a four-cluster
solution is exploratory, not causal or externally validated. Forecast scenarios
need out-of-time evaluation before business use; no unseen-period forecast error
is claimed. These workbooks contain coursework data, not data from an employer.
Source-workbook fingerprint metadata and local connection credentials have been
removed from this public source package.
