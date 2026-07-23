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
