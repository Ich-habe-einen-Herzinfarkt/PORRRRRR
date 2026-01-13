#import "../utils.typ": todo, silentheading, flex-caption
#show figure: set block(breakable: true)
#show raw: set block(breakable: true)
= Implementacje tematu projektu <implementacje-tematu-projektu>
Kod źródłowy znajduje się na platformie GitHub pod linkiem: #link("https://github.com/Ich-habe-einen-Herzinfarkt/PORRRRRR")[GitHub];.

Implementacje rozdzielone są na wiele niezależnych od siebie gałęzi#footnote[Dodatkowo na gałęzi `report` znajduje się źródło tego raportu]. Implementacja wersji sekwencyjnej znajduje się na gałęzi `main`, a implementacje zrównoleglone znajdują się na odpowiednio nazwanych gałęziach: `SYCL` dla GPU (przez framework SYCL), `OpenMP` i `MPI`. Implementacje działają niezależnie od siebie, więc w celu ich uruchomienia należy sklonować odpowiednią gałąź i postępować zgodnie z `README.md` dla wybranej implementacji.

Poza tym na branchu `main` znajduje się kod benchmarku, który wykonuje testy dla sumarycznie 13 wersji implementacji na CPU i GPU.

== Wersja sekwencyjna <wersja-sekwencyjna>
Wersja sekwencyjna została zaimplementowana w języku `C++`. Cały kod znajduje się w pliku `main.cpp`.

- `ImageF` -- obrazy są przechowywane w formie wektora liczb zmiennoprzecinkowych: `vector<float>`, do którego elementów odwołujemy się indeksem wyliczanym przez funkcję `idx`
- `ImageF toGray(...)` -- funkcja konwertująca podany obraz do obrazu w odcieniach szarości
- `ImageF convolve(...)` -- funkcja nakłada operator Sobela na każdy piksel obrazu po kolei (sekwencyjnie) i zwraca obraz złożony z wyników operacji
- `vector<uint8_t> normalizeToU8(...)` -- funkcja normalizuje obraz typu `ImageF` do tablicy wartości typu `uint8_t`
- `int main(...)` -- wczytuje obraz, przeprowadza na nim operacje zgodnie z opisem operatora Sobela, a następnie zapisuje otrzymany wynik w pliku

Nasza naiwna sekwencyjna konwolucja używająca operatora Sobela wygląda następująco:
#figure(```cpp
ImageF convolve(const ImageF &in, int w, int h, const std::vector<float>& kernel, int kw, int kh){
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
```, caption: [Sekwencyjna implementacji konwolucji])


== OpenMP

OpenMP to API -- wykorzystujące głównie dyrektywy kompilatora który rozszerza -- do tworzenia programów dla systemów wielordzeniowych z dzieloną pamięcią. Pozwala ono na bardzo proste dodanie obsługi wielu wątków do programu i w naszym wypadku wymagało minimalnych modyfikacji w porównaniu do wersji sekwencyjnej.

Przykładowo w funkcji konwolucji główną zmianą -- poza dodaniem dyrektywy `#pragma omp parallel for` -- jest połączenie pętli po koordynatach `x` i `y` w jedną pętlę zrównolegloną właśnie przez OpenMP.

#figure(
  ```cpp
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
  ```, caption: [Implementacja konwolucji z użyciem OpenMP]
)

Mimo tego, przez możliwość zrównoleglenia, nastąpiła niewielka zmiana w implementacji pełnego algorytmu - wydzieliliśmy funkcję `magnitude` do obliczania wielkości gradientu, umożliwiając zrównoleglenie jej wewnętrznej pętli.


== MPI

Message Passing Interface (MPI) to standard definiujący API do przekazywania wiadomości między procesami tworzony przez MPI Forum. W praktyce jest to więc rozwiązanie niższego poziomu w porównaniu do np. OpenMP, wymagające manualnego uruchamiania procesów bez prostych abstrakcji pozwalających np. na zrównoleglenie pętli przez dodanie jednej dyrektywy `#pragma parallel for`.

Model działania MPI jest także znacząco inny niż OpenMP, nie polegając na współdzielonej pamięci, co umożliwia rozdzielenie pracy na wiele osobnych systemów. Niestety nie odbywa się to bez kosztów i poza zwiększonym skomplikowaniem API, przekazywanie wiadomości ma większy narzut wydajnościowy w porównaniu do dostępów do tej samej pamięci.

Konsekwentnie, możemy zauważyć bardziej znaczące różnice w konstrukcji programu korzystającego z MPI w porównaniu do wersji sekwencyjnej i korzystającej z OpenMP. W naszym wypadku same wykonywane kroki algorytmu nie różnią się znacząco, natomiast nastąpiła duża zmiana w sposobie ich wywoływania: wersja w MPI dzieli obraz na wiele części z użyciem metody MPI `Scatterv` i synchronizuje je między procesami -- każdy proces dostaje więc swój mały obraz na którym może pracować, a na końcu są one łączone w jedną całość z użyciem `Gatherv`.

Dodatkowo procesy w obliczeniach korzystają z wierszy obrazu, które należą do innych procesów, co skutuje potrzebą wysłania odpowiednio pierwszego i ostatniego wiersza danego fragmentu do "sąsiednich" procesów. Obsłużenie przekazywania sobie informacji między procesami powoduje kolejne opóźnienia.

Choć koncepcyjnie tego typu podejście jest dość proste -- i ma zaletę względem choćby OpenMP w formie pełnej kontroli nad tym jaki proces ma dostęp do jakich danych -- możemy zauważyć, że wymaga ono znacząco więcej kodu.

#figure(
  ```cpp
// Boradcast metadata
MPI_Bcast(&width, 1, MPI_INT, 0, MPI_COMM_WORLD);
MPI_Bcast(&height, 1, MPI_INT, 0, MPI_COMM_WORLD);
MPI_Bcast(&channels, 1, MPI_INT, 0, MPI_COMM_WORLD);

// Distribute work across processes
int rows_per_process = height / num_processes;
int remainder = height % num_processes;
int start_row = rank * rows_per_process + std::min(rank, remainder);
int end_row = start_row + rows_per_process + (rank < remainder ? 1 : 0);
int local_height = end_row - start_row;

// Send loaded image to other processes so they don't need to load them themselves
std::vector<int> sendcounts;
std::vector<int> displs;

if (rank == 0) {
    sendcounts.resize(num_processes);
    displs.resize(num_processes);

    int current_disp = 0;
    for (int r = 0; r < num_processes; r++) {
        int r_start = r * rows_per_process + std::min(r, remainder);
        int r_end = r_start + rows_per_process + (r < remainder ? 1 : 0);
        int r_h = r_end - r_start;

        sendcounts[r] = r_h * width * channels; // Note: Bytes, not pixels!
        displs[r] = current_disp;
        current_disp += sendcounts[r];
    }
}

// Receive the image
std::vector<uint8_t> local_data(width * local_height * channels);

MPI_Scatterv(
    data, sendcounts.data(), displs.data(), MPI_UNSIGNED_CHAR, // Send params
    local_data.data(), local_height * width * channels, MPI_UNSIGNED_CHAR, // Recv params
    0, MPI_COMM_WORLD // Root and Comm
);
  ```, caption: [Rozdzielenie obrazu między procesy z użyciem MPI_Scatterv]
)

#figure(
  ```cpp
// Gather results
ImageF final_result;
if (rank == 0) final_result.resize(width * height);

std::vector<int> recvcounts(num_processes);
std::vector<int> displs_v2(num_processes);
if (rank == 0) {
    int current_disp = 0;
    for (int r = 0; r < num_processes; r++) {
        // Re-calculate the layout logic for other ranks
        int r_start = r * rows_per_process + std::min(r, remainder);
        int r_end = r_start + rows_per_process + (r < remainder ? 1 : 0);
        int r_height = r_end - r_start;

        recvcounts[r] = r_height * width;
        displs_v2[r] = current_disp;
        current_disp += recvcounts[r];
    }
}

MPI_Gatherv(output.data(), local_height * width, MPI_FLOAT, final_result.data(), recvcounts.data(), displs_v2.data(), MPI_FLOAT, 0, MPI_COMM_WORLD);

  ```, caption: [Zbieranie wyników do jednego obrazu]
)

== GPU (SYCL)
Do zaimplementowania operatora Sobela na karcie graficznej wykorzystaliśmy `SYCL` --  osadzony w `C++` język do programowania heterogennego, skupiony na programowaniu `GPU` (choć z założenia ma wspierać też inne akceleratory, np. `FPGA`), utrzymywanym przez grupę Khronos. Koncepcyjnie jest inspirowany modelem `CUDA` i `HIP`, zapewniając podobne doświadczenie developerskie pisania kodu dzielonego z `C++` na hoście, używając abstrakcji na wyższym poziomie niż `Vulkan` czy `OpenCL`. Cała implementacja znajduje się w pliku `main.cpp` -- poza benchmarkiem, który został wydzielony do pliku `bench.cpp` i zawiera dodatkowe implementacje testowane w czasie prac nad ostateczną wersją.

`SYCL` opiera się na koncepcie projektowania kerneli na urządzenia (reprezentowanych jako funkcje — typowo lambdy) umieszczanych w specyficznych dla urządzenia kolejkach. Wykorzystaliśmy to, dzieląc program na trzy osobne kernele wykonywane w kolejności: przekształcenie obrazu na skalę szarości, filtr Sobela i normalizację wyników.

Typowo kernele implementowane są jako anonimowe wyrażenia lambda, do których przenieśliśmy naszą implementację zostawiając jako osobną nazwaną funkcję tylko `main`. Przykładowo, fragment kodu odpowidzialny za konwolucję w wersji SYCL wygląda następująco:

#figure(
  ```cpp
#pragma region Sobel
  // Sobel optimized for RDNA3: 128x1 work-groups, 2 pixels per work-item
  // Might need adjustment for other GPUs, especially other vendors
  int workW = (w + 1) / PIXELS_PER_WI;  
  int globalX = ((workW + WG_X - 1) / WG_X) * WG_X;
  int globalY = h;
  
  queue.parallel_for<sobel_kernel>(
      sycl::nd_range<2>(
          sycl::range<2>(globalY, globalX),
          sycl::range<2>(WG_Y, WG_X)
      ),
      [=](sycl::nd_item<2> item) {
          int y = item.get_global_id(0);
          int x0 = item.get_global_id(1) * 2;
          
          if (y >= h) return;
          
          // Process two adjacent pixels
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
#pragma endregion
  ```, caption: [Implementacja konwolucji w SYCL]
)<sycl-conv>

Poza realizacją głównej pętli jako dodanie mapującego kernela do kolejki przez `queue.parallel_for`, możemy na @sycl-conv[Programie] zauważyć znaczącą różnicę w implementacji: częściowo jest to unrolling pętli,co może pozytywnie wpłynąć także na wersję na CPU#footnote[dla kompletności wersja sekwencyjna konwolucji z tą implementacją została dodana do benchmarku], ale co ważniejsze zmiana ta pozwala każdemu z naszych rdzeni GPU pracować nad tylko małą częścią problemu (2 pikselami#footnote[Wartość 2 pikseli została znaleziona eksperymentalnie i jest specyficzna do używanego sprzętu. Bardzo możliwe, że inne architektury GPU -- w szczególności Nvidii -- lepiej sprawdzą się z inną konfiguracją rozmiaru grup i ilości pracy na grupę.]) z użyciem relatywnie prostych operacji. Pozwala to znacznie lepiej wykorzystać masywną liczbę rdzeni dostępną na procesorze graficznym niż gdybyśmy portowali wersję na CPU w bardziej naiwny sposób.

Prawdopodobnie nie jest to też optymalna implementacja#footnote[Warto też wspomnieć, że prawdopodobnie możliwe by było także wykorzystanie wbudowanych w kartę graficzną prymitywów i potencjalnie hardware'u dedykowanego do pracy z obrazami. W ramach pracy zignorowaliśmy bowiem graficzną naturę zadania, przyjmując za cel zbadanie ogólnego przypadku.] -- bardziej zaawansowanym podejściem do optymalizacji na GPU jest "kafelkowanie", gdzie grupuje się rdzenie w "kafelki" które najpierw ładują fragmenty całego zadania (tutaj nawet obrazu) do lokalnej dla grupy pamięci, a później pracują na niej bez konieczności wolnych dostępów do globalnych dla kernela danych.

Dwie główne implementacje `SYCL` to `oneAPI` od Intela i otwartoźródłowe `AdaptiveCpp`. W teorii oba kompilatory wspierają `GPU` zarówno Intela, jak i AMD oraz Nvidii, ale ze względu na problemy ze środowiskiem `oneAPI` zdecydowaliśmy się używać `AdaptiveCpp`.
