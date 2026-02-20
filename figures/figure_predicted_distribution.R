# =============================================================================
# Figure: Predicted mechanism distribution vs curated dataset (actual)
# Description: Faceted horizontal bar chart — two panels (Predicted / Actual),
#              same x-axis scale for direct comparison of proportions.
# Output: figures/figure_predicted_distribution.png (300 dpi)
# =============================================================================

library(ggplot2)
library(dplyr)

# --- Data --------------------------------------------------------------------
predicted <- data.frame(
  Mechanism = c(
    "Autophosphorylation", "Autoubiquitination", "Autocatalytic",
    "Autoregulation", "Autoinhibition", "Autolysis", "Autoinducer"
  ),
  pct   = c(58.1, 11.9, 11.7, 9.6, 4.0, 2.6, 2.1),
  Group = "Predicted\n(n\u202f=\u202f97,657 across 3,340,955 abstracts)"
)

actual <- data.frame(
  Mechanism = c(
    "Autophosphorylation", "Autoregulation", "Autocatalytic",
    "Autoinhibition", "Autoubiquitination", "Autolysis", "Autoinducer"
  ),
  pct   = c(53.4, 11.9, 11.0, 9.2, 8.9, 2.9, 2.9),
  Group = "Curated dataset\n(n\u202f=\u202f1,332)"
)

df <- rbind(predicted, actual)

# Mechanism order: ascending by predicted % so largest sits at top of y-axis
mech_order <- predicted %>%
  arrange(pct) %>%
  pull(Mechanism)

df <- df %>%
  mutate(
    Mechanism = factor(Mechanism, levels = mech_order),
    Group     = factor(Group,
                       levels = c(
                         "Curated dataset\n(n\u202f=\u202f1,332)",
                         "Predicted\n(n\u202f=\u202f97,657 across 3,340,955 abstracts)"
                       )),
    label     = sprintf("%.1f%%", pct)
  )

# --- Colour palette ----------------------------------------------------------
col_accent <- "#d97742"
col_ink    <- "#1a2332"
col_muted  <- "#6b7a89"
col_bg     <- "#ffffff"

# --- Plot --------------------------------------------------------------------
p <- ggplot(df, aes(x = pct, y = Mechanism)) +

  # Bar
  geom_col(fill = col_accent, alpha = 0.75, width = 0.65) +

  # Label at bar end
  geom_text(
    aes(x = pct + 0.8, label = label),
    hjust = 0, size = 3.1, colour = col_ink
  ) +

  # Two facets — fixed shared x-axis for direct comparison
  facet_wrap(~ Group, ncol = 2) +

  labs(x = "Percentage (%)", y = NULL) +

  scale_x_continuous(
    limits = c(0, 72),
    breaks = c(0, 10, 20, 30, 40, 50, 60),
    expand = expansion(mult = c(0.02, 0))
  ) +

  scale_y_discrete(expand = expansion(add = c(0.5, 0.5))) +

  theme_classic(base_size = 12) +
  theme(
    strip.text       = element_text(
      colour = col_ink, face = "bold", size = 10
    ),
    strip.background = element_rect(fill = "#fef5f0", colour = NA),
    axis.title.x     = element_text(
      colour = col_ink, size = 11, margin = margin(t = 8)
    ),
    axis.text.y      = element_text(colour = col_ink,   size = 11),
    axis.text.x      = element_text(colour = col_muted, size = 10),
    axis.line.y      = element_blank(),
    axis.ticks.y     = element_blank(),
    axis.line.x      = element_line(colour = "#cccccc", linewidth = 0.4),
    axis.ticks.x     = element_line(colour = "#cccccc", linewidth = 0.4),
    panel.background = element_rect(fill = col_bg, colour = NA),
    plot.background  = element_rect(fill = col_bg, colour = NA),
    panel.spacing    = unit(1.5, "lines"),
    plot.margin      = margin(15, 20, 15, 15)
  )

# --- Save --------------------------------------------------------------------
output_path <- "figures/figure_predicted_distribution.png"

ggsave(
  filename = output_path,
  plot     = p,
  width    = 10,
  height   = 5,
  dpi      = 300,
  bg       = col_bg
)

message("Saved: ", output_path)