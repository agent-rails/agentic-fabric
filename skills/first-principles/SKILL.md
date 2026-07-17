---
name: first-principles
description: Run a first-principles derivation pass before adopting a framework, tool, pattern, or template. Forces a derivation from fundamental outcome → constraints → derived requirements → which parts of the candidate map → which parts are ceremony for someone else's situation. Use when user is about to adopt SLSA, Backstage, ArgoCD pattern, a maturity-ladder framework, a vendor blueprint, "best practice" template, or any "should we adopt X" decision. Trigger phrases include "first principles", "should we adopt", "do we need", "derive from scratch", "is this the right framework", "what level should we target".
---

## When to use

- Type-1 (hard-to-reverse) decisions: framework adoption, golden-path design, agent boundaries, new initiatives, security/compliance ladder targets.
- BEFORE writing any plan, RFC, or implementation for adopting something external.
- When the natural framing is "what level of X should we target" — that framing itself is the trap.

## When NOT to use

- Bugfixes, formatting, daily ops, triage, recurring chores. Type-2 reversible work. Adding Socratic gates here burns time for no gain.
- Implementation of an already-derived decision. Run the skill once at the decision point, not on every commit.

## The derivation pass

Produce these sections in order. Do not skip ahead. Each section's answer constrains the next.

### 1. Fundamental outcome
- One sentence. What are we actually trying to achieve, stripped of the framework's vocabulary?
- Wrong: "Reach SLSA L3." Right: "Customers running our binary can prove it descends from reviewed code built in an environment we control."
- If the answer is the framework's name, you have not derived anything. Try again.

### 2. Threat / constraint model (what makes this hard)
- What specifically goes wrong if we do nothing? Who is the adversary or failure mode? What's the blast radius?
- What constraints are real (regulatory, customer trust, cost, team size)? What constraints are imagined?
- This section's job: surface the *actual* problem before the framework names parts of it.

### 3. Derived requirements (without naming the candidate)
- From outcome + threats, list what any solution must do. Use plain language, not framework vocabulary.
- Example for supply-chain: "two humans must approve every line shipped to prod", "build environment must have no interactive shell access", "consumer must verify provenance at the boundary".
- If you cannot list requirements without using the framework's terms, you do not understand the problem yet.

### 4. Candidate mapping
- Take the framework/tool/pattern. For each derived requirement, which part of the candidate maps?
- For each part of the candidate, which derived requirement does it serve? If none — it's ceremony for someone else's situation.
- Output as two lists: *covered*, *ceremony*.

### 5. Gaps the candidate misses
- Which derived requirements have no answer in the candidate?
- These are the parts you'd build yourself or pull from elsewhere.
- This is usually the most valuable output — frameworks always miss something for *your* situation.

### 6. Reframe
- One paragraph: how to think about the candidate now. Vocabulary, not target. A toolbox, not a ladder.
- Concrete next steps: what to adopt, what to skip, what to build yourself.

### 7. Steelman pass (catch confirmation bias)
- Sections 1–6 derive forward. That motion has built-in bias — once you name a fundamental outcome, the derivation tends to confirm whatever direction you started from.
- Take the strongest critic of this derivation. What would they say? Examples:
  - "You under-counted ceremony cost — the 'covered' parts of section 4 are heavier in practice than they look."
  - "Your derived requirements (section 3) smuggled in the candidate's vocabulary anyway — re-read them with fresh eyes."
  - "The gaps in section 5 are exactly what the candidate is built for; you're rejecting it for not being something else."
  - "Your threat model (section 2) is too narrow — a real adversary has options you didn't list."
- For each critique, decide: does the derivation still stand, or does it need rework? If rework — go back to the relevant section and redo. Do not paper over.
- The output of this pass is one of: *derivation holds*, *section N revised*, *abandon — different problem than I thought*.

## Output format

Single markdown block. Sections 1–7 as headers. No preamble, no apologies, no "great question".

Pair with `architecture-deepen` (vocabulary) and the planning rule's Step 0 (forces this skill on Type-1 work). The planning Step 0 may invoke this skill explicitly when the work is "adopt X".

## Anti-patterns this skill exists to prevent

- "What level should we target" — pre-commits to the ladder before deriving.
- "Industry best practice" — analogy-by-authority. Restate as: whose situation produced this practice?
- "Compliance requires it" — sometimes true (FedRAMP, EU CRA), often the framework was *chosen* to satisfy compliance and the choice itself is unexamined. Check.
- Maturity-ladder thinking applied uniformly — frameworks tier evenly across all artifacts; your threat model does not. Different artifact classes deserve different answers.
- Skipping section 3 — jumping straight from threats to "so we adopt X" hides the analogy.

## Example invocations

- `/first-principles SLSA adoption for our build pipeline`
- `/first-principles Backstage as our IDP frontend`
- `/first-principles GitOps with ArgoCD applicationsets for new team onboarding`
- `/first-principles target SLSA L3 across all repos` (skill should reject the framing and rederive)
