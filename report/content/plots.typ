#import "@preview/lilaq:0.5.0" as lq

#let data = json("../benchmarks.json")

#let is-mean(b) = b.run_type == "aggregate" and b.aggregate_name == "mean" and b.aggregate_unit == "time"
#let means = data.benchmarks.filter(is-mean)

// Extract image dimensions from benchmark names
#let get-dimensions(name) = {
  if str.contains(name, "640/480") { (640, 480) }
  else if str.contains(name, "1280/720") { (1280, 720) }
  else if str.contains(name, "1920/1080") { (1920, 1080) }
  else if str.contains(name, "3840/2160") { (3840, 2160) }
  else if str.contains(name, "7680/4320") { (7680, 4320) }
  else { none }
}

#let get-size-pixels(name) = {
  let dims = get-dimensions(name)
  if dims != none { dims.at(0) * dims.at(1) } else { none }
}

#let get-size-label(name) = {
  let dims = get-dimensions(name)
  if dims != none { 
    str(dims.at(0)) + "×" + str(dims.at(1))
  } else { 
    "unknown" 
  }
}

#let categorize(name) = {
  if str.contains(name, "CPU") { "CPU" }
  else if str.contains(name, "OpenMP") { "OpenMP" }
  else if str.contains(name, "MPI") { "MPI" }
  else { "GPU" }
}

// Prepare data for all results
#let all-by-size = means.map(b => (
    name: b.name,
    pixels: get-size-pixels(b.name),
    label: get-size-label(b.name),
    tp: b.bytes_per_second / 1e9,  // GiB/s
    cat: categorize(b.name)
  )).filter(d => d.pixels != none).sorted(key: d => d.pixels)

// Group by category, then by size
#let by-cat = (:) 
#{
  for item in all-by-size {
    let cat = item.cat
    if cat not in by-cat {
      by-cat.insert(cat, ())
    }
    by-cat.at(cat).push(item)
  }
}

// Extract unique pixel sizes and sort
#let unique-sizes = all-by-size.map(d => d.pixels).dedup().sorted()
// Create sorted list of categories
#let cat-order = ("CPU", "OpenMP", "MPI", "GPU")
#let cats-present = cat-order.filter(c => c in by-cat)

// === Plot 1: All Results ===
#let plot1-series = ()
#{
  for cat in cats-present {
    let cat-data = by-cat.at(cat).sorted(key: d => d.pixels)
    let x-vals = unique-sizes.map(sz => 
      cat-data.find(d => d.pixels == sz)
    )
    let y-vals = unique-sizes.map(sz => 
      cat-data.find(d => d.pixels == sz)
    )
    plot1-series.push((
      cat: cat,
      y: y-vals
    ))
  }
}

#let all-diagram = figure(
  lq.diagram(
    width: 100%,
    height: 8cm,
    xlabel: [Image Size],
    ylabel: [Throughput (GiB/s)],
    lq.xaxis(
      ticks: unique-sizes.enumerate().map(p => (
        p.at(0),
        [#all-by-size.filter(d => d.pixels == p.at(1)).first().label]
      )),
      subticks: none,
    ),
    lq.yaxis(),
    ..plot1-series.map(s => lq.plot(
      range(unique-sizes.len()),
      s.y,
      mark: "circle",
      stroke: 2pt,
      label: [#s.cat]
    ))
  ),
  caption: [All benchmark results: Throughput vs. Image Size],
)

// === Plot 2: Full Pipeline Results Only ===
#let fp-data = all-by-size.filter(d => str.contains(d.name, "FullPipeline"))
#let fp-by-cat = (:)
for item in fp-data {
  let cat = item.cat
  if cat not in fp-by-cat {
    fp-by-cat.insert(cat, ())
  }
  fp-by-cat.at(cat).push(item)
}

#let fp-sizes = fp-data.map(d => d.pixels).sorted().dedup()
#let fp-cats-present = cats-present.filter(c => c in fp-by-cat)

#let plot2-series = ()
for cat in fp-cats-present {
  let cat-data = fp-by-cat.at(cat).sorted(by: d => d.pixels)
  let y-vals = fp-sizes.map(sz =>
    cat-data.find(d => d.pixels == sz) |> (d => if d != none { d.tp } else { 0 })
  )
  plot2-series.push((
    cat: cat,
    y: y-vals
  ))
}

#let full-diagram = figure(
  lq.diagram(
    width: 100%,
    height: 8cm,
    xlabel: [Image Size],
    ylabel: [Throughput (GiB/s)],
    lq.xaxis(
      ticks: fp-sizes.enumerate().map(p => (
        p.at(0),
        [#fp-data.filter(d => d.pixels == p.at(1)).first().label]
      )),
      subticks: none,
    ),
    ..plot2-series.map(s => lq.plot(
      range(fp-sizes.len()),
      s.y,
      mark: "square",
      stroke: 2pt,
      label: [#s.cat]
    ))
  ),
  caption: [Full Pipeline benchmarks: Throughput vs. Image Size],
)

// === Plot 3: Best at 7680x4320 ===
#let max-pixels = 7680 * 4320
#let big-results = all-by-size.filter(d => d.pixels == max-pixels)

#let best-by-cat-7680 = (:)
for item in big-results {
  let cat = item.cat
  if cat not in best-by-cat-7680 {
    best-by-cat-7680.insert(cat, item)
  } else if item.tp > best-by-cat-7680.at(cat).tp {
    best-by-cat-7680.at(cat) = item
  }
}

#let bar-cats = ("CPU", "OpenMP", "MPI", "GPU").filter(c => c in best-by-cat-7680)
#let bar-vals = bar-cats.map(c => best-by-cat-7680.at(c).tp)
#let bar-labels = bar-cats.map(c => [#c])

#let best-diagram = figure(
  lq.diagram(
    width: 100%,
    height: 6cm,
    xlabel: [Implementation],
    ylabel: [Throughput (GiB/s)],
    lq.xaxis(
      ticks: bar-cats.enumerate().map(p => (
        p.at(0),
        [#p.at(1)]
      )),
      subticks: none,
    ),
    lq.bar(
      range(bar-cats.len()),
      bar-vals,
      fill: lq.cycle,
      width: 0.6,
      label: none
    )
  ),
  caption: [Best results at 7680×4320: CPU vs OpenMP vs MPI vs GPU],
)
