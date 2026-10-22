# Run explicitly in your own R library.
packages <- c('data.table', 'ranger', 'xgboost', 'e1071', 'jsonlite', 'knitr', 'rmarkdown')
install.packages(setdiff(packages, rownames(installed.packages())))
