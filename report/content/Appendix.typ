#import "../utils.typ": todo, silentheading, flex-caption
#import "@local/bytes:1.2.0": format-bytes-rate, format-items-rate
= Pełne wyniki benchmarków <full-results>

#let data = json("../benchmarks.json")

#let is-mean(b) = b.run_type == "aggregate" and b.aggregate_name == "mean" and b.aggregate_unit == "time"
#let is-stddev(b) = b.run_type == "aggregate" and b.aggregate_name == "stddev" and b.aggregate_unit == "time"

#let means = data.benchmarks.filter(is-mean)
#let stddevs = data.benchmarks.filter(is-stddev)

#let get-size(name) = {
  if str.find(name, "640/480") != none { $640 times 480$ }
  else if str.find(name, "1280/720") != none { $1280 times 720$ }
  else if str.find(name, "1920/1080") != none { $1920 times 1080$ }
  else if str.find(name, "3840/2160") != none { $3840 times 2160$ }
  else if str.find(name, "7680/4320") != none { $7680 times 4320$ }
  else { 0.0 }
}

#let fmt-si(n) = {
  if n >= 1e9 { str(calc.round(n / 1e9, digits: 2)) + " Gi/s" }
  else if n >= 1e6 { str(calc.round(n / 1e6, digits: 2)) + " Mi/s" }
  else if n >= 1e3 { str(calc.round(n / 1e3, digits: 2)) + " ki/s" }
  else { str(calc.round(n)) + " /s" }
}

#let name-filter(n) = n.replace("BM_", "").split("/").at(0)
#{
  set page(margin: (x: 3em))
  show figure: set block(breakable: true)
  figure(
    table(
      columns: 6,
      align: (center, left, right, right, right, right),
      table.header(
        [*ID*], [*Name*], [*Image Size*], [*Time*],
        [*Throughput (B/s)*],
        [*Throughput (items/s)*],
      ),
      ..for (i, (mean, stddev)) in means.zip(stddevs).enumerate() {
        let sz = get-size(mean.name)
        (
          [#(i + 1)],
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