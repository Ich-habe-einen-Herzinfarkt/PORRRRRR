#import "../utils.typ": todo, silentheading, flex-caption

#todo[
	- pozbyć się kolokwializmów
 - przygotować wykres porównujący najlepsze wersje poszczególnych implementacji
]

= Opis projektu <opis-projektu>
Projekt koncentruje się na zaimplementowaniu rozwiązania wybranego tematu w czterech wersjach: sekwencyjnej oraz zrównoleglonej w trzech różnych technologiach. Następnie wykonuje się porównanie czasu obliczeń dla przykładowych instancji problemu i przeprowadza analizę wyników.

= Opis tematu projektu <opis-tematu-projektu>
Tematem projektu jest *operacja splotu na obrazie z wykorzystaniem filtra do wykrywania krawędzi*. Ze znanych powszechnie operatorów został wybrany Sobel, który bazuje na idei Irwina Sobela oraz Gary'ego M. Feldmana przedstawionej w referacie z 1968 roku. Do wykrywania krawędzi używa się operatora dyskretnego różniczkowania i wykorzystuje się go do aproksymacji gradientu intensywności obrazu. Dzięki temu jesteśmy w stanie zlokalizować krawędzie, interpretując je jako nagłe zmiany w intensywności @automaticaddison-sobel@sobel-operator-wiki.

Operator używa dwóch jąder przekształcenia w formie macierzy $3 times 3$ o wartościach całkowitych -- jednego do aproksymacji gradientu horyzontalnych zmian w intensywności obrazu, a drugiego do aproksymacji gradientu zmian w kierunku wertykalnym. Obliczenia są wykonywane oddzielnie dla każdego piksela, a więc istnieje potencjał do ich zrównoleglenia.

Pierwszym krokiem jest konwersja obrazu do odcieni szarości, co wyznacza nam wartości intensywności dla pikseli. Następnie dla każdego z pikseli wyodrębniamy fragment obrazu w formie macierzy pikseli $3 times 3$, w którym dany piksel jest środkowym elementem. Jeśli owy fragment wykraczałby poza granice obrazu, to "wystające" elementy są uzupełniane wartościami zerowymi. Nazwijmy ową macierz $A$.

Niech $\* : upright(bold(Z))^(3 times 3) times upright(bold(Z))^(3 times 3) -> upright(bold(Z))$ to iloczyn po odpowiadających sobie elementach macierzy, a następnie suma wartości wszystkich jej elementów. Wykonujemy kolejno następujące obliczenia:
#[
  #set math.mat(delim: "[")
  $
    G_x & = mat(
                -1, 0, 1;
                -2, 0, 2;
                -1, 0, 1
            ) * A\
    G_y & = mat(
                -1, -2, -1;
                0, 0, 0;
                1, 2, 1
            ) * A\
    G   & = sqrt(G_x^2 + G_y^2)
  $
]

W ten sposób otrzymujemy nowy obraz o wymiarach pierwotnego, który ma wyższe wartości pikseli na wykrytych krawędziach.

#figure(image("../images/Bikesgray.png", width: 90%), caption: [
	obraz w odcieniach szarości@sobel-operator-wiki
])

#figure(image("../images/Bikesgraysobel.png", width: 90%), caption: [
  wynik użycia operatora Sobela@sobel-operator-wiki
])