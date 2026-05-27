# bump-terraform-cli

A composite action that fetches the latest Terraform CLI release from the HashiCorp checkpoint API and updates a target file with the new version.

## Usage

Update a YAML value by path:

```yaml
- uses: craigsloggett/bump-terraform-cli@v1
  with:
    file: .github/workflows/lint.yml
    path: .jobs.terraform.steps[1].with.terraform_version
```

Update a line by regex:

```yaml
- uses: craigsloggett/bump-terraform-cli@v1
  with:
    file: Makefile
    match: '^TERRAFORM_VERSION'
    replace: 'TERRAFORM_VERSION := {version}'
```

Open a pull request only when the file actually changed:

```yaml
- id: bump-terraform-cli
  uses: craigsloggett/bump-terraform-cli@v1
  with:
    file: Dockerfile
    match: '^ARG TERRAFORM_VERSION='
    replace: 'ARG TERRAFORM_VERSION={version}'

- if: steps.bump-terraform-cli.outputs.changed == 'true'
  uses: craigsloggett/create-github-pull-request@v1
  with:
    commit-message: 'chore(build): Bump Terraform CLI to ${{ steps.bump-terraform-cli.outputs.version }}'
    pull-request-head-branch: bump-terraform-cli-${{ steps.bump-terraform-cli.outputs.version }}
```

## Inputs

| Input     | Required | Default | Description                                                                                         |
| --------- | -------- | ------- | ----------------------------------------------------------------------------------------------------|
| `file`    | Yes      |         | Path to the file to update.                                                                         |
| `path`    | No       |         | yq expression targeting the value to update in the file (e.g. `.inputs.terraform-version.default`). |
| `match`   | No       |         | Extended regex (ERE) matching the line to update. Use with `replace`.                               |
| `replace` | No       |         | Replacement line. Use `{version}` as the placeholder for the new version.                           |

Provide either `path` (for YAML) or `match` and `replace` (for line-based files), not both.

For YAML replacements:

- The path must begin with `.` and resolve to an existing value.
- The value must be a plain `MAJOR.MINOR.PATCH` version (no prefixes, suffixes, or constraint operators).
- The value must sit on the same line as its key. Block and folded scalars are not supported; use `match`/`replace` instead.

For line-based replacements:

- The match pattern must match exactly one line in the file.
- The action errors out if zero or more than one lines match.
- `{version}` is the only placeholder recognized in replace.

## Outputs

| Output    | Description                                                                                   |
| --------- | --------------------------------------------------------------------------------------------- |
| `version` | The latest Terraform CLI version, as reported by the HashiCorp checkpoint API.                |
| `changed` | `true` if the file was modified by this run, `false` if it was already at the latest version. |
| `file`    | Path to the file targeted by the bump.                                                        |
