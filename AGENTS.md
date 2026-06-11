# AI Agent Guidelines

If you are an AI assistant or agent working on the `micrate` codebase, please adhere strictly to the following guidelines:

- This is Crystal, not Ruby. Do not use Ruby-isms or dynamic meta-programming hacks.
- Always run `ameba` to verify linting and formatting before committing.
- Always run `crystal spec` to ensure tests pass.
- Avoid unsafe `.not_nil!` assertions; use proper type narrowing (`if let`, `.try`).
- Prefer modern Crystal 1.20 features (e.g., `M:N` scheduling safe concurrency).
- Do not use deprecated `yaml_mapping` or `json_mapping`; use `YAML::Serializable` and `JSON::Serializable`.
