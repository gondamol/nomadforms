# Guards the reserved-word parse bug (rules$`in`) that once stopped this whole
# file from loading, plus the core validation rules.

test_that("required fields are enforced", {
  expect_false(nf_validate("", rules = list(required = TRUE))$valid)
  expect_true(nf_validate("x", rules = list(required = TRUE))$valid)
})

test_that("empty optional values pass without further checks", {
  res <- nf_validate("", rules = list(min = 5))
  expect_true(res$valid)
})

test_that("in-list rule accepts members and rejects non-members", {
  rules <- list(`in` = c("apple", "mango"))
  expect_true(nf_validate("apple", rules = rules)$valid)
  bad <- nf_validate("banana", rules = rules)
  expect_false(bad$valid)
  expect_match(bad$errors[[1]], "must be one of")
})

test_that("not_in rule rejects listed values", {
  expect_false(nf_validate("x", rules = list(not_in = c("x", "y")))$valid)
  expect_true(nf_validate("z", rules = list(not_in = c("x", "y")))$valid)
})

test_that("numeric range is enforced", {
  expect_false(nf_validate(3, rules = list(min = 5))$valid)
  expect_true(nf_validate(7, rules = list(min = 5, max = 10))$valid)
  expect_false(nf_validate(11, rules = list(max = 10))$valid)
})

test_that("pattern (regex) rule is enforced", {
  rules <- list(pattern = "^[0-9]{3}$")
  expect_true(nf_validate("123", rules = rules)$valid)
  expect_false(nf_validate("12a", rules = rules)$valid)
})
