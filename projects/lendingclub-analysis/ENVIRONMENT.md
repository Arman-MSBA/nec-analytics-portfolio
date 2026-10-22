# Environment

This R Markdown final analysis uses tidyverse, ggplot2, maps and kableExtra. No original package-version lockfile was present. Six headerless annual loan CSVs are read with explicit column names, plus States.csv and states_regions.csv.

The public copy is a path-portable adaptation of the course source. It was syntax-checked during packaging; the full models were not rerun. No lockfile is invented. Install packages with `source('install_packages.R')`, then render from this directory with `rmarkdown::render('analysis.Rmd')`. The data must be supplied separately under `data/`. A compatible R installation and Pandoc are required. Package upgrades can change results.
