# =============================================================================
# Figures for Section 3.5: Comparing Source of Autoregulation Data
# Data queried from shiny_app/data/predictions.db (100,065 autoregulatory entries)
#
# Outputs (saved individually):
#   figures/figure_35_source.png      — source breakdown (SOORENA vs curated DBs)
#   figures/figure_35_types.png       — mechanism type distribution
#   figures/figure_35_timeline.png    — publication year timeline
#   figures/figure_35_journals.png    — top 10 journals
#   figures/figure_35_confidence.png  — prediction confidence distribution
# =============================================================================

library(ggplot2)
library(dplyr)
library(scales)

# --- Shared palette -----------------------------------------------------------
col_accent  <- "#d97742"   # orange — SOORENA predictions
col_curated <- "#4a6fa5"   # blue   — curated databases
col_ink     <- "#1a2332"
col_muted   <- "#6b7a89"
col_bg      <- "#ffffff"

save_fig <- function(p, filename, width, height) {
  ggsave(
    filename = filename,
    plot     = p,
    width    = width,
    height   = height,
    dpi      = 300,
    bg       = col_bg
  )
  message("Saved: ", filename)
}

# =============================================================================
# Figure A: Source Distribution
# Query: SELECT Source, COUNT(*) FROM predictions GROUP BY Source
# =============================================================================

source_df <- data.frame(
  Source = c("OmniPath", "TRRUST", "SIGNOR", "UniProt", "SOORENA Predicted"),
  n      = c(20, 61, 995, 1332, 97657),
  Type   = c("Curated", "Curated", "Curated", "Curated", "Predicted")
) %>%
  arrange(n) %>%
  mutate(
    Source = factor(Source, levels = Source),
    label  = formatC(n, format = "d", big.mark = ",")
  )

p_source <- ggplot(source_df, aes(x = n, y = Source, fill = Type)) +
  geom_col(width = 0.55) +
  geom_text(aes(label = label), hjust = -0.12, size = 3.4, colour = col_ink) +
  scale_x_log10(
    labels = label_comma(),
    expand = expansion(mult = c(0, 0.3))
  ) +
  scale_fill_manual(
    values = c("Predicted" = col_accent, "Curated" = col_curated),
    labels = c("Curated databases", "SOORENA predictions")
  ) +
  labs(x = "Number of entries (log\u2081\u2080 scale)", y = NULL, fill = NULL) +
  theme_classic(base_size = 12) +
  theme(
    legend.position   = "top",
    legend.text       = element_text(colour = col_ink, size = 10),
    axis.title.x      = element_text(colour = col_ink, size = 11, margin = margin(t = 8)),
    axis.text         = element_text(colour = col_ink, size = 11),
    axis.line.y       = element_blank(),
    axis.ticks.y      = element_blank(),
    axis.line.x       = element_line(colour = "#cccccc", linewidth = 0.4),
    axis.ticks.x      = element_line(colour = "#cccccc", linewidth = 0.4),
    panel.background  = element_rect(fill = col_bg, colour = NA),
    plot.background   = element_rect(fill = col_bg, colour = NA),
    plot.margin       = margin(15, 20, 15, 15)
  )

save_fig(p_source, "figures/figure_35_source.png", width = 7.5, height = 4)

# =============================================================================
# Figure B: Mechanism Type Distribution (SOORENA predictions only)
# Query: SELECT Autoregulatory_Type, COUNT(*) FROM predictions
#         WHERE Has_Mechanism='Yes' GROUP BY Autoregulatory_Type
# =============================================================================

types_df <- data.frame(
  Type = c(
    "Autoinducer", "Autolysis", "Autoinhibition",
    "Autoregulation", "Autocatalytic",
    "Autoubiquitination", "Autophosphorylation"
  ),
  n = c(2112, 2593, 4037, 9740, 11560, 11722, 58274)
) %>%
  arrange(n) %>%
  mutate(
    Type  = factor(Type, levels = Type),
    label = formatC(n, format = "d", big.mark = ",")
  )

p_types <- ggplot(types_df, aes(x = n, y = Type)) +
  geom_col(fill = col_accent, width = 0.6, alpha = 0.9) +
  geom_text(aes(label = label), hjust = -0.1, size = 3.3, colour = col_ink) +
  scale_x_continuous(
    labels = label_comma(),
    expand = expansion(mult = c(0, 0.2))
  ) +
  labs(x = "Number of entries", y = NULL) +
  theme_classic(base_size = 12) +
  theme(
    axis.title.x     = element_text(colour = col_ink, size = 11, margin = margin(t = 8)),
    axis.text        = element_text(colour = col_ink, size = 11),
    axis.line.y      = element_blank(),
    axis.ticks.y     = element_blank(),
    axis.line.x      = element_line(colour = "#cccccc", linewidth = 0.4),
    axis.ticks.x     = element_line(colour = "#cccccc", linewidth = 0.4),
    panel.background = element_rect(fill = col_bg, colour = NA),
    plot.background  = element_rect(fill = col_bg, colour = NA),
    plot.margin      = margin(15, 20, 15, 15)
  )

save_fig(p_types, "figures/figure_35_types.png", width = 7.5, height = 5)

# =============================================================================
# Figure C: Publication Timeline (1970–2024)
# Query: SELECT Year, COUNT(*) FROM predictions
#         WHERE Has_Mechanism='Yes' AND Year BETWEEN 1970 AND 2024
# =============================================================================

timeline_df <- data.frame(
  Year = 1970:2024,
  n = c(
     34,  23,  33,  43,  44, 121, 117, 125, 125, 139,  # 1970–1979
    177, 192, 242, 331, 410, 512, 594, 658, 841, 980,  # 1980–1989
   1061,1417,1606,1936,2296,2424,2557,2586,2765,2926,  # 1990–1999
   2993,2995,3218,3270,3402,3419,3261,3493,3519,3462,  # 2000–2009
   3444,3440,3243,3135,2982,2874,2633,2349,2174,2051,  # 2010–2019
   1990,1975,1748,1736,1774                            # 2020–2024
  )
)

p_timeline <- ggplot(timeline_df, aes(x = Year, y = n)) +
  geom_area(fill = col_accent, alpha = 0.25) +
  geom_line(colour = col_accent, linewidth = 0.9) +
  scale_x_continuous(
    breaks = seq(1970, 2024, by = 5),
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  scale_y_continuous(
    labels = label_comma(),
    expand = expansion(mult = c(0, 0.08))
  ) +
  labs(x = "Publication year", y = "Number of papers") +
  theme_classic(base_size = 12) +
  theme(
    axis.title   = element_text(colour = col_ink, size = 11, margin = margin(t = 6)),
    axis.text    = element_text(colour = col_muted, size = 10),
    axis.line    = element_line(colour = "#cccccc", linewidth = 0.4),
    axis.ticks   = element_line(colour = "#cccccc", linewidth = 0.4),
    panel.background = element_rect(fill = col_bg, colour = NA),
    plot.background  = element_rect(fill = col_bg, colour = NA),
    plot.margin      = margin(15, 20, 15, 15)
  )

save_fig(p_timeline, "figures/figure_35_timeline.png", width = 9, height = 4)

# =============================================================================
# Figure D: Top 10 Journals
# Query: SELECT Journal, COUNT(*) FROM predictions
#         WHERE Has_Mechanism='Yes' GROUP BY Journal ORDER BY n DESC LIMIT 10
# =============================================================================

journals_df <- data.frame(
  Journal = c(
    "The Journal of Biological Chemistry",
    "PNAS",
    "Journal of Bacteriology",
    "Biochemical and Biophysical\nResearch Communications",
    "Oncogene",
    "Molecular and Cellular Biology",
    "The EMBO Journal",
    "Molecular Microbiology",
    "Biochemistry",
    "FEBS Letters"
  ),
  n = c(13091, 5116, 3443, 3005, 2435, 2435, 1975, 1903, 1848, 1835)
) %>%
  arrange(n) %>%
  mutate(
    Journal = factor(Journal, levels = Journal),
    label   = formatC(n, format = "d", big.mark = ",")
  )

p_journals <- ggplot(journals_df, aes(x = n, y = Journal)) +
  geom_col(fill = col_accent, width = 0.6, alpha = 0.9) +
  geom_text(aes(label = label), hjust = -0.1, size = 3.3, colour = col_ink) +
  scale_x_continuous(
    labels = label_comma(),
    expand = expansion(mult = c(0, 0.22))
  ) +
  labs(x = "Number of entries", y = NULL) +
  theme_classic(base_size = 12) +
  theme(
    axis.title.x     = element_text(colour = col_ink, size = 11, margin = margin(t = 8)),
    axis.text.y      = element_text(colour = col_ink, size = 10, lineheight = 0.9),
    axis.text.x      = element_text(colour = col_muted, size = 10),
    axis.line.y      = element_blank(),
    axis.ticks.y     = element_blank(),
    axis.line.x      = element_line(colour = "#cccccc", linewidth = 0.4),
    axis.ticks.x     = element_line(colour = "#cccccc", linewidth = 0.4),
    panel.background = element_rect(fill = col_bg, colour = NA),
    plot.background  = element_rect(fill = col_bg, colour = NA),
    plot.margin      = margin(15, 20, 15, 15)
  )

save_fig(p_journals, "figures/figure_35_journals.png", width = 8, height = 5.5)

# =============================================================================
# Figure E: Prediction Confidence Distribution
# Query: SELECT ROUND(Type_Confidence, 2), COUNT(*) FROM predictions
#         WHERE Has_Mechanism='Yes' AND Source='Predicted'
# =============================================================================

conf_df <- data.frame(
  bin = c(
    0.18,0.19,0.20,0.21,0.22,0.23,0.24,0.25,0.26,0.27,0.28,0.29,
    0.30,0.31,0.32,0.33,0.34,0.35,0.36,0.37,0.38,0.39,
    0.40,0.41,0.42,0.43,0.44,0.45,0.46,0.47,0.48,0.49,
    0.50,0.51,0.52,0.53,0.54,0.55,0.56,0.57,0.58,0.59,
    0.60,0.61,0.62,0.63,0.64,0.65,0.66,0.67,0.68,0.69,
    0.70,0.71,0.72,0.73,0.74,0.75,0.76,0.77,0.78,0.79,
    0.80,0.81,0.82,0.83,0.84,0.85,0.86,0.87,0.88,0.89,
    0.90,0.91,0.92,0.93,0.94,0.95
  ),
  n = c(
      1,   3,   5,  10,  18,  30,  34,  76,  89, 129, 132, 153,
    190, 201, 229, 268, 285, 285, 333, 340, 355, 368,
    397, 426, 431, 415, 437, 445, 441, 432, 439, 473,
    465, 458, 454, 436, 432, 450, 457, 465, 481, 507,
    516, 486, 491, 531, 588, 567, 627, 616, 613, 618,
    686, 718, 777, 854, 870, 940,1056,1112,1256,1311,
   1428,1566,1928,2184,2396,2934,3407,4071,4918,6325,
   6920,7653,8379,9389,6273, 178
  )
)

# Median confidence
med_conf <- conf_df$bin[which.min(abs(cumsum(conf_df$n) - sum(conf_df$n) / 2))]

p_conf <- ggplot(conf_df, aes(x = bin, y = n)) +
  geom_col(
    fill  = col_accent,
    width = 0.019,
    alpha = 0.85
  ) +
  geom_vline(
    xintercept = 0.90,
    linetype   = "dashed",
    colour     = col_muted,
    linewidth  = 0.6
  ) +
  annotate(
    "text",
    x = 0.905, y = max(conf_df$n) * 0.95,
    label    = "0.90",
    hjust    = 0,
    size     = 3.3,
    colour   = col_muted
  ) +
  scale_x_continuous(
    breaks = seq(0.2, 1.0, by = 0.1),
    limits = c(0.15, 1.0),
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  scale_y_continuous(
    labels = label_comma(),
    expand = expansion(mult = c(0, 0.08))
  ) +
  labs(x = "Type confidence score", y = "Number of entries") +
  theme_classic(base_size = 12) +
  theme(
    axis.title   = element_text(colour = col_ink, size = 11, margin = margin(t = 6)),
    axis.text    = element_text(colour = col_muted, size = 10),
    axis.line    = element_line(colour = "#cccccc", linewidth = 0.4),
    axis.ticks   = element_line(colour = "#cccccc", linewidth = 0.4),
    panel.background = element_rect(fill = col_bg, colour = NA),
    plot.background  = element_rect(fill = col_bg, colour = NA),
    plot.margin      = margin(15, 20, 15, 15)
  )

save_fig(p_conf, "figures/figure_35_confidence.png", width = 7.5, height = 4)

message("\nAll Section 3.5 figures saved successfully.")