Whenever the user asks you to create a plan do the following.

If the user does not specify where to document the plan then create a plan.md file and put it there.

<Output rules for every turn>
- Ask exactly ONE next question.
- Keep prose concise and specific. Avoid redundancy.
- If user answer is ambiguous, ask a clarifying follow-up instead of guessing.
- If user makes a choice that will cause inconsistency with the established conventions in the codebase or the choice will cause tech debt. Push back and confirm with the user about their choice.
- From the answer fill out the in the specific md file with the decision made
- iterate until all requirements are gathered
- for every question provide the options explain the pros and cons then give your recommendation.
</Output rules for every turn>

<Mandatory things to get approval on (ask only after other details are captured)>
Do not put things into the document then expect the user to read it. Instead present it to the user and once confirmed then put it into the plan.md file. Show the user in the chat and once approved add this to the plan:

Step 0) First-principles check (BEFORE A)
- Ask exactly these, one at a time, present answers for confirmation, then write to plan:
  - What fundamental outcome are we trying to achieve? (Not "build X" — the underlying need.)
  - What assumption about the current/proposed approach are we accepting unexamined? (Template copied from where? Whose situation was it designed for?)
  - If we started from zero, knowing only the constraints, would we arrive at this design?
  - What does the framework/tool/pattern give us that we actually need vs. ceremony for someone else's threat model?
- If answers are shaky or reveal copied-template thinking, push back before proceeding to A. Do not skip Step 0 to save time — this is the gate that prevents six months of wasted work.
- Skip Step 0 only for Type-2 (reversible) work: bugfixes, formatting, recurring chores. State explicitly when skipping and why.

A) File Layout (high-level)
- Provide a suggest files/folders to be created and a short purpose for each.

B) Class/Method/Function Structure (high-level)
- Provide outline the classes/functions and their responsibilities.

C) Function Pseudocode (high-level)
- For each function, provide bullet-point pseudocode of its main steps and failure cases.

D) TDD plan assembly (after A/B/C):
- Propose a unit test suite: test names, inputs/outputs, edge cases, fixtures.
- Propose an integration test suite: black-box scenarios, setup/teardown, and how to run non-interactively (e.g., `yarn vitest run src/__tests__/integration --reporter=verbose`).
- Specify test runner and commands; state flakiness/rate-limit mitigation.

E) To-Do commit list (final step)
- Group commits by phase for iterative end-to-end slices. Each commit should include its own testing.
- For each phase, include a layer checklist (use only what applies): backend logic, middletier logic (if needed), frontend logic, and infra logic and deployment testing. Be sure to ask the user which layers are needed to confirm.
- Produce a sequenced list of atomic commits (small, self-contained).
- Use conventional commits: `feat`, `fix`, `refactor`, `chore`, `test`, `docs`.
- For each commit, include:
  - Commit: `<type>(scope): <subject>`
  - Phase: `<phase number/name>`
  - Layers: `backend` | `middletier` | `frontend` | `infra` (only relevant)
  - Changes: bullet list of code edits/files
  - Tests: bullet list of specific test cases added or updated

Remember to ask the user questions step by step!

F) Always add the following to do at the end of the plan:
- Do a PR review of the changes in the branch as if you are another engineer reviewing.
- Decide on which one of the PR recommendations to following. Apply the recommended changes and iterate on tests to ensure everything is passing.
- Look at all the changes and remove any unnecessary comments in the code.

G) Decision sentence (Type-1 plans only) — written by the user, not the agent
- For Type-1 (hard-to-reverse) plans only, the closing decision sentence — *what we are doing and why, in one or two sentences* — is written by the user from memory, with no agent in the loop.
- The agent drafts file layout / structure / pseudocode / commits (A through F). The user writes the decision.
- Symmetric closure with Step 0: agent does not start the plan and agent does not close the plan. Both bookends are the user's.
- Reason: synthesis encodes understanding. If the user cannot write the decision sentence from memory, they did not own the plan — they typed it. Surface that and rework before proceeding.
- For Type-2 (reversible) plans, this step is optional — the bookend matters less when the cost of being wrong is an afternoon.

</Mandatory things to get approval on (ask only after other details are captured)>

Once everything is completed if this is a sub plan from another plan source document then update the original source document with details that was decided on here. Keep it concise with only relevant information.