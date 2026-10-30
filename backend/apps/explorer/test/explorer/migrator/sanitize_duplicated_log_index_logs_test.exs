defmodule Explorer.Migrator.SanitizeDuplicatedLogIndexLogsTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.Log
  alias Explorer.Chain.TokenTransfer
  alias Explorer.Chain.Token.Instance
  alias Explorer.Migrator.{SanitizeDuplicatedLogIndexLogs, MigrationStatus}
end
