#!/usr/bin/env python3
"""Hook for GitHub PR titles tied to Azure DevOps tickets.

PreToolUse: enforce "[AB#<number>] <short_title>" on mcp__github__create_pull_request /
update_pull_request and `gh pr create` / `gh pr edit` run via Bash. Exit 2 blocks the tool call and
feeds stderr back to Claude.

PostToolUse: after a PR is created, tell Claude to set the ADO ticket's "GitHub Pull Request URL"
(Custom.GitHubPullRequestURL) to the new PR's URL.
"""
import json
import re
import shlex
import sys

PATTERN = re.compile(r"^\[AB#\d+\] \S.*$")
AB_NUMBER = re.compile(r"^\[AB#(\d+)\]")
PR_URL = re.compile(r"https://[^\s\"'\\]+/pull/\d+")
OPERATORS = {"&&", "||", ";", "|", "&"}


def block(title):
    shown = "(none given)" if title is None else repr(title)
    sys.stderr.write(
        f"Blocked: PR title {shown} must match '[AB#<ADO_NUMBER>] <short_title>' "
        "(e.g. '[AB#1363516] Skip CI/CD - Releases if version is already deployed'). "
        "See the ado-pr-title skill: find the ADO number from the user or the branch name "
        "(ask if unknown), then retry with a conforming title.\n"
    )
    sys.exit(2)


def check(title, required):
    if title is None:
        if required:
            block(None)
        return
    # A title built from a shell variable / substitution can't be verified statically.
    if title.startswith("$") or title.startswith("`"):
        return
    if not PATTERN.match(title):
        block(title)


def gh_titles(command):
    """Yield (subcommand, title_or_None) for each `gh pr create|edit` in the command."""
    try:
        tokens = shlex.split(command, posix=True)
    except ValueError:
        return
    i = 0
    while i < len(tokens) - 2:
        if tokens[i] == "gh" and tokens[i + 1] == "pr" and tokens[i + 2] in ("create", "edit"):
            sub = tokens[i + 2]
            title = None
            j = i + 3
            while j < len(tokens) and tokens[j] not in OPERATORS:
                t = tokens[j]
                if t in ("--title", "-t") and j + 1 < len(tokens):
                    title = tokens[j + 1]
                    j += 1
                elif t.startswith("--title="):
                    title = t[len("--title="):]
                elif t.startswith("-t") and len(t) > 2 and not t.startswith("--"):
                    title = t[2:].lstrip("=")
                j += 1
            yield sub, title
            i = j
        else:
            i += 1


def post_created(data):
    """PostToolUse: ask Claude to record the new PR's URL on the ADO ticket."""
    tool = data.get("tool_name", "")
    inp = data.get("tool_input") or {}
    if tool == "mcp__github__create_pull_request":
        title = inp.get("title")
    elif tool == "Bash":
        command = inp.get("command") or ""
        title = next((t for sub, t in gh_titles(command) if sub == "create" and t), None)
    else:
        return
    number = AB_NUMBER.match(title or "")
    url = PR_URL.search(json.dumps(data.get("tool_response")))
    if not (number and url):
        return  # PR not created (or not an ADO-titled PR): nothing to record
    ado, pr = number.group(1), url.group(0)
    message = (
        f"PR created: {pr}. Now set the 'GitHub Pull Request URL' on ADO work item AB#{ado}: "
        f"call get_work_item({ado}) and get_work_item_type_fields for its type (required before "
        f"updates), then update_work_item(work_item_id={ado}, azure_devops_project from the work "
        f"item's System.TeamProject, custom_fields={{\"Custom.GitHubPullRequestURL\": \"{pr}\"}}). "
        "Overwrite any existing value, and tell the user it was updated."
    )
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PostToolUse", "additionalContext": message}}))


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    if data.get("hook_event_name") == "PostToolUse":
        post_created(data)
        return
    tool = data.get("tool_name", "")
    inp = data.get("tool_input") or {}

    if tool == "mcp__github__create_pull_request":
        check(inp.get("title"), required=True)
    elif tool == "mcp__github__update_pull_request":
        check(inp.get("title"), required=False)  # only when a title is being set
    elif tool == "Bash":
        command = inp.get("command") or ""
        if "gh" not in command or "pr" not in command:
            return
        for sub, title in gh_titles(command):
            check(title, required=(sub == "create"))


main()
