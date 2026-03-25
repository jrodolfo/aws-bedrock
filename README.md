# aws bedrock shell playground

![shell](https://img.shields.io/badge/shell-zsh-89e051)
![aws bedrock](https://img.shields.io/badge/aws-bedrock-ff9900)
![license](https://img.shields.io/badge/license-MIT-blue)

Small `zsh` scripts for experimenting with Amazon Bedrock from the command line.

The project keeps two workflows separate on purpose:

- `generate-image.sh` for image generation with Amazon Nova Canvas
- `generate-text.sh` for text generation with Amazon Nova 2 Lite

That split keeps the model contracts explicit and avoids mixing image-generation payloads with text-generation payloads.

## features

- sequential output naming for generated files
- separate scripts for image and text model families
- shell-based tests that do not make live Bedrock calls
- minimal dependencies and no framework setup

## prerequisites

- macOS or a Unix-like shell environment with `zsh`
- AWS CLI installed
- Bedrock model access enabled in your AWS account
- AWS credentials configured locally
- `jq`
- `base64`

## getting started

1. Configure your AWS credentials if you have not done that yet.

```bash
aws configure
```

2. Make sure your account can invoke the models used by these scripts.

- `amazon.nova-canvas-v1:0`
- `amazon.nova-2-lite-v1:0`

3. Run one of the generators.

```bash
./generate-image.sh "A green parrot sitting on a tree branch, tropical jungle, photorealistic, high detail"
./generate-text.sh "Summarize the main differences between REST and GraphQL."
```

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
```

What it does:

- sends the prompt to `amazon.nova-canvas-v1:0`
- saves the result under `images/` as `image-0001.png`, `image-0002.png`, and so on
- opens the generated image automatically on macOS

## text generation

Generate text with Amazon Nova 2 Lite:

```bash
./generate-text.sh "Summarize the main differences between REST and GraphQL."
```

What it does:

- sends the prompt to `amazon.nova-2-lite-v1:0`
- saves the result under `texts/` as `response-0001.txt`, `response-0002.txt`, and so on
- prints the generated response to the terminal

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

## notes

- default region is `us-east-1`
- output folders such as `images/` and `texts/` are ignored by Git
- each script validates the model ID so image and text requests do not get mixed up

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
