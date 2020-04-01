Application.put_env(:tesla, :adapter, Tesla.Mock)

ExUnit.start(capture_log: true)
