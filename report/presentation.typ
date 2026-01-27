#import "@preview/touying:0.6.1": *
#import "@local/wut-thesis:0.1.11": wut-presentation, title-slide, slide, focus-slide
#import "@preview/codly:1.3.0": *
#import "@preview/numbly:0.1.0": numbly
#import "content/plots.typ": all-diagram, full-diagram, best-diagram, full-diagram-no-gpu, full-diagram-speedup, full-diagram-no-gpu-speedup, best-diagram-base
#import "@local/bytes:1.2.0": format-bytes, format-bytes-rate
#import "@preview/rustycure:0.2.0": qr-code
#import "utils.typ": todo


// Load benchmark data and calculate speedups
#let data = json("benchmarks.json")
#let is-mean(b) = b.run_type == "aggregate" and b.aggregate_name == "mean" and b.aggregate_unit == "time"
#let means = data.benchmarks.filter(is-mean)

// Get FullPipeline results for 7680x4320 (largest image)
#let get-fp-mean(name-pattern) = {
  means.find(m => str.contains(m.name, name-pattern) and str.contains(m.name, "7680/4320"))
}

// Full pipeline results (for slide header speedups)
#let cpu-baseline = get-fp-mean("FullPipeline_CPU")
#let openmp-result = get-fp-mean("FullPipeline_OpenMP")
#let mpi-result = get-fp-mean("FullPipeline_MPI")
#let sycl-result = get-fp-mean("FullPipeline_SYCL")

// Best kernel-only results (for comparison table)
#let cpu-kernel = get-fp-mean("BM_Sobel_CPU")
#let cpu-kernel-unrolled = get-fp-mean("BM_Sobel_CPU_Unrolled")

#let openmp-kernel = get-fp-mean("BM_Sobel_OpenMP")
#let mpi-kernel = get-fp-mean("BM_Sobel_MPI")
#let sycl-kernel = get-fp-mean("BM_Sobel_Optimized_Combo")

// Calculate speedups
// Full pipeline speedups (for slide headers)
#let openmp-speedup = calc.round(openmp-result.bytes_per_second / cpu-baseline.bytes_per_second, digits: 2)
#let mpi-speedup = calc.round(mpi-result.bytes_per_second / cpu-baseline.bytes_per_second, digits: 2)
#let sycl-speedup = calc.round(sycl-result.bytes_per_second / cpu-baseline.bytes_per_second, digits: 1)

// Kernel-only speedups (for comparison table)
#let openmp-kernel-speedup = calc.round(openmp-kernel.bytes_per_second / cpu-kernel.bytes_per_second, digits: 2)
#let mpi-kernel-speedup = calc.round(mpi-kernel.bytes_per_second / cpu-kernel.bytes_per_second, digits: 2)
#let sycl-kernel-speedup = calc.round(sycl-kernel.bytes_per_second / cpu-kernel.bytes_per_second, digits: 1)

#let openmp-kernel-speedup-unrolled = calc.round(openmp-kernel.bytes_per_second / cpu-kernel-unrolled.bytes_per_second, digits: 2)
#let mpi-kernel-speedup-unrolled = calc.round(mpi-kernel.bytes_per_second / cpu-kernel-unrolled.bytes_per_second, digits: 2)
#let sycl-kernel-speedup-unrolled = calc.round(sycl-kernel.bytes_per_second / cpu-kernel-unrolled.bytes_per_second, digits: 1)


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
    author: [Jakub Bliźniuk, Mateusz Szyperek, Kalina Białek],
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
      image("images/input-hdd.webp", height: 50%),
      image("images/output-hdd.webp", height: 50%),
    ),
    caption: [Obraz wejściowy $->$ wynik operatora Sobela],
  )
]

#figure(
    grid(
      columns: 2,
      gutter: 1em,
      image("images/input_bis.webp", height: 80%),
      image("images/output_bis.webp", height: 80%),
    ),
    caption: [Obraz wejściowy $->$ wynik operatora Sobela],
  )

= Narzędzia do zrównoleglania

== Wykorzystane technologie

#slide[
  #show list: text.with(size: 32pt)
  
  - *OpenMP*
  - *MPI* 
  - *SYCL* (AdaptiveCpp)
  
  #pause
  
  *Platforma testowa:*
  - CPU: AMD Ryzen 9 7900X (12 rdzeni / 24 wątki)
  - GPU: AMD Radeon RX 7800 XT
]

= Implementacje

== Wersja sekwencyjna

#show raw: set block(breakable: true)
#show figure: set block(breakable: true)
#slide[
  Bazowa implementacja -- naiwna konwolucja:
  #set text(size: 12pt)
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

== OpenMP -- przyspieszenie #openmp-speedup$times$

#slide[
  - Minimalna ingerencja w kod - wystarczy dodać jedną dryrektywę `#pragma`.
  - Rozdzielenie pętli – pętla po pikselach (`for (int i = 0; i < w*h; ++i)`) jest podzielona między wątki.
  - Statyczny podział – `schedule(static)` zapewnia równomierny podział iteracji, co jest korzystne przy stałym koszcie obliczeniowym per piksel.
  - Współdzielone zasoby – obrazy wejściowy i wyjściowy, rozmiary oraz kernel są przekazywane jako `shared`, co eliminuje niepotrzebne kopiowanie.  

]
#slide[
  #set text(size: 12pt)
  #figure(```cpp
ImageF convolve(const ImageF &in, int w, int h,
                const std::vector<float> &kernel, int kw, int kh) {
  ImageF out(w * h, 0.0f);
  int padX = kw / 2, padY = kh / 2;
  
  #pragma omp parallel for schedule(static) default(none) shared(in, out, w, h, kernel, kw, kh, padX, padY)
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
== MPI -- przyspieszenie #mpi-speedup$times$

#slide[
  Model przekazywania wiadomości -- podział obrazu między procesy:
  #set text(size: 13pt)
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

== SYCL (GPU) -- kilka wersji  

#slide[
  - Zoptymalizowany kernel
    - przyspieszenie #sycl-speedup$times$
    - zoptymalizowana pod Sobela wersja konwolucji
    - grupowanie po 128 wątków
    - obliczanie 2 pikseli na wątek
  #pause
  - Bazowa wersja algorytmu
    - Znacząco wolniejsza od zoptymalizowanej!
    - Przy okazji tworzenia tego rozwiązania powstała szybsza wersja
  #pause
  - Bufory zamiast Unified Shared Memory
    - abstrakcja koncepcyjnie do problemu lepiej pasowała, ale była wolniejsza
  #pause
  - Podejście do tilingu
    - *powinno* być możliwe uzyskanie wyższej wydajności
    - w praktyce moje podejścia się nie udały i były wolniejsze niż wersja finalna
]

== Końcowa wersja SYCL
#slide[
  #set text(size: 14pt)
  #columns(2)[
```cpp
queue.parallel_for<sobel_kernel>(
      sycl::nd_range<2>(
          sycl::range<2>(globalY, globalX),
          sycl::range<2>(WG_Y, WG_X)
      ),
      [=](sycl::nd_item<2> item) {
          int y = item.get_global_id(0);
          int x0 = item.get_global_id(1) * 2;
          if (y >= h) return;
          #pragma unroll
          for (int dx = 0; dx < PIXELS_PER_WI; ++dx) {
              int x = x0 + dx;
              if (x >= w) continue;
              if (x > 0 && y > 0 && x < w - 1 && y < h - 1) {
                  float p00 = gray[(y-1) * w + (x-1)];
                  float p01 = gray[(y-1) * w + x];
                  float p02 = gray[(y-1) * w + (x+1)];
                  float p10 = gray[y * w + (x-1)];
                  float p12 = gray[y * w + (x+1)];
                  float p20 = gray[(y+1) * w + (x-1)];
                  float p21 = gray[(y+1) * w + x];
                  float p22 = gray[(y+1) * w + (x+1)];

                  float gx = -p00 + p02 - 2.0f * p10 + 2.0f * p12 - p20 + p22;
                  float gy = -p00 - 2.0f * p01 - p02 + p20 + 2.0f * p21 + p22;

                  mag[y * w + x] = sycl::native::sqrt(gx * gx + gy * gy);
              } else {
                  mag[y * w + x] = 0.0f;
              }
          }
      }
  );
```
  ]
]



  
= Wyniki

== Wszystkie implementacje

#slide[
  #set text(size: 18pt)
  #all-diagram

  *Uwaga:* Skala logarytmiczna
]

== Pełny pipeline przetwarzania

#slide[
  #set text(size: 18pt)
  #full-diagram

  Pełne przetwarzanie: szarość $->$ Sobel $->$ normalizacja
]

== Pełny pipeline (przyspieszenie)
#slide[
  #full-diagram-speedup 
]

== CPU: OpenMP vs MPI

#slide[
  #set text(size: 18pt)
  #full-diagram-no-gpu

  #pause
  
  *Zaskoczenie:* MPI lepsze niż OpenMP mimo narzutu komunikacji!
]

== CPU: OpenMP vs MPI (przyspieszenie)
#slide[
  #full-diagram-no-gpu-speedup 
]

== Porównanie wyników (sobel 7680$times$4320)

#let nproc = 24

#slide[
  #set text(size: 18pt)
  #best-diagram-base
]
#slide[
  #place(horizon + center,
  table(
    columns: (auto, auto, auto, auto),
    inset: 8pt,
    align: center,
    [*Metoda*], [*Przepustowość*], [*Przyspieszenie*], [*Wydajność*],
    [CPU (sekw.)], [#format-bytes-rate[#cpu-kernel.bytes_per_second]], [1$times$], [#calc.round(1/1, digits: 4)],
    [OpenMP], [#format-bytes-rate[#openmp-kernel.bytes_per_second]], [#openmp-kernel-speedup$times$], [#calc.round(openmp-kernel-speedup/nproc, digits: 4)],
    [MPI], [#format-bytes-rate[#mpi-kernel.bytes_per_second]], [#mpi-kernel-speedup$times$], [#calc.round(mpi-kernel-speedup/nproc, digits: 4)],
    [GPU (SYCL)], [#format-bytes-rate[#sycl-kernel.bytes_per_second]], [#sycl-kernel-speedup$times$], [n/a#footnote[Niestety sprawdzenie zajętości na GPU wymagało by w praktyce wykorzystania profilera, którego nie udało się na testowym systemie uruchomić]]
  ))
]

== Porównanie ze zoptymalizowaną wersją CPU

#let nproc = 24

#slide[
  #set text(size: 18pt)
  #best-diagram
]
#slide[
  #place(horizon + center,
  table(
    columns: (auto, auto, auto, auto),
    inset: 8pt,
    align: center,
    [*Metoda*], [*Przepustowość*], [*Przyspieszenie*], [*Wydajność*],
    [CPU (sekw.)], [#format-bytes-rate[#cpu-kernel-unrolled.bytes_per_second]], [1$times$], [#calc.round(1/1, digits: 4)],
    [OpenMP], [#format-bytes-rate[#openmp-kernel.bytes_per_second]], [#openmp-kernel-speedup-unrolled$times$], [#calc.round(openmp-kernel-speedup-unrolled/nproc, digits: 4)],
    [MPI], [#format-bytes-rate[#mpi-kernel.bytes_per_second]], [#mpi-kernel-speedup-unrolled$times$], [#calc.round(mpi-kernel-speedup-unrolled/nproc, digits: 4)],
    [GPU (SYCL)], [#format-bytes-rate[#sycl-kernel.bytes_per_second]], [#sycl-kernel-speedup-unrolled$times$], [n/a#footnote[Niestety sprawdzenie zajętości na GPU wymagało by w praktyce wykorzystania profilera, którego nie udało się na testowym systemie uruchomić]]
  ))
]

== Kluczowe obserwacje

#slide[
  #show list: text.with(size: 28pt)
  
  - konwolucja na GPU osiąga *#format-bytes-rate[#sycl-kernel.bytes_per_second]* (już dość blisko 624 GiB/s przepustowości pamięci karty)
  #pause
  - Zoptymalizowana wersja sekwencyjna *jest szybsza niż naiwne wersje równoległe*
  #pause
  - Optymalizacja algorytmu potrafi być ważniejsza niż zrównoleglenie
  #pause
  - MPI (#mpi-speedup$times$) > OpenMP (#openmp-speedup$times$) dla tego problemu i implementacji
  #pause
  - Naiwne kafelkowanie (tiling) na GPU nie pomogło
]

= Wnioski

== Podsumowanie

#slide[
  #show list: text.with(size: 26pt)
  
  #pause
  - *Wszystkie 3 metody* osiągnęły przyspieszenie > 1 dla pełnego pipeline'u
  #pause
  - *GPU (SYCL)* -- najlepsze wyniki, #sycl-speedup$times$ przyspieszenie
  #pause
  - *MPI* -- zaskakująco dobre wyniki na CPU (#mpi-speedup$times$)
  #pause
  - *OpenMP* -- najprostsze do implementacji (#openmp-speedup$times$)
  #pause
  - *Optymalizacja algorytmu* może dać większe zyski niż zrównoleglenie

  #v(1em)
]

= Pytania

#focus-slide[
  #set text(size: 40pt)
  #place(top+center)[Kod źródłowy: #link("https://github.com/Ich-habe-einen-Herzinfarkt/PORRRRRR")]
  #place(bottom + center, qr-code("https://github.com/Ich-habe-einen-Herzinfarkt/PORRRRRR", light-color: rgb("#006872"), dark-color: white, height: 60%, quiet-zone: false))
  
]

= Dodatek: przyspieszanie z użyciem instrukcji wektorowych

== Oryginalny kod

#columns(2)[
  #set text(size: 14pt)
  ```cpp
  for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            float s = 0.0f;
            for (int ky = 0; ky < kh; ++ky) {
                for (int kx = 0; kx < kw; ++kx) {
                    int ix = x + kx - padX;
                    int iy = y + ky - padY;
                    if (ix >= 0 && ix < w && iy >= 0 && iy < h) {
                        s += in[idx(ix, iy, w)] * kernel[ky * kw + kx];
                    }
                }
            }
            out[idx(x, y, w)] = s;
        }
    }
  ```
  #colbreak()
  #set text(size: 9pt)
  ```asm
[...]
        lea     edx, [r13 + r10 + 7]
        cmp     edx, r14d
        jae     .LBB2_39
        cmp     edi, ebp
        jae     .LBB2_39
        lea     edx, [rcx + r10 + 7]
        vmovss  xmm1, dword ptr [r15 + 4*rdx]
        vfmadd231ss     xmm0, xmm1, dword ptr [r12 + 4*r10]
        jmp     .LBB2_39
.LBB2_41:
        mov     rdx, qword ptr [rsp + 24]
        lea     ebx, [rcx + r10]
        lea     rsi, [rdx + 4*r10]
        add     r10d, r13d
        xor     edx, edx
        jmp     .LBB2_42
        inc     rdx
        cmp     r11, rdx
        je      .LBB2_46
.LBB2_42:
        lea     r9d, [r10 + rdx]
        cmp     r9d, r14d
        jae     .LBB2_45
        cmp     edi, ebp
        jae     .LBB2_45
        lea     r9d, [rbx + rdx]
        vmovss  xmm1, dword ptr [r15 + 4*r9]
        vfmadd231ss     xmm0, xmm1, dword ptr [rsi + 4*rdx]
        jmp     .LBB2_45
[...]
  ```
]

== Wersja przyspieszona - AVX

#columns(2)[
  #set text(size:12pt)
  ```cpp
  for (int y = 1; y < h - 1; ++y) {
    for (int x = 1; x < w - 1; ++x) {
        float p00 = gray[(y-1) * w + (x-1)];
        float p01 = gray[(y-1) * w + x];
        float p02 = gray[(y-1) * w + (x+1)];
        float p10 = gray[y * w + (x-1)];
        float p12 = gray[y * w + (x+1)];
        float p20 = gray[(y+1) * w + (x-1)];
        float p21 = gray[(y+1) * w + x];
        float p22 = gray[(y+1) * w + (x+1)];

        float dx = -p00 + p02 - 2.0f * p10 + 2.0f * p12 - p20 + p22;
        float dy = -p00 - 2.0f * p01 - p02 + p20 + 2.0f * p21 + p22;

        mag[y * w + x] = std::sqrt(dx * dx + dy * dy);
    }
  }
  ```
  #colbreak()
  #set text(size: 9pt)
  ```asm
  [...]
  .LBB2_13:
        call    sqrtf@PLT
        vmovss  xmm4, dword ptr [rip + .LCPI2_20]
        vmovss  xmm3, dword ptr [rip + .LCPI2_19]
        vxorps  xmm5, xmm5, xmm5
        [...]
        vmovss  xmm4, dword ptr [rip + .LCPI2_20]
        vmovss  xmm3, dword ptr [rip + .LCPI2_19]
        vxorps  xmm5, xmm5, xmm5
.LBB2_11:
        vmovss  dword ptr [r15 + 4*rbp], xmm0
        vmovss  xmm0, dword ptr [r13 + 4*rbp - 30712]
        vfmsub213ss     xmm8, xmm3, xmm7
        vmovss  xmm1, dword ptr [r13 + 4*rbp + 30728]
        vsubss  xmm2, xmm0, xmm7
        vfmadd231ss     xmm2, xmm3, dword ptr [r13 + 4*rbp]
        vsubss  xmm0, xmm8, xmm0
        vaddss  xmm0, xmm9, xmm0
        vfmadd231ss     xmm2, xmm4, dword ptr [r13 + 4*rbp + 8]
        vfmadd213ss     xmm6, xmm4, xmm0
        vaddss  xmm0, xmm6, xmm1
        vmulss  xmm0, xmm0, xmm0
        vsubss  xmm2, xmm2, xmm9
        vaddss  xmm2, xmm2, xmm1
        vfmadd231ss     xmm0, xmm2, xmm2
        vucomiss        xmm0, xmm5
        jb      .LBB2_13
        vsqrtss xmm0, xmm0, xmm0
        jmp     .LBB2_14
  [...]
  ```
  
]