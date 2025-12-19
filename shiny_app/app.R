library(shiny)       # for building the interactive web app
library(DT)          # for rendering interactive data tables
library(dplyr)       # for data manipulation
library(readr)       # for reading CSV files
library(shinyjs)     # for JavaScript integration (e.g., toggle dark mode)
library(htmltools)   # for safe HTML rendering
library(plotly)      # Creates interactive, dynamic, and web-friendly plots from ggplot or standalone
library(ggplot2)
library(shinycssloaders) # for loading spinners

# Load CSV Data
# PERFORMANCE OPTIMIZATION: Load only subset to prevent browser freeze
# Full dataset has 3.38M rows which will freeze browser
# Loading first 100K rows for smooth performance
INITIAL_LOAD_LIMIT <- 100000

cat("Loading data with performance optimization...\n")
cat(paste("Initial load limit:", format(INITIAL_LOAD_LIMIT, big.mark=","), "rows\n"))

preview_df <- read.csv("data/predictions_for_app.csv",
                       stringsAsFactors = FALSE,
                       nrows = INITIAL_LOAD_LIMIT)
colnames(preview_df) <- gsub("\\.", " ", colnames(preview_df))

cat(paste("Loaded:", format(nrow(preview_df), big.mark=","), "rows successfully\n"))



# Ensure required columns exist; fill missing ones with NA
required_cols <- c(
  # Unique ID
  "Protein ID",

  # Protein metadata
  "AC",
  "Protein Name",
  "Gene Name",
  "OS",

  # Publication metadata
  "PMID",
  "Title",
  "Abstract",
  "Journal",
  "Authors",
  "Year",
  "Month",
  "Source",

  # Mechanism info
  "Has Mechanism",
  "Mechanism Probability",
  "Autoregulatory Type",
  "Type Confidence"
)

for (col in required_cols) {
  if (!(col %in% colnames(preview_df))) {
    preview_df[[col]] <- NA
  }
}

# Final data frame to be used
df <- preview_df[, required_cols]

# Convert probability/confidence to percent strings
num_or_na <- function(x) suppressWarnings(as.numeric(x))
safe_percent_column <- function(x) {
  num <- num_or_na(x)
  ifelse(!is.na(num), paste0(round(num * 100, 2), "%"), NA)
}
df$`Mechanism Probability` <- safe_percent_column(df$`Mechanism Probability`)
df$`Type Confidence`      <- safe_percent_column(df$`Type Confidence`)


# replace Autoregulatory Type 'NA' and 'none' values with 'non-autoregulatory'
df$`Autoregulatory Type` <- ifelse(
  is.na(df$`Autoregulatory Type`) |
    trimws(df$`Autoregulatory Type`) == "" |
    tolower(trimws(df$`Autoregulatory Type`)) == "none",
  "non-autoregulatory",
  df$`Autoregulatory Type`
)

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
          #stat_total_papers {
            font-size: 32px;
            font-weight: bold;
            color: #2c3e50;
            text-align: center;
            padding: 20px;
            background-color: #ecf0f1;
            border-radius: 8px;
            margin-top: 10px;
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
          column(3, selectInput("os", "OS",
                                choices = c("All", sort(unique(na.omit(df$OS)))),
                                multiple = TRUE))
        ),
        fluidRow(
          column(3, textInput("pmid", "PMID", placeholder = "Search PMID...")),
          column(3, textInput("author", "Author", placeholder = "Search author...")),
          column(3, selectInput("journal", "Journal",
                                choices = c("All", sort(unique(na.omit(df$Journal)))),
                                multiple = TRUE)),
          column(3, selectInput("source", "Data Source", choices = c("All", "UniProt", "Non-UniProt")))
        ),
        fluidRow(
          column(3, selectInput("type", "Autoregulatory Type",
                                choices = c("All", sort(unique(na.omit(df$`Autoregulatory Type`)))),
                                multiple = TRUE)),
          column(3, selectInput("year", "Publication Year",
                                choices = c("All", sort(unique(na.omit(df$Year)), decreasing = TRUE)),
                                multiple = TRUE)),
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
        
        # Download Button
        div(style = "margin: 0 30px;",
            downloadButton("download_csv", "Download CSV", class = "btn-primary mb-3")
        ),
        
        # Display Table with loading spinner
        div(style = "margin: 0 30px 20px 30px;",
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
      div(class = "filter-panel", style = "margin: 30px;",
        h2("Current Dataset Statistics"),
        p("Statistics based on currently displayed/filtered data", style = "color: #7f8c8d; margin-bottom: 25px;"),
        fluidRow(
          column(4,
            h4("Total Papers"),
            verbatimTextOutput("stat_total_papers", placeholder = TRUE)
          ),
          column(4,
            h4("Mechanism Distribution"),
            withSpinner(plotlyOutput("stat_mechanism_plot", height = "300px"), type = 6, color = "#2c3e50")
          ),
          column(4,
            h4("Source Distribution"),
            withSpinner(plotlyOutput("stat_source_plot", height = "300px"), type = 6, color = "#2c3e50")
          )
        ),
        hr(),
        fluidRow(
          column(6,
            h4("Autoregulatory Types"),
            withSpinner(plotlyOutput("stat_type_plot", height = "400px"), type = 6, color = "#2c3e50")
          ),
          column(6,
            h4("Publication Year Distribution"),
            withSpinner(plotlyOutput("stat_year_plot", height = "400px"), type = 6, color = "#2c3e50")
          )
        )
      ),

      # Model Performance Section
      div(class = "filter-panel", style = "margin: 30px;",
        h2("Model Training Performance"),
        p("Performance metrics from the published SOORENA study", style = "color: #7f8c8d; margin-bottom: 25px;"),

        # Stage 1 Performance
        h3("Stage 1: Binary Classification (n = 600 test samples)"),
        fluidRow(
          column(12,
            tableOutput("model_stage1_table")
          )
        ),

        hr(),

        # Stage 2 Overall Performance
        h3("Stage 2: Multi-class Classification - Overall Performance"),
        fluidRow(
          column(12,
            tableOutput("model_stage2_overall_table")
          )
        ),

        hr(),

        # Stage 2 Per-class Performance
        h3("Stage 2: Per-class Performance"),
        fluidRow(
          column(12,
            tableOutput("model_stage2_perclass_table")
          )
        ),

        br(),
        p("Source: bioRxiv preprint doi: https://doi.org/10.1101/2025.11.03.685842",
          style = "font-style: italic; color: #666; margin-top: 20px;")
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
      h2("Project Contributors"),
      tags$ul(
        tags$li("Alexandra Zhou – University of British Columbia"),
        tags$li("Hala Arar – University of British Columbia"),
        tags$li("Mingyang Zhang – University of British Columbia"),
        tags$li("Zheng He – University of British Columbia")
      ),
      h2("Mentor & Partner"),
      tags$ul(
        tags$li("Mohieddin Jafari – University of Helsinki (Partner)"), 
        tags$li("Payman Nickchi – University of British Columbia (Mentor)")
      )
    )
  ),
)


# Define Server Logic
server <- function(input, output, session) {


  # Download csv button
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("filtered_results_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(filtered_data(), file, row.names = FALSE)
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
  
  # Filtering Logic
  filtered_data <- reactive({
    result <- df
    print(paste("Initial rows:", nrow(result)))
    
    # Journal filter
    if (!is.null(input$journal) && !"All" %in% input$journal && length(input$journal) > 0) {
      result <- result %>% filter(Journal %in% input$journal)
    }
    print(paste("Rows after Journal filter:", nrow(result)))
    
    # Type filter
    if (!is.null(input$type) && !"All" %in% input$type && length(input$type) > 0) {
      result <- result %>% filter(`Autoregulatory Type` %in% input$type)
    }
    print(paste("Rows after Type filter:", nrow(result)))
    

    
    # OS filter
    if (!is.null(input$os) && !"All" %in% input$os && length(input$os) > 0) {
      result <- result %>% filter(OS %in% input$os)
    }
    print(paste("Rows after OS filter:", nrow(result)))
    
    
    # AC search
    if (!is.null(input$ac) && nzchar(input$ac)) {
      terms <- trimws(unlist(strsplit(input$ac, ",")))
      pattern <- paste0("\\b(", paste(terms, collapse = "|"), ")\\b")
      result <- result %>% filter(grepl(pattern, AC, ignore.case = TRUE))
    }
    print(paste("Rows after AC search:", nrow(result)))
  
    # Protein ID search
    if (!is.null(input$protein_id) && nzchar(input$protein_id)) {
      terms <- trimws(unlist(strsplit(input$protein_id, ",")))
      pattern <- paste0("\\b(", paste(terms, collapse = "|"), ")\\b")
      result <- result %>% filter(grepl(pattern, `Protein ID`, ignore.case = TRUE))
    }
  print(paste("Rows after Protein ID search:", nrow(result)))

    # PMID search
    if (!is.null(input$pmid) && nzchar(input$pmid)) {
      terms <- trimws(unlist(strsplit(input$pmid, ",")))
      pattern <- paste0("\\b(", paste(terms, collapse = "|"), ")\\b")
      result <- result %>% filter(grepl(pattern, PMID, ignore.case = TRUE))
    }
    print(paste("Rows after PMID search:", nrow(result)))
    
    # Author search
    if (!is.null(input$author) && nzchar(input$author)) {
      terms <- trimws(unlist(strsplit(input$author, ",")))
      pattern <- paste0("\\b(", paste(terms, collapse = "|"), ")\\b")
      result <- result %>% filter(grepl(pattern, Authors, ignore.case = TRUE))
    }
    print(paste("Rows after Author search:", nrow(result)))

    # Has Mechanism filter
    if (!is.null(input$has_mechanism) && input$has_mechanism != "All") {
      result <- result %>% filter(`Has Mechanism` == input$has_mechanism)
    }
    print(paste("Rows after Has Mechanism filter:", nrow(result)))

    # Source filter
    if (!is.null(input$source) && input$source != "All") {
      result <- result %>% filter(Source == input$source)
    }
    print(paste("Rows after Source filter:", nrow(result)))

    # Year filter
    if (!is.null(input$year) && !"All" %in% input$year && length(input$year) > 0) {
      result <- result %>% filter(Year %in% input$year)
    }
    print(paste("Rows after Year filter:", nrow(result)))

    # Month filter
    if (!is.null(input$month) && !"All" %in% input$month && length(input$month) > 0) {
      result <- result %>% filter(Month %in% input$month)
    }
    print(paste("Rows after Month filter:", nrow(result)))

    # Title / Abstract search
    if (!is.null(input$search) && nzchar(input$search)) {
      terms <- trimws(unlist(strsplit(input$search, ",")))
      pattern <- paste(terms, collapse = "|")
      result <- result %>%
        filter(grepl(pattern, Title, ignore.case = TRUE) |
                 grepl(pattern, Abstract, ignore.case = TRUE))
    }
    print(paste("Rows after Title/Abstract search:", nrow(result)))
    
    return(result)
  })

  # Statistics tab outputs
  # Dataset statistics (reactive based on filtered data)
  output$stat_total_papers <- renderText({
    data <- filtered_data()
    format(nrow(data), big.mark = ",")
  })

  output$stat_mechanism_plot <- renderPlotly({
    data <- filtered_data()
    counts <- table(data$`Has Mechanism`)
    plot_ly(
      labels = names(counts),
      values = as.vector(counts),
      type = 'pie',
      marker = list(colors = c('#ff6b6b', '#4ecdc4')),
      textinfo = 'label+percent',
      textposition = 'inside'
    ) %>%
      layout(
        showlegend = TRUE,
        margin = list(l = 10, r = 10, t = 10, b = 10)
      )
  })

  output$stat_source_plot <- renderPlotly({
    data <- filtered_data()
    counts <- table(data$Source)
    plot_ly(
      labels = names(counts),
      values = as.vector(counts),
      type = 'pie',
      marker = list(colors = c('#95e1d3', '#f38181')),
      textinfo = 'label+percent',
      textposition = 'inside'
    ) %>%
      layout(
        showlegend = TRUE,
        margin = list(l = 10, r = 10, t = 10, b = 10)
      )
  })

  output$stat_type_plot <- renderPlotly({
    data <- filtered_data()
    # Filter out non-autoregulatory entries
    data <- data %>% filter(`Autoregulatory Type` != "non-autoregulatory")
    type_counts <- as.data.frame(table(data$`Autoregulatory Type`))
    colnames(type_counts) <- c("Type", "Count")
    type_counts <- type_counts[order(type_counts$Count, decreasing = TRUE), ]

    plot_ly(
      data = type_counts,
      x = ~Count,
      y = ~reorder(Type, Count),
      type = 'bar',
      orientation = 'h',
      marker = list(color = '#667eea'),
      text = ~Count,
      textposition = 'outside'
    ) %>%
      layout(
        yaxis = list(title = ""),
        xaxis = list(title = "Number of Papers"),
        margin = list(l = 200, r = 50, t = 20, b = 50)
      )
  })

  output$stat_year_plot <- renderPlotly({
    data <- filtered_data()
    year_counts <- as.data.frame(table(data$Year))
    colnames(year_counts) <- c("Year", "Count")
    year_counts <- year_counts[year_counts$Year != "Unknown", ]

    if (nrow(year_counts) > 0) {
      year_counts$Year <- as.numeric(as.character(year_counts$Year))
      year_counts <- year_counts[order(year_counts$Year), ]

      plot_ly(
        data = year_counts,
        x = ~Year,
        y = ~Count,
        type = 'scatter',
        mode = 'lines+markers',
        marker = list(color = '#764ba2', size = 8),
        line = list(color = '#764ba2', width = 3),
        hovertemplate = paste('<b>Year:</b> %{x}<br>',
                            '<b>Papers:</b> %{y}<br>',
                            '<extra></extra>')
      ) %>%
        layout(
          xaxis = list(title = "Publication Year"),
          yaxis = list(title = "Number of Papers"),
          margin = list(l = 60, r = 30, t = 20, b = 50)
        )
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

  data$AC <- ifelse(!is.na(data$AC) & nchar(data$AC) > 30,
    paste0(substr(data$AC, 1, 30),
           '... <button class="btn btn-link btn-sm view-btn" data-field="AC" data-text="',
           htmltools::htmlEscape(data$AC),'">🔍</button>'),
    data$AC
  )

  data$`Protein Name` <- ifelse(!is.na(data$`Protein Name`) & nchar(data$`Protein Name`) > 50,
    paste0(substr(data$`Protein Name`, 1, 50),
           '... <button class="btn btn-link btn-sm view-btn" data-field="Protein Name" data-text="',
           htmltools::htmlEscape(data$`Protein Name`),'">🔍</button>'),
    data$`Protein Name`
  )

  data$`Gene Name` <- ifelse(!is.na(data$`Gene Name`) & nchar(data$`Gene Name`) > 30,
    paste0(substr(data$`Gene Name`, 1, 30),
           '... <button class="btn btn-link btn-sm view-btn" data-field="Gene Name" data-text="',
           htmltools::htmlEscape(data$`Gene Name`),'">🔍</button>'),
    data$`Gene Name`
  )

  data$`Protein ID` <- ifelse(!is.na(data$`Protein ID`) & nchar(data$`Protein ID`) > 25,
    paste0(substr(data$`Protein ID`, 1, 25),
           '... <button class="btn btn-link btn-sm view-btn" data-field="Protein ID" data-text="',
           htmltools::htmlEscape(data$`Protein ID`),'">🔍</button>'),
    data$`Protein ID`
  )

  data$OS <- ifelse(!is.na(data$OS) & nchar(data$OS) > 40,
    paste0(substr(data$OS, 1, 40),
           '... <button class="btn btn-link btn-sm view-btn" data-field="OS" data-text="',
           htmltools::htmlEscape(data$OS),'">🔍</button>'),
    data$OS
  )

  data$Title <- ifelse(!is.na(data$Title) & nchar(data$Title) > 50,
    paste0(substr(data$Title, 1, 50),
           '... <button class="btn btn-link btn-sm view-btn" data-field="Title" data-text="',
           htmltools::htmlEscape(data$Title),'">🔍</button>'),
    data$Title
  )

  data$Abstract <- ifelse(!is.na(data$Abstract) & nchar(data$Abstract) > 50,
    paste0(substr(data$Abstract, 1, 50),
           '... <button class="btn btn-link btn-sm view-btn" data-field="Abstract" data-text="',
           htmltools::htmlEscape(data$Abstract),'">🔍</button>'),
    data$Abstract
  )

  data$Journal <- ifelse(!is.na(data$Journal) & nchar(data$Journal) > 40,
    paste0(substr(data$Journal, 1, 40),
           '... <button class="btn btn-link btn-sm view-btn" data-field="Journal" data-text="',
           htmltools::htmlEscape(data$Journal),'">🔍</button>'),
    data$Journal
  )

  data$Authors <- ifelse(!is.na(data$Authors) & nchar(data$Authors) > 50,
    paste0(substr(data$Authors, 1, 50),
           '... <button class="btn btn-link btn-sm view-btn" data-field="Authors" data-text="',
           htmltools::htmlEscape(data$Authors),'">🔍</button>'),
    data$Authors
  )

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

  data$`Autoregulatory Type` <- ifelse(
    is.na(data$`Autoregulatory Type`) | data$`Autoregulatory Type` == "non-autoregulatory",
    data$`Autoregulatory Type`,
    paste0(
      data$`Autoregulatory Type`,
      ' <button class="btn btn-link btn-sm view-btn" data-field="Autoregulatory Type" data-text="',
      htmltools::htmlEscape(vapply(data$`Autoregulatory Type`, getOntologyDetails, character(1))),
      '"><span style="font-size:14px;">🔍</span></button>'
    )
  )

  datatable(
    data,
    escape = FALSE,
    options = list(
      pageLength = 10,
      lengthMenu = c(10, 25, 50, 100),
      scrollX = TRUE,
      dom = 'tip',
      order = list(),
      columnDefs = list(list(targets = "_all", orderSequence = c("asc","desc",""))),
      # Performance optimization: deferred rendering for large datasets
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
    Version = c("0.0.1", "0.0.2", "0.0.3", "0.0.4", "0.0.5", "0.0.6", "0.0.7", "0.0.8", "0.0.9"),
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
        "<li>Added PublicationDate support: Year and Month columns now available</li>",
        "<li>New Publication Year and Publication Month filter dropdowns</li>",
        "<li>Table now displays PublicationDate, Year, and Month for all papers</li>",
        "<li>Existing data labeled with 'No Date' / 'Unknown' until new data is added</li>",
        "<li>Created reusable prediction pipeline (predict_new_data.py) for processing new PubMed data</li>",
        "<li>Updated environment dependencies with python-dateutil for robust date parsing</li>",
        "<li>Infrastructure ready to handle millions of new predictions with date metadata</li>",
        "</ul>"
      )
    ),
    Date = c("2025-05-29", "2025-06-01", "2025-06-04", "2025-06-19", "2025-06-24", "2025-07-02", "2025-07-10", "2025-11-04", "2025-12-07"),
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
  
}

# Run App
shinyApp(ui, server)
