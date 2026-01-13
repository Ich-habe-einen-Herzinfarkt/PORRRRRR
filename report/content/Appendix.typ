#import "../utils.typ": todo, silentheading, flex-caption
#import "@local/bytes:1.2.0": format-bytes-rate, format-items-rate

#let data = json("../benchmarks.json")

#let is-mean(b) = b.run_type == "aggregate" and b.aggregate_name == "mean" and b.aggregate_unit == "time"
#let is-stddev(b) = b.run_type == "aggregate" and b.aggregate_name == "stddev" and b.aggregate_unit == "time"

#let means = data.benchmarks.filter(is-mean)
#let stddevs = data.benchmarks.filter(is-stddev)

#let get-size(name) = {
  if str.find(name, "640/480") != none { $640 &times 480$ }
  else if str.find(name, "1280/720") != none { $1280 &times 720$ }
  else if str.find(name, "1920/1080") != none { $1920 &times 1080$ }
  else if str.find(name, "3840/2160") != none { $3840 &times 2160$ }
  else if str.find(name, "7680/4320") != none { $7680 &times 4320$ }
  else { "brak" }
}

#let name-filter(n) = n.replace("BM_", "").split("/").at(0)
#{
  set page(margin: (x: 3em))
  show figure: set block(breakable: true)

  [= Pełne wyniki benchmarków <full-results>]
  figure(
    table(
      columns: 6,
      align: (center, left, center, right, right, right),
      table.header(
        [*ID*], [*Nazwa*], [*Rozmiar*], [*Czas*],
        [*Przepustowość (B/s)*],
        [*Przepustowość (items/s)*],
      ),
      ..for (i, (mean, stddev)) in means.zip(stddevs).enumerate() {
        let sz = get-size(mean.name)
        (
          [v#(calc.floor(i/5) + 1)],
          [#name-filter(mean.name)],
          [#sz],
          [#calc.round(mean.real_time, digits: 2) ms],
          [#format-bytes-rate[#mean.bytes_per_second +- #stddev.bytes_per_second]],
          [#format-items-rate[#mean.items_per_second +- #stddev.items_per_second]],
        )
      }
    ),
  )
}