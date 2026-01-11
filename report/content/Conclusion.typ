#import "../utils.typ": todo, silentheading, flex-caption

= Podsumowanie i wnioski
W ramach projektu zapoznaliśmy się i zaimplementowaliśmy operację splotu na obrazie z wykorzystaniem filtra do wykrywania krawędzi, bazując na filtrze Sobela.

Po stworzeniu implementacji sekwencyjnej zrównolegliliśmy działanie kodu na 3 rózne sposoby, poznając przy okazji biblioteki SYCL, OpenMP i MPI. Przy każdej metodzie zaobserwowaliśmy znaczący wzrost wydajności jaki ten algorytm wykazuje przy zrównolegleniu. 