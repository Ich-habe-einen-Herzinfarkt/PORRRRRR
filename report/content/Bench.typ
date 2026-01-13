#import "../utils.typ": todo, silentheading, flex-caption, enable-referable-enums, referable-enum
#import "plots.typ": all-diagram, full-diagram, best-diagram

= Benchmarki <bench>

W gałęzi `main` znajduje się także program do testowania wydajności implementacji wykorzystując bibliotekę Benchmark od Google@google_benchmark.

Jako platformę testową wykorzystaliśmy komputer klasy desktop z procesorem AMD Ryzen#sym.trademark 9 7900X i procesorem graficznym AMD Radeon RX 7800 XT. Testy zostały wykonane na systemie NixOS 25.11 z kernelem Linux w wersji 6.17.

Testowane były wersje AdaptiveCpp (SYCL) 25.02.0, LLVM/OpenMP 21.1.7 i MPI 5.0.9 zainstalowane z repozytorium NixPkgs.
#show: enable-referable-enums
#[
  #set enum(numbering: "(v1)", full: true)
  #referable-enum("")[
  + bazowa implementacja wersji sekwencyjnej
  
  + implementacja wersji sekwencyjnej po zoptymalizowaniu wewnętrznej pętli

  + zrównoleglona implementacja bazowej wersji sekwencyjnej z użyciem OpenMP

  + zrównoleglona implementacja bazowej wersji sekwencyjnej z użyciem MPI
  
  + zrównoleglona implementacja bazowej wersji sekwencyjnej z użyciem `SYCL` z użyciem buforów (starsza abstrakcja dzielenia pamięci między `CPU`/`GPU`)#footnote[Obecnie bufory nie są rekomendowane przez gorszą wydajność — kompilator nawet ostrzega przed ich użyciem]
  
  + zrównoleglona implementacja zoptymalizowanej wersji sekwencyjnej z użyciem `SYCL` z użyciem buforów (starsza abstrakcja dzielenia pamięci między `CPU`/`GPU`)
  
  + zrównoleglona implementacja zoptymalizowanej wersji sekwencyjnej z użyciem`SYCL` z użyciem USM (nowsza abstrakcja dzielenia pamięci między `CPU`/`GPU`)
  
  + zrównoleglona implementacja zoptymalizowanej wersji sekwencyjnej z użyciem `SYCL` i korzystająca z tilingu#footnote[Podział zadania na grupy wątków (kafelki), gdzie każda grupa najpierw ładuje swoje dane do lokalnej pamięci, czeka na synchronizację, a później wykonuje operacje na lokalnych danych]
  
  + zoptymalizowana zrównoleglona implementacja z użyciem na USM, przetwarzająca po dwa piksele na wątek; uproszczona<final-version> 
  
  + pełne przetwarzanie obrazu sekwencyjnie, wliczając przetwarzanie pikseli na skalę szarości i normalizację wyniku


  + pełne przetwarzanie obrazu 
  
  + pełne przetwarzanie obrazu zrównoleglone przez `SYCL` na GPU z użyciem kernela z @final-version
]
]

Dla każdego wariantu wykonano benchmark dla pięciu różnych rozdzielczości obrazów:
- $640 times 480$
-	$1280 times 720$
-	$1920 times 1080$
-	$3840 times 2160$
-	$7680 times 4320$

// #todo[Zaktualizować wykres]
// #figure(image("../images/line_graph.png"), caption: [
// 	Przepustowość benchmarków dla różnych rozdzielczości obrazów
// ])

#all-diagram

#todo[Opisać też MPI i OpenMP]
Możemy zauważyć, że w porównaniu do wersji na GPU nasza podstawowa wersja sekwencyjna działa bardzo wolno. Nawet z optymalizacją pętli remisuje tylko z jednym wariantem `GPU` — najwolniejszym testowanym (v3), korzystającym z mniej wydajnej abstrakcji pamięci i pierwotnej implementacji Sobela. Tę przewagę widać jedynie przy najmniejszym testowanym rozmiarze obrazów, gdzie wpływ kosztów stałych implementacji na `GPU` jest większy.

Dlaczego implementacja na procesorze graficznym może osiągać tak znacząco lepsze wyniki? Jest to konsekwencja adekwatności programu do alternatywnej, znacznie bardziej równoległej architektury `GPU`.

W przeciwieństwie do procesorów, które zawierają kilka do kilkudziesięciu (obecnie do 192 w niektórych procesorach serwerowych, choć w najbliższym czasie oczekiwane jest pojawienie się na rynku procesorów z nawet 256 rdzeniami) rdzeni, każdy z dużą pamięcią podręczną i zaawansowaną logiką do przyspieszania operacji sekwencyjnych, procesory graficzne wykorzystują bardzo dużą liczbę małych rdzeni, liczoną w tysiącach nawet po stronie konsumenckiej. Pojedynczy rdzeń jest jednak bardziej ograniczony niż w przypadku `CPU` i znacznie bardziej polega się na współdzieleniu zasobów (szczególnie pamięci) między rdzeniami, grupując je zwykle nawet w najmniejszym bloku w 32 lub 64 jednostki (warp w terminologii Nvidii i wavefront w terminologii AMD).

Ta liczba rdzeni oznacza, że zadania, które łatwo jest podzielić na bardzo wiele wątków — tak jak większość operacji na grafice — możemy przyspieszyć nawet setki razy względem `CPU`.

Dlaczego więc, poza oczywistymi ograniczeniami skalowania przy wzroście liczby wątków dla naszych problemów, nie wszystkie implementacje działają znacząco szybciej i dlaczego nie wykorzystujemy `GPU` do wszystkiego? W przypadku programowania `GPU` częstym ograniczeniem wydajności są czasy dostępu do różnych poziomów pamięci. W środowisku heterogennym dochodzi potrzeba zaprojektowania sposobu przeniesienia danych z procesora na akcelerator.

Wykorzystywany tu `SYCL` zapewnia dwie abstrakcje mające to ułatwić: bufory, które zapewniają prosty interfejs programistyczny, ale okazały się trudniejsze do optymalizacji, oraz Unified Shared Memory, zapewniającą dostęp wskaźnikowy do pamięci współdzielonej i możliwość manualnego zarządzania alokacją pamięci na urządzeniach. Koszt kopiowania pamięci na urządzenie jest znaczącym stałym kosztem i ma duży wpływ na wydajność rozwiązania.

Kolejnym aspektem wpływającym na wydajność jest projekt podziału algorytmu na wiele kerneli. Istotne jest dobranie odpowiedniego rozmiaru grup (powinny wykorzystywać wielokrotności rozmiaru warp/wavefront) i właściwe zarządzanie pamięcią w ramach grupy. Częstym podejściem do optymalizacji programów na `GPU` jest podział problemów na kafelki rdzeni z wydzieloną dla kafelka pamięcią współdzieloną, co pozwala grupować dostępy do pamięci. Zastosowane tu podejście do kafelkowania okazało się mało skuteczne, osiągając gorszą wydajność niż prostsze metody optymalizacji, nawet pomimo wielu prób. Prawdopodobnie możliwe byłoby zaprojektowanie lepszego kafelkowania, ale używane kafelki były zbyt małe, by zysk z przyspieszenia przeważył koszty synchronizacji pamięci między elementami kafelka.

#best-diagram

#todo[
  przygotować wykres porównujący najlepsze wersje poszczególnych implementacji
]
Ostatecznie najlepsze wyniki osiągnęła wersja realizująca nieco więcej w ramach pojedynczego wątku — obliczając dwa piksele naraz (zwiększenie do czterech na wykorzystywanej karcie prowadziło do spadku wydajności) i tworząca grupy będące wielokrotnością rozmiaru wavefrontu. Osiągnięte w ten sposób ponad 589GiB/s w najlepszym wypadku znacząco zbliża się do przepustowości pamięci w używanej karcie (624GiB/s).

Takie prędkości dotyczą jedynie rdzenia Sobela. Dodając pozostałe etapy przetwarzania — transformację na skalę szarości i końcową normalizację wyników do zapisu — wydajność spada, pozostając jednak na poziomie ponad 300 razy wyższym niż oryginalna implementacja sekwencyjna.

#full-diagram