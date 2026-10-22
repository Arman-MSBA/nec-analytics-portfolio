# Run explicitly in your own R library.
packages <- c('glmnet', 'Matrix', 'jsonlite', 'knitr', 'rmarkdown')
install.packages(setdiff(packages, rownames(installed.packages())))
