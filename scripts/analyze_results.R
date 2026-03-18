#!/usr/bin/env Rscript
# analyze_results.R — Post-experiment analysis of many-analyst results
#
# Reads: output/results_all.csv (combined from collect_results.sh)
# Produces: Fisher randomization test, summary statistics, specification analysis
#
# Usage: Rscript analyze_results.R

library(dplyr)
library(tidyr)
library(ggplot2)

# ============================================================================
# Load data
# ============================================================================
results <- read.csv("output/results_all.csv", stringsAsFactors = FALSE)

# Extract arm from agent_id (e.g., "null_001" -> "null")
results <- results |>
  mutate(
    arm = sub("_[0-9]+$", "", agent_id),
    arm = factor(arm, levels = c("negative", "none", "null"))
  )

cat("=== Sample Sizes ===\n")
print(table(results$arm))
cat("\n")

# ============================================================================
# 1. Summary statistics by arm
# ============================================================================
cat("=== ATT Summary by Arm ===\n")
arm_summary <- results |>
  group_by(arm) |>
  summarize(
    n = n(),
    mean_att = mean(att_estimate, na.rm = TRUE),
    sd_att = sd(att_estimate, na.rm = TRUE),
    median_att = median(att_estimate, na.rm = TRUE),
    min_att = min(att_estimate, na.rm = TRUE),
    max_att = max(att_estimate, na.rm = TRUE),
    .groups = "drop"
  )
print(arm_summary)
cat("\n")

# ============================================================================
# 2. Primary analysis: Fisher randomization test
# ============================================================================
cat("=== Fisher Randomization Test ===\n")
cat("H0 (sharp null): Permuting arm labels does not change ATT distribution\n")
cat("Test statistic: Difference in mean ATT (null arm - negative arm)\n\n")

# Observed test statistic
att_null <- results$att_estimate[results$arm == "null"]
att_neg <- results$att_estimate[results$arm == "negative"]
observed_diff <- mean(att_null, na.rm = TRUE) - mean(att_neg, na.rm = TRUE)
cat(sprintf("Observed difference (null - negative): %.4f\n", observed_diff))

# Permutation distribution
set.seed(42)
n_perms <- 10000
combined <- c(att_null, att_neg)
n_null <- length(att_null)
n_total <- length(combined)

perm_diffs <- replicate(n_perms, {
  perm_idx <- sample(n_total, n_null)
  mean(combined[perm_idx], na.rm = TRUE) - mean(combined[-perm_idx], na.rm = TRUE)
})

# Two-sided p-value
p_value <- mean(abs(perm_diffs) >= abs(observed_diff))
cat(sprintf("Fisher p-value (two-sided, %d permutations): %.4f\n", n_perms, p_value))
cat("\n")

# ============================================================================
# 3. Secondary: Kruskal-Wallis across all three arms
# ============================================================================
cat("=== Kruskal-Wallis Test (all three arms) ===\n")
kw_test <- kruskal.test(att_estimate ~ arm, data = results)
print(kw_test)
cat("\n")

# ============================================================================
# 4. Pairwise comparisons
# ============================================================================
cat("=== Pairwise Wilcoxon Tests ===\n")
att_control <- results$att_estimate[results$arm == "none"]

cat("Null vs. Control:\n")
print(wilcox.test(att_null, att_control))
cat("Negative vs. Control:\n")
print(wilcox.test(att_neg, att_control))
cat("Null vs. Negative:\n")
print(wilcox.test(att_null, att_neg))
cat("\n")

# ============================================================================
# 5. Specification channel analysis
# ============================================================================
cat("=== Specification Choices by Arm ===\n\n")

cat("Outcome variable:\n")
print(table(results$arm, results$outcome_variable))
cat("\n")

cat("Treatment definition:\n")
print(table(results$arm, results$treatment_definition))
cat("\n")

cat("Estimator:\n")
print(table(results$arm, results$estimator))
cat("\n")

cat("Control group:\n")
print(table(results$arm, results$control_group))
cat("\n")

# Chi-squared tests for specification independence
cat("Chi-squared test: outcome_variable ~ arm\n")
if (length(unique(results$outcome_variable)) > 1) {
  print(chisq.test(table(results$arm, results$outcome_variable), simulate.p.value = TRUE))
}
cat("\n")

cat("Chi-squared test: treatment_definition ~ arm\n")
if (length(unique(results$treatment_definition)) > 1) {
  print(chisq.test(table(results$arm, results$treatment_definition), simulate.p.value = TRUE))
}
cat("\n")

# ============================================================================
# 6. Plots
# ============================================================================

# ATT distribution by arm
p1 <- ggplot(results, aes(x = arm, y = att_estimate, fill = arm)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, alpha = 0.5, size = 2) +
  scale_fill_manual(values = c(
    "negative" = "#E63946",
    "none" = "#457B9D",
    "null" = "#2A9D8F"
  )) +
  labs(
    x = "Treatment Arm",
    y = "Reported ATT Estimate",
    title = "Distribution of ATT Estimates by Treatment Arm"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("output/att_by_arm.png", p1, width = 8, height = 6, dpi = 300)

# Permutation distribution
p2 <- ggplot(data.frame(diff = perm_diffs), aes(x = diff)) +
  geom_histogram(bins = 50, fill = "gray70", color = "white") +
  geom_vline(xintercept = observed_diff, color = "#E63946", linewidth = 1.2) +
  labs(
    x = "Difference in Mean ATT (Null - Negative)",
    y = "Count",
    title = "Fisher Randomization Distribution",
    subtitle = sprintf("Observed diff = %.4f, p = %.4f", observed_diff, p_value)
  ) +
  theme_minimal()

ggsave("output/fisher_permutation.png", p2, width = 8, height = 6, dpi = 300)

# Specification choices
p3 <- ggplot(results, aes(x = arm, fill = outcome_variable)) +
  geom_bar(position = "fill") +
  labs(
    x = "Treatment Arm",
    y = "Proportion",
    fill = "Outcome Variable",
    title = "Outcome Variable Choice by Arm"
  ) +
  theme_minimal()

ggsave("output/outcome_by_arm.png", p3, width = 10, height = 6, dpi = 300)

cat("\nPlots saved to output/\n")
cat("Done.\n")
