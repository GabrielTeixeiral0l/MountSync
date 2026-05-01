# Contributing to MountSync

First off, thank you for considering contributing to MountSync! It's people like you that make MountSync a great tool for everyone.

## Code of Conduct

By participating in this project, you agree to abide by the professional and respectful conduct expected in the Open Source community.

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, please check that an issue hasn't already been reported. When filing a bug, please use the structured Bug Report template and provide as much technical detail as possible (rclone version, mount status, and environment).

### Suggesting Enhancements

We welcome new ideas! Please use the Feature Request template to describe the problem you're solving and your proposed solution.

## Development Workflow

We follow a structured Git branching model:

- `main`: Stable, production-ready code.
- `dev`: Integration branch for new features and fixes.
- `feat/*`: Temporary branches for specific features or fixes (created from `dev`).

### Getting Started

Since you won't have direct push access to this repository, you must follow the standard Open Source workflow:

1. **Fork** the repository to your own GitHub account.
2. **Clone** your fork locally: `git clone https://github.com/your-username/mountsync.git`.
3. **Add the upstream** remote to stay synced with the original project:
   ```bash
   git remote add upstream https://github.com/gabrielteixeira/mountsync.git
   ```
4. **Create a feature branch** from the `dev` branch:
   ```bash
   git checkout -b feat/your-feature-name upstream/dev
   ```
5. **Implement and commit** your changes following our standards.
6. **Push** the branch to your fork: `git push origin feat/your-feature-name`.
7. **Open a Pull Request** from your fork to our `dev` branch.

## Engineering Standards

### Test-Driven Development (TDD)

We prioritize technical integrity. For any bug fix or new feature:
1. **Reproduce first**: Create a test case in `tests/` that fails (BATS).
2. **Implement**: Write the minimal code needed to make the test pass.
3. **Verify**: Ensure all existing tests still pass.

Run tests locally using:
```bash
bats tests/
# OR using the Docker environment
./tests/run_docker.sh
```

### Coding Style (Bash)

- Maintain modularity: core logic belongs in `src/core.sh`, commands in `src/commands/`.
- Use descriptive variable names and local scope within functions.
- Follow existing patterns in the codebase for error handling and logging.

### Commit Messages

We strictly follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat`: A new feature.
- `fix`: A bug fix.
- `refactor`: Code change that neither fixes a bug nor adds a feature.
- `test`: Adding or correcting tests.
- `chore`: Changes to build process or auxiliary tools.

Example: `feat(commands): add status command to check synchronization state`

## Pull Request Process

1. Ensure your code follows the style guidelines and all tests pass.
2. Update the README.md or help text if you've added/changed functionality.
3. Submit your PR against the `dev` branch.
4. Fill out the PR template completely.

After a successful merge into `dev`, feature branches are deleted.
