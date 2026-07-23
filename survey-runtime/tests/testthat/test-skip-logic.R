# Skip-logic evaluation across the supported condition forms.

test_that("string conditions evaluate against responses", {
  responses <- list(age = 20, county = "Turkana")
  expect_true(nf_skip_logic("age >= 18", responses))
  expect_false(nf_skip_logic("age < 18", responses))
  expect_true(nf_skip_logic("county == 'Turkana'", responses))
})

test_that("function conditions are supported", {
  expect_true(nf_skip_logic(function(r) r$x > 0, list(x = 5)))
  expect_false(nf_skip_logic(function(r) r$x > 0, list(x = -1)))
})

test_that("logical conditions pass through", {
  expect_true(nf_skip_logic(TRUE, list()))
  expect_false(nf_skip_logic(FALSE, list()))
})

test_that("evaluation errors return the default instead of crashing", {
  # The function warns and falls back to `default`; the warning is expected.
  expect_true(suppressWarnings(nf_skip_logic("undefined_var > 1", list(), default = TRUE)))
  expect_false(suppressWarnings(nf_skip_logic("undefined_var > 1", list(), default = FALSE)))
})

test_that("show_if_equals builds a predicate over responses", {
  rule <- nf_show_if_equals("q1", "yes")
  expect_true(is.function(rule))
  expect_true(rule(list(q1 = "yes")))
  expect_false(rule(list(q1 = "no")))
  expect_false(rule(list()))
})

test_that("show_if_in matches membership", {
  rule <- nf_show_if_in("county", c("Turkana", "Marsabit"))
  expect_true(rule(list(county = "Turkana")))
  expect_false(rule(list(county = "Nairobi")))
})

test_that("nf_condition_to_js transpiles conditions to JS lookups", {
  expect_equal(nf_condition_to_js("age >= 18"),
               "nfNum(nfGetValue('age')) >= 18")
  expect_equal(nf_condition_to_js("county == 'Turkana'"),
               "nfGetValue('county') == 'Turkana'")
  expect_match(nf_condition_to_js("a > 1 && b == 'x'"), "&&")
})

test_that("nf_skip_logic_js embeds the transpiled show condition", {
  js <- nf_skip_logic_js("q_notes", list(show_if = "children_u5 > 0"))
  expect_match(js, "nfNum\\(nfGetValue\\('children_u5'\\)\\) > 0")
  expect_match(js, "updateVisibility_q_notes")
})

test_that("nf_skip_logic_js inverts a hide_if condition", {
  js <- nf_skip_logic_js("q1", list(hide_if = "x == 'no'"))
  expect_match(js, "!\\(nfGetValue\\('x'\\) == 'no'\\)")
})

test_that("unsupported skip_rule shapes error clearly", {
  expect_error(nf_skip_logic_js("q1", list(foo = "bar")), "Unsupported skip_rule")
})
