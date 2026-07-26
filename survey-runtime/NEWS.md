# nomadforms 0.1.0

* Initial release.

* Survey question helpers (`nf_question()`) that render Shiny inputs, with
  `shiny` as an optional dependency so the rest of the package works without it.

* Response validation (`nf_validate()` and the `nf_validate_*()` family) covering
  required fields, numeric ranges, string lengths, regular expressions,
  membership rules, emails, URLs, phone numbers, and dates.

* Skip logic that evaluates in R (`nf_skip_logic()`, the `nf_show_if_*()`
  builders) and transpiles to browser JavaScript (`nf_condition_to_js()`,
  `nf_skip_logic_js()`) so the same rule drives both the server and the
  offline mobile client.

* Internationalization (`nf_t()`, `nf_tn()`) with built-in English, Spanish,
  French, and Swahili translations registered automatically on package load.

* Geolocation, multimedia capture, and signature widgets for field data
  collection.

* 'REDCap' codebook import (`nf_import_redcap()`) and data export to CSV, JSON,
  Excel, 'Stata', 'SPSS', and RDS, including value-labelled exports.
