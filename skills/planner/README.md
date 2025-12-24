# Planner Skill Architecture

## Overview

Two-phase planning workflow with forced reflection pauses and integrated TDD practices. Plans progress through planning → review → execution, with test specifications created before code implementation.

## Review Phase Architecture

The review phase has evolved from 3 steps to 4 steps to integrate Test-Driven Development:

```
REVIEW PHASE (4 steps)
  ├─ Step 1: @agent-technical-writer (plan-annotation)
  │    └─ Fixes temporal contamination, adds WHY comments
  ├─ Step 2: @agent-contract-specifier (contract specification)
  │    └─ Defines behavioral expectations (preconditions, postconditions)
  ├─ Step 3: @agent-test-specifier (test specification)
  │    └─ Defines verification strategies (unit, integration, property tests)
  └─ Step 4: @agent-quality-reviewer (plan-review)
       └─ Validates plan + contracts + tests before execution
```

### Why 4 Steps?

**Step ordering invariant:**
1. TW annotation (step 1) must come first → Clean comments before validation
2. Contract specification (step 2) must come second → Tests verify contract behaviors
3. Test specification (step 3) must come third → QR validates test-to-contract traceability
4. QR validation (step 4) must come last → Validates complete specification

**Why this ordering matters:**
- Test specification (step 3) depends on contracts (step 2): Tests cannot be designed without knowing expected behavior
- QR validation (step 4) depends on test specification (step 3): QR ensures every contract condition has corresponding tests
- Changing this order breaks dependencies: test-specifier needs complete contracts, QR needs complete test specs

## Data Flow: TDD Workflow

```
Planning Phase
     ↓
Write plan with milestones
     ↓
REVIEW PHASE
     ↓
Step 1: TW annotates code snippets
     ↓
Step 2: Contract-specifier defines behavioral expectations
     │
     ├─ Preconditions (what must be true before)
     ├─ Postconditions (what will be true after)
     ├─ Invariants (what must always be true)
     └─ Boundary conditions (edge case behaviors)
     ↓
Step 3: Test-specifier analyzes contracts
     │
     ├─ Reads contracts → Determines verification strategies
     ├─ Identifies edge cases from boundary conditions
     ├─ Selects test types (unit/integration/property-based)
     └─ Outputs test specification:
          ├─ Unit tests (function-level verification)
          ├─ Integration tests (component interactions)
          ├─ Property-based tests (invariant verification)
          └─ Coverage strategy (which tests verify which behaviors)
     ↓
Step 4: QR validates test-to-contract traceability
     ↓
EXECUTION PHASE (@agent-developer)
     │
     ├─ 1. Implements test files FIRST (from test specification)
     ├─ 2. Runs tests → Verifies FAILURES (RED phase)
     ├─ 3. Implements production code (from diffs)
     └─ 4. Runs tests → Verifies PASSES (GREEN phase)
     ↓
Acceptance Testing confirms all tests pass
```

## Architectural Decisions

### Why test-specifier is Separate from contract-specifier

**Separation rationale:**
- **Contracts:** Formal specifications consumed by humans and verification tools (focus: "is this behavior correct?")
- **Tests:** Executable code with framework-specific details (focus: "how do we verify thoroughly?")
- **Different expertise:** Formal specification (contracts) vs testing strategies (test design patterns)
- **Independent evolution:** Contract patterns can evolve separately from test patterns

### Why Review Phase Step 3 (Not Planning or Execution)

**Placement rationale:**
- **Not planning phase:** Test design is a specialized skill requiring validation, not ad-hoc planning
- **Not execution phase:** Tests must be reviewed before implementation (test-first principle)
- **Review phase ensures:** Tests are validated alongside contracts before execution begins
- **Maintains clean separation:** Planning (requirements) → Review (validation) → Execution (implementation)

### Why Mandatory (Not Optional)

**Mandatory step rationale:**
- **TDD requires discipline:** Tests must come before code (optional steps get skipped under pressure)
- **Simple code has complex edge cases:** Systematic test design finds issues "simple" milestones miss
- **test-specifier scales depth:** Simple getters get minimal tests, state machines get comprehensive tests
- **Consistency:** Every milestone has test coverage reviewed

## Tradeoffs

### Latency vs Quality

**Cost:** Review phase goes from 3 steps to 4 steps (approximately 25% increase in review time)

**Benefit:** Tests designed before implementation catch bugs early, prevent entire classes of defects, provide executable specification

**Rationale:** TDD front-loads quality investment. Time spent in test design prevents debugging time later. Users who want TDD rigor accept upfront time cost for long-term quality gain.

### Agent Specialization vs Simplicity

**Cost:** Additional agent to maintain (test-specifier), more complex workflow to understand (4 steps not 3)

**Benefit:** Clear separation of concerns, expertise in test design, consistent test quality across all milestones

**Rationale:** Testing is a specialized skill. Dedicated agent provides better guidance than general-purpose planning. Quality gains from expert test design outweigh workflow complexity cost.

### Mandatory vs Optional

**Cost:** Every milestone requires test specification even if tests seem obvious or simple

**Benefit:** No gaps in test coverage, consistent quality, prevents "this is too simple to test" mistakes

**Rationale:** Simple code often has complex edge cases discovered only through systematic test design. Mandatory step ensures consistent analysis. test-specifier can determine minimal test depth for truly simple cases while preventing under-testing of deceptively complex code.

## Invariants

**Test specification must be traceable to contracts:**
- Every contract condition should have corresponding tests
- Tests without contracts indicate missing behavioral specification
- Contracts without tests indicate incomplete verification strategy
- QR (step 4) validates this traceability before execution begins

**Developer must implement tests before production code:**
- Red phase (failing tests) proves tests are valid (not false positives)
- Green phase (passing tests) proves implementation correctness
- Skipping red phase allows false positives (tests that always pass)
- Developer verification checklist enforces this in execution phase

**Review phase ordering must be maintained:**
- TW annotation → Contracts → Tests → QR validation
- Each step depends on previous steps completing
- Changing order breaks dependencies (e.g., tests cannot be designed without contracts)

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Planning workflow, phases, plan format, TDD examples |
| `scripts/planner.py` | Step-by-step orchestration (planning and review phases) |
| `resources/temporal-contamination.md` | Detection heuristic for contaminated comments |
| `resources/diff-format.md` | Unified diff spec for code changes |
| `CLAUDE.md` | Navigation index with sync requirements |
| `README.md` | Architecture documentation (this file) |

## Integration Points

**Agents:**
- `@agent-technical-writer` (step 1): Annotates plan, fixes temporal contamination
- `@agent-contract-specifier` (step 2): Defines/validates behavioral contracts
- `@agent-test-specifier` (step 3): Defines test strategies and specifications
- `@agent-quality-reviewer` (step 4): Validates plan quality, contract-test traceability
- `@agent-developer` (execution): Implements tests-first workflow from specifications

**Commands:**
- `/plan-execution`: Executes plan through delegation, references test specifications

**Resources:**
- `resources/diff-format.md`: Embedded 1:1 in `developer.md`
- `resources/temporal-contamination.md`: Embedded 1:1 in `technical-writer.md` and `quality-reviewer.md`

## Evolution

**Before TDD integration (3-step review):**
- Planning → TW → Contracts → QR → Execution
- Tests designed during execution (not before)
- No systematic test specification review

**After TDD integration (4-step review):**
- Planning → TW → Contracts → **Tests** → QR → Execution
- Tests specified before execution begins
- Contract-to-test traceability validated by QR
- Developer implements tests-first workflow (RED → GREEN)

**Key improvement:** Test specifications are now validated before execution, ensuring systematic test coverage and TDD discipline.
