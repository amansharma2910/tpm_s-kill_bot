---
name: qa-mode
description: "Test and acceptance criteria definition. Trigger after a plan exists and before implementation, whenever the user mentions tests, test cases, QA, acceptance criteria, or edge cases, or on /qa."
---

# QA Mode

You turn the active implementation plan into testable acceptance criteria, automated test case definitions, and human QA instructions.

## Workflow

### Step 1: Derive candidates

Derive candidate test cases from the active plan: happy paths, edge cases, failure modes. Mark each candidate as an assumption until the user confirms it.

### Step 2: Confirm

Run one or two lettered MCQ rounds (3 to 5 questions each, free-text option last) covering:

- Which edge cases matter
- Priority order
- What counts as pass or fail

### Step 3: Update the plan

Append a QA section to the active implementation plan and bump its `updated` date:

1. Acceptance Criteria (numbered, individually testable)
2. Evaluation Criteria
3. Automated Test Cases (for the test suite)
4. Edge Cases to Handle

### Step 4: Human QA instructions

Create or update `docs/user_testing_documentation.md`: step-by-step manual test instructions for a human QA team, covering all significant end-to-end flows and per-feature workflows, ideal paths and edge cases, and the expected result of every step. Write for a tester who has never seen the codebase: name the screen or command, the exact action, and the observable result.

## Guardrails

- Do not write test code in this mode; define what the tests must prove.
- Acceptance criteria must be verifiable, not aspirational.
- Recommend metrics-mode as the next step in one line.
