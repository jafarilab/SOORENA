df <- read.csv('data/predictions_for_app.csv', stringsAsFactors = FALSE)
colnames(df) <- gsub("\\.", " ", colnames(df))
cat(paste('Total rows loaded:', nrow(df), '\n\n'))

cat('Before transformation:\n')
print(table(df$`Autoregulatory Type`, useNA='always'))
cat('\n')

# Apply the transformation
df$`Autoregulatory Type` <- ifelse(
  is.na(df$`Autoregulatory Type`) |
    trimws(df$`Autoregulatory Type`) == '' |
    tolower(trimws(df$`Autoregulatory Type`)) == 'none',
  'non-autoregulatory',
  df$`Autoregulatory Type`
)

cat('After transformation:\n')
print(table(df$`Autoregulatory Type`, useNA='always'))
cat('\n')

cat('Has Mechanism distribution:\n')
print(table(df$`Has Mechanism`, useNA='always'))
