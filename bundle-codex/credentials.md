# Jira Credentials

Do not commit this file.

If this directory later becomes a Git repository, add `credentials.md` and `cache/jira/` to `.gitignore`.

<!-- jira-acli:credentials:start -->
site=midasitweb-jira.atlassian.net
email=
token=
projects=
default_project=
<!-- jira-acli:credentials:end -->

## Notes

- `site` should be the Jira Cloud host only, without `https://`.
- `projects` is a comma-separated list used for suggestions and default resolution.
- `default_project` is optional but recommended.
- Keep the marker block format unchanged so `jira-acli` scripts can parse it reliably.
