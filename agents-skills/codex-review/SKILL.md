---
name: codex-review
description: Iterative code review loop with Codex CLI. Sends changes to Codex for review, fixes issues Codex raises, and re-submits until approved or a disagreement needs human resolution. Use when user asks for a Codex review, iterative review, or wants an external AI review of their changes.
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
color: yellow
---

# Codex Review - Iterative Review Loop

You orchestrate an iterative code review loop between yourself (Claude) and OpenAI Codex CLI. You fix issues that Codex identifies, then re-submit for review until Codex approves or you reach a genuine disagreement that needs human input.

## Prerequisites - What to Review

**This skill requires the user to specify what they want reviewed.** Do NOT proceed without a clear review target. If the user just says "review my code" without specifics, ask them:

> What would you like me to have Codex review? For example:
> - A PR (give me the PR number or branch name)
> - Specific files you've been working on
> - A research document or spec implementation
> - Changes related to a specific task or feature

## Step 0: Build the Review Brief

Before calling Codex, **you** (Claude) do the research to understand the full picture. Your job is to build a **review brief** — a compact but thorough set of instructions telling Codex what to look at, what files to read, what commands to run, and why the change is being made. You do NOT paste file contents into the prompt. Codex has `--sandbox read-only` and `--cd` so it can read files and run git commands itself.

### What Claude Does

1. **Identify the review target** from what the user said
2. **Research the change:**
   - For PRs: `gh pr view <number>` for the description, identify all changed files from `gh pr diff <number>`
   - For branches: `git log <default-branch>..HEAD` for commit messages, `git diff --name-only <default-branch>...HEAD` for changed files
   - For specific files: understand what they do and what depends on them
   - For documents: read the document to understand what it covers
3. **Map the dependency graph of changed files:**
   - What do the changed files import? (types, interfaces, base classes, utilities)
   - What imports the changed files? (callers, consumers, dependents)
   - Are there related test files?
   - Are there specs, PRDs, or research docs that drove this work?
4. **Understand the "why":**
   - Why is this change being made? (PR description, commit messages, user explanation)
   - What problem does it solve?
   - What are the constraints or requirements?
5. **Build the review brief** with all of this as structured instructions for Codex

### Review Brief Structure

The prompt to Codex should follow this structure. **Pass file paths and git commands — not file contents:**

```
You are a senior code reviewer. Another AI agent (Claude) will fix any issues you identify and re-submit for your verification. This is an iterative process — be precise.

## Why This Change
[Purpose, motivation, problem being solved — from PR description, commits, user explanation]

## Requirements / Spec
[If applicable: "Read the spec at path/to/spec.md for the full requirements this change implements"]

## What to Review

Run this command to see the diff:
  git diff main...HEAD
  [or: gh pr diff <number>]

Read these changed files in full:
- src/auth/middleware.ts (new auth flow — core of the change)
- src/auth/types.ts (updated session types)
- src/routes/login.ts (updated to use new middleware)

Read these related files for context:
- src/auth/session.ts (imports the changed types — check for breaking changes)
- src/db/users.ts (called by the new middleware — verify correct usage)
- src/types/api.ts (defines the Response type used in middleware)
- tests/auth/middleware.test.ts (existing tests — check if they still make sense)

Recent history for context:
  git log --oneline -10 -- src/auth/middleware.ts

## What to Focus On
[... review criteria ...]
```

### What Goes in the "Why" Section

Be generous with context. Codex's context window is large — it doesn't hurt to over-communicate. Include:
- The user's explanation of what they're doing and why
- PR description / commit messages
- Any background on the task, feature, or bug being addressed
- Constraints ("we can't change the API because mobile depends on it")
- Research that was done ("we evaluated X and Y, chose Y because...")

## Session Management

Each review run gets a unique run ID to support concurrent reviews. All temp files go in `./tmp/` (relative to the project directory), not `/tmp/`:

```bash
mkdir -p ./tmp
# If .gitignore exists and doesn't already have tmp/, add it
if [ -f .gitignore ] && ! grep -qx 'tmp/' .gitignore; then
  echo 'tmp/' >> .gitignore
fi
RUN_ID="codex-review-$(date +%s)-$$"
JSON_FILE="./tmp/${RUN_ID}-events.jsonl"
```

### How Codex Sessions Work

When you run `codex exec --json`, Codex outputs JSONL events to stdout. The first event contains the session ID:

```json
{"type":"thread.started","thread_id":"019ce530-6a45-7c51-b6c2-14b05f4207f7"}
```

The final agent message is in an `item.completed` event:

```json
{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"..."}}
```

To resume a session, use `codex exec resume <thread_id>`.

## Core Loop

```
0. User specifies what to review — refuse to proceed without this
1. Claude researches: changed files, dependencies, imports, callers, specs, motivation
2. Claude builds a review brief with file paths and git commands (NOT file contents)
3. Generate unique RUN_ID and JSON_FILE path
4. Send to Codex for initial review (codex exec --json), capture thread_id
5. Extract agent response text from JSONL events
6. Parse verdict: APPROVED | CHANGES_REQUESTED
7. If CHANGES_REQUESTED:
   a. Evaluate each issue - do you agree?
   b. If you agree: make the fixes, then resume Codex session with targeted re-review
   c. If you disagree on any point: escalate to user
8. If APPROVED: report success and exit
9. If max iterations (5) reached: escalate to user
```

## Step 1: Initial Codex Review

Write the review brief to a temp file and pipe it to Codex via stdin.

```bash
#!/bin/bash

RUN_ID="codex-review-$(date +%s)-$$"
mkdir -p ./tmp
# If .gitignore exists and doesn't already have tmp/, add it
if [ -f .gitignore ] && ! grep -qx 'tmp/' .gitignore; then
  echo 'tmp/' >> .gitignore
fi
JSON_FILE="./tmp/${RUN_ID}-events.jsonl"
PROMPT_FILE="./tmp/${RUN_ID}-prompt.txt"

cat > "$PROMPT_FILE" << 'PROMPT_EOF'
You are a senior code reviewer. Another AI agent (Claude) will fix any issues you identify and re-submit for your verification.

This is an iterative review process:
- Be precise and specific in your feedback (exact file paths, line numbers, concrete suggestions)
- Vague feedback wastes a review cycle — say exactly what is wrong and what should be done instead
- Claude will attempt fixes and come back. You will then verify those specific fixes.
- You can read any file in the repo and run git commands to understand the full context.

## Why This Change
{{WHY}}

## Requirements / Spec
{{SPEC_INSTRUCTIONS}}

## What to Review

{{GIT_COMMANDS}}

Read these changed files in full:
{{CHANGED_FILES_LIST}}

Read these related files for context:
{{RELATED_FILES_LIST}}

## What to Focus On

Only flag issues that would block a merge or cause real problems in production:
- Bugs, logic errors, incorrect behavior
- Security vulnerabilities (injection, XSS, auth bypass, data exposure, etc.)
- Performance problems, resource leaks, unbounded operations
- Missing error handling for failure cases that WILL happen (network, disk, permissions)
- API contract violations, breaking changes to public interfaces
- Race conditions, deadlocks, concurrency issues
- Data integrity risks (lost writes, inconsistent state, missing transactions)
- Incorrect integration with existing code (wrong types, missing required fields, misused APIs)

Do NOT flag:
- Style or formatting preferences
- Naming suggestions unless current names are actively misleading
- Missing comments or documentation
- "Nice to have" refactoring
- Hypothetical edge cases that are extremely unlikely
- Test coverage gaps unless a critical path is completely untested

## Response Format

VERDICT: [APPROVED | CHANGES_REQUESTED]

If CHANGES_REQUESTED, list each issue as:

ISSUE [number]:
FILE: [exact file path]
LINE: [line number or range]
PRIORITY: [P0 (critical) | P1 (high) | P2 (medium) | P3 (low)]
DESCRIPTION: [what is wrong and why it matters]
SUGGESTION: [specific code or approach to fix it]

If APPROVED:
SUMMARY: [1-2 sentence confirmation]
PROMPT_EOF

# Run codex with prompt from stdin
codex exec \
  --json \
  --cd "$(pwd)" \
  --sandbox read-only \
  - < "$PROMPT_FILE" > "$JSON_FILE" 2>&1

# Extract the thread_id from the first event
THREAD_ID=$(head -1 "$JSON_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('thread_id',''))")

# Extract the agent's response text from item.completed events
RESPONSE=$(python3 -c "
import json, sys
for line in open('$JSON_FILE'):
    try:
        evt = json.loads(line)
        if evt.get('type') == 'item.completed' and evt.get('item',{}).get('type') == 'agent_message':
            print(evt['item']['text'])
    except: pass
")

echo "THREAD_ID=$THREAD_ID"
echo "RUN_ID=$RUN_ID"
echo "---RESPONSE---"
echo "$RESPONSE"
```

**Variables to replace** (inside the heredoc before writing to PROMPT_FILE):
- `{{WHY}}`: Motivation, background, user explanation, PR description
- `{{SPEC_INSTRUCTIONS}}`: e.g., "Read the spec at specs/auth-redesign.md" or "No spec — this is a bug fix"
- `{{GIT_COMMANDS}}`: e.g., "Run: git diff main...HEAD" or "Run: gh pr diff 42"
- `{{CHANGED_FILES_LIST}}`: Bulleted list of changed file paths with brief annotation of what changed in each
- `{{RELATED_FILES_LIST}}`: Bulleted list of dependency/caller file paths with why each is relevant

After running, save the `THREAD_ID` for all subsequent `resume` calls.

## Step 2: Parse the Verdict

Read the response and look for:
- `VERDICT: APPROVED` — proceed to Step 4
- `VERDICT: CHANGES_REQUESTED` — proceed to Step 3
- If neither is found, treat as CHANGES_REQUESTED and parse what you can

## Step 3: Handle Requested Changes

For each issue Codex raised:

### 3a. Evaluate the Issue
Read the relevant file and line. Determine if Codex's feedback is valid:
- **You agree**: The issue is a real bug, security problem, or correctness issue
- **You disagree**: The issue is a false positive, stylistic nitpick, or based on missing context

### 3b. If You Agree with ALL Issues
1. Make the fixes using Edit/Write tools
2. Inform the user what you fixed and why
3. Resume the Codex session for **targeted verification** (not a full re-review):

```bash
#!/bin/bash

JSON_FILE="{{JSON_FILE}}"
PROMPT_FILE="./tmp/{{RUN_ID}}-followup.txt"

cat > "$PROMPT_FILE" << 'PROMPT_EOF'
I have addressed the issues you raised. Here is what I did for each:

{{FIXES_SUMMARY_BY_ISSUE_NUMBER}}

Please verify that each fix correctly addresses the issue you raised. You can read the updated files to confirm. Reference your original issue numbers.

- If all fixes are satisfactory: VERDICT: APPROVED
- If any fix is inadequate or introduced a new problem: VERDICT: CHANGES_REQUESTED (list only the remaining/new issues, referencing original issue numbers where applicable)

Do NOT do a full re-review at this stage. Only verify the specific fixes above.
PROMPT_EOF

# Resume the same Codex session by thread ID
# Note: resume inherits --cd and --sandbox from the original session
codex exec resume --json {{THREAD_ID}} \
  - < "$PROMPT_FILE" > "$JSON_FILE" 2>&1

# Extract the agent's response
RESPONSE=$(python3 -c "
import json, sys
for line in open('$JSON_FILE'):
    try:
        evt = json.loads(line)
        if evt.get('type') == 'item.completed' and evt.get('item',{}).get('type') == 'agent_message':
            print(evt['item']['text'])
    except: pass
")

echo "---RESPONSE---"
echo "$RESPONSE"
```

**Replace:**
- `{{THREAD_ID}}`: The Codex thread UUID from Step 1
- `{{RUN_ID}}`: The run ID from Step 1
- `{{JSON_FILE}}`: The `./tmp/${RUN_ID}-events.jsonl` path from Step 1
- `{{FIXES_SUMMARY_BY_ISSUE_NUMBER}}`: Describe each fix referencing the original issue number, e.g.:
  - "ISSUE 1 (null check in auth.ts:42): Added null guard before accessing user.role"
  - "ISSUE 3 (SQL injection in query.ts:89): Switched to parameterized query"

Then go back to Step 2.

### 3c. Final Full Re-Review

Once all individual issues are verified and approved, do one final full re-review pass to catch anything the fixes may have introduced:

```bash
PROMPT_FILE="./tmp/{{RUN_ID}}-final.txt"

cat > "$PROMPT_FILE" << 'PROMPT_EOF'
All previously raised issues have been addressed and verified. Please do one final full review pass of the current state of the code. Read the changed files again to see them in their current state. This is your chance to catch anything the fixes may have introduced or any issues you may have missed initially.

Use the same format:
VERDICT: [APPROVED | CHANGES_REQUESTED]
PROMPT_EOF

# Note: resume inherits --cd and --sandbox from the original session
codex exec resume --json {{THREAD_ID}} \
  - < "$PROMPT_FILE" > "$JSON_FILE" 2>&1
```

If this final pass raises new issues, go back to Step 2. If approved, proceed to Step 4.

### 3d. If You Disagree with Any Issue

Present the disagreement to the user clearly:

```
## Review Disagreement - Human Input Needed

Codex raised [N] issues. I agree with [X] and disagree with [Y].

### Issues I Agree With (and will fix):
- Issue 1: [summary] - [my plan to fix]

### Issues I Disagree With:
- Issue N: [summary]
  - **Codex says**: [their reasoning]
  - **I think**: [my reasoning]
  - **Why it matters**: [impact of choosing one way vs the other]

What would you like me to do?
1. Fix only the agreed issues and re-submit
2. Fix all issues (including ones I disagree with)
3. Skip the disputed issues and re-submit
4. Stop the review here
```

Wait for user input before proceeding.

## Step 4: Approved

When Codex approves:

```
## Codex Review: APPROVED

[Codex's summary]

**Review completed in [N] iteration(s).**
[If fixes were made: "Changes made during review: [brief list]"]
```

## Step 5: Max Iterations

If you hit 5 iterations without approval:

```
## Review Loop: Max Iterations Reached

After 5 review cycles, Codex is still requesting changes.

**Latest outstanding issues:**
[list remaining issues]

**Changes made so far:**
[list of fixes across all iterations]

Please review the remaining issues and decide how to proceed.
```

## Important Rules

1. **Require a review target.** Never start without the user specifying what to review.
2. **Pass file paths, not file contents.** Codex reads files itself via `--sandbox read-only`. The prompt contains instructions on what to read and why.
3. **Over-communicate context in the "Why" section.** Motivation, background, constraints, research — Codex's context window is large, use it.
4. **Write temp files to `./tmp/`** in the project directory (never `/tmp/`). Run `mkdir -p ./tmp` before writing. Ensure `tmp/` is in the project's `.gitignore`.
5. **Generate a unique RUN_ID** at the start of each review. Use it for all temp file paths.
6. **Use `--json` mode** to get structured JSONL output with the `thread_id` for session resume.
7. **Extract `thread_id`** from the `thread.started` event (first line of JSONL output).
8. **Never use `--last`** for resume — always use the explicit thread ID. Multiple reviews may run concurrently.
9. **Only use `codex exec` (without resume)** for the very first review in the loop.
10. **Always use `--sandbox read-only`** on the initial `codex exec` — Codex should only read, not modify files. YOU make the fixes.
11. **Always use `--cd "$(pwd)"`** on the initial `codex exec` so Codex can read files with correct paths. Resume calls inherit these settings — do NOT pass `--cd` or `--sandbox` to `codex exec resume`.
12. **Iterative re-reviews are targeted**, not full passes. Codex verifies specific fixes by issue number.
13. **One final full re-review** happens only after all issues are resolved, to catch regressions.
14. **Never make fixes you disagree with silently** — always escalate disagreements to the user.
15. **Track iteration count** — report it in the final output.
16. **Show the user what you're fixing** before each re-submission so they can follow along.
17. **Keep fixes minimal** — only fix what Codex flagged. Don't refactor or improve surrounding code.
