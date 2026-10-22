# Extracted from analysis.Rmd; run from this project folder.

# Set global chunk options: echo=TRUE ensures R code appears in knitted output
knitr::opts_chunk$set(echo = TRUE, warning = FALSE, message = FALSE,
                      fig.width = 10, fig.height = 6, fig.align = "center")

# Load all required R libraries for data manipulation, visualization, and mapping
library(tidyverse)    # Core data science toolkit (dplyr, ggplot2, readr, tidyr, etc.)
library(ggplot2)      # Grammar of graphics for data visualization
library(dplyr)        # Data manipulation verbs (filter, mutate, group_by, summarize)
library(readr)        # Fast CSV reading
library(scales)       # Formatting for axes (dollar signs, commas, percentages)
library(maps)         # US state map data for choropleth
library(mapdata)      # Additional map data
library(RColorBrewer) # Color palettes for visualizations
library(knitr)        # Table formatting with kable()
library(kableExtra)   # Enhanced table styling

# Define the data directory path
data_dir <- "data"   # Loan and lookup files are supplied separately.

# Define column names (derived from LCsample.csv header row)
col_names <- c("row_id", "loan_amnt", "term", "int_rate", "grade", "sub_grade",
               "emp_title", "emp_length", "home_ownership", "annual_inc",
               "issue_d", "loan_status", "purpose", "title", "addr_state",
               "dti", "delinq_2yrs", "inq_last_6mths", "mths_since_last_delinq",
               "open_acc", "total_pymnt", "total_rec_int", "last_pymnt_d",
               "last_pymnt_amnt", "last_credit_pull_d", "application_type",
               "tot_cur_bal", "acc_open_past_24mths", "pub_rec_bankruptcies",
               "Orig_Index", "issue_Month", "issue_Year")

# Read each annual CSV file and assign column names (files have no header row)
lc_2012 <- read_csv(file.path(data_dir, "data2012.csv"), col_names = col_names,
                    col_types = cols(.default = col_character()))
lc_2013 <- read_csv(file.path(data_dir, "data2013.csv"), col_names = col_names,
                    col_types = cols(.default = col_character()))
lc_2014 <- read_csv(file.path(data_dir, "data2014.csv"), col_names = col_names,
                    col_types = cols(.default = col_character()))
lc_2015 <- read_csv(file.path(data_dir, "data2015.csv"), col_names = col_names,
                    col_types = cols(.default = col_character()))
lc_2016 <- read_csv(file.path(data_dir, "data2016.csv"), col_names = col_names,
                    col_types = cols(.default = col_character()))
lc_2017 <- read_csv(file.path(data_dir, "data2017.csv"), col_names = col_names,
                    col_types = cols(.default = col_character()))

# Stack (bind_rows) all six data frames into one combined data frame
# bind_rows() is the tidyverse equivalent of rbind() and handles mismatched columns gracefully
lc_stacked <- bind_rows(lc_2012, lc_2013, lc_2014, lc_2015, lc_2016, lc_2017)

# Report the total number of rows and columns
cat("Total rows after stacking:", nrow(lc_stacked), "\n")
cat("Total columns:", ncol(lc_stacked), "\n")

# Load the states demographic file
# This file contains population, median income, unemployment rate, etc. by state
states_df <- read_csv(file.path(data_dir, "States.csv"),
                      col_types = cols(.default = col_character()))

# Rename columns for clarity
colnames(states_df) <- c("State", "Num_Households", "Median_income",
                          "Unemployment_rate", "Pct_below_poverty",
                          "population", "Males", "Females")

# Convert numeric columns from character to numeric
states_df <- states_df %>%
  mutate(across(c(Median_income, population, Num_Households,
                  Unemployment_rate, Pct_below_poverty, Males, Females),
                ~ as.numeric(gsub(",", "", .))))

# Load the states regions file (maps state names to Region and Division)
regions_df <- read_csv(file.path(data_dir, "states_regions.csv"),
                       col_types = cols(.default = col_character())) %>%
  select(State, `State Code`, Region, Division) %>%
  rename(state_code = `State Code`)

# Merge states demographics with regions on "State" name
states_full <- left_join(regions_df, states_df, by = "State")
cat("States + Regions rows:", nrow(states_full), "\n")

# Clean the Lending Club stacked data
lc_clean <- lc_stacked %>%
  # Convert numeric fields
  mutate(
    loan_amnt     = as.numeric(loan_amnt),
    annual_inc    = as.numeric(annual_inc),
    issue_Year    = as.numeric(issue_Year),
    dti           = as.numeric(dti),
    # Parse interest rate: strip spaces and "%" character then convert
    int_rate_clean = as.numeric(trimws(gsub("%", "", int_rate))),
    # Strip whitespace from categorical columns
    grade         = trimws(grade),
    emp_length    = trimws(emp_length),
    loan_status   = trimws(loan_status),
    purpose       = trimws(purpose)
  ) %>%
  # Remove any header rows accidentally included (row_id == "row_id")
  filter(loan_amnt != "loan_amnt" | is.na(loan_amnt))

# Final merge: join LC data with states_full using addr_state = state_code
lc_merged <- left_join(lc_clean, states_full,
                       by = c("addr_state" = "state_code"))

cat("Final merged rows:", nrow(lc_merged), "\n")
cat("Match rate:", round(mean(!is.na(lc_merged$State)) * 100, 1), "%\n")

# Count number of loans by state and compute per-capita rate
by_state <- lc_merged %>%
  filter(!is.na(addr_state), addr_state != "Unnamed: 23") %>%
  group_by(addr_state, State, Region, Division) %>%
  summarize(
    num_loans  = n(),                                  # total loan count
    population = first(population),                    # state population
    .groups    = "drop"
  ) %>%
  mutate(loans_per_1k = num_loans / population * 1000) %>%  # per-capita rate
  arrange(desc(num_loans))

# Display top 10 states by loan count
by_state %>%
  head(10) %>%
  select(State, addr_state, num_loans, loans_per_1k) %>%
  mutate(loans_per_1k = round(loans_per_1k, 2)) %>%
  kable(caption = "Top 10 States by Number of Loans",
        col.names = c("State", "Code", "# Loans", "Loans per 1,000 pop")) %>%
  kable_styling(bootstrap_options = c("striped","hover","condensed"))

# Aggregate by region
by_region <- lc_merged %>%
  filter(!is.na(Region)) %>%
  group_by(Region) %>%
  summarize(num_loans = n(), .groups = "drop") %>%
  arrange(desc(num_loans))

by_region %>%
  kable(caption = "Number of Loans by Region",
        col.names = c("Region", "Number of Loans")) %>%
  kable_styling(bootstrap_options = c("striped","hover"))

# Aggregate by division
by_division <- lc_merged %>%
  filter(!is.na(Division)) %>%
  group_by(Division) %>%
  summarize(num_loans = n(), .groups = "drop") %>%
  arrange(desc(num_loans))

by_division %>%
  kable(caption = "Number of Loans by Division",
        col.names = c("Division", "Number of Loans")) %>%
  kable_styling(bootstrap_options = c("striped","hover"))

# Compute average loan amount by state, sort descending
avg_by_state <- lc_merged %>%
  filter(!is.na(addr_state), addr_state != "Unnamed: 23") %>%
  group_by(addr_state, State) %>%
  summarize(avg_loan = mean(loan_amnt, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(avg_loan))

# Top and bottom 5 states
bind_rows(
  avg_by_state %>% head(5) %>% mutate(rank = "Highest"),
  avg_by_state %>% tail(5) %>% mutate(rank = "Lowest")
) %>%
  mutate(avg_loan = dollar(avg_loan)) %>%
  select(rank, State, addr_state, avg_loan) %>%
  kable(caption = "States with Highest and Lowest Average Loan Amounts",
        col.names = c("Rank Group", "State", "Code", "Avg Loan")) %>%
  kable_styling(bootstrap_options = c("striped","hover"))

# Average by division
avg_by_div <- lc_merged %>%
  filter(!is.na(Division)) %>%
  group_by(Division) %>%
  summarize(avg_loan = mean(loan_amnt, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(avg_loan)) %>%
  mutate(avg_loan_fmt = dollar(avg_loan))

avg_by_div %>%
  select(Division, avg_loan_fmt) %>%
  kable(caption = "Average Loan Amount by Division",
        col.names = c("Division", "Avg Loan Amount")) %>%
  kable_styling(bootstrap_options = c("striped","hover"))

# Filter to valid loan grades (A through G) and compute summaries by grade
grade_summary <- lc_merged %>%
  filter(grade %in% c("A","B","C","D","E","F","G")) %>%
  group_by(grade) %>%
  summarize(
    avg_int_rate = mean(int_rate_clean, na.rm = TRUE),  # average interest rate
    avg_loan_amnt = mean(loan_amnt, na.rm = TRUE),       # average loan amount
    count = n(),                                          # number of loans
    .groups = "drop"
  ) %>%
  arrange(grade)

grade_summary %>%
  mutate(
    avg_int_rate  = paste0(round(avg_int_rate, 2), "%"),
    avg_loan_amnt = dollar(avg_loan_amnt),
    count         = comma(count)
  ) %>%
  kable(caption = "Average Interest Rate and Loan Amount by Loan Grade",
        col.names = c("Grade", "Avg Interest Rate", "Avg Loan Amount", "# Loans")) %>%
  kable_styling(bootstrap_options = c("striped","hover"))

# Compute annual loan count, average loan, and average rate for all states combined
annual_overall <- lc_merged %>%
  filter(!is.na(issue_Year)) %>%
  group_by(issue_Year) %>%
  summarize(
    num_loans = n(),
    avg_loan  = mean(loan_amnt, na.rm = TRUE),
    avg_rate  = mean(int_rate_clean, na.rm = TRUE),
    .groups   = "drop"
  ) %>%
  arrange(issue_Year)

annual_overall %>%
  mutate(
    issue_Year = as.integer(issue_Year),
    num_loans  = comma(num_loans),
    avg_loan   = dollar(avg_loan),
    avg_rate   = paste0(round(avg_rate, 2), "%")
  ) %>%
  kable(caption = "Annual Lending Trends (2012-2017) — All States",
        col.names = c("Year", "# Loans", "Avg Loan Amount", "Avg Interest Rate")) %>%
  kable_styling(bootstrap_options = c("striped","hover"))

# Break down annual trends for the top 5 states by loan volume
top5_states <- by_state %>%
  top_n(5, num_loans) %>%
  pull(addr_state)

annual_top5 <- lc_merged %>%
  filter(addr_state %in% top5_states, !is.na(issue_Year)) %>%
  group_by(addr_state, State, issue_Year) %>%
  summarize(
    num_loans = n(),
    avg_loan  = mean(loan_amnt, na.rm = TRUE),
    avg_rate  = mean(int_rate_clean, na.rm = TRUE),
    .groups   = "drop"
  ) %>%
  arrange(addr_state, issue_Year)

annual_top5 %>%
  mutate(
    issue_Year = as.integer(issue_Year),
    num_loans  = comma(num_loans),
    avg_loan   = dollar(avg_loan),
    avg_rate   = paste0(round(avg_rate, 2), "%")
  ) %>%
  select(State, issue_Year, num_loans, avg_loan, avg_rate) %>%
  kable(caption = "Annual Trends for Top 5 States",
        col.names = c("State","Year","# Loans","Avg Loan","Avg Rate")) %>%
  kable_styling(bootstrap_options = c("striped","hover","condensed")) %>%
  collapse_rows(columns = 1, valign = "top")

# Aggregate to state level for correlation analysis
state_level <- lc_merged %>%
  filter(!is.na(addr_state), addr_state != "Unnamed: 23") %>%
  group_by(addr_state) %>%
  summarize(
    avg_loan       = mean(loan_amnt, na.rm = TRUE),
    population     = first(population),
    median_income  = first(Median_income),
    .groups        = "drop"
  ) %>%
  filter(!is.na(population), !is.na(median_income))

# Pearson correlation: population vs average loan amount
corr_pop_loan <- cor(state_level$population, state_level$avg_loan, use = "complete.obs")
corr_inc_loan <- cor(state_level$median_income, state_level$avg_loan, use = "complete.obs")

cat("Pearson correlation — Population vs Avg Loan Amount: ", round(corr_pop_loan, 3), "\n")
cat("Pearson correlation — Median Income vs Avg Loan Amount:", round(corr_inc_loan, 3), "\n")

# Examine relationship between loan grade and median income of the state
grade_income_tbl <- lc_merged %>%
  filter(grade %in% c("A","B","C","D","E","F","G"), !is.na(Median_income)) %>%
  group_by(grade) %>%
  summarize(
    avg_state_median_income = mean(Median_income, na.rm = TRUE),
    count = n(),
    .groups = "drop"
  ) %>%
  arrange(grade)

grade_income_tbl %>%
  mutate(
    avg_state_median_income = dollar(avg_state_median_income),
    count = comma(count)
  ) %>%
  kable(caption = "Average State Median Income by Loan Grade",
        col.names = c("Grade","Avg State Median Income","# Loans")) %>%
  kable_styling(bootstrap_options = c("striped","hover"))

# Compute default (charge-off) rate by year as an indicator of loan quality
default_by_year <- lc_merged %>%
  filter(grade %in% c("A","B","C","D","E","F","G"), !is.na(issue_Year)) %>%
  mutate(charged_off = ifelse(loan_status == "Charged Off", 1L, 0L)) %>%
  group_by(issue_Year) %>%
  summarize(
    total_loans   = n(),
    charged_off   = sum(charged_off, na.rm = TRUE),
    default_rate  = charged_off / total_loans * 100,
    .groups       = "drop"
  ) %>%
  filter(!is.na(issue_Year)) %>%
  arrange(issue_Year)

default_by_year %>%
  mutate(
    issue_Year   = as.integer(issue_Year),
    total_loans  = comma(total_loans),
    charged_off  = comma(charged_off),
    default_rate = paste0(round(default_rate, 2), "%")
  ) %>%
  kable(caption = "Charge-Off (Default) Rate by Year",
        col.names = c("Year","Total Loans","Charged Off","Default Rate")) %>%
  kable_styling(bootstrap_options = c("striped","hover"))

# Explore loan purpose distribution
purpose_summary <- lc_merged %>%
  filter(!is.na(purpose)) %>%
  group_by(purpose) %>%
  summarize(
    count    = n(),
    avg_loan = mean(loan_amnt, na.rm = TRUE),
    .groups  = "drop"
  ) %>%
  arrange(desc(count)) %>%
  head(8)

purpose_summary %>%
  mutate(count = comma(count), avg_loan = dollar(avg_loan)) %>%
  kable(caption = "Top Loan Purposes",
        col.names = c("Purpose","# Loans","Avg Loan Amount")) %>%
  kable_styling(bootstrap_options = c("striped","hover"))

# Create a dual bar chart: interest rate AND loan amount side by side, grouped by grade
grade_plot_data <- lc_merged %>%
  filter(grade %in% c("A","B","C","D","E","F","G")) %>%
  group_by(grade) %>%
  summarize(avg_rate = mean(int_rate_clean, na.rm = TRUE),
            avg_loan = mean(loan_amnt, na.rm = TRUE), .groups = "drop")

# Grade color palette (green = safe/low risk, red/purple = high risk)
grade_colors <- c("A"="#27ae60","B"="#2980b9","C"="#f39c12",
                  "D"="#e67e22","E"="#e74c3c","F"="#c0392b","G"="#8e44ad")

# Plot 1a: Average Interest Rate by Grade
p1a <- ggplot(grade_plot_data, aes(x = grade, y = avg_rate, fill = grade)) +
  geom_col(width = 0.7, color = "white") +
  geom_text(aes(label = paste0(round(avg_rate, 1), "%")),
            vjust = -0.5, fontface = "bold", size = 4) +
  scale_fill_manual(values = grade_colors) +
  scale_y_continuous(labels = function(x) paste0(x, "%"), limits = c(0, 33)) +
  labs(title = "Average Interest Rate by Loan Grade",
       x = "Loan Grade", y = "Average Interest Rate (%)") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none",
        plot.title = element_text(face = "bold"))

# Plot 1b: Average Loan Amount by Grade
p1b <- ggplot(grade_plot_data, aes(x = grade, y = avg_loan/1000, fill = grade)) +
  geom_col(width = 0.7, color = "white") +
  geom_text(aes(label = paste0("$", round(avg_loan/1000, 1), "K")),
            vjust = -0.5, fontface = "bold", size = 4) +
  scale_fill_manual(values = grade_colors) +
  scale_y_continuous(labels = dollar_format(suffix = "K"), limits = c(0, 24)) +
  labs(title = "Average Loan Amount by Loan Grade",
       x = "Loan Grade", y = "Average Loan Amount ($K)") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none",
        plot.title = element_text(face = "bold"))

library(gridExtra)  # For placing two plots side by side
grid.arrange(p1a, p1b, ncol = 2,
             top = "Lending Club: Interest Rate and Loan Amount by Grade")

# Create a choropleth map of average loan amount by state using ggplot2 + maps package
us_map <- map_data("state")  # Built-in US state map data

# Prepare loan data for mapping: need lowercase state name to join with map_data
avg_loan_map <- avg_by_state %>%
  mutate(region = tolower(State)) %>%   # map_data uses lowercase full state names
  filter(!is.na(region))

# Join map boundaries with loan data
map_joined <- us_map %>%
  left_join(avg_loan_map, by = "region")

ggplot(map_joined, aes(x = long, y = lat, group = group, fill = avg_loan)) +
  geom_polygon(color = "white", size = 0.3) +
  coord_fixed(1.3) +   # Fix aspect ratio for proper US map proportions
  scale_fill_gradientn(
    colors = c("#deebf7","#9ecae1","#4292c6","#084594"),  # Blue gradient
    name   = "Avg Loan ($)",
    labels = dollar_format(),
    na.value = "grey80"
  ) +
  labs(
    title    = "Average Lending Club Loan Amount by US State (2012-2017)",
    subtitle = "Darker blue = higher average loan amount",
    caption  = "Source: Lending Club loan data 2012-2017"
  ) +
  theme_void(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold", size = 15, hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5, color = "gray40"),
    legend.position = "right"
  )

# Sample the data for scatter plot (full dataset too large to plot efficiently)
set.seed(42)  # Set seed for reproducibility
lc_sample <- lc_merged %>%
  filter(!is.na(annual_inc), !is.na(loan_amnt),
         annual_inc < 200000, loan_amnt < 40000,
         grade %in% c("A","B","C","D","E","F","G")) %>%
  sample_n(8000)   # Random sample of 8,000 rows for plotting performance

grade_colors <- c("A"="#27ae60","B"="#2980b9","C"="#f39c12",
                  "D"="#e67e22","E"="#e74c3c","F"="#c0392b","G"="#8e44ad")

ggplot(lc_sample, aes(x = annual_inc, y = loan_amnt, color = grade)) +
  geom_point(alpha = 0.25, size = 1.2) +
  geom_smooth(method = "lm", color = "black", se = TRUE,
              linewidth = 1.2, linetype = "dashed") +  # Add linear trend line
  scale_color_manual(values = grade_colors, name = "Loan Grade") +
  scale_x_continuous(labels = dollar_format(scale = 0.001, suffix = "K"),
                     limits = c(0, 200000)) +
  scale_y_continuous(labels = dollar_format()) +
  labs(
    title    = "Annual Income vs. Loan Amount (Sample: 8,000 loans)",
    subtitle = "Color-coded by loan grade; dashed line shows overall linear trend",
    x = "Annual Income ($)",
    y = "Loan Amount ($)",
    caption  = "Source: Lending Club 2012-2017"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold"),
    legend.position = "right"
  ) +
  guides(color = guide_legend(override.aes = list(alpha = 1, size = 3)))

# Define the correct order for employment length categories
emp_order <- c("< 1 year","1 year","2 years","3 years","4 years",
               "5 years","6 years","7 years","8 years","9 years","10+ years")

# Compute average loan amount by employment length
emp_summary <- lc_merged %>%
  filter(emp_length %in% emp_order) %>%
  mutate(emp_length = factor(emp_length, levels = emp_order)) %>%
  group_by(emp_length) %>%
  summarize(avg_loan = mean(loan_amnt, na.rm = TRUE),
            count = n(), .groups = "drop")

ggplot(emp_summary, aes(x = emp_length, y = avg_loan, fill = avg_loan)) +
  geom_col(color = "white", width = 0.75) +
  geom_text(aes(label = paste0("$", round(avg_loan/1000, 1), "K")),
            vjust = -0.4, fontface = "bold", size = 3.8) +
  scale_fill_gradient(low = "#deebf7", high = "#08306b",
                      labels = dollar_format(), name = "Avg Loan") +
  scale_y_continuous(labels = dollar_format(), limits = c(0, 18500)) +
  labs(
    title    = "Average Loan Amount by Length of Employment",
    subtitle = "Borrowers with longer employment tenure request larger loans",
    x = "Employment Length",
    y = "Average Loan Amount ($)",
    caption  = "Source: Lending Club 2012-2017"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold"),
    axis.text.x   = element_text(angle = 30, hjust = 1),
    legend.position = "none"
  )

# Compute per-capita loan rate by region
region_percap <- by_state %>%
  group_by(Region) %>%
  summarize(
    total_loans = sum(num_loans),
    total_pop   = sum(population, na.rm = TRUE),
    .groups     = "drop"
  ) %>%
  mutate(loans_per_1k = total_loans / total_pop * 1000) %>%
  filter(!is.na(Region)) %>%
  arrange(desc(loans_per_1k))

region_colors <- c("South"="#e74c3c","West"="#3498db",
                   "Northeast"="#2ecc71","Midwest"="#f39c12")

# Plot 5a: Pie chart of total loan volume by region
p5a <- ggplot(by_region, aes(x = "", y = num_loans, fill = Region)) +
  geom_col(width = 1, color = "white", size = 1) +
  coord_polar(theta = "y") +
  scale_fill_manual(values = region_colors) +
  geom_text(aes(label = paste0(Region, "\n",
                               scales::percent(num_loans/sum(num_loans), accuracy = 0.1))),
            position = position_stack(vjust = 0.5), fontface = "bold", size = 3.8) +
  labs(title = "Loan Volume by Region") +
  theme_void(base_size = 12) +
  theme(plot.title = element_text(face = "bold", hjust = 0.5),
        legend.position = "none")

# Plot 5b: Loans per capita by region
p5b <- ggplot(region_percap, aes(x = reorder(Region, -loans_per_1k),
                                  y = loans_per_1k, fill = Region)) +
  geom_col(width = 0.65, color = "white") +
  geom_text(aes(label = round(loans_per_1k, 2)),
            vjust = -0.5, fontface = "bold", size = 4.5) +
  scale_fill_manual(values = region_colors) +
  scale_y_continuous(limits = c(0, max(region_percap$loans_per_1k) * 1.2)) +
  labs(title = "Loans per 1,000 Population by Region",
       x = "Region", y = "Loans per 1,000 Population") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"),
        legend.position = "none")

grid.arrange(p5a, p5b, ncol = 2,
             top = "Regional Lending Patterns — Lending Club 2012-2017")
