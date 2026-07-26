# Codebook import. Guards two bugs that made REDCap import unusable:
#   1. read.csv(na.strings=) turns empty cells into NA, and nchar(NA_character_)
#      is NA_integer_, so the guards in the parsers errored inside `if`.
#      An empty validation or branching column is the common case, not an edge
#      case, so this crashed on most real dictionaries.
#   2. auto_generate emitted calls to nf_text_input()/nf_select_input()/... ,
#      none of which this package exports. The generated script never ran.

redcap_fixture <- function() {
  path <- tempfile(fileext = ".csv")
  writeLines(c(
    paste0('"Variable / Field Name","Form Name","Field Type","Field Label",',
           '"Choices, Calculations, OR Slider Labels",',
           '"Text Validation Type OR Show Slider Number","Required Field?",',
           '"Branching Logic (Show field only if...)"'),
    '"hh_name","demog","text","Household head name","","","y",""',
    '"county","demog","dropdown","County","1, Turkana | 2, Marsabit","","y",""',
    '"n_children","demog","text","Number of children","","integer","n",""',
    '"consent_doc","demog","file","Consent form","","","n","[county] = \'1\'"'
  ), path)
  path
}

test_that("a dictionary with empty validation and branching cells imports", {
  path <- redcap_fixture()
  on.exit(unlink(path), add = TRUE)

  questions <- expect_no_error(nf_import_redcap(path))
  expect_named(questions, c("hh_name", "county", "n_children", "consent_doc"))
})

test_that("REDCap field types map onto question types", {
  path <- redcap_fixture()
  on.exit(unlink(path), add = TRUE)

  questions <- nf_import_redcap(path)
  expect_equal(questions$hh_name$type, "text")
  expect_equal(questions$county$type, "select")
})

test_that("required flags and choices are parsed", {
  path <- redcap_fixture()
  on.exit(unlink(path), add = TRUE)

  questions <- nf_import_redcap(path)
  expect_true(questions$hh_name$required)
  expect_false(questions$n_children$required)
  expect_equal(unname(questions$county$choices), c("1", "2"))
  expect_equal(names(questions$county$choices), c("Turkana", "Marsabit"))
})

test_that("branching logic is only attached where present", {
  path <- redcap_fixture()
  on.exit(unlink(path), add = TRUE)

  questions <- nf_import_redcap(path)
  expect_null(questions$hh_name$skip_logic)
  expect_false(is.null(questions$consent_doc$skip_logic))
})

test_that("generated code calls nf_question and parses as R", {
  path <- redcap_fixture()
  on.exit(unlink(path), add = TRUE)

  questions <- nf_import_redcap(path)
  code <- utils::capture.output(generated <- nomadforms:::generate_ui_code(questions))

  emitted <- generated[!grepl("^#", generated)]
  expect_true(all(grepl("^nf_question\\(", emitted)))
  # The whole block must be syntactically valid R, not just look like it.
  expect_no_error(parse(text = paste(emitted, collapse = "\n")))
})

test_that("field types nf_question cannot represent become comments, not calls", {
  path <- redcap_fixture()
  on.exit(unlink(path), add = TRUE)

  questions <- nf_import_redcap(path)
  invisible(utils::capture.output(generated <- nomadforms:::generate_ui_code(questions)))

  file_entry <- grep("consent_doc", generated, value = TRUE)
  expect_length(file_entry, 1)
  expect_match(file_entry, "^#")
})

test_that("generic CSV import handles blank required cells", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  writeLines(c(
    "field_name,field_type,field_label,choices,required",
    "age,numeric,Age in years,,yes",
    "water,radio,Main water source,Piped|Borehole|River,"
  ), path)

  questions <- nf_import_csv(path)
  expect_true(questions$age$required)
  expect_false(questions$water$required)
  expect_equal(questions$water$choices, c("Piped", "Borehole", "River"))
})
