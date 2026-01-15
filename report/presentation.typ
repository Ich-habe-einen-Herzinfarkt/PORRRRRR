#import "@preview/touying:0.6.1": *
#import "@local/wut-thesis:0.1.8": wut-presentation, title-slide, slide, focus-slide
#import "@preview/codly:1.3.0": *
#import "@preview/numbly:0.1.0": numbly
#import "content/plots.typ": all-diagram, full-diagram, best-diagram, full-diagram-no-gpu

// Load benchmark data and calculate speedups
#let data = json("benchmarks.json")
#let is-mean(b) = b.run_type == "aggregate" and b.aggregate_name == "mean" and b.aggregate_unit == "time"
#let means = data.benchmarks.filter(is-mean)

// Get FullPipeline results for 7680x4320 (largest image)
#let get-fp-mean(name-pattern) = {
  means.find(m => str.contains(m.name, name-pattern) and str.contains(m.name, "7680/4320"))
}

#let cpu-baseline = get-fp-mean("FullPipeline_CPU")
#let openmp-result = get-fp-mean("FullPipeline_OpenMP")
#let mpi-result = get-fp-mean("FullPipeline_MPI")
#let sycl-result = get-fp-mean("FullPipeline_SYCL")

// Calculate speedups (based on throughput - higher is better)
#let openmp-speedup = calc.round(openmp-result.bytes_per_second / cpu-baseline.bytes_per_second, digits: 2)
#let mpi-speedup = calc.round(mpi-result.bytes_per_second / cpu-baseline.bytes_per_second, digits: 2)
#let sycl-speedup = calc.round(sycl-result.bytes_per_second / cpu-baseline.bytes_per_second, digits: 1)

// Use local bytes formatter for nicer units
#import "@local/bytes:1.2.0": format-bytes, format-bytes-rate

#set text(
  lang: "pl",
  font: "Adagio_Slab"
)
#show: codly-init.with()
#show: wut-presentation.with(
  aspect-ratio: "16-9",
  config-info(
    title: [Operacja splotu na obrazie z wykorzystaniem filtra do wykrywania krawędzi],
    subtitle: [Zrównoleglenie z użyciem OpenMP, MPI i SYCL],
    author: ("Jakub Bliźniuk", "Mateusz Szyperek", "Kalina Białek"),
    date: datetime.today(),
    institution: [Politechnika Warszawska],
    font: "Source Sans Pro"
  ),
)
#show heading: text.with(font: "Source Serif Pro")
#set heading(numbering: numbly("{1}.", default: "1.1"))

#title-slide()
#components.adaptive-columns(outline(indent: 1em, title: "Agenda", depth: 1))
#set align(horizon)
#set par(leading: 0.65em)

= Wprowadzenie

== Problem

#slide[
  - Wybrany operator: *Sobel* (1968)
  - Wykorzystuje dyskretne różniczkowanie do aproksymacji gradientu intensywności obrazu
  - Krawędzie = nagłe zmiany intensywności

  #pause

  Używa dwóch jąder konwolucji $3 times 3$:
  #[
    #set math.mat(delim: "[")
    $ G_x = mat(-1, 0, 1; -2, 0, 2; -1, 0, 1) * A quad quad G_y = mat(-1, -2, -1; 0, 0, 0; 1, 2, 1) * A $
    $ G = sqrt(G_x^2 + G_y^2) $
  ]
]

== Potencjał do zrównoleglenia

#slide[
  #pause
  - Obliczenia wykonywane *niezależnie dla każdego piksela*
  #pause
  - Brak zależności między wynikami sąsiednich pikseli
  #pause
  - Idealny kandydat do przetwarzania równoległego

  #v(1em)

  #figure(
    grid(
      columns: 2,
      gutter: 1em,
      image("images/Bikesgray.png", width: 80%),
      image("images/Bikesgraysobel.png", width: 80%),
    ),
    caption: [Obraz wejściowy (szarość) $->$ wynik operatora Sobela]
  )
]

= Narzędzia do zrównoleglania

== Wykorzystane technologie

#slide[
  #show list: text.with(size: 32pt)
  
  #pause
  - *OpenMP* -- dyrektywy kompilatora dla systemów z dzieloną pamięcią
  #pause
  - *MPI* -- przekazywanie wiadomości między procesami
  #pause
  - *SYCL* (AdaptiveCpp) -- programowanie GPU w C++
  
  #v(1em)
  #pause
  
  *Platforma testowa:*
  - CPU: AMD Ryzen 9 7900X (12 rdzeni / 24 wątki)
  - GPU: AMD Radeon RX 7800 XT
]

= Implementacje

== Wersja sekwencyjna

#slide[
  Bazowa implementacja -- naiwna konwolucja:

  #figure(```cpp
ImageF convolve(const ImageF &in, int w, int h, 
                const std::vector<float>& kernel, int kw, int kh){
    ImageF out(w*h, 0.0f);
    int padX = kw/2, padY = kh/2;
    for(int y=0;y<h;++y){
        for(int x=0;x<w;++x){
            float s = 0.0f;
            for(int ky=0; ky<kh; ++ky){
                for(int kx=0; kx<kw; ++kx){
                    int ix = x + kx - padX;
                    int iy = y + ky - padY;
                    if(ix>=0 && ix<w && iy>=0 && iy<h){
                        s += in[idx(ix,iy,w)] * kernel[ky*kw + kx];
                    }
                }
            }
            out[idx(x,y,w)] = s;
        }
    }
    return out;
}
  ```)
]

== OpenMP -- przyspieszenie #openmp-speedup×

#slide[
  Minimalne zmiany -- jedna dyrektywa `#pragma`:

  #figure(```cpp
ImageF convolve(const ImageF &in, int w, int h,
                const std::vector<float> &kernel, int kw, int kh) {
  ImageF out(w * h, 0.0f);
  int padX = kw / 2, padY = kh / 2;
  
  #pragma omp parallel for schedule(static) default(none) \
      shared(in, out, w, h, kernel, kw, kh, padX, padY)
  for (int i = 0; i < w * h; ++i) {
      int x = i % w;
      int y = i / w;
      float sum = 0.0f;
      for (int ky = 0; ky < kh; ++ky) {
          for (int kx = 0; kx < kw; ++kx) {
              int ix = x + kx - padX;
              int iy = y + ky - padY;
              if (ix >= 0 && ix < w && iy >= 0 && iy < h) {
                  sum += in[idx(ix, iy, w)] * kernel[ky * kw + kx];
              }
          }
      }
      out[i] = sum;
  }
  return out;
}
  ```)
]

== MPI -- przyspieszenie #mpi-speedup×

#slide[
  Model przekazywania wiadomości -- podział obrazu między procesy:

  #figure(```cpp
// Rozdzielenie obrazu
int rows_per_process = height / num_processes;
int remainder = height % num_processes;
int local_height = end_row - start_row;

// Wysłanie fragmentów do procesów
MPI_Scatterv(
    data, sendcounts.data(), displs.data(), MPI_UNSIGNED_CHAR,
    local_data.data(), local_height * width * channels, MPI_UNSIGNED_CHAR,
    0, MPI_COMM_WORLD
);

// ... przetwarzanie lokalne ...

// Zebranie wyników
MPI_Gatherv(output.data(), local_height * width, MPI_FLOAT, 
            final_result.data(), recvcounts.data(), displs_v2.data(), 
            MPI_FLOAT, 0, MPI_COMM_WORLD);
  ```)

  #pause
  *Uwaga:* Wymaga wymiany wierszy granicznych między procesami!
]

== SYCL (GPU) -- przyspieszenie #sycl-speedup×

#slide[
  Zoptymalizowany kernel -- 2 piksele na wątek:

  #figure(```cpp
queue.parallel_for<sobel_kernel>(
    sycl::nd_range<2>(
        sycl::range<2>(globalY, globalX),
        sycl::range<2>(WG_Y, WG_X)  // 128x1 work-groups (RDNA3)
    ),
    [=](sycl::nd_item<2> item) {
        int y = item.get_global_id(0);
        int x0 = item.get_global_id(1) * 2;  // 2 piksele na wątek
        
        #pragma unroll
        for (int dx = 0; dx < 2; ++dx) {
            int x = x0 + dx;
            // Unrolled Sobel computation...
            float gx = -p00 + p02 - 2.0f*p10 + 2.0f*p12 - p20 + p22;
            float gy = -p00 - 2.0f*p01 - p02 + p20 + 2.0f*p21 + p22;
            mag[y * w + x] = sycl::native::sqrt(gx*gx + gy*gy);
        }
    }
);
  ```)
]

= Wyniki

== Wszystkie implementacje

#slide[
  #set text(size: 18pt)
  #all-diagram

  *Uwaga:* Skala logarytmiczna -- GPU dominuje o ~300x!
]

== Pełny pipeline przetwarzania

#slide[
  #set text(size: 18pt)
  #full-diagram

  Pełne przetwarzanie: szarość → Sobel → normalizacja
]

== CPU: OpenMP vs MPI

#slide[
  #set text(size: 18pt)
  #full-diagram-no-gpu

  #pause
  
  *Zaskoczenie:* MPI lepsze niż OpenMP mimo narzutu komunikacji!
]

== Porównanie najlepszych wyników (7680×4320)

#slide[
  #set text(size: 18pt)
  #best-diagram

  #v(1em)
  
  #table(
    columns: (auto, auto, auto),
    inset: 8pt,
    align: center,
    [*Metoda*], [*Przepustowość*], [*Przyspieszenie*],
    [CPU (sekw.)], [#format-bytes-rate[#cpu-baseline.bytes_per_second]], [1×],
    [OpenMP], [#format-bytes-rate[#openmp-result.bytes_per_second]], [#openmp-speedup×],
    [MPI], [#format-bytes-rate[#mpi-result.bytes_per_second]], [#mpi-speedup×],
    [GPU (SYCL)], [#format-bytes-rate[#sycl-result.bytes_per_second]], [#sycl-speedup×],
  )
]

== Kluczowe obserwacje

#slide[
  #show list: text.with(size: 28pt)
  
  #pause
  - GPU osiąga *#format-bytes-rate[#sycl-result.bytes_per_second]* (blisko limitu 624 GiB/s pamięci karty)
  #pause
  - Zoptymalizowana wersja sekwencyjna *bije naiwne wersje równoległe*
  #pause
  - Optymalizacja algorytmu ważniejsza niż ślepe zrównoleglenie
  #pause
  - MPI (#mpi-speedup×) > OpenMP (#openmp-speedup×) dla tego problemu
  #pause
  - Kafelkowanie (tiling) nie pomogło -- za małe kafelki
]

= Wnioski

== Podsumowanie

#slide[
  #show list: text.with(size: 26pt)
  
  #pause
  - *Wszystkie 3 metody* osiągnęły przyspieszenie > 1 dla pełnego pipeline'u
  #pause
  - *GPU (SYCL)* -- najlepsze wyniki, #sycl-speedup× przyspieszenie
  #pause
  - *MPI* -- zaskakująco dobre wyniki na CPU (#mpi-speedup×)
  #pause
  - *OpenMP* -- najprostsze do implementacji (#openmp-speedup×)
  #pause
  - *Optymalizacja algorytmu* może dać większe zyski niż zrównoleglenie

  #v(1em)
  #pause
  
  #align(center)[
    #text(size: 24pt, weight: "bold")[
      _"Z wolnym algorytmem nie jest w stanie pomóc żadne rozwiązanie do rozpraszania obliczeń"_
    ]
  ]
]

== Dziękuję za uwagę!

#focus-slide[
  *Pytania?*
  
  #v(2em)
  
  Kod źródłowy: #link("https://github.com/Ich-habe-einen-Herzinfarkt/PORRRRRR")[GitHub]
]
