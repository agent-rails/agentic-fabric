# Shape-based filters on text the model controls

Kind: anti-pattern.

## Problem

A grounding, hallucination or anti-injection check compares model output with a "trusted" channel that also contains text the model chose, such as tool arguments a tool echoes back. A false positive is fixed with an exception keyed on the text's shape: a separator, a currency symbol, a token position.

## Context

Eval scorers and runtime checks that decide whether a number or fact in a reply is backed by tool output.

## What goes wrong

The model writes its own tool arguments. Whatever shape the exception accepts, the model can put into an argument, have the tool echo it, then "quote" it as grounded. Each patch closes one shape and leaves the mechanism. A weakened grounding check is worse than a noisy one: noise wastes attention, a weakened check certifies fabrications.

## Do instead

- Before accepting an exception, ask: can the model write into the position it targets? If yes, it is an instruction to the model, not a filter.
- Try it: build a tool call whose argument carries exactly the shape the rule allows and see whether it launders into a grounded value.
- Fix the false positive at its source. Often the tool and the model just format the same value differently; make them agree.
- For the residual class, use positive provenance: a value is grounded only if a tool computed it and returned it as a typed field, and the scorer reads that structure, not strings.
- If a fourth fix to the same instance is coming, withdraw the mechanism and pin the safe over-reporting behaviour with a test.

## Evidence

Observed: one eval scorer, 2026-09. Three successive shape-based exceptions were each defeated in review by a crafted tool argument (n = 3 attempts). The original false positive disappeared with a formatting change alone; the exception was withdrawn and a test now pins that a regrouped number is reported.

## When it does not hold

When the trusted channel is computed from state the model cannot write to and never echoes its arguments, shape normalisation is safe.

## Related

- [eval-scorer-review](eval-scorer-review.md)
- [keyword-list-as-security-control](keyword-list-as-security-control.md)
- [adjacent-shape-defeats-new-control](adjacent-shape-defeats-new-control.md)
