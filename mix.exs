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

  def application do
    [extra_applications: [:logger, :radio_thermostat, :ssdp, :cicada]]
  end

  defp deps do
    [
      {:radio_thermostat, github: "NationalAssociationOfRealtors/radio_thermostat"},
      {:ssdp, "~> 0.1.3"},
      {:cicada, github: "rosetta-home/cicada", optional: true},
    ]
  end
end
