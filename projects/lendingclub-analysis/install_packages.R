# Run explicitly in your own R library.
packages <- c('tidyverse', 'ggplot2', 'dplyr', 'readr', 'scales', 'maps', 'mapdata', 'RColorBrewer', 'knitr', 'kableExtra', 'gridExtra', 'rmarkdown')
install.packages(setdiff(packages, rownames(installed.packages())))
