defmodule RosettaHomeRadioThermostat.Mixfile do
  use Mix.Project

  def project do
    [app: :rosetta_home_radio_thermostat,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger, :radio_thermostat, :ssdp]]
  end

  defp deps do
    [
      {:radio_thermostat, github: "NationalAssociationOfRealtors/radio_thermostat"},
      {:ssdp, "~> 0.1.2"},
      {:rosetta_home, github: "rosetta-home/cicada", branch: "dependency"},
    ]
  end
end
