# ElevenLabs Voice Agent

[![Docker Build](https://img.shields.io/badge/Docker-Build-blue?logo=docker)](https://docs.docker.com/)
[![Node.js](https://img.shields.io/badge/Node.js-18.x-green?logo=node.js)](https://nodejs.org/)
[![PNPM](https://img.shields.io/badge/PNPM-8.x-orange?logo=pnpm)](https://pnpm.io/)

## Overview

This is a voice agent service built with Next.js and Docker, designed to integrate with ElevenLabs' voice technology.

## Prerequisites

- Docker 20.10.0 or later
- Node.js 18.x or later
- PNPM 8.x or later

## Getting Started

### Local Development

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd eleven-labs-voice-agent
   ```

2. **Install dependencies**
   ```bash
   pnpm install
   ```

3. **Set up environment variables**
   Create a `.env` file in the root directory with the required variables:
   ```env
   NODE_ENV=development
   # Add other environment variables here
   ```

4. **Start the development server**
   ```bash
   pnpm dev
   ```

### Building with Docker

1. **Build the Docker image**
   ```bash
   docker build -t eleven-labs-voice-agent .
   ```

2. **Run the container**
   ```bash
   docker run -p 3000:3000 --env-file .env eleven-labs-voice-agent
   ```

## Project Structure

```
├── .github/           # GitHub workflows
├── app/               # Next.js app directory
├── components/        # Reusable components
├── lib/               # Utility functions
├── public/            # Static files
├── styles/            # Global styles
└── ui/                # UI components
```

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `NODE_ENV` | Application environment | Yes | `production` |
| `PORT` | Port to run the server | No | `3000` |

## Cleanup

To remove build artifacts and dependencies:

```bash
# Remove node_modules and build artifacts
rm -rf .next node_modules .pnpm-store

# Or using PowerShell
Remove-Item -Recurse -Force .next, node_modules, .pnpm-store
```

## Troubleshooting

- **Build issues**: Ensure you have the correct Node.js and PNPM versions installed
- **Docker issues**: Make sure Docker is running and you have sufficient disk space
- **Port conflicts**: Check if port 3000 is available or change the `PORT` environment variable

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.