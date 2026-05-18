# Core Beliefs

## 1. Repository knowledge is the system of record

Facts needed by the agent must live in markdown, scripts, tests, or execution plans.

## 2. AGENTS.md is a map, not a manual

Keep `AGENTS.md` short and canonical. Detailed guidance belongs in `docs/`; do not maintain duplicate instruction files.

## 3. Mechanical checks beat prose

Every critical invariant should have a test when feasible.

## 4. Make the network path legible

Firewall/routing changes must be explainable, testable, and reversible.

## 5. Fail closed

If Xray is unavailable, OpenVPN clients should not bypass Xray through direct forwarding/NAT.

## 6. Prefer small, reviewable changes

Implement atomic phases and update the execution plan as work progresses.
