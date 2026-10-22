# Environment

The source was written against the XGBoost 3.2 API (evaluation history is stored as an attribute). No complete original dependency lockfile was available. The saved seed is 691006; the four models fit 6,000 common training rows. Full execution is computationally expensive.

The public copy is a path-portable adaptation of the course source. It was syntax-checked during packaging; the full models were not rerun. No lockfile is invented. Install packages with `source('install_packages.R')`, then render from this directory with `rmarkdown::render('analysis.Rmd')`. The data must be supplied separately under `data/`. A compatible R installation and Pandoc are required. Package upgrades can change results.
