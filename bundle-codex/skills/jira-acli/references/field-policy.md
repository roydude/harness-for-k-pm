# Dynamic Field Policy

This skill does not hardcode per-project JSON files such as `NMRS.json`.

## Project resolution order

1. Explicit project from the user request or command flags
2. `default_project` in `/Users/ago0528/.codex/credentials.md`
3. First value in `projects`

If none of these exist, stop and ask for the project key.

## Minimum required fields

### Create

- `project`
- `type`
- `summary`

Optional but common:

- `description` or `description-file`
- `assignee`
- `label`
- `parent`

### Edit

- `key`
- At least one change field such as `summary`, `description`, `description-file`, `assignee`, or `label`

### Transition

- `key`
- `status`

### Comment

- `key`
- `body` or `body-file`

## Policy for organization-specific fields

The following should be treated as project-specific and potentially unresolved until confirmed:

- custom fields
- sprint assignment
- fixVersion
- epic linkage
- parent constraints across issue types
- workflow status names

When one of these is needed:

1. Stop at preview.
2. State the missing field explicitly.
3. Ask for the exact value or confirm that REST fallback is acceptable.

## Caching

If project metadata or field hints are fetched later, cache them under:

```text
/Users/ago0528/.codex/cache/jira/projects/<site>/<project>.json
```

Treat the cache as disposable runtime state, not source of truth.

## Verification

After `create`, `edit`, `transition`, or `comment`, always re-fetch the issue and verify:

- the key exists
- edited fields match intent
- the status actually changed
- the comment was added when applicable
