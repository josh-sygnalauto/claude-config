---
name: planner
description: Interactive sequential planning for complex tasks. Use when breaking down multi-step projects, system designs, migration strategies, or architectural decisions. Invoked via python script that outputs required actions between steps.
---

# Planner Skill

## Purpose

Two-phase planning workflow with forced reflection pauses:

1. **PLANNING PHASE**: Break down complex tasks into milestones with concrete specifications
2. **REVIEW PHASE**: Orchestrate TW annotation and QR validation before execution

## When to Use

Use the planner skill when the task has:

- Multiple milestones with dependencies
- Architectural decisions requiring documentation
- Migration steps that need coordination
- Complexity that benefits from forced reflection pauses

## When to Skip

Skip the planner skill when the task is:

- Single-step with obvious implementation
- A quick fix or minor change
- Already well-specified by the user

## Workflow Overview

```
PLANNING PHASE (steps 1-N)
    |
    v
Write plan to file
    |
    v
REVIEW PHASE (steps 1-3)
    |-- Step 1: @agent-technical-writer (plan-annotation)
    |-- Step 2: @agent-contract-specifier (contract specification)
    |-- Step 3: @agent-quality-reviewer (plan-review)
    v
APPROVED --> /plan-execution
```

---

## PLANNING PHASE

### Preconditions

Before invoking step 1, you MUST have:

1. **Plan file path** - If user did not specify, ASK before proceeding
2. **Clear problem statement** - What needs to be accomplished

### Invocation

Script location: `scripts/planner.py` (relative to this skill)

```bash
python3 scripts/planner.py \
  --step-number 1 \
  --total-steps <estimated_steps> \
  --thoughts "<your thinking about the problem>"
```

### Arguments

| Argument        | Description                                      |
| --------------- | ------------------------------------------------ |
| `--phase`       | Workflow phase: `planning` (default) or `review` |
| `--step-number` | Current step (starts at 1)                       |
| `--total-steps` | Estimated total steps for this phase             |
| `--thoughts`    | Your thinking, findings, and progress            |

### Planning Workflow

1. Confirm preconditions (plan file path, problem statement)
2. Invoke step 1 immediately
3. Complete REQUIRED ACTIONS from output
4. Invoke next step with your thoughts
5. Repeat until `STATUS: phase_complete`
6. Write plan to file using format below

---

## Phase Transition: Planning to Review

When planning phase completes, the script outputs an explicit `ACTION REQUIRED` marker:

```
============================================
>>> ACTION REQUIRED: INVOKE REVIEW PHASE <<<
============================================
```

**You MUST invoke the review phase before proceeding to /plan-execution.**

The review phase ensures:

- Temporally contaminated comments are fixed (via @agent-technical-writer)
- Code snippets have WHY comments (via @agent-technical-writer)
- Plan is validated for production risks (via @agent-quality-reviewer)
- Documentation needs are identified

**Why TW is mandatory**: The planning phase naturally produces temporally contaminated comments -- change-relative language ("Added...", "Replaced..."), baseline references ("Instead of...", "Previously..."), and location directives ("After line 425"). These make sense during planning but are inappropriate for production code. TW transforms them to timeless present form before @agent-developer transcribes them verbatim.

Without review, @agent-developer will transcribe contaminated comments directly into production code.

---

## REVIEW PHASE

After writing the plan file, transition to review phase:

```bash
python3 scripts/planner.py \
  --phase review \
  --step-number 1 \
  --total-steps 3 \
  --thoughts "Plan written to [path/to/plan.md]"
```

### Review Step 1: Technical Writer Review and Fix

Delegate to @agent-technical-writer with mode: `plan-annotation`

TW will:

- **Review and fix** temporally contaminated comments (see `resources/temporal-contamination.md`)
- Read ## Planning Context section
- Add WHY comments to code snippets
- Enrich plan prose with rationale
- Add documentation milestone if missing

**This step is never skipped.** Even if plan prose seems complete, code comments from the planning phase require temporal contamination review.

### Review Step 2: Contract Specification

Delegate to @agent-contract-specifier with mode: `plan-analysis`

Contract Specifier will:

- Analyze the plan and identify components needing formal contracts
- Define preconditions, postconditions, and invariants for HIGH priority components
- Specify boundary conditions and error behaviors
- Add contracts to plan file or separate contracts file (see Contracts section below)

**Why contracts matter**: Contracts formalize behavioral expectations BEFORE implementation. They:

- Eliminate ambiguity that causes implementation variance
- Define edge cases upfront rather than discovering them during testing
- Remove design decision burden from @agent-developer
- Provide testable acceptance criteria for @agent-quality-reviewer

**This step is never skipped.** Contract Specifier will analyze the plan and determine which components need contracts (HIGH/MEDIUM/LOW priority). Even simple plans benefit from explicit boundary condition documentation.

### Review Step 3: Quality Reviewer Validation

Delegate to @agent-quality-reviewer with mode: `plan-review`

QR will:

- Check production reliability (RULE 0)
- Check project conformance (RULE 1)
- Verify TW annotations are sufficient
- **Verify contracts are testable and complete**
- Exclude risks already documented in Planning Context
- Return verdict: PASS | PASS_WITH_CONCERNS | NEEDS_CHANGES

### After Review

- **PASS / PASS_WITH_CONCERNS**: Ready for `/plan-execution`
- **NEEDS_CHANGES**: Return to planning phase to address issues

---

## Plan Format

Write your plan using this structure:

```markdown
# [Plan Title]

## Overview

[Problem statement, chosen approach, and key decisions in 1-2 paragraphs]

## Planning Context

This section is consumed VERBATIM by downstream agents (Technical Writer, Quality Reviewer).
Quality matters: vague entries here produce poor annotations and missed risks.

### Decision Log

| Decision           | Reasoning Chain                                            |
| ------------------ | ---------------------------------------------------------- |
| [What you decided] | [Multi-step reasoning: premise → implication → conclusion] |

Each rationale must contain at least 2 reasoning steps. Single-step rationales are insufficient.

INSUFFICIENT: "Polling over webhooks | Webhooks are unreliable"
SUFFICIENT: "Polling over webhooks | Third-party API has 30% webhook delivery failure in testing → unreliable delivery would require fallback polling anyway → simpler to use polling as primary mechanism"

INSUFFICIENT: "500ms timeout | Matches upstream latency"
SUFFICIENT: "500ms timeout | Upstream 95th percentile is 450ms → 500ms covers 95% of requests without timeout → remaining 5% should fail fast rather than queue"

Include BOTH architectural decisions AND implementation-level micro-decisions:

- Architectural: "Event sourcing over CRUD | Need audit trail + replay capability → CRUD would require separate audit log → event sourcing provides both natively"
- Implementation: "Mutex over channel | Single-writer case → channel coordination adds complexity without benefit → mutex is simpler with equivalent safety"

Technical Writer sources ALL code comments from this table. If a micro-decision isn't here, TW cannot document it.

### Rejected Alternatives

| Alternative          | Why Rejected                                                        |
| -------------------- | ------------------------------------------------------------------- |
| [Approach not taken] | [Concrete reason: performance, complexity, doesn't fit constraints] |

Technical Writer uses this to add "why not X" context to code comments.

### Constraints & Assumptions

- [Technical: API limits, language version, existing patterns to follow]
- [Organizational: timeline, team expertise, approval requirements]
- [Dependencies: external services, libraries, data formats]

### Known Risks

| Risk            | Mitigation                                    |
| --------------- | --------------------------------------------- |
| [Specific risk] | [Concrete mitigation or "Accepted: [reason]"] |

Quality Reviewer excludes these from findings - be thorough.

## Invisible Knowledge

This section captures information NOT visible from reading the code. Technical Writer uses this for README.md documentation during post-implementation.

### Architecture
```

[ASCII diagram showing component relationships]

Example:
User Request
|
v
+----------+ +-------+
| Auth |---->| Cache |
+----------+ +-------+
|
v
+----------+ +------+
| Handler |---->| DB |
+----------+ +------+

```

### Data Flow
```

[How data moves through the system - inputs, transformations, outputs]

Example:
HTTP Request --> Validate --> Transform --> Store --> Response
|
v
Log (async)

````

### Why This Structure
[Reasoning behind module organization that isn't obvious from file names]
- Why these boundaries exist
- What would break if reorganized differently

### Invariants
[Rules that must be maintained but aren't enforced by code]
- Ordering requirements
- State consistency rules
- Implicit contracts between components

### Tradeoffs
[Key decisions with their costs and benefits]
- What was sacrificed for what gain
- Performance vs. readability choices
- Consistency vs. flexibility choices

## Milestones

### Milestone 1: [Name]
**Files**: [exact paths - e.g., src/auth/handler.py, not "auth files"]

**Flags** (if applicable): [needs TW rationale, needs error handling review, needs conformance check]

**Requirements**:
- [Specific: "Add retry with exponential backoff", not "improve error handling"]

**Acceptance Criteria**:
- [Testable: "Returns 429 after 3 failed attempts" - QR can verify pass/fail]
- [Avoid vague: "Works correctly" or "Handles errors properly"]

**Code Changes** (for non-trivial logic, use unified diff format):

See `resources/diff-format.md` for specification.

```diff
--- a/path/to/file.py
+++ b/path/to/file.py
@@ -123,6 +123,15 @@ def existing_function(ctx):
   # Context lines (unchanged) serve as location anchors
   existing_code()

+  # WHY comment explaining rationale - transcribed verbatim by Developer
+  new_code()

   # More context to anchor the insertion point
   more_existing_code()
````

### Milestone N: ...

### Milestone [Last]: Documentation

**Files**:

- `path/to/CLAUDE.md` (index updates)
- `path/to/README.md` (if Invisible Knowledge section has content)

**Requirements**:

- Update CLAUDE.md index entries for all new/modified files
- Each entry has WHAT (contents) and WHEN (task triggers)
- If plan's Invisible Knowledge section is non-empty:
  - Create/update README.md with architecture diagrams from plan
  - Include tradeoffs, invariants, "why this structure" content
  - Verify diagrams match actual implementation

**Acceptance Criteria**:

- CLAUDE.md enables LLM to locate relevant code for debugging/modification tasks
- README.md captures knowledge not discoverable from reading source files
- Architecture diagrams in README.md match plan's Invisible Knowledge section

**Source Material**: `## Invisible Knowledge` section of this plan

## Milestone Dependencies (if applicable)

```
M1 ---> M2
   \
    --> M3 --> M4
```

Independent milestones can execute in parallel during /plan-execution.

````

---

## Contracts

Contracts are formal specifications that define behavioral expectations BEFORE implementation. They are a critical quality gate that prevents entire classes of defects.

### Why Contracts Are Essential

| Without Contracts | With Contracts |
|-------------------|----------------|
| Ambiguous specs lead to implementation variance | Precise specs eliminate guesswork |
| Edge cases discovered during testing | Edge cases specified upfront |
| Developer makes design decisions | Developer executes specifications |
| QR finds issues after implementation | QR verifies against defined contracts |
| Bugs caught late (expensive) | Bugs prevented early (cheap) |

### Contract Types

| Type | Purpose | Example |
|------|---------|---------|
| **Preconditions** | What must be true BEFORE function executes | `requires: user_id is non-empty string` |
| **Postconditions** | What will be true AFTER function completes | `ensures: returns sorted list in ascending order` |
| **Invariants** | What must ALWAYS be true | `invariant: account.balance >= 0` |
| **Boundary conditions** | Behavior at edges | `empty list → returns empty list` |
| **State transitions** | Valid state changes | `IDLE → RUNNING (guard: queue non-empty)` |

### When Contracts Are Required

**Always require contracts for:**
- Public APIs and external interfaces
- Functions with complex validation logic
- State machines and stateful components
- Operations with multiple valid approaches
- Error-prone operations (I/O, concurrency, parsing)
- Security-sensitive code (auth, crypto, input validation)

**Contracts are optional for:**
- Simple getters/setters
- Pure utility functions with obvious behavior
- Internal helpers with single call site
- Boilerplate and generated code

### Contract Location in Repository

Contracts should be discoverable and maintainable. Choose a location based on project complexity.

**Decision heuristic:**
```
Default: Option 1 (inline in plan)
  └── 10+ components with contracts? → Option 2 (dedicated directory)
  └── Strong module ownership/boundaries? → Option 3 (co-location)

Within a repository, use ONE pattern consistently.
```

#### Option 1: Inline in Plan File (Default)

For most projects, embed contracts directly in the plan's milestone specifications:

```markdown
### Milestone 2: User Validation

**Contracts**:

## Contract: validate_email(email: str) -> bool

### Preconditions
- requires: email is non-null string

### Postconditions
- ensures: returns True if email matches RFC 5322 format
- ensures: returns False otherwise (never raises)

### Boundary Conditions
| Input | Expected |
|-------|----------|
| "" | False |
| "user@domain.com" | True |
| "invalid" | False |
```

#### Option 2: Dedicated Contracts Directory (Complex Projects)

For large projects with many contracts, create a dedicated directory:

```
project/
├── src/
│   └── services/
│       ├── user_service.py
│       └── payment_service.py
├── contracts/                    # Dedicated contracts directory
│   ├── README.md                 # Contract conventions
│   ├── user_service.contracts.md
│   └── payment_service.contracts.md
└── docs/
    └── plans/
```

**When to use dedicated directory:**
- 10+ components with formal contracts
- Contracts need versioning independent of code
- Multiple teams reference the same contracts
- Regulatory requirements mandate specification documentation

#### Option 3: Alongside Source Files (Domain-Driven)

For domain-driven designs, co-locate contracts with their implementations:

```
src/
├── auth/
│   ├── auth.py
│   ├── auth.contracts.md         # Contracts for this module
│   └── auth_test.py
├── payments/
│   ├── payments.py
│   ├── payments.contracts.md
│   └── payments_test.py
```

**When to use co-location:**
- Strong module boundaries
- Teams own specific modules end-to-end
- Contracts evolve with implementations

### Contract-to-Code Traceability

Contracts should trace to implementation. Recommended patterns:

**In code (assertions):**
```python
def validate_email(email: str) -> bool:
    # Contract: requires email is non-null string
    assert email is not None, "Precondition: email must be non-null"

    result = _validate_email_format(email)

    # Contract: ensures returns bool (never raises)
    assert isinstance(result, bool)
    return result
```

**In tests (property-based):**
```python
@pytest.mark.parametrize("input,expected", [
    ("", False),                    # Boundary: empty
    ("user@domain.com", True),      # Boundary: valid
    ("invalid", False),             # Boundary: missing @
])
def test_validate_email_contract(input, expected):
    """Verifies: validate_email boundary conditions"""
    assert validate_email(input) == expected
```

### CLAUDE.md Index Entry

When contracts exist, add them to CLAUDE.md:

```markdown
| File/Directory | Contents | Read When |
|----------------|----------|-----------|
| `contracts/` | Formal specifications (pre/post/invariants) | Implementing features, writing tests, reviewing PRs |
| `contracts/user_service.contracts.md` | User validation contracts | Modifying user validation logic |
```

---

## Resources

| Resource                              | Purpose                                                 |
| ------------------------------------- | ------------------------------------------------------- |
| `resources/diff-format.md`            | Authoritative specification for code change format      |
| `resources/temporal-contamination.md` | Terminology for detecting/fixing temporally contaminated comments |

---

## Quick Reference

```bash
# Start planning
python3 scripts/planner.py --step-number 1 --total-steps 4 --thoughts "..."

# Continue planning
python3 scripts/planner.py --step-number 2 --total-steps 4 --thoughts "..."

# Backtrack if needed
python3 scripts/planner.py --step-number 2 --total-steps 4 --thoughts "New info invalidated prior decision..."

# Start review (after plan written) - 3 steps: TW → Contracts → QR
python3 scripts/planner.py --phase review --step-number 1 --total-steps 3 --thoughts "Plan at ..."

# Contract specification
python3 scripts/planner.py --phase review --step-number 2 --total-steps 3 --thoughts "TW done, contracts needed for ..."

# Quality review
python3 scripts/planner.py --phase review --step-number 3 --total-steps 3 --thoughts "Contracts defined, ready for QR..."
````
