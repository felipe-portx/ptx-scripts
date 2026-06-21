# refresh_aws_credentials.sh

> Part of the **ptx-cli** internal toolkit.

A small Bash helper that fetches short-lived AWS credentials via `ptx aws-credential-process` and writes them to the `ptx-session` profile in your local AWS CLI configuration. If you are not logged in, it triggers `ptx login` and retries automatically.

---

## Table of contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [How it works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Support](#support)
- [License](#license)

---

## Prerequisites

This script is intended for **Linux** and **macOS** environments. Windows is not supported; use WSL if you need to run it from a Windows machine.

The following tools must be available on your `PATH`:

| Tool   | Purpose                                       | Check                |
| ------ | --------------------------------------------- | -------------------- |
| `ptx`  | Internal CLI that brokers AWS credentials     | `ptx --version`      |
| `aws`  | AWS CLI v2, used to write the profile        | `aws --version`      |
| `jq`   | JSON parsing of the credential payload       | `jq --version`       |
| `bash` | The script is written for Bash, not POSIX sh | `bash --version`     |

`ptx` is an internal tool. If you don't have it installed or can't authenticate, contact **TechOps** for access and setup.

## Installation

Clone the `ptx-cli` repository and make the script executable:

```bash
git clone <ptx-cli-repo-url>
cd ptx-cli
chmod +x refresh_aws_credentials.sh
```

Optionally, symlink it into a directory on your `PATH` so you can call it from anywhere:

```bash
ln -s "$(pwd)/refresh_aws_credentials.sh" ~/.local/bin/refresh-aws-credentials
```

## Usage

Run the script directly:

```bash
./refresh_aws_credentials.sh
```

On success, the `ptx-session` profile in `~/.aws/credentials` is updated with a fresh access key, secret key, and session token.

To use the refreshed credentials, pass the profile explicitly:

```bash
aws s3 ls --profile ptx-session
```

Or lock your current shell to the profile for the rest of the session:

```bash
export AWS_PROFILE=ptx-session
```

> **Note:** AWS session tokens are short-lived. Re-run the script whenever your credentials expire (you will typically see an `ExpiredToken` error from the AWS CLI).

## How it works

The script performs the following steps:

1. Verifies that `jq` is installed.
2. Calls `ptx aws-credential-process`, capturing both `stdout` (the JSON payload) and `stderr` (errors) separately.
3. If `ptx` fails because you are not logged in, it runs `ptx login` and retries the credential fetch once.
4. Validates that the returned payload is non-empty and contains the expected AWS credential fields. The script accepts both flat (`AccessKeyId` at the top level) and nested (`Credentials.AccessKeyId`) JSON layouts.
5. Writes the parsed credentials to the `ptx-session` profile using `aws configure set`.
6. Prints a reminder of how to use the profile.

The script intentionally runs with `set +e` so it can inspect exit codes and surface meaningful error messages rather than aborting silently.

## Troubleshooting

**`'jq' utility is required but not installed`**
Install `jq`: `brew install jq` on macOS, or `sudo apt-get install jq` on Debian/Ubuntu.

**`'ptx' command failed with exit code …`**
Run the failing command directly (`ptx aws-credential-process`) and inspect the error. Common causes are an expired internal session or a misconfigured `ptx` install. Contact TechOps if the underlying issue is not obvious.

**`Login process failed or was aborted`**
The interactive `ptx login` flow was cancelled or failed. Re-run the script and complete the login prompt.

**`'ptx' returned a blank, null, or empty JSON response`**
The credential broker returned nothing. This usually indicates a transient issue with the internal service — retry, and escalate to TechOps if it persists.

**`Could not parse valid AWS keys out of the JSON payload`**
`ptx` returned JSON in an unexpected shape. Capture the raw output printed by the script and share it with TechOps.

**`ExpiredToken` errors from the AWS CLI after a successful run**
Session tokens are short-lived; simply re-run the script.

## Support

For issues with `ptx` itself, authentication problems, or credential broker outages, contact **TechOps**.

For bugs or feature requests in this script, open an issue or merge request in the `ptx-cli` repository.

## License

Proprietary — internal use only. Do not distribute outside the organization.
