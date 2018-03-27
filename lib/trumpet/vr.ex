defmodule Trumpet.VR do
  alias Trumpet.Utils

  @stations %{
    "Ainola" => "AIN",
    "Alavus" => "ALV",
    "Aviapolis" => "AVP",
    "Dragsvik" => "DRA",
    "Eläinpuisto-Zoo" => "EPZ",
    "Eno" => "ENO",
    "Espoo" => "EPO",
    "Haapajärvi" => "HPJ",
    "Haapamäki" => "HPK",
    "Haarajoki" => "HAA",
    "Hankasalmi" => "HKS",
    "Hanko" => "HNK",
    "Hanko-Pohjoinen" => "HKP",
    "Harjavalta" => "HVA",
    "Heinävesi" => "HNV",
    "Helsinki" => "HKI",
    "Helsinki lentoasema" => "LEN",
    "Herrala" => "HR",
    "Hiekkaharju" => "HKH",
    "Hikiä" => "HK",
    "Humppila" => "HP",
    "Huopalahti" => "HPL",
    "Hyvinkää" => "HY",
    "Hämeenlinna" => "HL",
    "Höljäkkä" => "HöL",
    "Iisalmi" => "ILM",
    "Iittala" => "ITA",
    "Ilmala" => "ILA",
    "Imatra" => "IMR",
    "Inkeroinen" => "IKR",
    "Inkoo" => "IKO",
    "Isokyrö" => "IKY",
    "Joensuu" => "JNS",
    "Jokela" => "JK",
    "Jorvas" => "JRS",
    "Joutseno" => "JTS",
    "Juupajoki" => "JJ",
    "Jyväskylä" => "JY",
    "Jämsä" => "JÄS",
    "Järvelä" => "JR",
    "Järvenpää" => "JP",
    "Kajaani" => "KAJ",
    "Kannelmäki" => "KAN",
    "Kannus" => "KNS",
    "Karjaa" => "KR",
    "Karkku" => "KRU",
    "Kauhava" => "KHA",
    "Kauklahti" => "KLH",
    "Kauniainen" => "KNI",
    "Kausala" => "KA",
    "Kemi" => "KEM",
    "Kemijärvi" => "KJÄ",
    "Kera" => "KEA",
    "Kerava" => "KE",
    "Kerimäki" => "KIÄ",
    "Kesälahti" => "KTI",
    "Keuruu" => "KEU",
    "Kilo" => "KIL",
    "Kirkkonummi" => "KKN",
    "Kitee" => "KIT",
    "Kiuruvesi" => "KRV",
    "Kivistö" => "KTö",
    "Kohtavaara" => "KOH",
    "Koivuhovi" => "KVH",
    "Koivukylä" => "KVY",
    "Kokemäki" => "KKI",
    "Kokkola" => "KOK",
    "Kolari" => "KLI",
    "Kolho" => "KLO",
    "Kontiomäki" => "KON",
    "Koria" => "KRA",
    "Korso" => "KRS",
    "Kotka" => "KTA",
    "Kotkan satama" => "KTS",
    "Kouvola" => "KV",
    "Kuopio" => "KUO",
    "Kupittaa" => "KUT",
    "Kylänlahti" => "KYN",
    "Kymi" => "KY",
    "Kyminlinna" => "KLN",
    "Käpylä" => "KÄP",
    "Lahti" => "LH",
    "Laihia" => "LAI",
    "Lapinlahti" => "LNA",
    "Lappeenranta" => "LR",
    "Lappila" => "LAA",
    "Lappohja" => "LPO",
    "Lapua" => "LPA",
    "Leinelä" => "LNÄ",
    "Lempäälä" => "LPÄ",
    "Leppävaara" => "LPV",
    "Lieksa" => "LIS",
    "Loimaa" => "LM",
    "Louhela" => "LOH",
    "Luoma" => "LMA",
    "Lusto" => "LUS",
    "Malmi" => "ML",
    "Malminkartano" => "MLO",
    "Mankki" => "MNK",
    "Martinlaakso" => "MRL",
    "Masala" => "MAS",
    "Mikkeli" => "MI",
    "Mommila" => "MLA",
    "Muhos" => "MH",
    "Muurola" => "MUL",
    "Myllykoski" => "MKI",
    "Myllymäki" => "MY",
    "Myyrmäki" => "MYR",
    "Mäkkylä" => "MÄK",
    "Mäntsälä" => "MLÄ",
    "Mäntyharju" => "MR",
    "Nastola" => "NSL",
    "Nivala" => "NVL",
    "Nokia" => "NOA",
    "Nuppulinna" => "NUP",
    "Nurmes" => "NRM",
    "Oitti" => "OI",
    "Orivesi" => "OV",
    "Orivesi keskusta" => "OVK",
    "Oulainen" => "OU",
    "Oulu" => "OL",
    "Oulunkylä" => "OLK",
    "Paimenportti" => "PTI",
    "Paltamo" => "PTO",
    "Parikkala" => "PAR",
    "Parkano" => "PKO",
    "Parola" => "PRL",
    "Pasila" => "PSL",
    "Pello" => "PEL",
    "Petäjävesi" => "PVI",
    "Pieksämäki" => "PM",
    "Pietarsaari" => "PTS",
    "Pihlajavesi" => "PH",
    "Pitäjänmäki" => "PJM",
    "Pohjois-Haaga" => "POH",
    "Pori" => "PRI",
    "Puistola" => "PLA",
    "Pukinmäki" => "PMK",
    "Punkaharju" => "PUN",
    "Purola" => "PUR",
    "Pyhäsalmi" => "PHÄ",
    "Pännäinen" => "PNÄ",
    "Pääskylahti" => "PKY",
    "Rekola" => "RKL",
    "Retretti" => "REE",
    "Riihimäki" => "RI",
    "Rovaniemi" => "ROI",
    "Runni" => "RNN",
    "Ruukki" => "RKI",
    "Ryttylä" => "RY",
    "Salo" => "SLO",
    "Santala" => "STA",
    "Saunakallio" => "SAU",
    "Savio" => "SAV",
    "Savonlinna" => "SAV",
    "Seinäjoki" => "SK",
    "Siilinjärvi" => "SIJ",
    "Simpele" => "SPL",
    "Siuntio" => "STI",
    "Skogby" => "SKY",
    "Sukeva" => "SKV",
    "Suonenjoki" => "SNJ",
    "Tammisaari" => "TMS",
    "Tampere" => "TPE",
    "Tapanila" => "TNA",
    "Tavastila" => "TSL",
    "Tervajoki" => "TK",
    "Tervola" => "TRV",
    "Tikkurila" => "TKL",
    "Toijala" => "TL",
    "Tolsa" => "TOL",
    "Tornio" => "TOR",
    "Tuomarila" => "TRL",
    "Turenki" => "TU",
    "Turku" => "TKU",
    "Turku satama" => "TUS",
    "Tuuri" => "TUU",
    "Uimaharju" => "UIM",
    "Utajärvi" => "UTJ",
    "Uusikylä" => "UKÄ",
    "Vaala" => "VAA",
    "Vaasa" => "VS",
    "Vainikkala" => "VNA",
    "Valimo" => "VMO",
    "Vammala" => "VMA",
    "Vantaankoski" => "VKS",
    "Varkaus" => "VAR",
    "Vehkala" => "VEH",
    "Vihanti" => "VTI",
    "Vihtari" => "VIH",
    "Viiala" => "VIA",
    "Viinijärvi" => "VNJ",
    "Vilppula" => "VLP",
    "Villähde" => "VLH",
    "Vuonislahti" => "VSL",
    "Ylistaro" => "YST",
    "Ylitornio" => "YTR",
    "Ylivieska" => "YV",
    "Ähtäri" => "ÄHT"
  }

  defp get_station_shortcode(station_name) do
    shortcode = Utils.ci_get_in(@stations, [station_name])
    case is_nil(shortcode) do
      true  -> station_name
      false -> shortcode
    end
    |> String.upcase()
  end

  defp parse_train_response(from, to, response, train) do
    response = Enum.at(response, train)
    train_type = response["trainType"]
    train_number = response["trainNumber"]
    stations =
      response
      |> Map.get("timeTableRows")
    from =
      Enum.filter(stations, fn(station) ->
        station["stationShortCode"] == from && station["type"] == "DEPARTURE"
      end)
      |> List.first()
    to =
      Enum.filter(stations, fn(station) ->
        station["stationShortCode"] == to && station["type"] == "ARRIVAL"
      end)
     |> List.first()
    local = Timex.timezone("Europe/Helsinki", Timex.now)
    departure =
      from["scheduledTime"]
      |> Timex.parse!("{ISO:Extended}")
      |> Timex.Timezone.convert(local)
      |> Timex.format!("%y-%m-%d %H:%M", :strftime)
    arrival =
      to["scheduledTime"]
      |> Timex.parse!("{ISO:Extended}")
      |> Timex.Timezone.convert(local)
      |> Timex.format!("%y-%m-%d %H:%M", :strftime)
    "Train #{train_type} #{train_number} from #{from["stationShortCode"]} #{departure} " <>
    "to #{to["stationShortCode"]} #{arrival}"
  end

  def get_next_train(from, to, train \\ 0) when is_binary(from) do
    from = get_station_shortcode(from)
    to = get_station_shortcode(to)
    train =
      case is_binary(train) do
        true  -> String.to_integer(train)
        false -> train
      end
    opts = "limit=#{train+1}"
    request_url = "https://rata.digitraffic.fi/api/v1/live-trains/station/#{from}/#{to}?#{opts}"
    response = HTTPoison.get!(request_url).body |> Poison.decode!()
    case is_map(response) do
      true  -> response["errorMessage"]
      false -> parse_train_response(from, to, response, train)
    end
  end

  def get_next_train(args) when is_list(args) do
    case Enum.count(args) >= 2 do
      true  -> get_next_train(Enum.at(args, 0), Enum.at(args, 1), Enum.at(args, 2, 0))
      false -> ""
    end
  end

  def get_live_train(train_number) when is_binary(train_number) do
    "https://junatkartalla.vr.fi/?lang=fi-FI&train=#{train_number}"
  end

  def get_live_train(args) when is_list(args) do
    train = Enum.join(args)
    Regex.scan(~r/[0-9]/, train)
    |> Enum.join()
    |> get_live_train()
  end
end
