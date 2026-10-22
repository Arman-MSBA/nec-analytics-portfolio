# Environment

The saved execution record reports R 4.5.3, glmnet 5.1 and Matrix 1.7-6. Seed: 20261019. The data MD5 must match 7194dac8f4ceb0aea3de143001ac2ea6. The analysis fits 55 regularization paths (1,111 alpha/lambda settings across five folds).

The public copy is a path-portable adaptation of the course source. It was syntax-checked during packaging; the full models were not rerun. No lockfile is invented. Install packages with `source('install_packages.R')`, then render from this directory with `rmarkdown::render('analysis.Rmd')`. The data must be supplied separately under `data/`. A compatible R installation and Pandoc are required. Package upgrades can change results.
