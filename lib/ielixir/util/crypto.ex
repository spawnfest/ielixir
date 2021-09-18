defmodule IElixir.Util.Crypto do
  @spec compute_signature(
          algo :: atom(),
          key :: String.t(),
          packet_parts :: list(String.t())
        ) :: bitstring()
  def compute_signature(algo, key, packet_parts) do
    ctx =
      Enum.reduce(
        packet_parts,
        :crypto.mac_init(:hmac, algo, key),
        &:crypto.mac_update(&2, &1)
      )
      |> :crypto.mac_final()

    for <<h::size(4), l::size(4) <- ctx>>, into: <<>>, do: <<to_hex_char(h), to_hex_char(l)>>
  end

  defp to_hex_char(i) when i >= 0 and i < 10, do: ?0 + i
  defp to_hex_char(i) when i >= 10 and i < 16, do: ?a + (i - 10)
end
