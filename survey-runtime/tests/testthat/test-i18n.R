# Guards the reserved-word parse bug (`next` key) and the silent-passthrough
# bug where translations were never registered on load.

test_that("default translations are registered on package load", {
  # .onLoad should have populated these without an explicit init call.
  expect_equal(nf_t("common.buttons.next", lang = "en"), "Next")
  expect_equal(nf_t("common.buttons.next", lang = "sw"), "Ifuatayo")
  expect_equal(nf_t("common.buttons.next", lang = "fr"), "Suivant")
})

test_that("unknown keys fall back to the key or a supplied fallback", {
  expect_equal(nf_t("no.such.key", lang = "en"), "no.such.key")
  expect_equal(nf_t("no.such.key", lang = "en", fallback = "X"), "X")
})

test_that("unknown language falls back to English", {
  expect_equal(nf_t("common.buttons.submit", lang = "zz"), "Submit")
})
