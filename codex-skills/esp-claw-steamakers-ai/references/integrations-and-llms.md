# Telegram and LLM integrations

## Telegram behavior

Telegram is enabled in this board profile together with local/Web messaging.
The transient message `ESP-Claw is snapping on it...` means the request was
accepted; a delayed final response can still arrive. Diagnose long waits from
serial logs before treating them as a crash.

Use a persistent chat session for skill activation and multi-tool work. `/new`
starts a new conversational session but cannot repair a provider request-schema
bug by itself. A full hardware test must complete all scripts in one incoming
request rather than relying on a follow-up `Sí`.

The response language follows the system/profile instructions and the user's
language. Configure a durable preference such as “Respon sempre en català” or
“Always reply in English”; do not assume `/new` retains an unstored preference.

## Provider lessons from this project

Free cloud quotas and schemas change frequently. Check current provider docs and
the configured model before recommending one. The project observed these
failure signatures during development:

- OpenRouter free models: daily `HTTP 429` quota exhaustion.
- Groq with `openai/gpt-oss-20b`: rejected stored assistant fields such as
  `reasoning_details` and `refusal`; long histories also exceeded an 8000 TPM
  allowance with `HTTP 413`, and bursts produced `HTTP 429`.
- Cerebras free: configured as an alternative, but do not claim unlimited use.
- Mistral free: tool calls worked, including GPIO and TFT control, until its
  free quota returned `HTTP 429`.
- Google AI Studio: an earlier OpenAI-compatible request returned
  `Value is not a string: null`. The current firmware later completed a
  multi-tool Gemini session successfully; treat the old error as a regression
  test, not as proof that Google remains unusable.

Other observed messages:

- `LLM returned empty text response` may mean the model issued a tool call but
  supplied no user-facing text. Check whether the requested hardware action
  actually ran and whether tool-call-only responses are handled.
- Rate-limit errors are provider-side constraints. Reduce history/context,
  start a genuinely new session, select a smaller supported model, add retry
  with backoff where appropriate, or rotate among allowed free providers. Never
  promise a cloud service that is both free and unlimited.

Keep provider-specific compatibility normalization in the firmware rather than
asking students to manually edit session history. Do not expose API keys in
logs, documentation, screenshots, commits, releases, or test output.

## Board tool routing

Routine generic GPIO requests should call the protected board script directly
with exact args such as `{action:"write", pin:12, level:1}`; use `level`, not
`value`. TFT color requests should call the persistent display controller
directly. This short routing avoids unnecessary skill/context expansion, which
matters under low free-tier TPM limits.
