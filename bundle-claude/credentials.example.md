# Jira Credentials Template

Copy this file to `credentials.md` in your local runtime directory and keep the copied file out of Git.

<!-- jira-acli:credentials:start -->
site=your-domain.atlassian.net
email=you@example.com
projects=
default_project=
<!-- jira-acli:credentials:end -->

## Notes

- Keep secrets out of this file. Prefer `acli jira auth login --web` so tokens stay in ACLI's auth store.
- `site` should be the Jira Cloud host only, without `https://`.
- `projects` is a comma-separated list used for suggestions and default resolution.
- `default_project` is optional but recommended.
- Keep the marker block format unchanged so `jira-acli` scripts can parse it reliably.
