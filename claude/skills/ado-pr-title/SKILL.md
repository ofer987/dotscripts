---
name: ado-pr-title
description: Format GitHub Pull Request titles as "[AB#<ADO_NUMBER>] <short_title>" for work tied to an Azure DevOps (ADO) ticket, start the PR description with a link to the ticket, label it "AI Generated", and record the new PR's URL on the ticket's "GitHub Pull Request URL" field. Use when creating or retitling a GitHub PR for an ADO work item, ticket, story, or bug, or when the user mentions AB# numbers.
---

# ADO Pull Request Title

## Format

```
[AB#<ADO_NUMBER>] <short_title>
```

- `AB#` is uppercase, followed by digits only, and the brackets are followed by exactly one space and a non-empty title (the pattern is `^\[AB#\d+\] \S.*$`).
- `<ADO_NUMBER>`: the numeric ADO work item ID, no `#` or spaces inside the brackets.
- `<short_title>`: a brief, imperative summary of the change (aim for under ~70 characters total). Do not repeat the ticket's full title or add a conventional-commit prefix like `fix(ci):`.

Examples:

- `[AB#1363516] Skip CI/CD - Releases if version is already deployed`
- `[AB#1402200] Add retry to bundle upload`

## PR body

The PR body must start with a link to the ADO work item, followed by a blank line and the rest of the description:

```
[AB#<ADO_NUMBER>](<ADO_WORK_ITEM_URL>)

<rest of the description>
```

- `<ADO_WORK_ITEM_URL>` is the work item's web URL, for example `https://dev.azure.com/<org>/<project>/_workitems/edit/<ADO_NUMBER>`. Take it from the `url` field of the `get_work_item` response; never guess it.
- The number in the link must equal the number in the title and the branch, compared as exact digits: branch `ab-7-foo` means ticket 7, so `[AB#7]` matches but `[AB#007]` does not.

Example:

```
[AB#1402200](https://dev.azure.com/my-org/My%20Project/_workitems/edit/1402200)

Retries bundle uploads up to three times with backoff.
```

### Repository PR template

If the repository has a `.github/pull_request_template.md` (in the root of the checked-out repository), the rest of the description must follow it: keep its headings, order and checklists, and fill in every section. The ticket link stays the very first line, above the template's first heading. Do not drop, rename or reorder template sections, and do not leave placeholder text or HTML comments from the template unfilled; write "N/A" for a section that does not apply.

If there is no such file, use this structure after the ticket link line (the ticket number is the link itself):

```
[AB#<ADO_NUMBER>](<ADO_WORK_ITEM_URL>)

## Description

<what changed and why>

## Tests

<how the change was tested, with results; omit this section if not relevant>

## Related changes

<related PRs, tickets or follow-ups; write "None" if there are none>
```

## Workflow

1. Get the ADO number from the current (checked-out) Git branch name, matching `^[A-Za-z]+[-_#](\d+)` (e.g. `ab-1363516-...` or `AB#1363516-...`; the head of an `owner:branch` is the part after the colon). The checked-out branch is the source of truth for the ticket number.
   - If the branch doesn't match, assume it is not for an ADO ticket (including `feature/ab-123`): use neither this format nor the URL recording, and do not put an `[AB#<number>]` prefix in the title (the hook blocks it, since it cannot match the branch).
2. Confirm the ticket exists with the ADO MCP `get_work_item` tool before creating the PR, and note the `url` it returns for the PR body link. If it doesn't exist, tell the user and ask how to proceed. Never guess a number.
   - Before creating a PR, check whether one already exists for the checked-out branch. Call the GitHub MCP `list_pull_requests` with `state: "open"` and `head: "<owner>:<checked-out branch>"` (`<owner>` is the owner of the repository the branch is pushed to). The `<owner>:` prefix is required: without it the filter is silently ignored and the call returns unrelated open PRs. Then keep only the PRs whose `head.ref` equals the checked-out branch name exactly and whose head repository owner matches `<owner>`.
     - One match: do not create a new PR. Update it with `update_pull_request` (and `pull_request_read` first), and skip steps 5 and 6 (labeling and URL recording happen on creation only).
     - More than one match (the same branch targeting different base branches): ask the user which PR to update (list number, title and base branch), or whether to create a new one, and wait for the answer.
     - No match: create the new PR.
3. If the short title isn't given, derive it from the ticket title (from `get_work_item`) or from the diff, then shorten it.
   Before writing the body, check for `.github/pull_request_template.md` and read it if it exists (see "Repository PR template").
4. Apply the format when creating the PR with the GitHub MCP `create_pull_request`, and when retitling an existing PR with `update_pull_request` (a title is required on create; an update that doesn't change the title needs no check). Start the body with the ticket link described in "PR body" (when creating, and when an update sets a new body). Do not use `gh` or other Bash commands to create or edit the PR. The number in the title must equal the branch's ticket number (`ab-123-foo` requires `[AB#123] ...`). Compare the digits exactly: `ab-7-foo` requires `[AB#7]`, never `[AB#007]`, and `ab-007-foo` requires `[AB#007]`, never `[AB#7]`. This is enforced: the hook blocks any title whose number differs from the branch's, and any `[AB#<number>]` title on a branch that has no ticket number. If the user supplies a different number, do not try to override it; point out the mismatch and ask them to switch to a branch named for that ticket (or drop the prefix if the work isn't for a ticket).
5. After the PR is created, apply the GitHub label `AI Generated` to it (creation only, not title edits):
   - Call `pull_request_read` (method `get`) and note the PR's current `labels`; the repository may already have added some.
   - Call the GitHub MCP `issue_write` with `method: "update"`, the PR's number as `issue_number`, and `labels` set to the existing labels plus `AI Generated`. The call replaces the label set, so always include the existing ones. Skip the call if `AI Generated` is already present.
   - Do not use `gh` or other Bash commands to label the PR.
6. After the PR is created, set the ticket's **GitHub Pull Request URL** (`Custom.GitHubPullRequestURL`) to the PR's URL, overwriting any existing value (including "Not Applicable"):
   - `get_work_item` for the ticket, then `get_work_item_type_fields` for its type (the update tool requires both first).
   - The type-fields list can omit the field even when the ticket has it, so skip only if `Custom.GitHubPullRequestURL` is missing from both the `get_work_item_type_fields` list and the `get_work_item` response: then skip the update, tell the user the field is unavailable on that work item type, and leave the PR as created.
   - `update_work_item` with `work_item_id`, `azure_devops_project` (the work item's `System.TeamProject`), and `custom_fields={"Custom.GitHubPullRequestURL": "<PR URL>"}`.
   - Tell the user the field was updated. Only do this on creation, not on title edits.

## Notes

- The `AB#<number>` in the title lets Azure Boards link the PR to the work item.
- The ticket link at the top of the PR body gives reviewers a one-click path to the work item. Keep its number consistent with the title's number.
