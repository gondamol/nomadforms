# NomadForms Survey Runtime

Core R package for creating and running surveys with NomadForms.

## Installation

```r
# From source
devtools::install()
```

## Quick Start

### 1. Create a Survey (Quarto)

Create a `survey.qmd` file:

```markdown
---
title: "My Survey"
format: html
server: shiny
---

# Demographics

```{r}
library(nomadforms)

nf_question("name", "text", "What is your name?", required = TRUE)
nf_question("age", "numeric", "How old are you?", min = 0, max = 120)
```
``

### 2. Set Up Database

```r
library(nomadforms)

# Connect to database
conn <- nf_database(
  dbname = "nomadforms",
  user = "postgres",
  password = "your_password"
)

# Initialize schema
nf_init_schema(conn)
```

### 3. Run Survey

```bash
quarto preview survey.qmd
```

## Question Types

- `text`: Text input
- `numeric`: Number input with optional min/max
- `radio`: Radio buttons (single choice)
- `checkbox`: Checkboxes (multiple choice)
- `select`: Dropdown menu
- `date`: Date picker
- `slider`: Slider for numeric values

## Features

- **Database Integration**: PostgreSQL/Supabase support
- **Validation**: Required fields, min/max, type checking
- **Session Management**: Track survey progress
- **Audit Trail**: Log all data changes

## Dependencies

- R >= 4.0.0
- shiny >= 1.7.0
- quarto >= 1.3
- DBI
- RPostgres

## License

MIT

