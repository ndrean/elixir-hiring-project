defmodule LiveviewCounter.Flags do
  @flags %{
    "GB" => "🇬🇧",
    "ZA" => "🇿🇦",
    "CO" => "🇨🇴",
    "RO" => "🇷🇴",
    "AR" => "🇦🇷",
    "HK" => "🇭🇰",
    "DE" => "🇩🇪",
    "IN" => "🇮🇳",
    "MX" => "🇲🇽",
    "US" => "🇺🇸",
    "SE" => "🇸🇪",
    "COL" => "🇨🇴",
    "CA" => " 🇨🇦",
    "ES" => "🇪🇸",
    "BR" => "🇧🇷",
    "CL" => "🇨🇱",
    "SG" => "🇸🇬",
    "AU" => "🇦🇺",
    "JP" => "🇯🇵",
    "FR" => "🇫🇷",
    "NL" => "🇳🇱"
  }

  @centers [
    %{city: "Amsterdam", country: "NL", short: "ams"},
    %{city: "Ashburn", country: "US", short: "iad"},
    %{city: "Atlanta", country: "US", short: "atl"},
    %{city: "Bogotá", country: "CO", short: "bog"},
    %{city: "Boston", country: "US", short: "bos"},
    %{city: "Bucharest", country: "RO", short: "otp"},
    %{city: "Chennai", country: "IN", short: "maa"},
    %{city: "Chicago", country: "US", short: "ord"},
    %{city: "Dallas", country: "US", short: "dfw"},
    %{city: "Denver", country: "US", short: "den"},
    %{city: "Ezeiza", country: "AR", short: "eze"},
    %{city: "Frankfurt", country: "DE", short: "fra"},
    %{city: "Guadalajara", country: "MX", short: "gdl"},
    %{city: "Hong Kong", country: "HK", short: "hkg"},
    %{city: "Johannesburg", country: "ZA", short: "jnb"},
    %{city: "London", country: "GB", short: "lhr"},
    %{city: "Los Angeles", country: "US", short: "lax"},
    %{city: "Madrid", country: "ES", short: "mad"},
    %{city: "Miami", country: "US", short: "mia"},
    %{city: "Montreal", country: "CA", short: "yul"},
    %{city: "Mumbai", country: "IN", short: "bom"},
    %{city: "Paris", country: "FR", short: "cdg"},
    %{city: "Phoenix", country: "US", short: "phx"},
    %{city: "Querétaro", country: "MX", short: "qro"},
    %{city: "Rio de Janeiro", country: "BR", short: "gig"},
    %{city: "San Jose", country: "US", short: "sjc"},
    %{city: "Santiago", country: "CL", short: "scl"},
    %{city: "Sao Paulo", country: "BR", short: "gru"},
    %{city: "Seattle", country: "US", short: "sea"},
    %{city: "Secaucus", country: "US", short: "ewr"},
    %{city: "Singapore", country: "SG", short: "sin"},
    %{city: "Stockholm", country: "SE", short: "arn"},
    %{city: "Sydney", country: "AU", short: "syd"},
    %{city: "Tokyo", country: "JP", short: "nrt"},
    %{city: "Toronto", country: "CA", short: "yyz"}
  ]

  def assign do
    @centers
    |> Enum.map(fn location -> %{location | country: @flags[location.country]} end)

    # @centers
    # |> Enum.map(fn {ci, co, sh} -> {ci, Enum.find(@flags, fn flag -> flag[co] end), sh} end)
  end
end
