# bump-terraform-cli

A composite action that fetches the latest Terraform CLI release and updates a target file with the new version.

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

Pair with [`craigsloggett/create-github-pull-request`](https://github.com/craigsloggett/create-github-pull-request) to open a pull request for the resulting working tree changes.

### Inputs

| Input     | Required? | Default | Description                                                                                                  |
| --------- | --------- | ------- | ------------------------------------------------------------------------------------------------------------ |
| `file`    | `true`    |         | Path to the file to update.                                                                                  |
| `path`    | `false`   |         | yq expression targeting the value to update in the file (e.g. `.inputs.terraform-version.default`).          |
| `match`   | `false`   |         | Regex pattern matching the line to update in the file. Use with `replace`.                                   |
| `replace` | `false`   |         | Replacement line. Use `{version}` as the placeholder for the new version.                                    |

Provide either `path` (for YAML) or `match` and `replace` (for line-based files), not both.

### Outputs

| Output    | Description                          |
| --------- | ------------------------------------ |
| `version` | The latest Terraform CLI version.    |
