library(shiny)       # for building the interactive web app
library(DT)          # for rendering interactive data tables
library(dplyr)       # for data manipulation
library(DBI)         # for database interface
library(RSQLite)     # for SQLite database
library(shinyjs)     # for JavaScript integration (e.g., toggle dark mode)
library(htmltools)   # for safe HTML rendering
library(plotly)      # Creates interactive, dynamic, and web-friendly plots from ggplot or standalone
library(ggplot2)
library(shinycssloaders) # for loading spinners
library(rsconnect)  # for deploying the app to shinyapps.io

# Connect to SQLite Database
cat("Connecting to SQLite database...\n")
DB_PATH <- "data/predictions.db"

if (!file.exists(DB_PATH)) {
  stop(paste("Database not found:", DB_PATH, "\n",
             "Please run create_sqlite_database.py first to create the database."))
}

# Create database connection
conn_info <- dbConnect(RSQLite::SQLite(), DB_PATH)

# Get total row count
total_rows <- dbGetQuery(conn_info, "SELECT COUNT(*) as count FROM predictions")$count
cat(paste("Connected to database with", format(total_rows, big.mark=","), "rows\n"))

cat("Database ready!\n")

# Close the initial info connection; each Shiny session will open its own
dbDisconnect(conn_info)

# How many rows to fetch per page for the main table
DEFAULT_PAGE_SIZE <- 50
PAGE_SIZE_OPTIONS <- c(25, 50, 100, 500)

# Ontology Info Table (authoritative)
ontology_info <- list(
  Autokinase = list(
    Definition = "A protein kinase that phosphorylates itself, typically through autophosphorylation at specific residues (Huang et al., 2017; Mechaly et al., 2017).",
    Synonym = "self-kinase, autophosphorylating kinase, self-phosphorylating enzyme",
    Antonym = "heterophosphorylation, trans-phosphorylation",
    Related = "autophosphorylation"
  ),
  Autophosphorylation = list(
    Definition = "The process by which a protein kinase phosphorylates itself, often leading to activation or conformational changes (Wang, 2002; Bayliss et al., 2023).",
    Synonym = "self-phosphorylation, cis-phosphorylation, intramolecular phosphorylation",
    Antonym = "dephosphorylation, heterophosphorylation",
    Related = "autokinase"
  ),
  Autoubiquitination = list(
    Definition = "The process where an E3 ubiquitin ligase attaches ubiquitin to itself, typically marking itself for degradation (Ciechanover et al., 2011; Amemiya et al., 2008).",
    Synonym = "self-ubiquitination, cis-ubiquitination, auto-ubiquitylation",
    Antonym = "deubiquitination, heteroubiquitination",
    Related = "protein degradation"
  ),
  Autolysis = list(
    Definition = "The process of self-digestion where a protease cleaves itself, often resulting in activation or inactivation (Kapust et al., 2001; Little, 1991).",
    Synonym = "self-cleavage, autocatalytic cleavage, self-proteolysis",
    Antonym = "heterolysis, trans-cleavage",
    Related = "autocatalysis"
  ),
  Autocatalysis = list(
    Definition = "A catalytic process where the product of the reaction catalyzes its own formation or the enzyme catalyzes its own modification (Klemm et al., 2009; Lv et al., 2020).",
    Synonym = "self-catalysis, positive feedback catalysis, autocatalytic reaction",
    Antonym = "heterocatalysis, negative feedback",
    Related = "autolysis, positive feedback"
  ),
  Autoactivation = list(
    Definition = "A regulatory mechanism where a protein positively regulates its own expression or activity (Thomas et al., 2018; García-López et al., 2019).",
    Synonym = "self-activation, positive autoregulation, self-stimulation",
    Antonym = "autoinhibition, negative autoregulation",
    Related = "positive feedback, autoinduction"
  ),
  Autoinhibition = list(
    Definition = "A regulatory mechanism where a protein negatively regulates its own expression or activity (Chen et al., 2020; Rodriguez-Martinez et al., 2021).",
    Synonym = "self-inhibition, negative autoregulation, self-repression",
    Antonym = "autoactivation, positive autoregulation",
    Related = "negative feedback, autorepression"
  ),
  Autoinduction = list(
    Definition = "A process where a protein induces its own expression, typically through positive feedback loops (Miller & Bassler, 2018; Sharma et al., 2022).",
    Synonym = "self-induction, auto-stimulation, positive feedback induction",
    Antonym = "autorepression, negative feedback",
    Related = "autoactivation, positive feedback"
  ),
  Autofeedback = list(
    Definition = "A regulatory loop where a protein's output influences its own activity or expression (Williams et al., 2019; Kumar et al., 2020).",
    Synonym = "self-feedback, autoregulatory loop, feedback regulation",
    Antonym = "feedforward regulation, open-loop control",
    Related = "feedback loop, homeostasis"
  ),
  Autoregulation = list(
    Definition = "The general process by which a biological system regulates its own activity, expression, or function (Johnson & Smith, 2021; Martinez et al., 2019).",
    Synonym = "self-regulation, autonomous regulation, homeostatic control",
    Antonym = "heteroregulation, external regulation",
    Related = "homeostasis, feedback control"
  )
)

# Map dataset labels to ontology keys when names differ
ontology_key_map <- c(
  "Autocatalytic" = "Autocatalysis",
  "Autoinducer"   = "Autoinduction"
  # Add more aliases here if your data contains other variants
)

# Ontology path helper for display
get_ontology_path <- function(key) {
  enzymatic <- c("Autokinase","Autophosphorylation","Autoubiquitination","Autolysis","Autocatalysis")
  expression <- c("Autoactivation","Autoinhibition","Autoinduction","Autofeedback","Autoregulation")
  if (key %in% enzymatic)   return(paste("Autoregulatory Mechanisms (Root) → Enzymatic Self-Modification →", key))
  if (key %in% expression)  return(paste("Autoregulatory Mechanisms (Root) → Expression Control →", key))
  "Autoregulatory Mechanisms (Root)"
}


# Define UI
# Header UI reused across all tabs
header_ui <- div(
  class = "header-section",
  div(class = "app-title", img(src = "logo.png"), "SOORENA"),
  div(class = "header-logos",
      img(src = "logoHelsinki.png"),
      img(src = "logoUBC.png"),
      img(src = "logoJafariLab.png")
  )
)

# Define UI
ui <- navbarPage(
  title = NULL,
  id = "main_nav",

  # Tab: Search and Main App Interface
  # background-image: url('header_img.png');
  tabPanel(
    title = "Search",
    fluidPage(
      useShinyjs(),
      tags$head(
        tags$style(HTML("
          body {
            background-color: #f9f9f9;
          }
          :root {
            --stats-bg: #f5f9fc;
            --stats-surface: #ffffff;
            --stats-ink: #1f2d3d;
            --stats-muted: #6b7a89;
            --stats-accent: #3498db;
            --stats-accent-2: #e76f51;
            --stats-accent-3: #2c3e50;
            --stats-border: #e1e8ee;
            --stats-shadow: 0 8px 24px rgba(15, 23, 42, 0.08);
          }
          .header-section {
            background-size: 50% auto;
            background-position: center;
            background-repeat: no-repeat;
            background-color: #ffffff;
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-top: 20px;
            padding: 20px 30px;
            border-radius: 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
          }
          .app-title {
            font-size: 48px;
            font-weight: bold;
            color: #2c3e50;
            margin: 0;
            display: flex;
            align-items: center;
          }
          .app-title img {
            height: 120px;
            margin-right: 20px;
          }
          .header-logos {
            display: flex;
            gap: 20px;
          }
          .header-logos img {
            height: 120px;
          }
          .filter-panel {
            background-color: #ffffff;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 30px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
          }
          .btn-warning {
            margin-top: 10px;
          }
          .dataTables_wrapper {
            background-color: #ffffff;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            margin: 0 0 20px 0;
          }
          /* Statistics tab styling */
          .filter-panel h2 {
            color: #2c3e50;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
            margin-bottom: 20px;
            font-weight: 600;
          }
          .filter-panel h3 {
            color: #34495e;
            margin-top: 30px;
            margin-bottom: 15px;
            font-weight: 600;
          }
          .filter-panel h4 {
            color: #7f8c8d;
            font-weight: 600;
            margin-bottom: 15px;
            font-size: 16px;
          }
          .table {
            font-size: 14px;
            margin-top: 10px;
          }
          .table th {
            background-color: #ecf0f1;
            font-weight: 600;
            color: #2c3e50;
          }
          .table-hover tbody tr:hover {
            background-color: #f5f6f7;
          }
          .stats-panel {
            position: relative;
            background: #ebf5fb;
            border: 1px solid #d6eaf8;
            border-radius: 12px;
            padding: 24px;
            margin: 30px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
          }
          .stats-panel--compact {
            max-width: 1100px;
            margin: 30px auto;
          }
          .stats-header {
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            gap: 16px;
            margin-bottom: 18px;
          }
          .stats-title {
            color: var(--stats-ink);
            font-size: 26px;
            font-weight: 700;
            margin: 0 0 6px 0;
          }
          .stats-subtitle {
            color: var(--stats-muted);
            margin: 0;
            font-size: 14px;
          }
          .stats-pill {
            padding: 6px 12px;
            border-radius: 999px;
            background: rgba(42, 157, 143, 0.12);
            color: var(--stats-accent);
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.6px;
            white-space: nowrap;
          }
          .stats-grid {
            display: grid;
            gap: 44px;
          }
          .stats-grid + .stats-grid {
            margin-top: 22px;
          }
          .stats-grid--top {
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
          }
          .stats-grid--two {
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
          }
          .stats-grid--one {
            grid-template-columns: 1fr;
          }
          .stat-card {
            background: var(--stats-surface);
            border: 1px solid var(--stats-border);
            border-radius: 14px;
            padding: 16px;
            box-shadow: 0 6px 14px rgba(15, 23, 42, 0.08);
            animation: statsFadeUp 0.6s ease;
            transition: box-shadow 0.2s ease, border-color 0.2s ease;
            position: relative;
            z-index: 0;
          }
          .stat-card:hover {
            box-shadow: 0 8px 16px rgba(15, 23, 42, 0.12);
            border-color: rgba(42, 157, 143, 0.35);
            z-index: 2;
          }
          .stat-card__header {
            display: flex;
            align-items: baseline;
            justify-content: space-between;
            gap: 8px;
          }
          .stat-card__title {
            color: var(--stats-ink);
            font-size: 16px;
            font-weight: 600;
            margin: 0 0 10px 0;
          }
          .stat-card__meta {
            color: var(--stats-muted);
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.4px;
          }
          .stat-card__value-large {
            display: block;
            margin-top: 12px;
          }
          .stat-card__value-large #stat_total_papers {
            font-size: 48px;
            font-weight: 700;
            color: var(--stats-ink);
            line-height: 1;
            font-variant-numeric: tabular-nums;
          }
          .stat-label {
            color: var(--stats-muted);
            font-size: 13px;
            text-transform: uppercase;
            letter-spacing: 0.6px;
            font-weight: 600;
          }
          .stat-value {
            margin-top: 8px;
            margin-bottom: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          #stat_total_papers {
            font-size: 44px;
            font-weight: 700;
            color: var(--stats-ink);
            line-height: 1;
            font-variant-numeric: tabular-nums;
          }
          .stat-meta {
            color: var(--stats-muted);
            font-size: 12px;
          }
          .chart-note {
            color: var(--stats-muted);
            font-size: 12px;
            margin: -4px 0 8px 0;
          }
          .stats-note {
            color: var(--stats-muted);
            font-size: 13px;
            margin-top: 16px;
            font-style: italic;
          }
          .stats-table-card .table {
            margin-bottom: 0;
          }
          @media (max-width: 768px) {
            .stats-header {
              flex-direction: column;
              align-items: flex-start;
            }
            .stats-panel {
              margin: 20px;
              padding: 20px;
            }
          }
          @keyframes statsFadeUp {
            from {
              opacity: 0;
              transform: translateY(8px);
            }
            to {
              opacity: 1;
              transform: translateY(0);
            }
          }
        "))
      ),

      # Header section
      header_ui,

      # Search and Filter Controls
  # Search and Filter Controls
  div(class = "filter-panel",
    fluidRow(
      column(
        width = 8,
        fluidRow(
          column(3, textInput("protein_id", "Protein ID", placeholder = "Search protein ID...")),
          column(3, textInput("ac", "AC", placeholder = "Search AC...")),
          column(3, selectInput("has_mechanism", "Has Mechanism", choices = c("All", "Yes", "No"))),
          column(3, selectizeInput("os", "OS",
                                choices = NULL,
                                multiple = TRUE,
                                options = list(placeholder = 'Select OS...')))
        ),
        fluidRow(
          column(3, textInput("pmid", "PMID", placeholder = "Search PMID...")),
          column(3, textInput("author", "Author", placeholder = "Search author...")),
          column(3, selectizeInput("journal", "Journal",
                                choices = NULL,
                                multiple = TRUE,
                                options = list(placeholder = 'Select journal...'))),
          column(3, selectInput("source", "Data Source", choices = c("All", "UniProt", "Non-UniProt")))
        ),
        fluidRow(
          column(3, selectizeInput("type", "Autoregulatory Type",
                                choices = NULL,
                                multiple = TRUE,
                                options = list(placeholder = 'Select type...'))),
          column(3, selectizeInput("year", "Publication Year",
                                choices = NULL,
                                multiple = TRUE,
                                options = list(placeholder = 'Select year...'))),
          column(3, selectInput("month", "Publication Month",
                                choices = c("All", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"),
                                multiple = TRUE))
        )
      ),
      column(
        width = 4,
        textAreaInput("search", "Search Title / Abstract", placeholder = "Type or paste any text...", height = "120px"),
        actionButton("reset_filters", "Reset Filters", class = "btn-warning")
      )
    )
  ),

        # Display Table with loading spinner
        div(style = "margin: 0 30px 20px 30px;",
            div(
              style = "display: flex; align-items: center; justify-content: space-between; gap: 10px; margin-bottom: 10px;",
              div(
                style = "display: flex; align-items: center; gap: 10px;",
                selectInput("rows_per_page", "Rows per page",
                            choices = PAGE_SIZE_OPTIONS,
                            selected = DEFAULT_PAGE_SIZE,
                            width = "140px"),
                actionButton("prev_page", "Previous", class = "btn-default"),
                actionButton("next_page", "Next", class = "btn-default"),
                textOutput("page_status", inline = TRUE)
              ),
              downloadButton("download_csv", "Download CSV", class = "btn-primary mb-0")
            ),
            withSpinner(DTOutput("result_table"),
                       type = 6,
                       color = "#2c3e50",
                       size = 1.5))
      )
    ),

  # Tab: Statistics
  tabPanel(
    title = "Statistics",
    fluidPage(
      header_ui,

      # Dataset Statistics Section
      div(class = "stats-panel",
        div(class = "stats-header",
          div(
            h2("Dataset Statistics", class = "stats-title"),
            p("Based on current filters", class = "stats-subtitle")
          ),
          div(class = "stats-pill", "Live filtered view")
        ),
        div(class = "stats-grid stats-grid--top",
          div(class = "stat-card stat-card--chart",
            div(class = "stat-card__header",
              h4("Total Matching Papers", class = "stat-card__title"),
              span(class = "stat-card__value-large", textOutput("stat_total_papers", inline = TRUE))
            )
          ),
          div(class = "stat-card stat-card--chart",
            div(class = "stat-card__header",
              h4("Has Mechanism", class = "stat-card__title"),
              span(class = "stat-card__meta", "Yes vs No")
            ),
            withSpinner(plotlyOutput("stat_mechanism_plot", height = "230px"), type = 6, color = "#2c3e50")
          ),
          div(class = "stat-card stat-card--chart",
            div(class = "stat-card__header",
              h4("Source Mix", class = "stat-card__title"),
              span(class = "stat-card__meta", "UniProt vs Non-UniProt")
            ),
            withSpinner(plotlyOutput("stat_source_plot", height = "230px"), type = 6, color = "#2c3e50")
          )
        ),
        div(class = "stats-grid stats-grid--two",
          div(class = "stat-card stat-card--wide",
            h4("Autoregulatory Types", class = "stat-card__title"),
            withSpinner(plotlyOutput("stat_type_plot", height = "340px"), type = 6, color = "#2c3e50")
          ),
          div(class = "stat-card stat-card--wide",
            div(class = "stat-card__header",
              h4("Publication Timeline", class = "stat-card__title"),
              span(class = "stat-card__meta", "Bubble size shows paper count")
            ),
            div(class = "chart-note", "Bubble size reflects paper count; color deepens with volume."),
            withSpinner(plotlyOutput("stat_year_plot", height = "340px"), type = 6, color = "#2c3e50")
          )
        ),
        div(class = "stats-grid stats-grid--one",
          div(class = "stat-card stat-card--wide",
            h4("Top Journals", class = "stat-card__title"),
            withSpinner(plotlyOutput("stat_journal_plot", height = "320px"), type = 6, color = "#2c3e50")
          )
        )
      ),

      # Model Performance Section
      div(class = "stats-panel stats-panel--compact",
        div(class = "stats-header",
          div(
            h2("Model Training Performance", class = "stats-title"),
            p("Performance metrics from the published SOORENA study", class = "stats-subtitle")
          ),
          div(class = "stats-pill", "Model benchmarks")
        ),
        div(class = "stats-grid stats-grid--two",
          div(class = "stat-card stats-table-card",
            h4("Stage 1: Binary Classification (n = 600 test samples)", class = "stat-card__title"),
            tableOutput("model_stage1_table")
          ),
          div(class = "stat-card stats-table-card",
            h4("Stage 2: Multi-class - Overall Performance", class = "stat-card__title"),
            tableOutput("model_stage2_overall_table")
          )
        ),
        div(class = "stat-card stats-table-card", style = "margin-top: 16px;",
          h4("Stage 2: Per-class Performance", class = "stat-card__title"),
          tableOutput("model_stage2_perclass_table")
        ),
        p("Source: bioRxiv preprint doi: https://doi.org/10.1101/2025.11.03.685842",
          class = "stats-note")
      )
    )
  ),

  # Tab: Ontology
  tabPanel(
    title = "Ontology",
    fluidPage(
      header_ui,

      tags$head(
        tags$style(HTML("
          .tree-link {
            color: #2c3e50;
            text-decoration: none;
            cursor: pointer;
            font-weight: 500;
          }
          .tree-link:hover {
            color: #3498db;
            text-decoration: underline;
          }
          .mechanism-box {
            scroll-margin-top: 80px;
          }
        "))
      ),

      div(style = "
         padding: 30px;
         background: #ffffff;
         border-radius: 12px;
         box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
         margin: 30px;
         font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
         line-height: 1.8;
         font-size: 15px;",

          h2("Autoregulatory Mechanisms Ontology", style = "color: #2c3e50; font-weight: 700; margin-bottom: 20px;"),

          p(style = "font-size: 16px; color: #555;",
            "A structured classification of self-directed biochemical processes identified and categorized by the SOORENA pipeline."),

          # Ontology Tree - FIXED with better contrast and clickable links
          h3("Hierarchical Structure", style = "color: #2c3e50; margin-top: 30px;"),
          div(style = "
            background: #f8f9fa;
            padding: 25px;
            border-radius: 8px;
            border: 2px solid #dee2e6;
            margin: 20px 0;",
            tags$pre(style = "
              color: #2c3e50;
              font-size: 15px;
              line-height: 2.2;
              font-family: 'Menlo', 'Monaco', 'Courier New', monospace;
              margin: 0;
              font-weight: 500;",
              HTML("Self-directed biochemical processes
│
├─── Self-catalytic chemistry
│    └─── <a href='#autocatalytic' class='tree-link'>Autocatalytic Reaction</a>
│
├─── Protein self-modification (post-translational)
│    ├─── <a href='#autophosphorylation' class='tree-link'>Autophosphorylation</a>
│    └─── <a href='#autoubiquitination' class='tree-link'>Autoubiquitination</a>
│
├─── Intrinsic regulatory control
│    ├─── <a href='#autoregulation' class='tree-link'>Autoregulation of Gene Expression</a>
│    └─── <a href='#autoinhibition' class='tree-link'>Autoinhibition within Proteins</a>
│
├─── Self-degradation and lysis
│    └─── <a href='#autolysis' class='tree-link'>Autolysis</a>
│
└─── Population-level self-signaling
     └─── <a href='#autoinducer' class='tree-link'>Autoinducer Molecules in Quorum Sensing</a>")
            )
          ),

          hr(style = "margin: 40px 0; border-top: 2px solid #e0e0e0;"),

          # Detailed Mechanism Descriptions with MUTED PROFESSIONAL COLORS
          h3("Mechanism Definitions with Ontology Relations and Citations", style = "color: #2c3e50;"),

          # 1. Autocatalytic Reaction
          div(id = "autocatalytic", class = "mechanism-box",
              style = "margin: 30px 0; padding: 25px; background: #fef9e7; border-radius: 8px; border-left: 5px solid #d4af37; box-shadow: 0 2px 4px rgba(0,0,0,0.08);",
              h4("1. Autocatalytic Reaction", style = "color: #7d6608; margin-bottom: 15px; font-weight: 600;"),
              p(style = "color: #555; margin-bottom: 15px;",
                "A chemical reaction in which its product or intermediate accelerates the same reaction. Supports nonlinear self-reinforcement and chemical self-organization."),

              div(style = "background: #ffffff; padding: 15px; border-radius: 6px; margin: 15px 0; border: 1px solid #f0f0f0;",
                h5("Core Ontology Relations", style = "color: #2c3e50; font-size: 14px; margin-bottom: 10px;"),
                tags$ul(style = "margin: 0; padding-left: 20px; color: #555;",
                  tags$li(tags$b("is-a:"), " chemical reaction"),
                  tags$li(tags$b("has-input:"), " reaction substrates"),
                  tags$li(tags$b("has-output:"), " product that acts as catalyst"),
                  tags$li(tags$b("enables:"), " self-amplification in reaction networks"),
                  tags$li(tags$b("occurs-in:"), " biochemical and chemical systems")
                )
              ),

              p(tags$b("Key References:"), style = "color: #2c3e50; margin-top: 15px;"),
              tags$ul(style = "margin: 5px 0; padding-left: 20px; color: #666; font-size: 14px;",
                tags$li("Blackmond D. G. (2009). ", tags$i("Angewandte Chemie International Edition"), ", 48, 6092-6101."),
                tags$li("Plasson R., Brandenburg A., Jullien L., Bersini H. (2011). ", tags$i("Chemical Society Reviews"), ", 40, 2005-2018.")
              )
          ),

          # 2. Autophosphorylation
          div(id = "autophosphorylation", class = "mechanism-box",
              style = "margin: 30px 0; padding: 25px; background: #edf4f7; border-radius: 8px; border-left: 5px solid #2c5aa0; box-shadow: 0 2px 4px rgba(0,0,0,0.08);",
              h4("2. Autophosphorylation", style = "color: #1e3a5f; margin-bottom: 15px; font-weight: 600;"),
              p(style = "color: #555; margin-bottom: 15px;",
                "A protein kinase phosphorylates its own amino acid residues (cis or trans), tuning its conformation, catalytic activity, localization, and signaling dynamics."),

              div(style = "background: #ffffff; padding: 15px; border-radius: 6px; margin: 15px 0; border: 1px solid #f0f0f0;",
                h5("Core Ontology Relations", style = "color: #2c3e50; font-size: 14px; margin-bottom: 10px;"),
                tags$ul(style = "margin: 0; padding-left: 20px; color: #555;",
                  tags$li(tags$b("is-a:"), " protein self-modification event"),
                  tags$li(tags$b("part-of:"), " post-translational regulation"),
                  tags$li(tags$b("regulates:"), " kinase activity and activation state"),
                  tags$li(tags$b("has-input:"), " kinase + ATP"),
                  tags$li(tags$b("has-output:"), " phosphorylated kinase + ADP"),
                  tags$li(tags$b("occurs-in:"), " bacteria, plants, animals")
                )
              ),

              p(tags$b("Key References:"), style = "color: #2c3e50; margin-top: 15px;"),
              tags$ul(style = "margin: 5px 0; padding-left: 20px; color: #666; font-size: 14px;",
                tags$li("Reinhardt R. et al. (2023). ", tags$i("eLife"), ", 12, e88210."),
                tags$li("Xu Q. et al. (2015). ", tags$i("PNAS"), ", 112, 11753-11758.")
              )
          ),

          # 3. Autoubiquitination
          div(id = "autoubiquitination", class = "mechanism-box",
              style = "margin: 30px 0; padding: 25px; background: #f4f0f7; border-radius: 8px; border-left: 5px solid #6c4a8e; box-shadow: 0 2px 4px rgba(0,0,0,0.08);",
              h4("3. Autoubiquitination", style = "color: #4a2c5f; margin-bottom: 15px; font-weight: 600;"),
              p(style = "color: #555; margin-bottom: 15px;",
                "An E3 ubiquitin ligase attaches ubiquitin to itself, altering its stability, proteasomal targeting, and signaling functions depending on chain type and site."),

              div(style = "background: #ffffff; padding: 15px; border-radius: 6px; margin: 15px 0; border: 1px solid #f0f0f0;",
                h5("Core Ontology Relations", style = "color: #2c3e50; font-size: 14px; margin-bottom: 10px;"),
                tags$ul(style = "margin: 0; padding-left: 20px; color: #555;",
                  tags$li(tags$b("is-a:"), " protein self-ubiquitylation"),
                  tags$li(tags$b("part-of:"), " ubiquitin–proteasome regulatory system"),
                  tags$li(tags$b("regulates:"), " E3 ligase abundance and pathway output"),
                  tags$li(tags$b("has-input:"), " E3 ligase + ubiquitin + E2 enzyme"),
                  tags$li(tags$b("has-output:"), " ubiquitylated E3 ligase"),
                  tags$li(tags$b("occurs-in:"), " eukaryotic cells")
                )
              ),

              p(tags$b("Key References:"), style = "color: #2c3e50; margin-top: 15px;"),
              tags$ul(style = "margin: 5px 0; padding-left: 20px; color: #666; font-size: 14px;",
                tags$li("Buetow L., Huang D. T. (2021). ", tags$i("International Journal of Molecular Sciences"), ", 22, 6057."),
                tags$li("Nityanandam R. et al. (2011). ", tags$i("BMC Biochemistry"), ", 12, 33.")
              )
          ),

          # 4. Autoregulation
          div(id = "autoregulation", class = "mechanism-box",
              style = "margin: 30px 0; padding: 25px; background: #eef7ee; border-radius: 8px; border-left: 5px solid #4a7c59; box-shadow: 0 2px 4px rgba(0,0,0,0.08);",
              h4("4. Autoregulation of Gene Expression", style = "color: #2d5f3a; margin-bottom: 15px; font-weight: 600;"),
              p(style = "color: #555; margin-bottom: 15px;",
                "A gene product regulates transcription of the same gene through positive or negative feedback, tuning gene expression dynamics, noise, and homeostasis."),

              div(style = "background: #ffffff; padding: 15px; border-radius: 6px; margin: 15px 0; border: 1px solid #f0f0f0;",
                h5("Core Ontology Relations", style = "color: #2c3e50; font-size: 14px; margin-bottom: 10px;"),
                tags$ul(style = "margin: 0; padding-left: 20px; color: #555;",
                  tags$li(tags$b("is-a:"), " gene regulatory feedback motif"),
                  tags$li(tags$b("part-of:"), " transcriptional regulatory network"),
                  tags$li(tags$b("regulates:"), " mRNA abundance and response time"),
                  tags$li(tags$b("has-input:"), " gene product (protein or RNA)"),
                  tags$li(tags$b("has-output:"), " altered transcription rate"),
                  tags$li(tags$b("occurs-in:"), " bacteria, yeast, multicellular organisms")
                )
              ),

              p(tags$b("Key References:"), style = "color: #2c3e50; margin-top: 15px;"),
              tags$ul(style = "margin: 5px 0; padding-left: 20px; color: #666; font-size: 14px;",
                tags$li("Alon U. (2007). ", tags$i("Nature Reviews Genetics"), ", 8, 450-461."),
                tags$li("Becskei A., Serrano L. (2000). ", tags$i("Nature"), ", 405, 590-593.")
              )
          ),

          # 5. Autoinducer
          div(id = "autoinducer", class = "mechanism-box",
              style = "margin: 30px 0; padding: 25px; background: #eef7f5; border-radius: 8px; border-left: 5px solid #2a7a6b; box-shadow: 0 2px 4px rgba(0,0,0,0.08);",
              h4("5. Autoinducer Molecules in Quorum Sensing", style = "color: #1a5447; margin-bottom: 15px; font-weight: 600;"),
              p(style = "color: #555; margin-bottom: 15px;",
                "Small diffusible molecules synthesized and detected by bacteria. Their accumulation with increasing cell density triggers coordinated community-wide transcriptional changes."),

              div(style = "background: #ffffff; padding: 15px; border-radius: 6px; margin: 15px 0; border: 1px solid #f0f0f0;",
                h5("Core Ontology Relations", style = "color: #2c3e50; font-size: 14px; margin-bottom: 10px;"),
                tags$ul(style = "margin: 0; padding-left: 20px; color: #555;",
                  tags$li(tags$b("is-a:"), " extracellular signaling molecule"),
                  tags$li(tags$b("part-of:"), " quorum-sensing signal-response system"),
                  tags$li(tags$b("regulates:"), " group-level behavior and virulence"),
                  tags$li(tags$b("has-input:"), " bacterial metabolic pathways"),
                  tags$li(tags$b("has-output:"), " receptor activation and transcriptional changes"),
                  tags$li(tags$b("occurs-in:"), " bacterial populations")
                )
              ),

              p(tags$b("Key References:"), style = "color: #2c3e50; margin-top: 15px;"),
              tags$ul(style = "margin: 5px 0; padding-left: 20px; color: #666; font-size: 14px;",
                tags$li("Papenfort K., Bassler B. L. (2016). ", tags$i("Nature Reviews Microbiology"), ", 14, 576-588."),
                tags$li("Mukherjee S., Bassler B. L. (2019). ", tags$i("Nature Reviews Microbiology"), ", 17, 371-382.")
              )
          ),

          # 6. Autoinhibition
          div(id = "autoinhibition", class = "mechanism-box",
              style = "margin: 30px 0; padding: 25px; background: #fdf1f1; border-radius: 8px; border-left: 5px solid #a94442; box-shadow: 0 2px 4px rgba(0,0,0,0.08);",
              h4("6. Autoinhibition within Proteins", style = "color: #6f2c2c; margin-bottom: 15px; font-weight: 600;"),
              p(style = "color: #555; margin-bottom: 15px;",
                "Intrinsic structural interactions prevent inappropriate activation of a protein, maintaining it in an inactive state until relieved by ligand binding, structural rearrangement, or post-translational modification."),

              div(style = "background: #ffffff; padding: 15px; border-radius: 6px; margin: 15px 0; border: 1px solid #f0f0f0;",
                h5("Core Ontology Relations", style = "color: #2c3e50; font-size: 14px; margin-bottom: 10px;"),
                tags$ul(style = "margin: 0; padding-left: 20px; color: #555;",
                  tags$li(tags$b("is-a:"), " intrinsic negative regulatory process"),
                  tags$li(tags$b("part-of:"), " protein activity control"),
                  tags$li(tags$b("regulates:"), " activation threshold and specificity"),
                  tags$li(tags$b("has-input:"), " inactive protein structure"),
                  tags$li(tags$b("has-output:"), " relieved inhibition and activation"),
                  tags$li(tags$b("occurs-in:"), " multi-domain signaling proteins")
                )
              ),

              p(tags$b("Key References:"), style = "color: #2c3e50; margin-top: 15px;"),
              tags$ul(style = "margin: 5px 0; padding-left: 20px; color: #666; font-size: 14px;",
                tags$li("Fenton M. et al. (2023). ", tags$i("Cell Reports"), ", 42, 112739."),
                tags$li("Khan R. B. et al. (2019). ", tags$i("Frontiers in Molecular Biosciences"), ", 6, 144.")
              )
          ),

          # 7. Autolysis
          div(id = "autolysis", class = "mechanism-box",
              style = "margin: 30px 0; padding: 25px; background: #f5f6f7; border-radius: 8px; border-left: 5px solid #5a6c7d; box-shadow: 0 2px 4px rgba(0,0,0,0.08);",
              h4("7. Autolysis", style = "color: #34495e; margin-bottom: 15px; font-weight: 600;"),
              p(style = "color: #555; margin-bottom: 15px;",
                "Self-degradation mediated by endogenous lytic enzymes, occurring during programmed cell death, post-mortem breakdown, or engineered microbial lysis systems."),

              div(style = "background: #ffffff; padding: 15px; border-radius: 6px; margin: 15px 0; border: 1px solid #f0f0f0;",
                h5("Core Ontology Relations", style = "color: #2c3e50; font-size: 14px; margin-bottom: 10px;"),
                tags$ul(style = "margin: 0; padding-left: 20px; color: #555;",
                  tags$li(tags$b("is-a:"), " lytic cell death mechanism"),
                  tags$li(tags$b("part-of:"), " cellular degradation process"),
                  tags$li(tags$b("regulates:"), " release of intracellular contents"),
                  tags$li(tags$b("has-input:"), " endogenous hydrolases"),
                  tags$li(tags$b("has-output:"), " membrane rupture and component release"),
                  tags$li(tags$b("occurs-in:"), " microbes, tissues, postmortem environments")
                )
              ),

              p(tags$b("Key References:"), style = "color: #2c3e50; margin-top: 15px;"),
              tags$ul(style = "margin: 5px 0; padding-left: 20px; color: #666; font-size: 14px;",
                tags$li("Yamaguchi Y., Nariya H., Inouye M. (2013). ", tags$i("Applied and Environmental Microbiology"), ", 79, 3120-3126."),
                tags$li("Pérez-Torrado R. et al. (2015). ", tags$i("Comprehensive Reviews in Food Science and Food Safety"), ", 14, 726-743.")
              )
          ),

          hr(style = "margin: 40px 0; border-top: 2px solid #e0e0e0;"),

          # Classification Pipeline - professional colors
          h3("SOORENA Classification Pipeline", style = "color: #2c3e50;"),
          div(style = "background: #34495e; padding: 25px; border-radius: 8px; color: #ffffff; box-shadow: 0 2px 8px rgba(0,0,0,0.15);",
              p(style = "font-size: 16px; margin-bottom: 15px;", "This ontology is implemented through a two-stage deep learning classification system:"),
              tags$ol(style = "line-height: 2.2; font-size: 15px;",
                tags$li(tags$b("Stage 1 - Binary Classification:"), " Identifies papers describing autoregulatory mechanisms (96.0% accuracy, 93.8% F1)"),
                tags$li(tags$b("Stage 2 - Multi-class Classification:"), " Categorizes mechanisms into 7 types using weighted cross-entropy loss to handle class imbalance (95.5% accuracy, 96.2% macro F1)")
              ),
              div(style = "background: rgba(255,255,255,0.1); padding: 15px; border-radius: 6px; margin-top: 20px; border: 1px solid rgba(255,255,255,0.2);",
                p(style = "margin: 5px 0;", tags$b("Base Model:"), " PubMedBERT"),
                p(style = "margin: 5px 0;", tags$b("Training Data:"), " 1,332 manually curated papers"),
                p(style = "margin: 5px 0;", tags$b("Total Database:"), " 254,212 analyzed papers")
              )
          )
      )
    )
  ),



  # Tab: Patch Notes
  tabPanel(
    title = "Patch Notes",
    fluidPage(
      header_ui,
      h2("Patch Notes"),
      withSpinner(
        DT::dataTableOutput("patch_notes_table"),
        type = 6,
        color = "#2c3e50",
        size = 1.5
      )
    )
  ),

  # Tab: About Us
  tabPanel(
    title = "About Us",
    fluidPage(
      header_ui,

      # Page Title
      div(
        style = "text-align: center; margin: 40px 0 60px 0;",
        h1("About SOORENA", style = "font-size: 2.5em; font-weight: 600; color: #2c3e50; margin-bottom: 15px;"),
        p("Self-lOOp containing or autoREgulatory Nodes in biological network Analysis",
          style = "font-size: 1.2em; color: #7f8c8d; font-style: italic;")
      ),

      # Project Description
      div(
        style = "max-width: 900px; margin: 0 auto 60px auto; padding: 0 20px;",
        p("SOORENA is a comprehensive database for exploring autoregulatory mechanisms in proteins.
          Our machine learning-powered platform analyzes millions of scientific publications to identify
          and classify autoregulatory protein mechanisms, providing researchers with unprecedented access
          to this critical biological information.",
          style = "font-size: 1.1em; line-height: 1.8; color: #34495e; text-align: center;")
      ),

      # Team Section Header
      div(
        style = "text-align: center; margin: 60px 0 40px 0;",
        h2("Project Contributors", style = "font-size: 2em; font-weight: 600; color: #2c3e50; margin-bottom: 10px;"),
        div(style = "width: 80px; height: 4px; background: #3498db; margin: 0 auto;")
      ),

      # Team Members Grid
      div(
        style = "max-width: 1200px; margin: 0 auto; padding: 0 20px;",

        # Row 1: Hala and Mohieddin
        div(
          style = "display: flex; flex-wrap: wrap; justify-content: center; gap: 40px; margin-bottom: 40px;",

          # Hala Arar
          div(
            style = "flex: 0 1 280px; text-align: center; background: white; padding: 30px 20px; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); transition: transform 0.3s;",
            div(
              style = "width: 180px; height: 180px; margin: 0 auto 20px auto; border-radius: 50%; overflow: hidden; border: 4px solid #3498db;",
              tags$img(src = "images/team/hala_arar.jpg",
                      style = "width: 100%; height: 100%; object-fit: cover;",
                      alt = "Hala Arar")
            ),
            h3("Hala Arar", style = "font-size: 1.4em; font-weight: 600; color: #2c3e50; margin: 15px 0 10px 0;"),
            p("Department of Statistics", style = "font-size: 0.95em; color: #7f8c8d; margin: 5px 0;"),
            p("University of British Columbia", style = "font-size: 0.95em; color: #7f8c8d; margin: 5px 0;"),
            p("Vancouver, BC, Canada", style = "font-size: 0.9em; color: #95a5a6; margin: 5px 0;")
          ),

          # Mohieddin Jafari
          div(
            style = "flex: 0 1 280px; text-align: center; background: white; padding: 30px 20px; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); transition: transform 0.3s;",
            div(
              style = "width: 180px; height: 180px; margin: 0 auto 20px auto; border-radius: 50%; overflow: hidden; border: 4px solid #3498db;",
              tags$img(src = "images/team/mohieddin_jafari.jpg",
                      style = "width: 100%; height: 100%; object-fit: cover;",
                      alt = "Mohieddin Jafari")
            ),
            h3("Mohieddin Jafari", style = "font-size: 1.4em; font-weight: 600; color: #2c3e50; margin: 15px 0 10px 0;"),
            p("Department of Biochemistry and Developmental Biology", style = "font-size: 0.95em; color: #7f8c8d; margin: 5px 0;"),
            p("University of Helsinki, Finland", style = "font-size: 0.95em; color: #7f8c8d; margin: 5px 0;"),
            p("Faculty of Medicine and Health Technology, Tampere University, Finland", style = "font-size: 0.9em; color: #95a5a6; margin: 5px 0;"),
            p("Tampere Institute for Advanced Study, Finland", style = "font-size: 0.9em; color: #95a5a6; margin: 5px 0;")
          )
        ),

        # Row 2: Payman and Jehad
        div(
          style = "display: flex; flex-wrap: wrap; justify-content: center; gap: 40px;",

          # Payman Nickchi
          div(
            style = "flex: 0 1 280px; text-align: center; background: white; padding: 30px 20px; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); transition: transform 0.3s;",
            div(
              style = "width: 180px; height: 180px; margin: 0 auto 20px auto; border-radius: 50%; overflow: hidden; border: 4px solid #3498db;",
              tags$img(src = "images/team/payman_nickchi.jpg",
                      style = "width: 100%; height: 100%; object-fit: cover;",
                      alt = "Payman Nickchi")
            ),
            h3("Payman Nickchi", style = "font-size: 1.4em; font-weight: 600; color: #2c3e50; margin: 15px 0 10px 0;"),
            p("Department of Statistics", style = "font-size: 0.95em; color: #7f8c8d; margin: 5px 0;"),
            p("University of British Columbia", style = "font-size: 0.95em; color: #7f8c8d; margin: 5px 0;"),
            p("Vancouver, BC, Canada", style = "font-size: 0.9em; color: #95a5a6; margin: 5px 0;")
          ),

          # Jehad Aldahdooh
          div(
            style = "flex: 0 1 280px; text-align: center; background: white; padding: 30px 20px; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); transition: transform 0.3s;",
            div(
              style = "width: 180px; height: 180px; margin: 0 auto 20px auto; border-radius: 50%; overflow: hidden; border: 4px solid #3498db;",
              tags$img(src = "images/team/jehad_aldahdooh.jpg",
                      style = "width: 100%; height: 100%; object-fit: cover;",
                      alt = "Jehad Aldahdooh")
            ),
            h3("Jehad Aldahdooh", style = "font-size: 1.4em; font-weight: 600; color: #2c3e50; margin: 15px 0 10px 0;"),
            p("Research Programs Unit", style = "font-size: 0.95em; color: #7f8c8d; margin: 5px 0;"),
            p("University of Helsinki", style = "font-size: 0.95em; color: #7f8c8d; margin: 5px 0;"),
            p("Helsinki, Finland", style = "font-size: 0.9em; color: #95a5a6; margin: 5px 0;")
          )
        )
      ),

      # Acknowledgements Section
      div(
        style = "max-width: 900px; margin: 80px auto 40px auto; padding: 30px; background: #f8f9fa; border-radius: 10px;",
        h3("Acknowledgements", style = "font-size: 1.6em; font-weight: 600; color: #2c3e50; margin-bottom: 20px; text-align: center;"),
        p("We would like to thank the following individuals for their valuable contributions to this project:",
          style = "font-size: 1.05em; color: #34495e; text-align: center; margin-bottom: 15px;"),
        div(
          style = "text-align: center; font-size: 1.05em; color: #7f8c8d; line-height: 1.8;",
          p("Zheng He • Yining Zhou • Mingyang Zhang", style = "margin: 10px 0;")
        )
      ),

      # Footer spacing
      div(style = "height: 60px;")
    )
  )
)


# Define Server Logic
server <- function(input, output, session) {

  # Open a per-session database connection
  conn <- dbConnect(RSQLite::SQLite(), DB_PATH)

  # Track current page for server-side pagination
  current_page <- reactiveVal(1)
  page_size <- reactive({
    size <- as.numeric(input$rows_per_page)
    if (is.null(size) || is.na(size)) DEFAULT_PAGE_SIZE else size
  })

  # Build WHERE clause and parameter list based on current filters
  build_filter_query <- function() {
    query <- "FROM predictions WHERE 1=1"
    params <- list()

    # Journal filter
    if (!is.null(input$journal) && !"All" %in% input$journal && length(input$journal) > 0) {
      placeholders <- paste(rep("?", length(input$journal)), collapse = ",")
      query <- paste(query, "AND Journal IN (", placeholders, ")")
      params <- c(params, as.list(input$journal))
    }

    # Type filter
    if (!is.null(input$type) && !"All" %in% input$type && length(input$type) > 0) {
      placeholders <- paste(rep("?", length(input$type)), collapse = ",")
      query <- paste(query, "AND Autoregulatory_Type IN (", placeholders, ")")
      params <- c(params, as.list(input$type))
    }

    # OS filter
    if (!is.null(input$os) && !"All" %in% input$os && length(input$os) > 0) {
      placeholders <- paste(rep("?", length(input$os)), collapse = ",")
      query <- paste(query, "AND OS IN (", placeholders, ")")
      params <- c(params, as.list(input$os))
    }

    # AC search
    if (!is.null(input$ac) && nzchar(input$ac)) {
      query <- paste(query, "AND AC LIKE ?")
      params <- c(params, paste0("%", input$ac, "%"))
    }

    # Protein ID search
    if (!is.null(input$protein_id) && nzchar(input$protein_id)) {
      query <- paste(query, "AND Protein_ID LIKE ?")
      params <- c(params, paste0("%", input$protein_id, "%"))
    }

    # PMID search
    if (!is.null(input$pmid) && nzchar(input$pmid)) {
      query <- paste(query, "AND PMID LIKE ?")
      params <- c(params, paste0("%", input$pmid, "%"))
    }

    # Author search
    if (!is.null(input$author) && nzchar(input$author)) {
      query <- paste(query, "AND Authors LIKE ?")
      params <- c(params, paste0("%", input$author, "%"))
    }

    # Has Mechanism filter
    if (!is.null(input$has_mechanism) && input$has_mechanism != "All") {
      query <- paste(query, "AND Has_Mechanism = ?")
      params <- c(params, input$has_mechanism)
    }

    # Source filter
    if (!is.null(input$source) && input$source != "All") {
      query <- paste(query, "AND Source = ?")
      params <- c(params, input$source)
    }

    # Year filter
    if (!is.null(input$year) && !"All" %in% input$year && length(input$year) > 0) {
      placeholders <- paste(rep("?", length(input$year)), collapse = ",")
      query <- paste(query, "AND Year IN (", placeholders, ")")
      params <- c(params, as.list(input$year))
    }

    # Month filter
    if (!is.null(input$month) && !"All" %in% input$month && length(input$month) > 0) {
      placeholders <- paste(rep("?", length(input$month)), collapse = ",")
      query <- paste(query, "AND Month IN (", placeholders, ")")
      params <- c(params, as.list(input$month))
    }

    # Title / Abstract search
    if (!is.null(input$search) && nzchar(input$search)) {
      query <- paste(query, "AND (Title LIKE ? OR Abstract LIKE ?)")
      search_pattern <- paste0("%", input$search, "%")
      params <- c(params, search_pattern, search_pattern)
    }

    list(where = query, params = params)
  }

  # Simple helper to safely truncate and escape text while keeping the magnifier button
  safe_cell <- function(text, max_chars, field) {
    vapply(seq_along(text), function(i) {
      val <- text[i]
      if (is.na(val) || trimws(val) == "") return("—")
      trimmed <- trimws(val)
      escaped_full <- htmltools::htmlEscape(trimmed)
      if (nchar(trimmed) > max_chars) {
        truncated <- htmltools::htmlEscape(substr(trimmed, 1, max_chars))
        paste0(
          truncated, "... ",
          '<button class=\"btn btn-link btn-sm view-btn\" data-field=\"', field,
          '\" data-text=\"', escaped_full, '\">🔍</button>'
        )
      } else {
        escaped_full
      }
    }, character(1))
  }

  # Populate filter dropdowns once at startup with top N most common values
  # This prevents loading thousands of options which causes app freeze
  observeEvent(session$clientData, once = TRUE, {
    # Load top 100 most common journals
    top_journals <- dbGetQuery(conn,
      "SELECT Journal, COUNT(*) as n FROM predictions
       WHERE Journal IS NOT NULL
       GROUP BY Journal
       ORDER BY n DESC
       LIMIT 100")$Journal

    updateSelectizeInput(session, "journal",
      choices = c("All" = "All", top_journals),
      server = FALSE)

    # Load top 100 most common organisms (OS has 9000+ unique values!)
    top_os <- dbGetQuery(conn,
      "SELECT OS, COUNT(*) as n FROM predictions
       WHERE OS IS NOT NULL
       GROUP BY OS
       ORDER BY n DESC
       LIMIT 100")$OS

    updateSelectizeInput(session, "os",
      choices = c("All" = "All", top_os),
      server = FALSE)

    # Load all autoregulatory types (only ~10 values)
    all_types <- dbGetQuery(conn,
      "SELECT DISTINCT Autoregulatory_Type FROM predictions
       WHERE Autoregulatory_Type IS NOT NULL
       ORDER BY Autoregulatory_Type")$Autoregulatory_Type

    updateSelectizeInput(session, "type",
      choices = c("All" = "All", all_types),
      server = FALSE)

    # Load all years (only ~50 values)
    all_years <- dbGetQuery(conn,
      "SELECT DISTINCT Year FROM predictions
       WHERE Year IS NOT NULL
       ORDER BY Year DESC")$Year

    updateSelectizeInput(session, "year",
      choices = c("All" = "All", all_years),
      server = FALSE)
  })

  # Reset pagination whenever filters change
  observeEvent(list(input$journal, input$type, input$os, input$ac, input$protein_id,
                    input$pmid, input$author, input$has_mechanism, input$source,
                    input$year, input$month, input$search, input$rows_per_page), {
    current_page(1)
  })

  # Download csv button
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("filtered_results_", Sys.Date(), ".csv")
    },
    content = function(file) {
      data <- filtered_data()
      # Convert underscores back to spaces for column names
      colnames(data) <- gsub("_", " ", colnames(data))
      write.csv(data, file, row.names = FALSE)
    }
  )


  # Show Full text
    observeEvent(input$show_full_text, {
      showModal(modalDialog(
        title = paste("Full", input$show_full_text$field),
        HTML(paste0("<div style='white-space: pre-wrap; font-family: sans-serif;'>",
                    input$show_full_text$text, "</div>")),
        easyClose = TRUE,
        footer = modalButton("Close"),
        size = "m"
      ))
    })

  # Reset all filters to default state
  observeEvent(input$reset_filters, {
    updateTextInput(session, "protein_id", value = "")
    updateTextInput(session, "ac", value = "")
    updateTextInput(session, "pmid", value = "")
    updateTextInput(session, "author", value = "")
    updateSelectInput(session, "journal", selected = "All")
    updateSelectInput(session, "os", selected = "All")
    updateSelectInput(session, "type", selected = "All")
    updateSelectInput(session, "has_mechanism", selected = "All")
    updateSelectInput(session, "source", selected = "All")
    updateSelectInput(session, "year", selected = "All")
    updateSelectInput(session, "month", selected = "All")
    updateTextAreaInput(session, "search", value = "")
  })

  # Get total count of matching rows (for "Showing X of Y" display)
  total_count <- reactive({
    filters <- build_filter_query()
    query <- paste("SELECT COUNT(*) as count", filters$where)

    if (length(filters$params) > 0) {
      count_result <- dbGetQuery(conn, query, params = filters$params)
    } else {
      count_result <- dbGetQuery(conn, query)
    }

    return(count_result$count)
  })

  # Filtering Logic - Build SQL query dynamically with LIMIT
  filtered_data <- reactive({
    filters <- build_filter_query()
    offset <- (current_page() - 1) * page_size()
    query <- paste(
      "SELECT *",
      filters$where,
      "ORDER BY Title IS NULL, PMID",
      "LIMIT ? OFFSET ?"
    )
    params <- c(filters$params, page_size(), offset)

    result <- dbGetQuery(conn, query, params = params)

    # Convert column names back to spaces for display
    colnames(result) <- gsub("_", " ", colnames(result))

    # Replace Autoregulatory Type 'NA' and 'none' values with 'non-autoregulatory'
    if ("Autoregulatory Type" %in% colnames(result)) {
      result$`Autoregulatory Type` <- ifelse(
        is.na(result$`Autoregulatory Type`) |
          trimws(result$`Autoregulatory Type`) == "" |
          tolower(trimws(result$`Autoregulatory Type`)) == "none",
        "non-autoregulatory",
        result$`Autoregulatory Type`
      )
    }

    return(result)
  })

  observeEvent(input$next_page, {
    req(total_count())
    max_page <- max(ceiling(total_count() / page_size()), 1)
    if (current_page() < max_page) {
      current_page(current_page() + 1)
    }
  })

  observeEvent(input$prev_page, {
    if (current_page() > 1) {
      current_page(current_page() - 1)
    }
  })

  observe({
    total <- total_count()
    max_page <- max(ceiling(total / page_size()), 1)
    if (current_page() > max_page) {
      current_page(max_page)
    }
  })

  output$page_status <- renderText({
    total <- as.numeric(total_count()[1])

    if (is.na(total) || total <= 0) {
      return("No results to display")
    }

    max_page <- ceiling(total / page_size())
    page <- min(current_page(), max_page)
    paste0("Page ", page, " of ", max_page)
  })

  # Statistics tab outputs
  # Dataset statistics (reactive based on filtered data)
  output$stat_total_papers <- renderText({
    total <- as.numeric(total_count()[1])
    if (is.na(total)) total <- 0
    format(total, big.mark = ",")
  })

  output$stat_mechanism_plot <- renderPlotly({
    filters <- build_filter_query()
    query <- paste(
      "SELECT Has_Mechanism AS label, COUNT(*) as n",
      filters$where,
      "GROUP BY Has_Mechanism"
    )
    res <- if (length(filters$params) > 0) {
      dbGetQuery(conn, query, params = filters$params)
    } else {
      dbGetQuery(conn, query)
    }
    if (nrow(res) == 0) {
      res <- data.frame(label = character(0), n = numeric(0))
    }
    res$label <- ifelse(is.na(res$label) | res$label == "", "Unknown", res$label)
    res$label <- factor(res$label, levels = c("Yes", "No", "Unknown"))
    res <- res[order(res$label), ]
    color_map <- c("Yes" = "#3498db", "No" = "#e76f51", "Unknown" = "#94a3b8")

    plot_ly(
      labels = res$label,
      values = res$n,
      text = format(res$n, big.mark = ","),
      type = 'pie',
      hole = 0.55,
      sort = FALSE,
      marker = list(colors = unname(color_map[as.character(res$label)])),
      textinfo = 'label+percent',
      textposition = 'inside',
      hovertemplate = "<b>%{label}</b><br>Papers: %{text}<extra></extra>"
    ) %>%
      layout(
        showlegend = FALSE,
        margin = list(l = 10, r = 10, t = 10, b = 10)
      )
  })

  output$stat_source_plot <- renderPlotly({
    filters <- build_filter_query()
    query <- paste(
      "SELECT Source AS label, COUNT(*) as n",
      filters$where,
      "GROUP BY Source"
    )
    res <- if (length(filters$params) > 0) {
      dbGetQuery(conn, query, params = filters$params)
    } else {
      dbGetQuery(conn, query)
    }
    if (nrow(res) == 0) {
      res <- data.frame(label = character(0), n = numeric(0))
    }
    res$label <- ifelse(is.na(res$label) | res$label == "", "Unknown", res$label)
    res$label <- factor(res$label, levels = c("UniProt", "Non-UniProt", "Unknown"))
    res <- res[order(res$label), ]
    color_map <- c("UniProt" = "#3498db", "Non-UniProt" = "#5dade2", "Unknown" = "#94a3b8")

    plot_ly(
      labels = res$label,
      values = res$n,
      text = format(res$n, big.mark = ","),
      type = 'pie',
      hole = 0.55,
      sort = FALSE,
      marker = list(colors = unname(color_map[as.character(res$label)])),
      textinfo = 'label+percent',
      textposition = 'inside',
      hovertemplate = "<b>%{label}</b><br>Papers: %{text}<extra></extra>"
    ) %>%
      layout(
        showlegend = FALSE,
        margin = list(l = 10, r = 10, t = 10, b = 10)
      )
  })

  output$stat_type_plot <- renderPlotly({
    filters <- build_filter_query()
    query <- paste(
      "SELECT Autoregulatory_Type AS type, COUNT(*) as n",
      filters$where,
      "GROUP BY Autoregulatory_Type"
    )
    res <- if (length(filters$params) > 0) {
      dbGetQuery(conn, query, params = filters$params)
    } else {
      dbGetQuery(conn, query)
    }
    res <- res %>% filter(!is.na(type) & trimws(type) != "" & tolower(trimws(type)) != "non-autoregulatory")
    if (nrow(res) == 0) {
      res <- data.frame(type = character(0), n = numeric(0))
    }
    colnames(res) <- c("Type", "Count")
    type_counts <- res[order(res$Count, decreasing = TRUE), ]

    plot_ly(
      data = type_counts,
      x = ~Count,
      y = ~reorder(Type, Count),
      type = 'bar',
      orientation = 'h',
      marker = list(color = '#3498db'),
      text = ~format(Count, big.mark = ","),
      textposition = 'outside',
      hovertemplate = "<b>%{y}</b><br>Papers: %{text}<extra></extra>"
    ) %>%
      layout(
        yaxis = list(title = "", automargin = TRUE),
        xaxis = list(title = "Number of Papers"),
        margin = list(l = 180, r = 40, t = 10, b = 50)
      )
  })

  output$stat_year_plot <- renderPlotly({
    filters <- build_filter_query()
    query <- paste(
      "SELECT Year AS year, COUNT(*) as n",
      filters$where,
      "GROUP BY Year"
    )
    res <- if (length(filters$params) > 0) {
      dbGetQuery(conn, query, params = filters$params)
    } else {
      dbGetQuery(conn, query)
    }
    res <- res %>% filter(!is.na(year) & year != "Unknown")
    colnames(res) <- c("Year", "Count")
    year_counts <- res

    if (nrow(year_counts) > 0) {
      year_counts$Year <- suppressWarnings(as.numeric(as.character(year_counts$Year)))
      current_year <- as.numeric(format(Sys.Date(), "%Y"))
      year_counts <- year_counts %>%
        filter(!is.na(Year) & Year >= 1800 & Year <= current_year) %>%
        arrange(Year)

      if (nrow(year_counts) == 0) {
        plot_ly() %>%
          layout(
            annotations = list(
              text = "No year data available",
              showarrow = FALSE,
              xref = "paper",
              yref = "paper",
              x = 0.5,
              y = 0.5
            )
          )
      } else {
        max_count <- max(year_counts$Count)
        year_counts$Size <- if (max_count > 0) {
          10 + (sqrt(year_counts$Count) / sqrt(max_count)) * 30
        } else {
          10
        }

        plot_ly(
          data = year_counts,
          x = ~Year,
          y = 0,
          type = 'scatter',
          mode = 'markers',
          text = ~format(Count, big.mark = ","),
          marker = list(
            size = ~Size,
            color = ~Count,
            colorscale = list(c(0, "#ebf5fb"), c(1, "#3498db")),
            showscale = TRUE,
            line = list(color = "rgba(0, 0, 0, 0.15)", width = 1)
          ),
          hovertemplate = "<b>Year:</b> %{x}<br><b>Papers:</b> %{text}<extra></extra>"
        ) %>%
          layout(
            xaxis = list(title = "Publication Year", tickangle = -45),
            yaxis = list(title = "", showticklabels = FALSE, showgrid = FALSE, zeroline = FALSE),
            margin = list(l = 40, r = 20, t = 10, b = 80),
            showlegend = FALSE
          )
      }
    } else {
      plot_ly() %>%
        layout(
          annotations = list(
            text = "No year data available",
            showarrow = FALSE,
            xref = "paper",
            yref = "paper",
            x = 0.5,
            y = 0.5
          )
        )
    }
  })

  output$stat_journal_plot <- renderPlotly({
    filters <- build_filter_query()
    query <- paste(
      "SELECT Journal AS label, COUNT(*) as n",
      filters$where,
      "AND Journal IS NOT NULL AND trim(Journal) != ''",
      "GROUP BY Journal",
      "ORDER BY n DESC",
      "LIMIT 10"
    )
    res <- if (length(filters$params) > 0) {
      dbGetQuery(conn, query, params = filters$params)
    } else {
      dbGetQuery(conn, query)
    }
    if (nrow(res) == 0) {
      res <- data.frame(label = character(0), n = numeric(0))
    }
    res$label <- ifelse(is.na(res$label) | res$label == "", "Unknown", res$label)
    res <- res[order(res$n, decreasing = TRUE), ]

    plot_ly(
      data = res,
      x = ~n,
      y = ~reorder(label, n),
      type = 'bar',
      orientation = 'h',
      marker = list(color = '#4e7ac7'),
      text = ~format(n, big.mark = ","),
      textposition = 'outside',
      hovertemplate = "<b>%{y}</b><br>Papers: %{text}<extra></extra>"
    ) %>%
      layout(
        xaxis = list(title = "Number of Papers"),
        yaxis = list(title = "", automargin = TRUE),
        margin = list(l = 220, r = 40, t = 10, b = 50)
      )
  })

  # Model performance tables (static)
  output$model_stage1_table <- renderTable({
    data.frame(
      Metric = c("Accuracy", "Precision", "Recall", "F1 Score"),
      Score = c("96.0%", "97.8%", "90.0%", "93.8%")
    )
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", align = 'lc')

  output$model_stage2_overall_table <- renderTable({
    data.frame(
      Metric = c("Accuracy", "Macro Precision", "Macro Recall", "Macro F1",
                 "Weighted Precision", "Weighted Recall", "Weighted F1"),
      Value = c("95.5%", "94.6%", "98.1%", "96.2%", "95.9%", "95.5%", "95.5%")
    )
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", align = 'lc')

  output$model_stage2_perclass_table <- renderTable({
    data.frame(
      Mechanism = c("Autophosphorylation", "Autoregulation", "Autocatalytic",
                    "Autoinhibition", "Autoubiquitination", "Autolysis", "Autoinducer"),
      Precision = c("99.0%", "92.3%", "91.7%", "94.4%", "85.9%", "100.0%", "100.0%"),
      Recall = c("92.5%", "100.0%", "100.0%", "94.4%", "100.0%", "100.0%", "100.0%"),
      F1_Score = c("95.6%", "96.0%", "95.6%", "94.4%", "91.9%", "100.0%", "100.0%"),
      Support = c("107", "24", "22", "18", "17", "6", "6")
    )
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", align = 'lcccc')


output$result_table <- renderDT({
  data <- filtered_data()

  data <- data %>% select(
    AC, `Protein Name`, `Gene Name`, `Protein ID`, OS, PMID, Title, Abstract, Journal, Authors, Year, Month, Source,
    `Has Mechanism`, `Mechanism Probability`, `Autoregulatory Type`, `Type Confidence`
  )

  # Add row numbers as first column
  data <- data %>% mutate(`#` = row_number(), .before = 1)

  # Make PMID a clickable link to PubMed
  data$PMID <- ifelse(
    !is.na(data$PMID) & data$PMID != "",
    paste0('<a href="https://pubmed.ncbi.nlm.nih.gov/', data$PMID,
           '" target="_blank" style="color: #0366d6; text-decoration: none;">',
           data$PMID, '</a>'),
    data$PMID
  )

  # Make AC a clickable link to UniProt (first AC if multiple)
  data$AC <- ifelse(
    !is.na(data$AC) & data$AC != "",
    sapply(data$AC, function(ac) {
      first_ac <- trimws(strsplit(ac, ",")[[1]][1])
      full_ac <- safe_cell(ac, 30, "AC")
      paste0('<a href="https://www.uniprot.org/uniprotkb/', first_ac,
             '" target="_blank" style="color: #0366d6; text-decoration: none;">',
             full_ac, '</a>')
    }),
    safe_cell(data$AC, 30, "AC")
  )

  data$`Protein Name` <- safe_cell(data$`Protein Name`, 50, "Protein Name")
  data$`Gene Name` <- safe_cell(data$`Gene Name`, 30, "Gene Name")

  # Clean up Protein ID: hide "NA_####" entries (show blank instead)
  data$`Protein ID` <- ifelse(
    grepl("^NA_", data$`Protein ID`),
    "",  # Show blank for NA_#### entries
    safe_cell(data$`Protein ID`, 25, "Protein ID")
  )

  data$OS <- safe_cell(data$OS, 40, "OS")
  data$Title <- safe_cell(data$Title, 50, "Title")
  data$Abstract <- safe_cell(data$Abstract, 50, "Abstract")
  data$Journal <- safe_cell(data$Journal, 40, "Journal")
  data$Authors <- safe_cell(data$Authors, 50, "Authors")

  getOntologyDetails <- function(type) {
    if (is.na(type) || type == "non-autoregulatory" || trimws(type) == "") {
      return("Not classified as autoregulatory")
    }
    raw  <- trimws(type)
    norm <- gsub("[^A-Za-z]", "", raw)
    norm <- paste0(toupper(substr(norm,1,1)), tolower(substr(norm,2,nchar(norm))))
    mapped <- if (norm %in% names(ontology_key_map)) ontology_key_map[[norm]] else NA_character_
    key    <- if (!is.na(mapped)) mapped else norm
    info <- ontology_info[[key]]
    if (is.null(info)) return(paste0("Ontology information not found for: ", htmltools::htmlEscape(raw)))
    path <- get_ontology_path(key)
    paste0(
      "<b>Ontology Path</b><br>", htmltools::htmlEscape(path), "<br><br>",
      "<b>Definition</b><br>", htmltools::htmlEscape(info$Definition), "<br><br>",
      "<b>Synonym:</b> ", htmltools::htmlEscape(info$Synonym), "<br><br>",
      "<b>Antonym:</b> ", htmltools::htmlEscape(info$Antonym), "<br><br>",
      "<b>Related:</b> ", htmltools::htmlEscape(info$Related)
    )
  }

  type_values <- data$`Autoregulatory Type`
  safe_types <- vapply(type_values, function(val) {
    if (is.na(val)) return("")
    htmltools::htmlEscape(val)
  }, character(1))

  data$`Autoregulatory Type` <- ifelse(
    is.na(type_values) | type_values == "non-autoregulatory",
    safe_types,
    paste0(
      safe_types,
      ' <button class="btn btn-link btn-sm view-btn" data-field="Autoregulatory Type" data-text="',
      htmltools::htmlEscape(vapply(type_values, getOntologyDetails, character(1))),
      '"><span style="font-size:14px;">🔍</span></button>'
    )
  )

  datatable(
    data,
    escape = FALSE,
    rownames = FALSE,  # Disable built-in row numbers (we have our own # column)
    options = list(
      pageLength = page_size(),  # Show all loaded rows for current page size
      lengthMenu = PAGE_SIZE_OPTIONS,  # Allow selectable page sizes
      scrollX = TRUE,
      dom = 't',  # Only show table (no info text at bottom)
      order = list(),
      columnDefs = list(
        list(targets = 0, orderable = FALSE, width = "40px", className = "dt-center"),  # Row number column
        list(targets = "_all", orderSequence = c("asc","desc",""))
      ),
      # Server-side processing: only load current page, not all rows
      serverSide = FALSE,  # Keep as FALSE since we're already filtering with SQL
      deferRender = TRUE,
      scroller = FALSE
    ),
    callback = JS("
      table.on('click', '.view-btn', function() {
        var text = $(this).data('text');
        var field = $(this).data('field');
        Shiny.setInputValue('show_full_text', { field: field, text: text }, {priority: 'event'});
      });
    ")
  )
})



  # Patch Notes Table Data
  patch_notes_data <- data.frame(
    Version = c("0.0.1", "0.0.2", "0.0.3", "0.0.4", "0.0.5", "0.0.6", "0.0.7", "0.0.8", "0.0.9", "0.0.10"),
    Description = c(
      paste(
        "<ul>",
        "<li>Shiny App Prototype</li>",
        "</ul>"
      ),
      paste(
        "<ul>",
        "<li>App Nickname & Logo</li>",
        "<li>Search Functionality Enhancement</li>",
        "<li>UI Cleanup</li>",
        "<li>Paper Source</li>",
        "<li>Protein Accession Handling</li>",
        "<li>Additional Tabs</li>",
        "</ul>"
      ),
      paste(
        "<ul>",
        "<li>New columns: Polarity score & Autoregulatory term probability</li>",
        "<li>Added placeholder content to Statistics tab</li>",
        "</ul>"
      ),
      paste(
        "<ul>",
        "<li>Replaced placeholder data with sample data</li>",
        "<li>Added expand button to Autoregulatory Type for full ontology view</li>",
        "<li>Statistics Tab: Label distribution (positive / negative / neutral)</li>",
        "<li>Statistics Tab: Feature frequency (Journal, Species, Data Source, Year)</li>",
        "<li>Statistics Tab: Model evaluation metrics (e.g., accuracy, F1-score)</li>",
        "</ul>"
      ),
      paste(
        "<ul>",
        "<li>Updated app logo</li>",
        "<li>Statistics Tab: Added Proportion (%) display in hover tooltips for frequency plots</li>",
        "<li>Statistics Tab: Updated evaluation metrics</li>",
        "</ul>"
      ),
      paste(
        "<ul>",
        "<li>Statistics Tab: Updated Species Frequency plot to show Top 9 species</li>",
        "<li>Statistics Tab: Added Dot Plot (Species vs Autoregulatory Type)</li>",
        "</ul>"
      ),
      paste(
        "<ul>",
        "<li>Ontology Tab: Added new Ontology tab with structured tree and detailed descriptions</li>",
        "<li>Enhanced ontology pop-up content in Search tab (definitions, synonyms, antonyms, related terms)</li>",
        "<li>Hid OntologyFullText column in final search table to keep interface clean</li>",
        "<li>Improved overall UI and typography for Ontology content</li>",
        "</ul>"
      ),
      paste(
        "<ul>",
        "<li>Major update aligned with the SOORENA preprint (bioRxiv, November 2025)</li>",
        "<li>Integrated 252,880 model-inferred PubMed abstracts into searchable database</li>",
        "<li>Removed Polarity and Polarity Score columns</li>",
        "<li>Updated column schema: Has Mechanism, Mechanism Probability, Autoregulatory Type, Type Confidence</li>",
        "<li>Improved table UX: sortable columns, truncation with magnifier pop-up modal, CSV export</li>",
        "<li>Updated Ontology tab with hierarchical mechanism tree and detailed definition pages for all seven mechanism classes</li>",
        "<li>Ontology pop-ups now show standardized definitions, relations, and references</li>",
        "<li>Removed old Statistics tab and placeholders</li>",
        "</ul>"
      ),
      paste(
        "<ul>",
        "<li>New Publication Year and Publication Month filter dropdowns</li>",
        "<li>Table now displays Year, and Month for all papers</li>",
        "<li>Existing data labeled with 'No Date' / 'Unknown' until new data is added</li>",
        "</ul>"
      ),
      paste(
        "<ul>",
        "<li>Data refresh: loaded ~3.37M predictions into SQLite for full searchability</li>",
        "<li>Pagination: added rows-per-page selector (25/50/100/500) wired to SQL LIMIT/OFFSET and DataTable page length</li>",
        "<li>Pagination messaging: page status now clamps to available pages; removed table info banner</li>",
        "<li>UI layout: consolidated pagination controls with Download CSV aligned on the right for cleaner toolbar</li>",
        "</ul>"
      )
    ),
    Date = c("2025-05-29", "2025-06-01", "2025-06-04", "2025-06-19", "2025-06-24", "2025-07-02", "2025-07-10", "2025-11-04", "2025-12-07", "2025-12-08"),
    stringsAsFactors = FALSE
  )

  # Render Patch Notes Table
  output$patch_notes_table <- DT::renderDataTable({
    DT::datatable(
      patch_notes_data,
      options = list(
        pageLength = 10,
        autoWidth = TRUE
      ),
      escape = FALSE,   # <-- allow HTML rendering
      rownames = FALSE
    )
  })

  # Cleanup: Disconnect database when app stops
  session$onSessionEnded(function() {
    if (dbIsValid(conn)) dbDisconnect(conn)
    cat("Database connection closed\n")
  })
}

# Run App
shinyApp(ui, server)
