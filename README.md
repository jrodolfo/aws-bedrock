# aws bedrock shell playground

![shell](https://img.shields.io/badge/shell-bash-89e051)
![aws bedrock](https://img.shields.io/badge/aws-bedrock-ff9900)
![license](https://img.shields.io/badge/license-MIT-blue)

Small `bash` scripts for experimenting with Amazon Bedrock from the command line.

The project keeps two workflows separate on purpose:

- `generate-image.sh` for image generation with Amazon Nova Canvas
- `generate-text.sh` for text generation with Amazon Nova 2 Lite

That split keeps the model contracts explicit and avoids mixing image-generation payloads with text-generation payloads.

## features

- sequential output naming for generated files
- separate scripts for image and text model families
- shell-based tests that do not make live Bedrock calls
- Git Bash support on Windows
- minimal dependencies and no framework setup

## prerequisites

- macOS, Linux, or Windows with Git Bash
- `bash`
- AWS CLI installed
- Bedrock model access enabled in your AWS account
- AWS credentials configured locally
- `jq`
- `base64`

## windows setup

These scripts are intended to run on macOS, Linux, and Windows. On Windows, use Git Bash.

1. Install the required tools.

```powershell
winget install --id Git.Git -e
winget install --id Amazon.AWSCLI -e
winget install --id jqlang.jq -e
```

If you use Chocolatey instead of `winget`:

```powershell
choco install git awscli jq
```

2. Restart Git Bash after installation so the updated `PATH` is visible.

3. Verify the required commands are available from Git Bash.

```bash
command -v bash
command -v aws
command -v jq
command -v base64
command -v mktemp
```

4. Configure AWS credentials if needed.

```bash
aws configure
```

## getting started

1. Configure your AWS credentials if you have not done that yet.

```bash
aws configure
```

2. Make sure your account can invoke the models used by these scripts.

- `amazon.nova-canvas-v1:0`
- a Nova 2 Lite inference profile such as `us.amazon.nova-2-lite-v1:0`

3. Run one of the generators.

```bash
./generate-image.sh "A green parrot sitting on a tree branch, tropical jungle, photorealistic, high detail"
./generate-text.sh "Summarize the main differences between REST and GraphQL."
```

Optional flags:

- `--region` to override the default AWS region
- `--output-dir` to choose where generated files are written
- `--no-open` on the image script to skip opening the output file

## environment variables

You can configure the scripts with environment variables instead of passing everything on the command line.

Common:

- `BEDROCK_REGION`
- `AWS_REGION`

Image generation:

- `MODEL_ID`

Text generation:

- `TEXT_INFERENCE_PROFILE_ID`
- `MODEL_ID` as an explicit advanced override

Precedence for region:

1. `--region`
2. `BEDROCK_REGION`
3. `AWS_REGION`
4. built-in default `us-east-1`

Example:

```bash
export BEDROCK_REGION=us-west-2
export TEXT_INFERENCE_PROFILE_ID=us.amazon.nova-2-lite-v1:0
```

See [.env.example](/Users/jrodolfo/workspace/aws/aws-bedrock/.env.example) for a minimal template.

Windows note:

- use Git Bash for the current scripts
- PowerShell is not a first-class target yet

## project structure

```text
.
├── generate-image.sh
├── generate-text.sh
├── images/
├── texts/
└── tests/
```

## image generation

Generate an image with Amazon Nova Canvas:

```bash
./generate-image.sh "A green parrot sitting on a tree branch, tropical jungle, photorealistic, high detail"
./generate-image.sh --region us-west-2 --output-dir ./tmp-images --no-open "A studio portrait of a red fox"
```

What it does:

- sends the prompt to `amazon.nova-canvas-v1:0`
- saves the result under `images/` as `image-0001.png`, `image-0002.png`, and so on
- opens the generated image automatically when a supported OS opener is available

## text generation

Generate text with Amazon Nova 2 Lite:

```bash
./generate-text.sh "Summarize the main differences between REST and GraphQL."
./generate-text.sh --region us-west-2 --output-dir ./tmp-texts "Write a short markdown summary of REST vs GraphQL."
```

What it does:

- sends the prompt through the configured Nova 2 Lite inference profile
- saves the result under `texts/` as `response-0001.md`, `response-0002.md`, and so on
- prints the generated response to the terminal

Configuration notes:

- by default the script uses `us.amazon.nova-2-lite-v1:0`
- you can override it with `TEXT_INFERENCE_PROFILE_ID`
- the value should be the inference profile ID or ARN used for Nova 2 Lite
- the script still accepts `MODEL_ID` as an explicit override, but the normal path is to use an inference profile

## sample prompts

Image prompt example:

```text
A green parrot sitting on a tree branch, tropical jungle, photorealistic, high detail
```

Text prompt example:

```text
Summarize the main differences between REST and GraphQL in plain English.
```

## tests

Run the test scripts:

```bash
./tests/test-generate-image.sh
./tests/test-generate-text.sh
```

The tests mock the `aws` command, so they do not make live Bedrock calls.

## troubleshooting

- Missing Bedrock access: if the AWS CLI is configured but the Bedrock call still fails, verify model access in the Bedrock console for the selected region.
- Inference profile errors: Nova 2 Lite may require an inference profile instead of direct on-demand invocation. Set `TEXT_INFERENCE_PROFILE_ID` if needed. The script defaults to `us.amazon.nova-2-lite-v1:0`.
- Headless servers: on EC2 or other non-GUI machines, the image script still saves the PNG and prints its full path even if nothing opens automatically.
- Windows Git Bash: use Git Bash for the current scripts, not PowerShell. Verify `aws`, `jq`, `base64`, and `mktemp` are available from Git Bash.

## notes

- default region is `us-east-1`
- output folders such as `images/` and `texts/` are ignored by Git
- each script validates the model ID so image and text requests do not get mixed up
- as of March 25, 2026, Nova 2 Lite may require an inference profile instead of direct on-demand invocation in some Bedrock setups
- Windows support targets Git Bash; PowerShell would require separate scripts

## license

This project is licensed under the MIT License. See [LICENSE](LICENSE).

## contact

For issues or inquiries, feel free to contact the maintainer:

- **Name:** Rod Oliveira
- **Role:** Software Developer
- **Email:** jrodolfo@gmail.com
- **GitHub:** https://github.com/jrodolfo
- **LinkedIn:** https://www.linkedin.com/in/rodoliveira
- **Webpage:** https://jrodolfo.net
