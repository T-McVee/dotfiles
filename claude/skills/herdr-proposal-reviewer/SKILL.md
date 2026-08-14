---
name: herdr-proposal-reviewer
description: >
  Alias for herdr-peer-reviewer Phase 1 (OpenSpec only). Prefer herdr-peer-reviewer
  for the full two-phase workflow.
---

# Herdr proposal reviewer

Use **`herdr-peer-reviewer`** and follow **Phase 1 — OpenSpec proposal** only.

## How to communicate (Herdr ≥ 0.8)

Same as peer reviewer: **do not** use `@manager` chat or `herdr agent send`.

When satisfied, signal the manager via **`herdr-signal`**:

```bash
SIGNAL=PROPOSAL_READY_FOR_TIM
BEAD=<BEAD_ID>
ADO=<ADO_ID>
BODY="OpenSpec change: <change-id>; reviewer sign-off: <paragraph>"
# bd note + bd dolt push, then:
# herdr agent prompt manager "$MSG" --wait --timeout 60000
```

Do **not** start Phase 2 or a draft PR from this role.
