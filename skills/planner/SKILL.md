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
REVIEW PHASE (steps 1-4)
    |-- Step 1: @agent-technical-writer (plan-annotation)
    |-- Step 2: @agent-contract-specifier (contract specification)
    |-- Step 3: @agent-test-specifier (test specification)
    |-- Step 4: @agent-quality-reviewer (plan-review)
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
  --total-steps 4 \
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

### Review Step 3: Test Specification

Delegate to @agent-test-specifier with mode: `plan-analysis`

Test Specifier will:

- Analyze the plan and contracts to determine test strategies
- Define unit tests for function-level behavior verification
- Define integration tests for component interactions
- Define property-based tests for invariants (when applicable)
- Identify edge cases and boundary conditions from contracts
- Specify coverage strategy (which test types verify which behaviors)
- Add test specifications to plan file in each milestone's Test Specification section

**Why test specification matters**: TDD requires tests BEFORE implementation. Test Specifier ensures:

- Tests are designed systematically (not ad-hoc during implementation)
- Edge cases are identified upfront from contracts
- Coverage strategy is explicit (which behaviors are verified by which tests)
- @agent-developer receives complete specification (requirements + contracts + tests + code)

**This step is never skipped.** Test Specifier will determine appropriate test depth based on milestone complexity. Simple milestones get minimal tests, complex state machines get comprehensive property-based tests.

### Review Step 4: Quality Reviewer Validation

Delegate to @agent-quality-reviewer with mode: `plan-review`

QR will:

- Check production reliability (RULE 0)
- Check project conformance (RULE 1)
- Verify TW annotations are sufficient
- **Verify contracts are testable and complete**
- **Verify test specifications cover all contract conditions**
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

**Test Specification:** (filled by @agent-test-specifier in review phase step 3)

*During planning phase, this can be empty or contain preliminary test ideas. After review phase step 3, this section contains complete test specifications from @agent-test-specifier.*

**Test Files:**
- [exact paths - e.g., tests/test_handler.py]

**Unit Tests:**
| Test Function | Purpose | Inputs | Expected Output | Verifies Contract |
|---------------|---------|--------|-----------------|-------------------|
| test_function_happy_path | Normal operation | valid input | expected result | Postcondition: correct output |
| test_function_edge_case | Boundary condition | edge input | edge result | Boundary: edge behavior |

**Integration Tests:** (if applicable)
| Test Function | Purpose | Setup | Action | Expected Behavior | Verifies Contract |
|---------------|---------|-------|--------|-------------------|-------------------|
| test_component_interaction | Multi-component flow | mock dependencies | invoke workflow | end-to-end result | Postcondition: system behavior |

**Property-Based Tests:** (if applicable)
| Property | Invariant | Test Strategy | Verifies Contract |
|----------|-----------|---------------|-------------------|
| Round-trip property | deserialize(serialize(x)) == x | Generate random inputs | Invariant: data integrity |

**Edge Cases:**
- [ ] Empty input ("", [], None)
- [ ] Boundary values (0, -1, MAX_INT)
- [ ] Concurrent access (if stateful)
- [ ] Network failures (if I/O)
- [ ] Malformed input (if parsing)

**Coverage Strategy:**
- Unit tests: [percentage] of contract preconditions/postconditions
- Integration tests: [which component interactions]
- Property tests: [which invariants]
- Target: [line coverage %], [branch coverage %]

**When tests are needed:**
- **Always:** Public APIs, complex validation, state machines, error-prone operations, security-sensitive code
- **Usually:** CRUD operations, I/O operations, business logic
- **Optional:** Simple getters/setters, trivial helpers, boilerplate

**Example (Simple):**
Milestone with email validation:
- Unit tests: valid format returns True, invalid format returns False, empty string returns False
- Edge cases: Unicode domains, very long emails, RFC 5322 edge formats
- Coverage: 100% of validation branches

**Example (Complex):**
Milestone with state machine (order workflow):
- Unit tests: Each valid state transition
- Property tests: Invalid transitions always rejected
- Integration tests: End-to-end order flow
- Edge cases: Concurrent state modifications
- Coverage: State transition table 100% covered

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

## TDD Workflow: Contracts and Tests

This section explains the relationship between contracts and test specifications in the TDD workflow.

### Contract vs Test Specification

| Aspect | Contracts | Test Specifications |
|--------|-----------|-------------------|
| **Focus** | WHAT behavior is required | HOW to verify that behavior |
| **Audience** | Humans, verification tools | @agent-developer, test frameworks |
| **Format** | Formal specifications (preconditions, postconditions, invariants) | Executable test cases (inputs, assertions, expected outputs) |
| **When** | Review step 2 (@agent-contract-specifier) | Review step 3 (@agent-test-specifier) |
| **Example** | "requires: email is non-null string" | "test_validate_email_none() → raises TypeError" |

**Key Principle:** Contracts define behavioral expectations. Tests verify those expectations are met.

### Example: Simple CRUD Operation

**Milestone:** Add user creation endpoint

**Contracts (from review step 2):**

#### Contract: create_user(email: str, name: str) -> user_id

**Preconditions:**
- requires: email is valid RFC 5322 format
- requires: name is non-empty string
- requires: email is unique (not in database)

**Postconditions:**
- ensures: user saved to database with generated user_id
- ensures: returns user_id as integer > 0
- ensures: email stored in lowercase

**Boundary Conditions:**
| Input | Behavior |
|-------|----------|
| Duplicate email | Raises DuplicateEmailError |
| Invalid email format | Raises ValidationError |
| Empty name | Raises ValidationError |

**Test Specification (from review step 3):**

**Test Files:** `tests/test_user_service.py`

**Unit Tests:**
| Test Function | Purpose | Inputs | Expected Output | Verifies Contract |
|---------------|---------|--------|-----------------|-------------------|
| test_create_user_valid | Happy path | email="user@example.com", name="Alice" | user_id > 0 | Postcondition: returns user_id |
| test_create_user_duplicate_email | Duplicate detection | email already in DB | Raises DuplicateEmailError | Boundary: duplicate email |
| test_create_user_invalid_email | Email validation | email="invalid" | Raises ValidationError | Precondition: valid email |
| test_create_user_empty_name | Name validation | name="" | Raises ValidationError | Precondition: non-empty name |
| test_create_user_email_lowercase | Case normalization | email="User@Example.Com" | Stored as "user@example.com" | Postcondition: lowercase storage |

**Edge Cases:**
- [x] Empty email
- [x] Empty name
- [x] Duplicate email
- [x] Very long email (>254 chars)
- [ ] Unicode in name

**Coverage Strategy:**
- Unit tests: 100% of preconditions (email format, name non-empty, uniqueness)
- Unit tests: 100% of postconditions (user_id returned, email lowercased, DB persistence)
- Target: 100% line coverage, 95%+ branch coverage

### Example: Complex State Machine

**Milestone:** Implement order workflow

**Contracts (from review step 2):**

#### Contract: Order State Machine

**States:** PENDING, PROCESSING, COMPLETED, CANCELLED

**Valid Transitions:**
- PENDING → PROCESSING (guard: payment confirmed)
- PROCESSING → COMPLETED (guard: shipment confirmed)
- PENDING → CANCELLED (guard: user requested)
- PROCESSING → CANCELLED (guard: admin override)

**Invariants:**
- invariant: Order can never transition from COMPLETED or CANCELLED to any other state (terminal states)
- invariant: State transitions are atomic (no partial updates)

**Test Specification (from review step 3):**

**Test Files:** `tests/test_order_workflow.py`

**Unit Tests:**
| Test Function | Purpose | Setup | Action | Expected | Verifies Contract |
|---------------|---------|-------|--------|----------|-------------------|
| test_pending_to_processing | Valid transition | Order in PENDING | confirm_payment() | State = PROCESSING | Valid transition: PENDING → PROCESSING |
| test_processing_to_completed | Valid transition | Order in PROCESSING | confirm_shipment() | State = COMPLETED | Valid transition: PROCESSING → COMPLETED |
| test_completed_to_processing_rejected | Invalid transition | Order in COMPLETED | transition(PROCESSING) | Raises InvalidTransitionError | Invariant: COMPLETED is terminal |
| test_cancelled_to_processing_rejected | Invalid transition | Order in CANCELLED | transition(PROCESSING) | Raises InvalidTransitionError | Invariant: CANCELLED is terminal |

**Property-Based Tests:**
| Property | Invariant | Test Strategy | Verifies Contract |
|----------|-----------|---------------|-------------------|
| Terminal states never transition | COMPLETED/CANCELLED → any state rejected | Generate 100 random transition attempts from terminal states | Invariant: terminal states |
| Valid transitions always succeed | Valid state + guard → success | Generate all valid transitions with satisfied guards | Valid transitions |
| Invalid transitions always fail | Invalid state pair → rejection | Generate invalid state pairs | Invalid transitions rejected |

**Integration Tests:**
| Test Function | Purpose | Flow | Expected Behavior | Verifies Contract |
|---------------|---------|------|-------------------|-------------------|
| test_order_happy_path_end_to_end | Complete order flow | PENDING → confirm payment → PROCESSING → confirm shipment → COMPLETED | Final state = COMPLETED | All valid transitions work |
| test_order_cancellation_from_pending | Cancel before processing | PENDING → cancel → CANCELLED | Final state = CANCELLED | Valid transition: PENDING → CANCELLED |

**Edge Cases:**
- [x] Concurrent transitions (two threads try to transition simultaneously)
- [x] Transition with guard unsatisfied (payment not confirmed)
- [x] Idempotent transitions (calling confirm_payment() twice)

**Coverage Strategy:**
- Unit tests: 100% of valid state transitions
- Unit tests: 100% of invalid state transitions (ensure rejection)
- Property tests: All invariants (terminal states, atomicity)
- Integration tests: End-to-end happy path + cancellation paths
- Target: 100% state transition coverage

### FAQ

**Q: What if my milestone is too simple for tests?**
A: @agent-test-specifier determines appropriate test depth. Simple getters/setters get minimal tests (2-3 unit tests). Let test-specifier make the call rather than skipping tests entirely.

**Q: Do I need to write test specifications during planning phase?**
A: No. Test Specification section can be empty during planning. @agent-test-specifier fills it during review phase step 3.

**Q: What if contracts are missing when I reach review step 3?**
A: @agent-test-specifier will request contracts first. Test specifications require contracts to determine what behavior to verify.

**Q: Can I skip review step 3 for urgent fixes?**
A: No. Review step 3 is mandatory. TDD requires tests before implementation. Skipping test specification defeats the purpose of TDD rigor. If truly urgent, consider whether planner skill is appropriate (use for complex tasks, skip for trivial fixes).

**Q: What if @agent-developer implements code before tests?**
A: Tests-first protocol is enforced by developer verification checklist. Developer must verify tests failed (RED) before implementing production code. Violating this indicates developer did not follow protocol.

**Q: How do I know if test specifications are complete?**
A: @agent-quality-reviewer (review step 4) validates test specifications cover all contract conditions. QR checks for contract-to-test traceability.

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

# Start review (after plan written) - 4 steps: TW → Contracts → Tests → QR
python3 scripts/planner.py --phase review --step-number 1 --total-steps 4 --thoughts "Plan at ..."

# Contract specification
python3 scripts/planner.py --phase review --step-number 2 --total-steps 4 --thoughts "TW done, contracts needed for ..."

# Test specification
python3 scripts/planner.py --phase review --step-number 3 --total-steps 4 --thoughts "Contracts defined, tests needed for ..."

# Quality review
python3 scripts/planner.py --phase review --step-number 4 --total-steps 4 --thoughts "Tests defined, ready for QR..."
````
