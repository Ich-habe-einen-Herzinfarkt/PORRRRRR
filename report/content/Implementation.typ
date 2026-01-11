#import "../utils.typ": todo, silentheading, flex-caption

= Implementacje tematu projektu <implementacje-tematu-projektu>
Kod źródłowy znajduje się na platformie github pod linkiem: #link("https://github.com/Ich-habe-einen-Herzinfarkt/PORRRRRR")[GitHub];.

Implementacja wersji sekwencyjnej znajduje się na branchu `main`, a implementacja zrównoleglona na branchu `SYCL`. Działają niezależnie od siebie, więc w celu ich uruchomienia należy sklonować odpowiedni branch i postępować zgodnie z `README.md` dla wybranej implementacji.

Poza tym na branchu `SYCL` znajduje się kod benchmarku, który wykonuje testy dla sumarycznie dziewięciu wariancji obu implementacji.

== Wersja sekwencyjna <wersja-sekwencyjna>
Wersja sekwencyjna została zaimplementowana w języku `C++`. Cały kod znajduje się w pliku `main.cpp`.

- `ImageF` -- obrazy są przechowywane w formie wektora liczb zmiennoprzecinkowych: `vector<float>`, do którego elementów odwołujemy się indeksem wyliczanym przez funkcję `idx`
- `ImageF toGray(...)` -- funkcja konwertująca podany obraz do obrazu w odcieniach szarości
- `ImageF convolve(...)` -- funkcja nakłada operator Sobela na każdy piksel obrazu po kolei (sekwencyjnie) i zwraca obraz złożony z wyników operacji
- `vector<uint8_t> normalizeToU8(...)` -- funkcja normalizuje obraz typu `ImageF` do tablicy wartości typu `uint8_t`
- `int main(...)` -- wczytuje obraz, przeprowadza na nim operacje zgodnie z opisem operatora Sobela, a następnie zapisuje otrzymany wynik w pliku

== Zrównoleglenie przy użyciu obliczeń na karcie graficznej <zrównoleglenie-przy-użyciu-obliczeń-na-karcie-graficznej>
Do zaimplementowania operatora Sobela pod obliczenia na karcie graficznej użyto `SYCL`, zatem kod źródłowy jest w języku `C++`. Cała implementacja znajduje się w pliku `main.cpp` -- poza benchmarkiem, który został wydzielony do pliku `bench.cpp` i zawiera dodatkowe implementacje testowane w czasie prac nad ostateczną wersją.

Wykorzystany tu `SYCL` jest osadzonym w `C++` językiem do programowania heterogennego, skupionym na programowaniu `GPU` (choć z założenia ma wspierać też inne akceleratory, np. `FPGA`), utrzymywanym przez grupę Khronos. Koncepcyjnie jest inspirowany modelem `CUDA` i `HIP`, zapewniając podobne doświadczenie developerskie pisania kodu dzielonego z `C++` na hoście, używając abstrakcji na wyższym poziomie niż `Vulkan` czy `OpenCL`.

`SYCL` opiera się na koncepcie projektowania kerneli na urządzenia (reprezentowanych jako funkcje — typowo lambdy) umieszczanych w specyficznych dla urządzenia kolejkach. Wykorzystaliśmy to, dzieląc program na trzy osobne kernele wykonywane w kolejności: przekształcenie obrazu na skalę szarości, filtr Sobela i normalizację wyników.

Dwie główne implementacje `SYCL` to `oneAPI` od Intela i otwartoźródłowe `AdaptiveCpp`. W teorii oba kompilatory wspierają `GPU` zarówno Intela, jak i AMD oraz Nvidii, ale ze względu na problemy ze środowiskiem `oneAPI` zdecydowaliśmy się używać `AdaptiveCpp`.

= Wstępne wyniki benchmarków dla dotychczasowych implementacji <wstępne-wyniki-benchmarków-dla-dotychczasowych-implementacji>
Pełne porównanie wyników działania implementacji zostanie wykonane w drugiej części projektu, gdy wszystkie trzy technologie będą miały swoje implementacje. Poniżej przedstawiamy wyniki benchmarku dla dotychczasowych implementacji: sekwencyjnej oraz korzystającej z obliczeń na `GPU`. Testy zostały przeprowadzone na komputerze z procesorem AMD Ryzen 7900X i kartą graficzną AMD Radeon RX 7800 XT. Wyniki zostały przedstawione w formie wykresu przepustowości dla każdego benchmarku oraz w formie tabeli z wynikami (umieszczona na końcu sprawozdania).

W skład testów wchodzi dziewięć wariantów implementacji: dwa pierwsze są sekwencyjne, pięć kolejnych jest po zrównolegleniu na `GPU`, a dwa ostatnie to pełny pipeline sekwencyjny oraz na `GPU`:

+ bazowa implementacja wersji sekwencyjnej

+ implementacja wersji sekwencyjnej po zoptymalizowaniu wewnętrznej pętli

+ zrównoleglona implementacja bazowej wersji sekwencyjnej: przy pomocy `SYCL` z użyciem buforów (starsza abstrakcja dzielenia pamięci między `CPU`/`GPU`)#footnote[obecnie nie rekomendowana przez gorszą wydajność — kompilator ostrzega przed jej użyciem]

+ zrównoleglona implementacja zoptymalizowanej wersji sekwencyjnej: przy pomocy `SYCL` z użyciem buforów (starsza abstrakcja dzielenia pamięci między `CPU`/`GPU`)

+ zrównoleglona implementacja zoptymalizowanej wersji sekwencyjnej: przy pomocy `SYCL` z użyciem USM (nowsza abstrakcja dzielenia pamięci między `CPU`/`GPU`)

+ zrównoleglona implementacja zoptymalizowanej wersji sekwencyjnej: przy pomocy `SYCL` i korzystająca z tilingu#footnote[podział zadania na grupy wątków \[kafelki\], gdzie każda grupa najpierw ładuje swoje dane do lokalnej pamięci, czeka na synchronizację, a później wykonuje operacje na danych]

+ zoptymalizowana zrównoleglona implementacja na USM, przetwarzająca po dwa piksele na wątek; uproszczona

+ pełne przetwarzanie obrazu na `CPU`, wliczając przetwarzanie pikseli na skalę szarości i normalizację wyniku

+ pełne przetwarzanie obrazu na `GPU` z użyciem kernela z v7

Dla każdego wariantu wykonano benchmark dla pięciu różnych rozdzielczości obrazów:
- $640 times 480$
-	$1280 times 720$
-	$1920 times 1080$
-	$3840 times 2160$
-	$7680 times 4320$
#figure(image("../images/line_graph.png"), caption: [
	Przepustowość benchmarków dla różnych rozdzielczości obrazów
])

Możemy zauważyć, że w porównaniu do wersji na GPU nasza podstawowa wersja sekwencyjna działa bardzo wolno. Nawet z optymalizacją pętli remisuje tylko z jednym wariantem `GPU` — najwolniejszym testowanym (v3), korzystającym z mniej wydajnej abstrakcji pamięci i pierwotnej implementacji Sobela. Tę przewagę widać jedynie przy najmniejszym testowanym rozmiarze obrazów, gdzie wpływ kosztów stałych implementacji na `GPU` jest większy.

Dlaczego implementacja na procesorze graficznym może osiągać tak znacząco lepsze wyniki? Jest to konsekwencja adekwatności programu do alternatywnej, znacznie bardziej równoległej architektury `GPU`.

W przeciwieństwie do procesorów, które zawierają kilka do kilkudziesięciu (obecnie do 192 w niektórych procesorach serwerowych, choć w najbliższym czasie oczekiwane jest pojawienie się na rynku procesorów z nawet 256 rdzeniami) rdzeni, każdy z dużą pamięcią podręczną i zaawansowaną logiką do przyspieszania operacji sekwencyjnych, procesory graficzne wykorzystują bardzo dużą liczbę małych rdzeni, liczoną w tysiącach nawet po stronie konsumenckiej. Pojedynczy rdzeń jest jednak bardziej ograniczony niż w przypadku `CPU` i znacznie bardziej polega się na współdzieleniu zasobów (szczególnie pamięci) między rdzeniami, grupując je zwykle nawet w najmniejszym bloku w 32 lub 64 jednostki (warp w terminologii Nvidii i wavefront w terminologii AMD).

Ta liczba rdzeni oznacza, że zadania, które łatwo jest podzielić na bardzo wiele wątków — tak jak większość operacji na grafice — możemy przyspieszyć nawet setki razy względem `CPU`.

Dlaczego więc, poza oczywistymi ograniczeniami skalowania przy wzroście liczby wątków dla naszych problemów, nie wszystkie implementacje działają znacząco szybciej i dlaczego nie wykorzystujemy `GPU` do wszystkiego? W przypadku programowania `GPU` częstym ograniczeniem wydajności są czasy dostępu do różnych poziomów pamięci. W środowisku heterogennym dochodzi potrzeba zaprojektowania sposobu przeniesienia danych z procesora na akcelerator.

Wykorzystywany tu `SYCL` zapewnia dwie abstrakcje mające to ułatwić: bufory, które zapewniają prosty interfejs programistyczny, ale okazały się trudniejsze do optymalizacji, oraz Unified Shared Memory, zapewniającą dostęp wskaźnikowy do pamięci współdzielonej i możliwość manualnego zarządzania alokacją pamięci na urządzeniach. Koszt kopiowania pamięci na urządzenie jest znaczącym stałym kosztem i ma duży wpływ na wydajność rozwiązania.

Kolejnym aspektem wpływającym na wydajność jest projekt podziału algorytmu na wiele kerneli. Istotne jest dobranie odpowiedniego rozmiaru grup (powinny wykorzystywać wielokrotności rozmiaru warp/wavefront) i właściwe zarządzanie pamięcią w ramach grupy. Częstym podejściem do optymalizacji programów na `GPU` jest podział problemów na kafelki rdzeni z wydzieloną dla kafelka pamięcią współdzieloną, co pozwala grupować dostępy do pamięci. Zastosowane tu podejście do kafelkowania okazało się mało skuteczne, osiągając gorszą wydajność niż prostsze metody optymalizacji, nawet pomimo wielu prób. Prawdopodobnie możliwe byłoby zaprojektowanie lepszego kafelkowania, ale używane kafelki były zbyt małe, by zysk z przyspieszenia przeważył koszty synchronizacji pamięci między elementami kafelka.

Ostatecznie najlepsze wyniki osiągnęła wersja realizująca nieco więcej w ramach pojedynczego wątku — obliczając dwa piksele naraz (zwiększenie do czterech na wykorzystywanej karcie prowadziło do spadku wydajności) i tworząca grupy będące wielokrotnością rozmiaru wavefrontu. Osiągnięte w ten sposób ponad 589GiB/s w najlepszym wypadku znacząco zbliża się do przepustowości pamięci w używanej karcie (624GiB/s).

Takie prędkości dotyczą jedynie rdzenia Sobela. Dodając pozostałe etapy przetwarzania — transformację na skalę szarości i końcową normalizację wyników do zapisu — wydajność spada, pozostając jednak na poziomie ponad 300 razy wyższym niż oryginalna implementacja sekwencyjna.

W ramach przyszłych testów interesujące będzie porównanie z wydajnością na wielu rdzeniach tego samego procesora.