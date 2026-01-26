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

// Extract benchmark short name (without size)
#let get-bench-name(name) = {
  name.replace("BM_", "").split("/").at(0)
}

// Prepare data for all results with version numbers
// Group means by benchmark name (5 sizes per version)
#let bench-names = means.map(m => get-bench-name(m.name)).dedup()
#let num-versions = bench-names.len()

// Prepare data for all results
#let all-by-size = means.enumerate().map(p => {
  let i = p.at(0)
  let b = p.at(1)
  (
    name: b.name,
    bench-name: get-bench-name(b.name),
    version: calc.floor(i / 5) + 1,
    pixels: get-size-pixels(b.name),
    label: get-size-label(b.name),
    tp: b.bytes_per_second / 1e9,  // GiB/s
    cat: categorize(b.name)
  )
}).filter(d => d.pixels != none)

// Group by version
#let by-version = (:)
#{
  for item in all-by-size {
    let v = str(item.version)
    if v not in by-version {
      by-version.insert(v, (items: (), name: item.bench-name, cat: item.cat))
    }
    by-version.at(v).items.push(item)
  }
}

// Extract unique pixel sizes and sort
#let unique-sizes = all-by-size.map(d => d.pixels).dedup().sorted()

// Function to get size label
#let size-label(sz) = {
  if sz == 640 * 480 { $ 640 times 480$ }
  else if sz == 1280 * 720 { $ 1280 times 720$ }
  else if sz == 1920 * 1080 { $ 1920 times 1080$ }
  else if sz == 3840 * 2160 { $ 3840 times 2160$ }
  else if sz == 7680 * 4320 { $ 7680 times 4320$ }
  else { str(sz) }
}

// Create sorted list of categories
#let cat-order = ("CPU", "OpenMP", "MPI", "GPU")

// === Plot 1: All Results by Version ===
#let plot1-series = ()
#{
  for v in range(1, num-versions + 1) {
    let v-str = str(v)
    if v-str in by-version {
      let v-data = by-version.at(v-str)
      let items = v-data.items.sorted(key: d => d.pixels)
      let y-vals = unique-sizes.map(sz => {
        let item = items.find(d => d.pixels == sz)
        if item != none { item.tp } else { float.nan }
      })
      plot1-series.push((
        version: v,
        name: v-data.name,
        cat: v-data.cat,
        y: y-vals
      ))
    }
  }
}

#let all-diagram = figure(
  lq.diagram(
    cycle: lq.color.map.petroff10 + (rgb(25,25,25),rgb(255,211,0),  rgb(0,50,120), ),
    width: 100%,
    height: 9.5cm,
    xlabel: [Rozmiar obrazu (piksele)],
    ylabel: [Przepustowość (GiB/s), logarytmiczna],
    xscale: "log",
    yscale: "log",
    ylim: (0.1, auto),
    xaxis: (
      ticks: unique-sizes.map(sz => (sz, size-label(sz))),
      subticks: none,
    ),
    legend: (position: right + top),
    ..plot1-series.map(s => lq.plot(
      unique-sizes,
      s.y,
      mark: "o",
      label: [v#s.version]
    ))
  ),
  caption: [Wszystkie wyniki benchmarków],
)

// === Plot 2: Full Pipeline Results Only ===
#let fp-data = all-by-size.filter(d => str.contains(d.name, "FullPipeline"))

// Group full pipeline by version
#let fp-by-version = (:)
#{
  for item in fp-data {
    let v = str(item.version)
    if v not in fp-by-version {
      fp-by-version.insert(v, (items: (), name: item.bench-name, cat: item.cat))
    }
    fp-by-version.at(v).items.push(item)
  }
}

#let fp-sizes = fp-data.map(d => d.pixels).dedup().sorted()
#let fp-versions = fp-by-version.keys().map(int).sorted()

#let plot2-series = ()
#{
  for v in fp-versions {
    let v-str = str(v)
    if v-str in fp-by-version {
      let v-data = fp-by-version.at(v-str)
      let items = v-data.items.sorted(key: d => d.pixels)
      let y-vals = fp-sizes.map(sz => {
        let item = items.find(d => d.pixels == sz)
        if item != none { item.tp } else { float.nan }
      })
      plot2-series.push((
        version: v,
        name: v-data.name,
        cat: v-data.cat,
        y: y-vals
      ))
    }
  }
}

#let plot2-series-speedup = ()
#{
  for v in fp-versions {
    let v-str = str(v)
    if v-str in fp-by-version {
      let v-data = fp-by-version.at(v-str)
      let items = v-data.items.sorted(key: d => d.pixels)
      let y-vals = fp-sizes.map(sz => {
        let item = items.find(d => d.pixels == sz)
        if item != none { item.tp / by-version.at("1").items.find(d => d.pixels == sz).tp } else { float.nan }
      })
      plot2-series-speedup.push((
        version: v,
        name: v-data.name,
        cat: v-data.cat,
        y: y-vals
      ))
    }
  }
}

#let full-diagram = figure(
  lq.diagram(
    width: 100%,
    height: 10cm,
    xlabel: [Rozmiar obrazu (piksele)],
    ylabel: [Przepustowość (GiB/s), logarytmiczna],
    yscale: "log",
    xscale: "log",
    ylim: (0.1, auto),
    xaxis: (
      ticks: fp-sizes.map(sz => (sz, size-label(sz))),
      subticks: none,
    ),
    yaxis: (
      tick-args: (density: 200%)
    ),
    legend: (position: right + top),
    ..plot2-series.map(s => lq.plot(
      fp-sizes,
      s.y,
      mark: "s",
      label: [v#s.version (#s.cat)]
    ))
  ),
  caption: [Pełny pipeline przetwarzania obrazu],
)

#let full-diagram-speedup = figure(
  lq.diagram(
    width: 100%,
    height: 10cm,
    xlabel: [Rozmiar obrazu (piksele)],
    ylabel: [Przyspieszenie],
    xscale: "log",
    yscale: "log",
    ylim: (0.1, auto),
    xaxis: (
      ticks: fp-sizes.map(sz => (sz, size-label(sz))),
      subticks: none,
    ),
    yaxis: (
      tick-args: (density: 200%)
    ),
    legend: (position: right + top),
    ..plot2-series-speedup.map(s => lq.plot(
      fp-sizes,
      s.y,
      mark: "s",
      label: [v#s.version (#s.cat)]
    ))
  ),
  caption: [Pełny pipeline przetwarzania obrazu],
)


#let plot3-series = plot2-series.filter(t => t.cat != "GPU")
#let full-diagram-no-gpu = figure(
  lq.diagram(
    width: 100%,
    height: 10cm,
    xlabel: [Rozmiar obrazu (piksele)],
    ylabel: [Przepustowość (GiB/s)],
    // yscale: "log",
    xscale: "log",
    ylim: (0.1, auto),
    xaxis: (
      ticks: fp-sizes.map(sz => (sz, size-label(sz))),
      subticks: none,
    ),
    yaxis: (
      tick-args: (density: 100%)
    ),
    legend: (position: right + top),
    ..plot3-series.map(s => lq.plot(
      fp-sizes,
      s.y,
      mark: "s",
      label: [v#s.version (#s.cat)]
    ))
  ),
  caption: [Pełny pipeline przetwarzania obrazu (bez GPU)],
)

#let plot3-series-speedup = plot2-series-speedup.filter(t => t.cat != "GPU")
#let full-diagram-no-gpu-speedup = figure(
  lq.diagram(
    width: 100%,
    height: 10cm,
    xlabel: [Rozmiar obrazu (piksele)],
    ylabel: [Przyspieszenie],
    // yscale: "log",
    xscale: "log",
    ylim: (0.1, auto),
    xaxis: (
      ticks: fp-sizes.map(sz => (sz, size-label(sz))),
      subticks: none,
    ),
    yaxis: (
      tick-args: (density: 100%)
    ),
    legend: (position: right + top),
    ..plot3-series-speedup.map(s => lq.plot(
      fp-sizes,
      s.y,
      mark: "s",
      label: [v#s.version (#s.cat)]
    ))
  ),
  caption: [Pełny pipeline przetwarzania obrazu (bez GPU)],
)

// === Plot 3: Best at 7680x4320 ===
#let max-pixels = 7680 * 4320
#let big-results = all-by-size.filter(d => d.pixels == max-pixels)

#let best-by-cat-7680 = (:)
#{
  for item in big-results {
    let cat = item.cat
    if cat not in best-by-cat-7680 {
      best-by-cat-7680.insert(cat, item)
    } else if item.tp > best-by-cat-7680.at(cat).tp {
      best-by-cat-7680.at(cat) = item
    }
  }
}

#let bar-cats = ("CPU", "OpenMP", "MPI", "GPU").filter(c => c in best-by-cat-7680)
#let bar-vals = bar-cats.map(c => calc.ceil(best-by-cat-7680.at(c).tp))

#let best-diagram = figure(
  lq.diagram(
    width: 100%,
    height: 6cm,
    xlabel: [Implementacja],
    ylabel: [Przepustowość (GiB/s, logarytmiczna)],
    yscale: "log",
    
    ylim: (0.1, auto),
    xaxis: (
      ticks: bar-cats.enumerate().map(p => (p.at(0), p.at(1))),
      subticks: none,
    ),
    lq.bar(
      range(bar-cats.len()),
      bar-vals,
      width: 0.6,
      base: 0.01,
    )
  ),
  caption: [Najlepsze wyniki dla obrazu $7680 times 4320$ pikseli],
)

#let best-by-cat-7680-base = (:)
#{
  for item in big-results {
    let cat = item.cat
    if cat not in best-by-cat-7680-base {
      best-by-cat-7680-base.insert(cat, item)
    } else if item.tp > best-by-cat-7680-base.at(cat).tp and not item.name.contains("CPU_Unrolled") {
      best-by-cat-7680-base.at(cat) = item
    }
  }
}
#let bar-vals-base = bar-cats.map(c => calc.ceil(best-by-cat-7680-base.at(c).tp))

#let best-diagram-base = figure(
  lq.diagram(
    width: 100%,
    height: 6cm,
    xlabel: [Implementacja],
    ylabel: [Przepustowość (GiB/s, logarytmiczna)],
    yscale: "log",
    
    ylim: (0.1, auto),
    xaxis: (
      ticks: bar-cats.enumerate().map(p => (p.at(0), p.at(1))),
      subticks: none,
    ),
    lq.bar(
      range(bar-cats.len()),
      bar-vals-base,
      width: 0.6,
      base: 0.01,
    )
  ),
  caption: [Najlepsze wyniki dla obrazu $7680 times 4320$ pikseli],
)
