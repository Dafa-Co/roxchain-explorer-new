import Config

# Configure your database
config :explorer, Explorer.Repo,
  timeout: :timer.seconds(80),
  migration_lock: nil

for repo <- [
      # Configure API database
      Explorer.Repo.Replica1,

      # Feature dependent repos
      Explorer.Repo.Account,
      Explorer.Repo.BridgedTokens,
      Explorer.Repo.ShrunkInternalTransactions,
      Explorer.Repo.EventNotifications,
      Explorer.Repo.Mud
    ] do
  config :explorer, repo, timeout: :timer.seconds(80)
end

config :explorer, Explorer.Tracer, env: "dev", disabled?: true

config :logger, :explorer, path: Path.absname("logs/dev/explorer.log")

config :logger, :reading_token_functions,
  path: Path.absname("logs/dev/explorer/tokens/reading_functions.log"),
  metadata_filter: [fetcher: :token_functions]

config :logger, :token_instances,
  path: Path.absname("logs/dev/explorer/tokens/token_instances.log"),
  metadata_filter: [fetcher: :token_instances]
