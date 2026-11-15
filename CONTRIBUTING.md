# Contributing

Thank you for looking.

- Bugs and ideas: open an issue. For a bypass or other security problem, use private vulnerability reporting instead (see SECURITY.md).
- Pull requests are welcome as proposals. They are not merged here: the maintainer ports an accepted change into the source and the next release publishes it, crediting you in the release commit with a `Co-authored-by` trailer. See [decision 0004](docs/decisions/0004-maintainer-ported-releases.md).

What makes a change easy to accept:

- A failing test first. A fix for a gate comes with a test that fails without the fix.
- No new behaviour without its row in the plugin's "What runs" table and its threat-model entry.
- Settings, not edits: anything an adopter may want to change becomes a documented option.
- Claims with their evidence. A number in the docs points to the test or script that produces it, or, if observed in operation, states its window, sample size and method (see the README's Evidence section).

Run the tests for a plugin with `bash plugins/<plugin>/tests/*.test.sh`, and validate with `claude plugin validate --strict .` and `claude plugin validate --strict plugins/<plugin>`.
